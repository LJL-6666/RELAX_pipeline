%% 专门处理sub141的电影任务数据
%
% 使用 Neuracle readbdfdata 读取原始数据备份（与交流任务相同的方法）
% 原始数据备份包含 56 个视频段（前28个交流 + 后28个电影）
% 提取后 28 个 trigger 21/22 配对作为电影任务数据

clear all; close all; clc;

fprintf('=== 专门处理 sub141 电影任务 ===\n');
fprintf('开始时间: %s\n\n', datestr(now));

%% ==================== 路径配置 ====================
base_dir = '<TASK_ROOT>';
subject_id = '141';

% 输入路径 - 使用原始数据备份（包含完整的交流+电影数据）
backup_dir = fullfile(base_dir, '数据', '脑电', subject_id, '原始数据备份');
questionnaire_dir = fullfile(base_dir, '数据', '量表', subject_id);

% 输出目录
output_dir = fullfile(base_dir, 'RELAX输入', '电影');
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

%% ==================== 依赖库配置 ====================
fprintf('正在配置依赖库...\n');

toolbox_dir = '<TOOLBOX_ROOT>';

% EEGLAB
eeglab_path = fullfile(toolbox_dir, 'eeglab2025.1.0');
addpath(eeglab_path);
fprintf('  EEGLAB: %s\n', eeglab_path);

% FieldTrip
fieldtrip_path = fullfile(toolbox_dir, 'fieldtrip-20181205');
addpath(fieldtrip_path);
addpath(fullfile(fieldtrip_path, 'fileio'));
fprintf('  FieldTrip: %s\n', fieldtrip_path);

% Neuracle读取器
neuracle_path = fullfile(toolbox_dir, 'NeuracleEEGFileReader1.2');
addpath(neuracle_path);
fprintf('  NeuracleReader: %s\n', neuracle_path);

% 电极位置文件
cap_file = fullfile(fieldtrip_path, 'template', 'electrode', 'standard_1005.elc');
fprintf('\n');

%% ==================== 初始化EEGLAB ====================
try
    evalc('eeglab(''nogui'')');
    fprintf('EEGLAB初始化成功\n\n');
catch
    warning('EEGLAB初始化失败');
end

%% ==================== 使用Neuracle读取器读取数据 ====================
fprintf('使用Neuracle读取器读取原始数据备份...\n');
fprintf('  目录: %s\n', backup_dir);

% 使用 readbdfdata 读取（与交流任务相同的方法）
files = {'data.bdf', 'evt.bdf'};
EEG = readbdfdata(files, [backup_dir filesep]);

fprintf('  采样率: %d Hz\n', EEG.srate);
fprintf('  通道数: %d\n', EEG.nbchan);
fprintf('  数据点数: %d (%.2f 分钟)\n', EEG.pnts, EEG.pnts/EEG.srate/60);
fprintf('  事件数: %d\n', length(EEG.event));

%% ==================== 提取 trigger 21/22 事件 ====================
fprintf('\n提取 trigger 21/22 事件...\n');

trigger_21 = [];  % [latency]
trigger_22 = [];

for i = 1:length(EEG.event)
    evt_type = EEG.event(i).type;
    if isnumeric(evt_type)
        val = evt_type;
    elseif ischar(evt_type) || isstring(evt_type)
        val = str2double(evt_type);
    else
        continue;
    end
    
    if val == 21
        trigger_21(end+1) = EEG.event(i).latency;
    elseif val == 22
        trigger_22(end+1) = EEG.event(i).latency;
    end
end

fprintf('  Trigger 21: %d 个\n', length(trigger_21));
fprintf('  Trigger 22: %d 个\n', length(trigger_22));

%% ==================== 配对视频段 ====================
fprintf('\n配对视频段 (trigger 21-22)...\n');

% 排序
trigger_21 = sort(trigger_21);
trigger_22 = sort(trigger_22);

% 配对
all_video_segments = [];
for i = 1:length(trigger_21)
    start_sample = trigger_21(i);
    
    % 查找下一个 trigger 22
    next_22_idx = find(trigger_22 > start_sample, 1);
    if ~isempty(next_22_idx)
        end_sample = trigger_22(next_22_idx);
        duration_sec = (end_sample - start_sample) / EEG.srate;
        all_video_segments(end+1, :) = [start_sample, end_sample, duration_sec];
    end
end

fprintf('  配对得到 %d 个视频段\n', size(all_video_segments, 1));
fprintf('  时长范围: %.1f - %.1f 秒\n', min(all_video_segments(:, 3)), max(all_video_segments(:, 3)));

%% ==================== 提取后28个作为电影任务 ====================
fprintf('\n提取后28个视频段作为电影任务数据...\n');

total_segments = size(all_video_segments, 1);

if total_segments >= 56
    % 正常情况：56个视频段，取后28个（第29-56个）
    video_segments = all_video_segments(29:56, :);
    fprintf('  从 %d 个视频段中提取第 29-56 段（共28个）\n', total_segments);
