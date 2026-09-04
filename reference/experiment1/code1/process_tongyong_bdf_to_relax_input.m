%% 处理Tongyong数据集的BDF原始数据，按视频编号对齐后作为RELAX输入
% 
% 功能：
% 1. 读取BDF格式的原始数据（data.bdf + evt.bdf）
% 2. 提取视频段（trigger 21/22配对）
% 3. 从问卷CSV读取视频编号（vid）信息
% 4. 按视频编号（而非播放顺序）对齐所有被试的数据
% 5. 转换为SET格式，作为RELAX预处理的输入
%
% 输入：
%   - BDF数据：data/data-tongyong/原始数据/可用原始数据/脑电/{ID}/data.bdf
%   - 事件文件：data/data-tongyong/原始数据/可用原始数据/脑电/{ID}/evt.bdf
%   - 问卷CSV：data/data-tongyong/原始数据/问卷/{ID}/exp1_*_rating.csv
%
% 输出：
%   - SET文件：按vid对齐后的数据，保存为 subXXX_vidYY.set
%   - 输出目录：data/data-tongyong/原始数据/可用原始数据/转化成set的脑电_aligned/
%
% Author: EEG Analysis Team
% Date: 2025-01-XX

clear all; close all; clc;

%% 路径配置
base_dir = '<DATA_ROOT>';
bdf_data_dir = fullfile(base_dir, 'data/data-tongyong/原始数据/可用原始数据/脑电');
questionnaire_dir = fullfile(base_dir, 'data/data-tongyong/原始数据/问卷');
output_dir = fullfile(base_dir, 'data/data-tongyong/原始数据/可用原始数据/转化成set的脑电_aligned');

% EEGLAB路径
eeglab_path = '<EEGLAB_ROOT>';
if exist(eeglab_path, 'dir')
    addpath(genpath(eeglab_path));
end

% FieldTrip路径
ft_path = '<FIELDTRIP_ROOT>';
if exist(ft_path, 'dir')
    addpath(ft_path);
    addpath(fullfile(ft_path, 'fileio'));
    addpath(fullfile(ft_path, 'preproc'));
    addpath(fullfile(ft_path, 'trialfun'));
end

% 电极位置文件
cap_file = '<CAPLOC_FILE>';

% 创建输出目录
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

%% 初始化EEGLAB
try
    eeglab('nogui');
catch
    warning('EEGLAB初始化失败，继续...');
end

%% 获取所有被试ID
subject_dirs = dir(bdf_data_dir);
subject_ids = {};
for i = 1:length(subject_dirs)
    if subject_dirs(i).isdir && ~strcmp(subject_dirs(i).name, '.') && ~strcmp(subject_dirs(i).name, '..')
        % 检查是否是数字目录（被试ID）
        if ~isempty(regexp(subject_dirs(i).name, '^\d+$', 'once'))
            subject_ids{end+1} = subject_dirs(i).name;
        end
    end
end
subject_ids = sort(subject_ids);

fprintf('找到 %d 个被试\n', length(subject_ids));

%% 处理每个被试
success_count = 0;
failed_subjects = {};

for sub_idx = 1:length(subject_ids)
    subject_id = subject_ids{sub_idx};
    fprintf('\n=== 处理被试 %s (%d/%d) ===\n', subject_id, sub_idx, length(subject_ids));
    
    try
        % 1. 读取问卷CSV，获取vid信息
        csv_file = find_questionnaire_csv(questionnaire_dir, subject_id);
        if isempty(csv_file)
            warning('未找到被试 %s 的问卷文件，跳过', subject_id);
            failed_subjects{end+1} = sprintf('%s: 未找到问卷文件', subject_id);
            continue;
        end
        
        [trial_vid_pairs, vid_list] = read_vid_from_csv(csv_file);
        fprintf('  读取到 %d 个视频段，vid范围: %d-%d\n', length(vid_list), min(vid_list), max(vid_list));
        
        % 2. 读取BDF数据并提取视频段
        bdf_dir = fullfile(bdf_data_dir, subject_id);
        data_bdf = fullfile(bdf_dir, 'data.bdf');
        evt_bdf = fullfile(bdf_dir, 'evt.bdf');
        
        if ~exist(data_bdf, 'file')
            warning('未找到被试 %s 的data.bdf文件，跳过', subject_id);
            failed_subjects{end+1} = sprintf('%s: 未找到data.bdf', subject_id);
            continue;
        end
        
        % 提取视频段（evt_bdf可能不存在，使用空字符串）
        if ~exist(evt_bdf, 'file')
            evt_bdf = '';
        end
        video_segments = extract_video_segments_from_bdf(data_bdf, evt_bdf);
        if isempty(video_segments)
            warning('未找到被试 %s 的视频段，跳过', subject_id);
            failed_subjects{end+1} = sprintf('%s: 未找到视频段', subject_id);
            continue;
        end
        
        fprintf('  提取到 %d 个视频段\n', length(video_segments));
        
        % 3. 建立trial到vid的映射（trial从1开始，对应CSV行号）
        if length(video_segments) ~= length(trial_vid_pairs)
            warning('视频段数量(%d)与CSV行数(%d)不匹配，使用较小的数量', ...
                length(video_segments), length(trial_vid_pairs));
            n_segments = min(length(video_segments), length(trial_vid_pairs));
            video_segments = video_segments(1:n_segments);
            trial_vid_pairs = trial_vid_pairs(1:n_segments, :);
        end
        
        % 4. 按vid从小到大排序，确保所有被试对齐
        fprintf('  按vid从小到大排序，实现对齐...\n');
        [sorted_vids, sort_idx] = sort(trial_vid_pairs(:, 2));  % 按vid列排序
        trial_vid_pairs = trial_vid_pairs(sort_idx, :);  % 排序trial_vid_pairs
        video_segments = video_segments(sort_idx);  % 同步排序video_segments
        fprintf('  排序完成，vid顺序: %s\n', mat2str(sorted_vids));
        
        % 5. 按vid对齐并转换为SET格式（此时数据已按vid排序）
        aligned_files = align_by_vid_and_convert_to_set(...
            data_bdf, video_segments, trial_vid_pairs, ...
            subject_id, output_dir, cap_file);
        
        fprintf('  ✓ 成功处理，生成 %d 个对齐后的SET文件\n', length(aligned_files));
        success_count = success_count + 1;
        
    catch ME
        warning('处理被试 %s 时出错: %s', subject_id, ME.message);
        failed_subjects{end+1} = sprintf('%s: %s', subject_id, ME.message);
        continue;
    end
end

%% 总结
fprintf('\n=== 处理完成 ===\n');
fprintf('成功: %d / %d\n', success_count, length(subject_ids));
if ~isempty(failed_subjects)
    fprintf('失败的被试:\n');
    for i = 1:length(failed_subjects)
        fprintf('  - %s\n', failed_subjects{i});
    end
end
fprintf('输出目录: %s\n', output_dir);

