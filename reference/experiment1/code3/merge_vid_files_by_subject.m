%% 合并同一被试的所有vid文件为一个文件
% 
% 功能：将RELAX处理后的同一被试的所有vid文件按vid顺序合并为一个文件
% 保留事件信息，方便后续按vid提取视频段
% 
% 输入：
%   - RELAX处理后的文件：RELAXProcessed/Cleaned_Data/subXXX_vidYY_RELAX.set
% 
% 输出：
%   - 合并后的文件：RELAXProcessed/Cleaned_Data_Merged/subXXX_RELAX_merged.set
% 
% Author: EEG Analysis Team
% Date: 2025-01-XX

clear all; close all; clc;

%% ========== 路径配置 ==========
base_dir = '/data/liujialing/TY';
input_dir = fullfile(base_dir, 'data/data-tongyong/原始数据/可用原始数据/转化成set的脑电_aligned/RELAXProcessed/Cleaned_Data');
output_dir = fullfile(base_dir, 'data/data-tongyong/原始数据/可用原始数据/转化成set的脑电_aligned/RELAXProcessed/Cleaned_Data_Merged');

% EEGLAB路径
eeglab_path = '/data/liujialing/eeglab-develop';
if exist(eeglab_path, 'dir')
    addpath(eeglab_path);
    try
        eeglab('nogui');
    catch
        warning('EEGLAB初始化失败，继续...');
    end
end

% 创建输出目录
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

%% ========== 获取所有被试ID ==========
cd(input_dir);
all_files = dir('*_RELAX.set');
if isempty(all_files)
    error('未找到RELAX处理后的文件！请检查路径：%s', input_dir);
end

% 提取所有唯一的被试ID
subject_ids = {};
for i = 1:length(all_files)
    filename = all_files(i).name;
    % 文件名格式：subXXX_vidYY_RELAX.set
    parts = strsplit(filename, '_');
    if length(parts) >= 2
        subject_id = parts{1}; % subXXX
        if ~ismember(subject_id, subject_ids)
            subject_ids{end+1} = subject_id;
        end
    end
end

subject_ids = sort(subject_ids);
fprintf('找到 %d 个被试需要合并\n', length(subject_ids));

%% ========== 处理每个被试 ==========
success_count = 0;
failed_subjects = {};

