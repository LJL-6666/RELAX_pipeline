%% 处理"电影"任务的BDF数据，转换为RELAX预处理输入
% 
% 功能：
% 1. 扫描所有被试的"电影"目录
% 2. 读取BDF格式的原始数据（data.bdf + evt.bdf）
% 3. 提取视频段（trigger 21/22配对）
% 4. 从问卷CSV读取视频编号（exp0_*_rating.csv）
% 5. 按视频编号对齐所有被试的数据
% 6. 转换为SET格式，作为RELAX预处理的输入
%
% 输入：
%   - BDF数据：数据\脑电\{ID}\电影\data.bdf
%   - 量表CSV：数据\量表\{ID}\exp0_*_rating.csv
%
% 输出：
%   - SET文件：RELAX输入\电影\subXXX_vidYY.set

clear all; close all; clc;

fprintf('=== 电影任务预处理脚本 ===\n');
fprintf('开始时间: %s\n\n', datestr(now));

%% ==================== 路径配置 ====================
base_dir = 'E:\ljl\work\通用\RELAX_update\归档\新预处理';
eeg_data_dir = fullfile(base_dir, '数据', '脑电');
questionnaire_dir = fullfile(base_dir, '数据', '量表');

% 输出目录
output_dir = fullfile(base_dir, 'RELAX输入', '电影');
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
    fprintf('创建输出目录: %s\n', output_dir);
end

script_dir = fullfile(base_dir, '预处理_电影任务');

%% ==================== 依赖库配置 ====================
fprintf('正在配置依赖库...\n');

toolbox_dir = 'D:\APP\matlab\bao';

% EEGLAB
eeglab_path = fullfile(toolbox_dir, 'eeglab2025.1.0');
if exist(eeglab_path, 'dir')
    addpath(eeglab_path);
    fprintf('  EEGLAB: %s\n', eeglab_path);
    eeglab_loaded = true;
else
    error('未找到EEGLAB: %s', eeglab_path);
end

% FieldTrip
fieldtrip_path = fullfile(toolbox_dir, 'fieldtrip-20181205');
if exist(fieldtrip_path, 'dir')
    addpath(fieldtrip_path);
    addpath(fullfile(fieldtrip_path, 'fileio'));
    addpath(fullfile(fieldtrip_path, 'utilities'));
    addpath(fullfile(fieldtrip_path, 'preproc'));
    addpath(fullfile(fieldtrip_path, 'trialfun'));
    biosig_path = fullfile(fieldtrip_path, 'external', 'biosig');
    if exist(biosig_path, 'dir')
        addpath(genpath(biosig_path));
    end
    fprintf('  FieldTrip: %s\n', fieldtrip_path);
else
    error('FieldTrip路径不存在: %s', fieldtrip_path);
end

% RELAX
relax_path = fullfile(toolbox_dir, 'RELAX-RELAX-v2.0.0');
if exist(relax_path, 'dir')
    addpath(relax_path);
    fprintf('  RELAX: %s\n', relax_path);
end

% MWF
mwf_path = fullfile(toolbox_dir, 'mwf-artifact-removal');
if exist(mwf_path, 'dir')
    addpath(genpath(mwf_path));
    fprintf('  MWF: %s\n', mwf_path);
end

% PrepPipeline
prep_path = fullfile(toolbox_dir, 'PrepPipeline');
if exist(prep_path, 'dir')
    addpath(genpath(prep_path));
    fprintf('  PrepPipeline: %s\n', prep_path);
end

% ICLabel
iclabel_path = fullfile(toolbox_dir, 'ICLabel');
if exist(iclabel_path, 'dir')
    addpath(genpath(iclabel_path));
    fprintf('  ICLabel: %s\n', iclabel_path);
end

% PICARD
picard_path = fullfile(toolbox_dir, 'PICARD1.0');
if exist(picard_path, 'dir')
    addpath(picard_path);
    fprintf('  PICARD: %s\n', picard_path);
end

% FastICA
fastica_path = fullfile(toolbox_dir, 'FastICA_25');
if exist(fastica_path, 'dir')
    addpath(fastica_path);
    fprintf('  FastICA: %s\n', fastica_path);
end

