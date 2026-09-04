%% 合并多个BDF文件并处理问题被试数据
% 
% 功能：
% 1. 检测并合并多个BDF文件（data.bdf, data.1.bdf, data.2.bdf等）
% 2. 提取视频段（trigger 21/22配对）
% 3. 从问卷CSV读取视频编号（vid）信息
% 4. 按视频编号对齐数据
% 5. 转换为SET格式
%
% 输入：
%   - 问题被试ID列表：[18, 24, 26, 35, 36, 42]
%   - BDF数据：可能包含多个文件（data.bdf, data.1.bdf, data.2.bdf等）
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
base_dir = '/data/liujialing/TY';
bdf_data_dir = fullfile(base_dir, 'data/data-tongyong/原始数据/可用原始数据/脑电');
questionnaire_dir = fullfile(base_dir, 'data/data-tongyong/原始数据/问卷');
output_dir = fullfile(base_dir, 'data/data-tongyong/原始数据/可用原始数据/转化成set的脑电_aligned');

% EEGLAB路径（只添加根目录，避免路径冲突）
eeglab_path = '/data/liujialing/eeglab-develop';
if exist(eeglab_path, 'dir')
    addpath(eeglab_path);
    % 让EEGLAB自己添加必要的路径
    try
        eeglab('nogui');
    catch
        % 如果eeglab还没初始化，继续
    end
end

% FieldTrip路径
ft_path = '/data/liujialing/TY/预处理/matlab/fieldtrip-20181205';
if exist(ft_path, 'dir')
    addpath(ft_path);
    addpath(fullfile(ft_path, 'fileio'));
    addpath(fullfile(ft_path, 'preproc'));
    addpath(fullfile(ft_path, 'trialfun'));
    addpath(fullfile(ft_path, 'utilities'));  % 添加utilities目录（包含ft_setopt等函数）
end

% 电极位置文件
cap_file = '/data/liujialing/TY/预处理/matlab/配置环境/standard_1005.elc';

% 添加当前目录到路径（使用辅助函数）
code_dir = fileparts(mfilename('fullpath'));
addpath(code_dir);
parent_dir = fileparts(code_dir);  % 父目录（code1）
addpath(parent_dir);  % 添加父目录以使用辅助函数（find_questionnaire_csv, read_vid_from_csv等）

% 创建输出目录
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

%% 初始化EEGLAB（在添加路径后）
% 注意：eeglab会自动添加必要的子路径，避免使用genpath导致冲突
try
    if ~exist('eeglab', 'file')
        % 如果eeglab不在路径中，尝试初始化
        eeglab('nogui');
    end
catch
    warning('EEGLAB初始化失败，继续...');
end

%% 问题被试ID列表
problem_subjects = {'18', '24', '26', '35', '36', '42'};

fprintf('找到 %d 个问题被试需要处理\n', length(problem_subjects));

%% 处理每个问题被试
success_count = 0;
failed_subjects = {};

