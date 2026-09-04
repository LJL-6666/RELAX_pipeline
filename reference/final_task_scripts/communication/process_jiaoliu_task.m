%% 处理"交流"任务的BDF数据，转换为RELAX预处理输入
% 
% 功能：
% 1. 扫描所有被试的"交流"目录
% 2. 读取BDF格式的原始数据（data.bdf + evt.bdf）
% 3. 提取视频段（trigger 21/22配对）
% 4. 从问卷CSV读取视频编号（exp1_*_rating.csv）
% 5. 按视频编号对齐所有被试的数据
% 6. 转换为SET格式，作为RELAX预处理的输入
%
% 输入：
%   - BDF数据：数据\脑电\{ID}\交流\data.bdf
%   - 量表CSV：数据\量表\{ID}\exp1_*_rating.csv
%
% 输出：
%   - SET文件：RELAX输入\交流\subXXX_vidYY.set
%
% Author: EEG Analysis Team
% Date: 2026-01

clear all; close all; clc;

fprintf('=== 交流任务预处理脚本 ===\n');
fprintf('开始时间: %s\n\n', datestr(now));

%% ==================== 路径配置 ====================
% 基础目录
base_dir = '<TASK_ROOT>';

% 数据目录
eeg_data_dir = fullfile(base_dir, '数据', '脑电');
questionnaire_dir = fullfile(base_dir, '数据', '量表');

% 输出目录
output_dir = fullfile(base_dir, 'RELAX输入', '交流');
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
    fprintf('创建输出目录: %s\n', output_dir);
end

% 脚本目录
script_dir = fullfile(base_dir, '预处理_交流任务');

%% ==================== 依赖库配置 ====================
fprintf('正在配置依赖库...\n');

% 工具包根目录
toolbox_dir = '<TOOLBOX_ROOT>';

% EEGLAB路径（必需）
eeglab_path = fullfile(toolbox_dir, 'eeglab2025.1.0');
if exist(eeglab_path, 'dir')
    addpath(eeglab_path);
    fprintf('  EEGLAB: %s\n', eeglab_path);
    eeglab_loaded = true;
else
    error('未找到EEGLAB: %s', eeglab_path);
end

% FieldTrip路径
fieldtrip_path = fullfile(toolbox_dir, 'fieldtrip-20181205');
if exist(fieldtrip_path, 'dir')
    addpath(fieldtrip_path);
    addpath(fullfile(fieldtrip_path, 'fileio'));
    addpath(fullfile(fieldtrip_path, 'utilities'));
    addpath(fullfile(fieldtrip_path, 'preproc'));
    addpath(fullfile(fieldtrip_path, 'trialfun'));
    % Biosig支持（用于BDF读取）
    biosig_path = fullfile(fieldtrip_path, 'external', 'biosig');
    if exist(biosig_path, 'dir')
        addpath(genpath(biosig_path));
    end
    fprintf('  FieldTrip: %s\n', fieldtrip_path);
else
    error('FieldTrip路径不存在: %s', fieldtrip_path);
end

% RELAX插件路径
relax_path = fullfile(toolbox_dir, 'RELAX-RELAX-v2.0.0');
if exist(relax_path, 'dir')
    addpath(relax_path);
    fprintf('  RELAX: %s\n', relax_path);
end

% MWF插件路径
mwf_path = fullfile(toolbox_dir, 'mwf-artifact-removal');
if exist(mwf_path, 'dir')
    addpath(genpath(mwf_path));
    fprintf('  MWF: %s\n', mwf_path);
end

% PrepPipeline路径
prep_path = fullfile(toolbox_dir, 'PrepPipeline');
if exist(prep_path, 'dir')
    addpath(genpath(prep_path));
    fprintf('  PrepPipeline: %s\n', prep_path);
end

% ICLabel路径
iclabel_path = fullfile(toolbox_dir, 'ICLabel');
if exist(iclabel_path, 'dir')
    addpath(genpath(iclabel_path));
    fprintf('  ICLabel: %s\n', iclabel_path);
end

% PICARD路径
picard_path = fullfile(toolbox_dir, 'PICARD1.0');
if exist(picard_path, 'dir')
    addpath(picard_path);
    fprintf('  PICARD: %s\n', picard_path);
end