% Biosig
biosig_path = fullfile(toolbox_dir, 'Biosig3.8.4');
if exist(biosig_path, 'dir')
    addpath(genpath(biosig_path));
    nan_path = fullfile(biosig_path, 'NaN');
    if exist(nan_path, 'dir')
        rmpath(genpath(nan_path));
    end
    fprintf('  Biosig: %s\n', biosig_path);
end

% Neuracle
neuracle_path = fullfile(toolbox_dir, 'NeuracleEEGFileReader1.2');
if exist(neuracle_path, 'dir')
    addpath(neuracle_path);
    fprintf('  NeuracleReader: %s\n', neuracle_path);
end

% 电极位置文件
cap_file = fullfile(fieldtrip_path, 'template', 'electrode', 'standard_1005.elc');
if ~exist(cap_file, 'file')
    warning('电极位置文件不存在，将跳过电极位置设置');
    cap_file = '';
end

% 添加code1目录（包括子目录）
code1_path = fullfile(base_dir, '实验1', 'code1');
if exist(code1_path, 'dir')
    addpath(code1_path);
    fprintf('  辅助函数(code1): %s\n', code1_path);
    % 添加问题数据处理子目录（包含extract_video_segments_from_multiple_bdf）
    problem_data_path = fullfile(code1_path, '问题数据处理');
    if exist(problem_data_path, 'dir')
        addpath(problem_data_path);
        fprintf('  问题数据处理函数: %s\n', problem_data_path);
    end
end

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

subject_dirs = dir(eeg_data_dir);
subject_list = {};

for i = 1:length(subject_dirs)
    if subject_dirs(i).isdir && ~startsWith(subject_dirs(i).name, '.')
        if ~isempty(regexp(subject_dirs(i).name, '^\d+$', 'once'))
            subject_id = subject_dirs(i).name;
            
            % 检查是否有"电影"子目录
            dianying_dir = fullfile(eeg_data_dir, subject_id, '电影');
            if exist(dianying_dir, 'dir')
                data_bdf = fullfile(dianying_dir, 'data.bdf');
                if exist(data_bdf, 'file')
                    subject_list{end+1} = subject_id;
                end
            end
        end
    end
end

subject_list = sort(subject_list);
fprintf('找到 %d 个有"电影"任务数据的被试\n\n', length(subject_list));

if isempty(subject_list)
    error('未找到任何有效的被试数据');
end

%% ==================== 处理每个被试 ====================
success_count = 0;
failed_subjects = {};
all_vid_info = {};