for sub_idx = 1:length(problem_subjects)
    subject_id = problem_subjects{sub_idx};
    fprintf('\n=== 处理问题被试 %s (%d/%d) ===\n', subject_id, sub_idx, length(problem_subjects));
    
    try
        % 1. 查找所有BDF文件
        bdf_dir = fullfile(bdf_data_dir, subject_id);
        bdf_files = dir(fullfile(bdf_dir, 'data*.bdf'));
        bdf_files = {bdf_files.name};
        
        % 排序：data.bdf, data.1.bdf, data.2.bdf, ...
        [bdf_files, sort_idx] = sort_natural(bdf_files);
        
        fprintf('  找到 %d 个BDF文件:\n', length(bdf_files));
        for i = 1:length(bdf_files)
            fprintf('    - %s\n', bdf_files{i});
        end
        
        % 构建完整路径
        bdf_file_paths = cell(size(bdf_files));
        for i = 1:length(bdf_files)
            bdf_file_paths{i} = fullfile(bdf_dir, bdf_files{i});
        end
        
        % 2. 读取问卷CSV，获取vid信息
        csv_file = find_questionnaire_csv(questionnaire_dir, subject_id);
        if isempty(csv_file)
            warning('未找到被试 %s 的问卷文件，跳过', subject_id);
            failed_subjects{end+1} = sprintf('%s: 未找到问卷文件', subject_id);
            continue;
        end
        
        [trial_vid_pairs, vid_list] = read_vid_from_csv(csv_file);
        fprintf('  读取到 %d 个视频段，vid范围: %d-%d\n', length(vid_list), min(vid_list), max(vid_list));
        
        % 3. 合并多个BDF文件并提取视频段
        % 使用FieldTrip的cell数组方式读取多个文件
        fprintf('  合并多个BDF文件...\n');
        video_segments = extract_video_segments_from_multiple_bdf(bdf_file_paths);
        
        if isempty(video_segments)
            warning('未找到被试 %s 的视频段，跳过', subject_id);
            failed_subjects{end+1} = sprintf('%s: 未找到视频段', subject_id);
            continue;
        end
        
        fprintf('  提取到 %d 个视频段\n', length(video_segments));
        
        % 4. 建立trial到vid的映射（trial从1开始，对应CSV行号）
        if length(video_segments) ~= length(trial_vid_pairs)
            warning('视频段数量(%d)与CSV行数(%d)不匹配，使用较小的数量', ...
                length(video_segments), length(trial_vid_pairs));
            n_segments = min(length(video_segments), length(trial_vid_pairs));
            video_segments = video_segments(1:n_segments);
            trial_vid_pairs = trial_vid_pairs(1:n_segments, :);
        end
        
        % 5. 按vid从小到大排序，确保所有被试对齐
        fprintf('  按vid从小到大排序，实现对齐...\n');
        [sorted_vids, sort_idx] = sort(trial_vid_pairs(:, 2));  % 按vid列排序
        trial_vid_pairs = trial_vid_pairs(sort_idx, :);  % 排序trial_vid_pairs
        video_segments = video_segments(sort_idx);  % 同步排序video_segments
        fprintf('  排序完成，vid顺序: %s\n', mat2str(sorted_vids));
        
        % 6. 按vid对齐并转换为SET格式（使用合并后的BDF文件列表）
        aligned_files = align_by_vid_and_convert_to_set_multiple_bdf(...
            bdf_file_paths, video_segments, trial_vid_pairs, ...
            subject_id, output_dir, cap_file);
        
        fprintf('  ✓ 成功处理，生成 %d 个对齐后的SET文件\n', length(aligned_files));
        success_count = success_count + 1;
        
    catch ME
        warning('处理被试 %s 时出错: %s', subject_id, ME.message);
        failed_subjects{end+1} = sprintf('%s: %s', subject_id, ME.message);
        if ~isempty(ME.stack)
            fprintf('  错误位置: %s (第 %d 行)\n', ME.stack(1).name, ME.stack(1).line);
        end
        continue;
    end
end

%% 总结
fprintf('\n=== 处理完成 ===\n');
fprintf('成功: %d / %d\n', success_count, length(problem_subjects));
if ~isempty(failed_subjects)
    fprintf('失败的被试:\n');
    for i = 1:length(failed_subjects)
        fprintf('  - %s\n', failed_subjects{i});
    end
end
fprintf('输出目录: %s\n', output_dir);

%% 辅助函数：自然排序
function [sorted, idx] = sort_natural(cell_array)
    % 自然排序：data.bdf, data.1.bdf, data.2.bdf, data.10.bdf
    % 而不是：data.1.bdf, data.10.bdf, data.2.bdf
    
    % 提取数字部分
    numbers = zeros(size(cell_array));
    for i = 1:length(cell_array)
        name = cell_array{i};
        % 查找 data. 后面的数字
        match = regexp(name, 'data\.(\d+)\.bdf', 'tokens');
        if ~isempty(match)
            numbers(i) = str2double(match{1}{1});
        else
            % data.bdf 设为 0
            numbers(i) = 0;
        end
    end
    
    [~, idx] = sort(numbers);
    sorted = cell_array(idx);
end