% FastICA路径
fastica_path = fullfile(toolbox_dir, 'FastICA_25');
if exist(fastica_path, 'dir')
    addpath(fastica_path);
    fprintf('  FastICA: %s\n', fastica_path);
end

% Biosig路径
biosig_path = fullfile(toolbox_dir, 'Biosig3.8.4');
if exist(biosig_path, 'dir')
    addpath(genpath(biosig_path));
    % 排除可能冲突的目录
    nan_path = fullfile(biosig_path, 'NaN');
    if exist(nan_path, 'dir')
        rmpath(genpath(nan_path));
    end
    fprintf('  Biosig: %s\n', biosig_path);
end

% Neuracle读取器路径
neuracle_path = fullfile(toolbox_dir, 'NeuracleEEGFileReader1.2');
if exist(neuracle_path, 'dir')
    addpath(neuracle_path);
    fprintf('  NeuracleReader: %s\n', neuracle_path);
end

% 电极位置文件
cap_file = fullfile(base_dir, '预处理_交流任务', 'standard_1005.elc');
if ~exist(cap_file, 'file')
    % 尝试从实验1复制
    cap_file_src = fullfile(base_dir, '实验1', 'standard_1005.elc');
    if exist(cap_file_src, 'file')
        copyfile(cap_file_src, cap_file);
        fprintf('  电极位置文件已复制\n');
    else
        % 尝试FieldTrip的标准电极文件
        cap_file_ft = fullfile(fieldtrip_path, 'template', 'electrode', 'standard_1005.elc');
        if exist(cap_file_ft, 'file')
            cap_file = cap_file_ft;
        else
            warning('电极位置文件不存在，将跳过电极位置设置');
            cap_file = '';
        end
    end
end

% 添加原始code1目录（使用原始辅助函数）
code1_path = fullfile(base_dir, '实验1', 'code1');
if exist(code1_path, 'dir')
    addpath(code1_path);
    fprintf('  辅助函数(code1): %s\n', code1_path);
end

% 添加当前脚本目录
addpath(script_dir);

fprintf('\n');

%% ==================== 初始化EEGLAB ====================
if eeglab_loaded
    try
        evalc('eeglab(''nogui'')');
        fprintf('EEGLAB初始化成功\n\n');
    catch
        warning('EEGLAB初始化失败，将使用基本功能');
    end
end

%% ==================== 扫描被试 ====================
fprintf('正在扫描被试目录...\n');

% 获取所有被试目录
subject_dirs = dir(eeg_data_dir);
subject_list = {};

for i = 1:length(subject_dirs)
    if subject_dirs(i).isdir && ~startsWith(subject_dirs(i).name, '.')
        % 检查是否是数字目录（被试ID）
        if ~isempty(regexp(subject_dirs(i).name, '^\d+$', 'once'))
            subject_id = subject_dirs(i).name;
            
            % 检查是否有"交流"子目录
            jiaoliu_dir = fullfile(eeg_data_dir, subject_id, '交流');
            if exist(jiaoliu_dir, 'dir')
                % 检查是否有data.bdf
                data_bdf = fullfile(jiaoliu_dir, 'data.bdf');
                if exist(data_bdf, 'file')
                    subject_list{end+1} = subject_id;
                end
            end
        end
    end
end

% 排序
subject_list = sort(subject_list);
fprintf('找到 %d 个有"交流"任务数据的被试\n\n', length(subject_list));

if isempty(subject_list)
    error('未找到任何有效的被试数据');
end

%% ==================== 处理每个被试 ====================
success_count = 0;
failed_subjects = {};
all_vid_info = {};  % 记录所有被试的vid信息