for sub_idx = 1:length(subject_list)
    subject_id = subject_list{sub_idx};
    fprintf('=== 处理被试 %s (%d/%d) ===\n', subject_id, sub_idx, length(subject_list));
    
    % 检查是否已处理过（检查输出目录中是否有该被试的SET文件）
    % 注意：文件名格式是 sub%03d_vid%02d.set，所以需要格式化被试ID
    sub_str = sprintf('sub%03d', str2double(subject_id));
    existing_files = dir(fullfile(output_dir, sprintf('%s_vid*.set', sub_str)));
    if ~isempty(existing_files)
        fprintf('  已存在 %d 个SET文件，跳过\n', length(existing_files));
        success_count = success_count + 1;
        continue;
    end
    
    try
        %% 1. 查找量表CSV文件（电影任务使用exp0_*_rating.csv）
        csv_file = find_exp0_csv(questionnaire_dir, subject_id);
        if isempty(csv_file)
            warning('未找到被试 %s 的exp0_*_rating.csv文件，跳过', subject_id);
            failed_subjects{end+1} = sprintf('%s: 未找到量表CSV', subject_id);
            continue;
        end
        fprintf('  量表文件: %s\n', csv_file);
        
        %% 2. 读取量表CSV，获取视频编号信息
        if exist('read_vid_from_csv', 'file')
            [trial_vid_pairs, vid_list] = read_vid_from_csv(csv_file);
        else
            error('未找到read_vid_from_csv函数，请确保code1目录已添加到路径');
        end
        if isempty(vid_list)
            warning('无法从CSV读取视频编号，跳过');
            failed_subjects{end+1} = sprintf('%s: CSV读取失败', subject_id);
            continue;
        end
        fprintf('  读取到 %d 个视频，vid范围: %d-%d\n', length(vid_list), min(vid_list), max(vid_list));
        
        %% 3. 查找所有BDF文件（支持多个BDF文件）
        dianying_dir = fullfile(eeg_data_dir, subject_id, '电影');
        
        % 查找所有data*.bdf文件（data.bdf, data.1.bdf, data.2.bdf等）
        bdf_files = dir(fullfile(dianying_dir, 'data*.bdf'));
        if isempty(bdf_files)
            warning('未找到BDF文件，跳过');
            failed_subjects{end+1} = sprintf('%s: 未找到BDF文件', subject_id);
            continue;
        end
        
        % 按文件名排序（确保顺序正确：data.bdf, data.1.bdf, data.2.bdf...）
        file_names = {bdf_files.name};
        % 提取数字部分进行自然排序
        numbers = zeros(size(file_names));
        for i = 1:length(file_names)
            name = file_names{i};
            match = regexp(name, 'data\.(\d+)\.bdf', 'tokens');
            if ~isempty(match)
                numbers(i) = str2double(match{1}{1});
            else
                numbers(i) = 0;  % data.bdf 设为 0
            end
        end
        [~, sort_idx] = sort(numbers);
        bdf_files = bdf_files(sort_idx);
        
        % 构建BDF文件路径列表
        bdf_file_paths = cell(length(bdf_files), 1);
        for i = 1:length(bdf_files)
            bdf_file_paths{i} = fullfile(dianying_dir, bdf_files(i).name);
        end
        
        fprintf('  找到 %d 个BDF文件: %s\n', length(bdf_files), strjoin({bdf_files.name}, ', '));
        
        % 主BDF文件（用于读取数据，如果有多个文件，FieldTrip会自动合并）
        if length(bdf_file_paths) > 1
            % 多个文件时，使用第一个作为主文件，但会在提取视频段时合并
            data_bdf = bdf_file_paths;  % 传入cell数组
        else
            data_bdf = bdf_file_paths{1};  % 单个文件，传入字符串
        end
        
        %% 4. 提取视频段（支持多个BDF文件合并）
        if length(bdf_file_paths) > 1
            % 多个BDF文件，使用合并函数
            if exist('extract_video_segments_from_multiple_bdf', 'file')
                fprintf('  使用多文件合并模式提取视频段...\n');
                video_segments = extract_video_segments_from_multiple_bdf(bdf_file_paths);
            else
                error('未找到extract_video_segments_from_multiple_bdf函数，请确保code1目录已添加到路径');
            end
        else
            % 单个BDF文件
            evt_bdf = fullfile(dianying_dir, 'evt.bdf');
            if ~exist(evt_bdf, 'file')
                evt_bdf = '';
            end
            if exist('extract_video_segments_from_bdf', 'file')
                video_segments = extract_video_segments_from_bdf(data_bdf, evt_bdf);
            else
                error('未找到extract_video_segments_from_bdf函数');
            end
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
        
        %% 6. 按vid排序
        [sorted_vids, sort_idx] = sort(trial_vid_pairs(:, 2));
        trial_vid_pairs = trial_vid_pairs(sort_idx, :);
        video_segments = video_segments(sort_idx);
        
        %% 7. 转换为SET格式
        fprintf('  正在转换为SET格式...\n');
        if exist('align_by_vid_and_convert_to_set', 'file')
            % align_by_vid_and_convert_to_set现在支持cell数组（多个BDF文件）
            saved_files = align_by_vid_and_convert_to_set(...
                data_bdf, video_segments, trial_vid_pairs, ...
                subject_id, output_dir, cap_file);
        else
            error('未找到align_by_vid_and_convert_to_set函数');
        end
        
        fprintf('  ✓ 成功生成 %d 个SET文件\n', length(saved_files));
        success_count = success_count + 1;
        
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
fprintf('\n下一步: 运行RELAX_dianying_task.m\n');

log_file = fullfile(output_dir, 'processing_log.mat');
save(log_file, 'subject_list', 'success_count', 'failed_subjects', 'all_vid_info');
fprintf('日志已保存: %s\n', log_file);

%% ==================== 辅助函数 ====================
function csv_file = find_exp0_csv(questionnaire_dir, subject_id)
    % 查找exp0_*_rating.csv文件（电影任务）
    csv_file = '';
    subject_dir = fullfile(questionnaire_dir, subject_id);
    if ~exist(subject_dir, 'dir')
        return;
    end
    
    files = dir(fullfile(subject_dir, 'exp0_*_rating.csv'));
    if ~isempty(files)
        csv_file = fullfile(subject_dir, files(1).name);
    end
end