for sub_idx = 1:length(subject_ids)
    subject_id = subject_ids{sub_idx};
    fprintf('\n=== 处理被试 %s (%d/%d) ===\n', subject_id, sub_idx, length(subject_ids));
    
    try
        % 1. 查找该被试的所有vid文件
        pattern = [subject_id '_vid*_RELAX.set'];
        vid_files = dir(fullfile(input_dir, pattern));
        
        if isempty(vid_files)
            warning('未找到被试 %s 的vid文件，跳过', subject_id);
            failed_subjects{end+1} = sprintf('%s: 未找到vid文件', subject_id);
            continue;
        end
        
        % 2. 提取vid编号并排序
        vid_numbers = [];
        vid_file_list = {};
        for i = 1:length(vid_files)
            filename = vid_files(i).name;
            % 文件名格式：subXXX_vidYY_RELAX.set
            parts = strsplit(filename, '_');
            if length(parts) >= 3
                vid_str = parts{2}; % vidYY
                vid_num = str2double(vid_str(4:end)); % 提取YY
                if ~isnan(vid_num)
                    vid_numbers(end+1) = vid_num;
                    vid_file_list{end+1} = filename;
                end
            end
        end
        
        % 按vid编号排序
        [sorted_vids, sort_idx] = sort(vid_numbers);
        vid_file_list = vid_file_list(sort_idx);
        
        fprintf('  找到 %d 个vid文件，vid范围: %d-%d\n', length(vid_file_list), min(sorted_vids), max(sorted_vids));
        
        % 3. 按顺序加载并合并文件
        EEG_merged = [];
        total_samples = 0;
        
        for vid_idx = 1:length(vid_file_list)
            vid = sorted_vids(vid_idx);
            filename = vid_file_list{vid_idx};
            filepath = fullfile(input_dir, filename);
            
            fprintf('  加载 vid%02d: %s\n', vid, filename);
            EEG = pop_loadset('filename', filename, 'filepath', input_dir);
            
            % 确保事件信息包含vid标记
            % 检查是否已有vid标记事件（检查videoIndex字段或type字段）
            has_vid_marker = false;
            if isfield(EEG, 'event') && ~isempty(EEG.event)
                for e = 1:length(EEG.event)
                    % 检查videoIndex字段（原始SET文件中的字段）
                    if isfield(EEG.event(e), 'videoIndex') && EEG.event(e).videoIndex == vid
                        has_vid_marker = true;
                        break;
                    end
                    % 检查type字段
                    if isfield(EEG.event(e), 'type')
                        if strcmp(EEG.event(e).type, 'videoStart') || ...
                           strcmp(EEG.event(e).type, sprintf('vid%02d', vid))
                            has_vid_marker = true;
                            break;
                        end
                    end
                end
            end
            
            % 如果没有vid标记，在数据开始处添加一个事件
            if ~has_vid_marker
                if isempty(EEG.event)
                    EEG.event = struct('type', {}, 'latency', {}, 'duration', {}, 'videoIndex', {}, 'vid', {});
                end
                % 在数据开始处添加vid标记事件
                vid_event = struct();
                vid_event.type = sprintf('vid%02d', vid); % 类型：vid01, vid02, ...
                vid_event.latency = 1; % 第一个采样点
                vid_event.duration = 0;
                vid_event.videoIndex = vid; % 保留原始字段名
                vid_event.vid = vid; % 添加新字段名（方便后续提取）
                if isfield(EEG.event, 'urevent')
                    vid_event.urevent = length(EEG.event) + 1;
                end
                EEG.event(end+1) = vid_event;
            else
                % 如果已有事件，确保vid信息存在（同时设置videoIndex和vid字段）
                for e = 1:length(EEG.event)
                    if isfield(EEG.event(e), 'videoIndex') && EEG.event(e).videoIndex == vid
                        % 确保vid字段也存在
                        if ~isfield(EEG.event(e), 'vid')
                            EEG.event(e).vid = vid;
                        end
                    elseif ~isfield(EEG.event(e), 'videoIndex') && ~isfield(EEG.event(e), 'vid')
                        % 如果都没有，添加vid信息
                        EEG.event(e).videoIndex = vid;
                        EEG.event(e).vid = vid;
                    end
                end
            end
            
            % 调整后续事件的latency（相对于合并后的时间轴）
            if ~isempty(EEG.event)
                for e = 1:length(EEG.event)
                    EEG.event(e).latency = EEG.event(e).latency + total_samples;
                end
            end
            
            % 合并数据
            if isempty(EEG_merged)
                EEG_merged = EEG;
                total_samples = EEG.pnts;
            else
                % 合并数据矩阵
                EEG_merged.data = [EEG_merged.data, EEG.data];
                EEG_merged.pnts = size(EEG_merged.data, 2);
                total_samples = EEG_merged.pnts;
                
                % 合并事件
                if ~isempty(EEG.event)
                    EEG_merged.event = [EEG_merged.event, EEG.event];
                end
                
                % 更新其他字段
                EEG_merged.times = (0:EEG_merged.pnts-1) / EEG_merged.srate * 1000; % 毫秒
            end
            
            fprintf('    vid%02d: %d 采样点, %.2f 秒\n', vid, EEG.pnts, EEG.pnts/EEG.srate);
        end
        
        % 4. 更新合并后的EEG结构
        EEG_merged.xmax = (EEG_merged.pnts - 1) / EEG_merged.srate;
        EEG_merged.times = (0:EEG_merged.pnts-1) / EEG_merged.srate * 1000; % 毫秒
        
        % 添加合并信息到EEG结构
        EEG_merged.merged_info = struct();
        EEG_merged.merged_info.subject_id = subject_id;
        EEG_merged.merged_info.vid_list = sorted_vids;
        EEG_merged.merged_info.vid_count = length(sorted_vids);
        EEG_merged.merged_info.total_duration = EEG_merged.pnts / EEG_merged.srate;
        
        % 5. 保存合并后的文件
        output_filename = sprintf('%s_RELAX_merged.set', subject_id);
        output_filepath = fullfile(output_dir, output_filename);
        
        fprintf('  保存合并后的文件: %s\n', output_filename);
        fprintf('  总采样点: %d, 总时长: %.2f 秒\n', EEG_merged.pnts, EEG_merged.pnts/EEG_merged.srate);
        
        EEG_merged = eeg_checkset(EEG_merged);
        pop_saveset(EEG_merged, 'filename', output_filename, 'filepath', output_dir);
        
        success_count = success_count + 1;
        fprintf('  ✓ 成功合并，包含 %d 个vid\n', length(sorted_vids));
        
    catch ME
        warning('处理被试 %s 时出错: %s', subject_id, ME.message);
        failed_subjects{end+1} = sprintf('%s: %s', subject_id, ME.message);
    end
end

%% ========== 总结 ==========
fprintf('\n=== 处理完成 ===\n');
fprintf('成功: %d / %d\n', success_count, length(subject_ids));
if ~isempty(failed_subjects)
    fprintf('失败的被试:\n');
    for i = 1:length(failed_subjects)
        fprintf('  - %s\n', failed_subjects{i});
    end
end
fprintf('输出目录: %s\n', output_dir);