for sub_idx = 1:length(subject_list)
    subject_id = subject_list{sub_idx};
    fprintf('=== 处理被试 %s (%d/%d) ===\n', subject_id, sub_idx, length(subject_list));
    
    try
        %% 1. 查找量表CSV文件（使用原始code1函数）
        % 优先使用原始函数，如果不存在则使用本地函数
        if exist('find_questionnaire_csv', 'file')
            csv_file = find_questionnaire_csv(questionnaire_dir, subject_id);
        else
            csv_file = find_exp1_csv(questionnaire_dir, subject_id);
        end
        if isempty(csv_file)
            warning('未找到被试 %s 的exp1_*_rating.csv文件，跳过', subject_id);
            failed_subjects{end+1} = sprintf('%s: 未找到量表CSV', subject_id);
            continue;
        end
        fprintf('  量表文件: %s\n', csv_file);
        
        %% 2. 读取量表CSV，获取视频编号信息（使用原始code1函数）
        if exist('read_vid_from_csv', 'file')
            [trial_vid_pairs, vid_list] = read_vid_from_csv(csv_file);
        else
            [trial_vid_pairs, vid_list] = read_vid_from_rating_csv(csv_file);
        end
        if isempty(vid_list)
            warning('无法从CSV读取视频编号，跳过');
            failed_subjects{end+1} = sprintf('%s: CSV读取失败', subject_id);
            continue;
        end
        fprintf('  读取到 %d 个视频，vid范围: %d-%d\n', length(vid_list), min(vid_list), max(vid_list));
        
        %% 3. 读取BDF数据
        jiaoliu_dir = fullfile(eeg_data_dir, subject_id, '交流');
        data_bdf = fullfile(jiaoliu_dir, 'data.bdf');
        evt_bdf = fullfile(jiaoliu_dir, 'evt.bdf');
        
        if ~exist(evt_bdf, 'file')
            evt_bdf = '';
        end
        
        %% 4. 提取视频段（trigger 21/22配对）（使用原始code1函数）
        if exist('extract_video_segments_from_bdf', 'file')
            video_segments = extract_video_segments_from_bdf(data_bdf, evt_bdf);
        else
            video_segments = extract_video_segments(data_bdf, evt_bdf);
        end
        if isempty(video_segments)
            warning('未提取到视频段，跳过');
            failed_subjects{end+1} = sprintf('%s: 未找到视频段', subject_id);
            continue;
        end
        fprintf('  提取到 %d 个视频段\n', length(video_segments));
        
        %% 5. 匹配视频段与vid
        n_segments = min(length(video_segments), length(trial_vid_pairs));
        if length(video_segments) ~= length(trial_vid_pairs)
            warning('视频段数量(%d)与CSV行数(%d)不匹配，使用较小的数量', ...
                length(video_segments), length(trial_vid_pairs));
        end
        video_segments = video_segments(1:n_segments);
        trial_vid_pairs = trial_vid_pairs(1:n_segments, :);
        
        %% 6. 按vid排序（确保所有被试对齐）
        [sorted_vids, sort_idx] = sort(trial_vid_pairs(:, 2));
        trial_vid_pairs = trial_vid_pairs(sort_idx, :);
        video_segments = video_segments(sort_idx);
        
        %% 7. 转换为SET格式并保存（使用原始code1函数）
        fprintf('  正在转换为SET格式...\n');
        if exist('align_by_vid_and_convert_to_set', 'file')
            saved_files = align_by_vid_and_convert_to_set(...
                data_bdf, video_segments, trial_vid_pairs, ...
                subject_id, output_dir, cap_file);
        else
            saved_files = convert_segments_to_set(...
                data_bdf, video_segments, trial_vid_pairs, ...
                subject_id, output_dir, cap_file);
        end
        
        fprintf('  ✓ 成功生成 %d 个SET文件\n', length(saved_files));
        success_count = success_count + 1;
        
        % 记录vid信息
        all_vid_info{end+1} = struct(...
            'subject_id', subject_id, ...
            'vid_list', sorted_vids, ...
            'n_segments', length(saved_files));
        
    catch ME
        warning('处理被试 %s 时出错: %s', subject_id, ME.message);
        failed_subjects{end+1} = sprintf('%s: %s', subject_id, ME.message);
        continue;
    end
    
    fprintf('\n');
end

%% ==================== 总结 ====================
fprintf('\n========================================\n');
fprintf('处理完成！\n');
fprintf('结束时间: %s\n', datestr(now));
fprintf('========================================\n\n');

fprintf('成功: %d / %d 个被试\n', success_count, length(subject_list));

if ~isempty(failed_subjects)
    fprintf('\n失败的被试:\n');
    for i = 1:length(failed_subjects)
        fprintf('  - %s\n', failed_subjects{i});
    end
end

fprintf('\n输出目录: %s\n', output_dir);
fprintf('\n下一步: 运行RELAX预处理脚本\n');

%% 保存处理日志
log_file = fullfile(output_dir, 'processing_log.mat');
save(log_file, 'subject_list', 'success_count', 'failed_subjects', 'all_vid_info');
fprintf('日志已保存: %s\n', log_file);