elseif total_segments > 28
    % 取后28个
    video_segments = all_video_segments(end-27:end, :);
    fprintf('  从 %d 个视频段中提取后28个\n', total_segments);
else
    error('视频段数量不足 (%d)，无法提取电影数据', total_segments);
end

n_segments = size(video_segments, 1);
fprintf('  电影任务视频段数: %d\n', n_segments);
fprintf('  电影数据时长范围: %.1f - %.1f 秒\n', min(video_segments(:, 3)), max(video_segments(:, 3)));

%% ==================== 读取量表CSV ====================
fprintf('\n读取量表文件...\n');

csv_files = dir(fullfile(questionnaire_dir, 'exp0_*_rating.csv'));
if isempty(csv_files)
    error('未找到 exp0 量表文件');
end
csv_file = fullfile(questionnaire_dir, csv_files(1).name);
fprintf('  量表文件: %s\n', csv_file);

T = readtable(csv_file);
vid_list = T.videoIndex;
trial_vid_pairs = [(1:length(vid_list))', vid_list];

fprintf('  读取到 %d 个视频编号: %s\n', length(vid_list), mat2str(vid_list(1:min(5,length(vid_list)))'));

%% ==================== 匹配视频编号 ====================
fprintf('\n匹配视频编号...\n');

n_to_use = min(n_segments, length(vid_list));
if n_segments ~= length(vid_list)
    warning('视频段数(%d)与量表行数(%d)不匹配，使用较小值: %d', ...
        n_segments, length(vid_list), n_to_use);
end

video_segments = video_segments(1:n_to_use, :);
trial_vid_pairs = trial_vid_pairs(1:n_to_use, :);

%% ==================== 按vid排序并保存为SET文件 ====================
fprintf('\n转换为SET格式...\n');

% 按vid排序
[sorted_vids, sort_idx] = sort(trial_vid_pairs(:, 2));
trial_vid_pairs = trial_vid_pairs(sort_idx, :);
video_segments = video_segments(sort_idx, :);

saved_files = {};

for i = 1:size(video_segments, 1)
    vid = trial_vid_pairs(i, 2);
    start_sample = round(video_segments(i, 1));
    end_sample = round(video_segments(i, 2));
    
    % 确保范围有效
    start_sample = max(1, start_sample);
    end_sample = min(EEG.pnts, end_sample);
    
    % 提取该视频段的数据
    segment_data = EEG.data(:, start_sample:end_sample);
    
    % 创建新的EEG结构
    EEG_seg = eeg_emptyset();
    EEG_seg.data = segment_data;
    EEG_seg.nbchan = size(segment_data, 1);
    EEG_seg.pnts = size(segment_data, 2);
    EEG_seg.trials = 1;
    EEG_seg.srate = EEG.srate;
    EEG_seg.xmin = 0;
    EEG_seg.xmax = (EEG_seg.pnts - 1) / EEG_seg.srate;
    EEG_seg.times = (0:EEG_seg.pnts-1) / EEG_seg.srate * 1000;
    
    % 复制通道信息
    EEG_seg.chanlocs = EEG.chanlocs;
    
    % 添加电极位置
    if exist(cap_file, 'file')
        try
            EEG_seg = pop_chanedit(EEG_seg, 'lookup', cap_file);
        catch
            % 忽略
        end
    end
    
    % 添加视频标记事件
    EEG_seg.event(1).type = sprintf('vid%02d', vid);
    EEG_seg.event(1).latency = 1;
    EEG_seg.event(1).duration = 0;
    
    % 设置文件信息
    EEG_seg.setname = sprintf('sub%03d_vid%02d', str2double(subject_id), vid);
    EEG_seg.filename = sprintf('sub%03d_vid%02d.set', str2double(subject_id), vid);
    EEG_seg.filepath = output_dir;
    
    % 检查并保存
    EEG_seg = eeg_checkset(EEG_seg);
    pop_saveset(EEG_seg, 'filename', EEG_seg.filename, 'filepath', output_dir);
    
    saved_files{end+1} = fullfile(output_dir, EEG_seg.filename);
    fprintf('  [%d/%d] 保存: %s (%.1f 秒)\n', i, size(video_segments, 1), ...
        EEG_seg.filename, EEG_seg.xmax);
end

%% ==================== 完成 ====================
fprintf('\n========================================\n');
fprintf('处理完成！\n');
fprintf('结束时间: %s\n', datestr(now));
fprintf('========================================\n\n');

fprintf('成功生成 %d 个SET文件\n', length(saved_files));
fprintf('输出目录: %s\n', output_dir);
fprintf('\n下一步:\n');
fprintf('  1. 运行 RELAX_dianying_task.m 对 sub141 进行RELAX处理\n');
fprintf('  2. 运行 merge_dianying_postrelax.m 合并数据\n');
