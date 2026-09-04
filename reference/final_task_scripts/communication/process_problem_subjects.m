%% 补充处理问题被试（112、131、141）
% 
% 问题被试：
% - 100: 数据已删除，无法处理
% - 112: 有多个BDF文件需要合并
% - 131: 原目录名是"人际"已改为"交流"，需要重新处理
% - 141: BDF在备份目录，需要复制后处理
%
% 功能：
% 1. 跳过已处理的被试（除非强制重新处理）
% 2. 特殊处理这些问题数据

clear all; close all; clc;

fprintf('=== 补充处理问题被试 ===\n');
fprintf('开始时间: %s\n\n', datestr(now));

%% ==================== 路径配置 ====================
base_dir = '<TASK_ROOT>';
eeg_data_dir = fullfile(base_dir, '数据', '脑电');
questionnaire_dir = fullfile(base_dir, '数据', '量表');
output_dir = fullfile(base_dir, 'RELAX输入', '交流');
script_dir = fullfile(base_dir, '预处理_交流任务');

%% ==================== 依赖库配置 ====================
fprintf('正在配置依赖库...\n');
toolbox_dir = '<TOOLBOX_ROOT>';

% EEGLAB
eeglab_path = fullfile(toolbox_dir, 'eeglab2025.1.0');
if exist(eeglab_path, 'dir')
    addpath(eeglab_path);
    fprintf('  EEGLAB: %s\n', eeglab_path);
end

% FieldTrip
fieldtrip_path = fullfile(toolbox_dir, 'fieldtrip-20181205');
if exist(fieldtrip_path, 'dir')
    addpath(fieldtrip_path);
    addpath(fullfile(fieldtrip_path, 'fileio'));
    addpath(fullfile(fieldtrip_path, 'utilities'));
    addpath(fullfile(fieldtrip_path, 'preproc'));
    fprintf('  FieldTrip: %s\n', fieldtrip_path);
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

% 原始code1辅助函数
code1_path = fullfile(base_dir, '实验1', 'code1');
if exist(code1_path, 'dir')
    addpath(code1_path);
    fprintf('  code1: %s\n', code1_path);
end

% 当前脚本目录
addpath(script_dir);

% 初始化EEGLAB
try
    evalc('eeglab(''nogui'')');
    fprintf('  EEGLAB初始化成功\n');
catch
    warning('EEGLAB初始化失败');
end

fprintf('\n');

%% ==================== 电极位置文件 ====================
cap_file = fullfile(fieldtrip_path, 'template', 'electrode', 'standard_1005.elc');
if ~exist(cap_file, 'file')
    cap_file = '';
end

%% ==================== 问题被试列表 ====================
problem_subjects = {'112', '131', '141'};
% 100已删除，无法处理

fprintf('待处理的问题被试: %s\n\n', strjoin(problem_subjects, ', '));

%% ==================== 处理被试131（目录已重命名） ====================
fprintf('========================================\n');
fprintf('处理被试 131（目录已从"人际"改为"交流"）\n');
fprintf('========================================\n');

subject_id = '131';
jiaoliu_dir = fullfile(eeg_data_dir, subject_id, '交流');

% 强制重新处理131（删除已有文件）
existing_files = dir(fullfile(output_dir, sprintf('sub%s_vid*.set', subject_id)));
if ~isempty(existing_files)
    fprintf('  删除已有的 %d 个旧文件...\n', length(existing_files));
    for i = 1:length(existing_files)
        delete(fullfile(output_dir, existing_files(i).name));
    end
end

% 检查交流目录是否存在
if exist(jiaoliu_dir, 'dir')
    data_bdf = fullfile(jiaoliu_dir, 'data.bdf');
    if exist(data_bdf, 'file')
        try
            process_single_subject(subject_id, eeg_data_dir, questionnaire_dir, output_dir, cap_file);
            fprintf('  ✓ 被试 %s 处理完成\n\n', subject_id);
        catch ME
            fprintf('  ✗ 被试 %s 处理失败: %s\n\n', subject_id, ME.message);
        end
    else
        fprintf('  ✗ 被试 %s 的交流目录下没有data.bdf\n\n', subject_id);
    end
else
    fprintf('  ✗ 被试 %s 的交流目录不存在\n\n', subject_id);
end

%% ==================== 处理被试141 ====================
fprintf('========================================\n');
fprintf('处理被试 141\n');
fprintf('========================================\n');

subject_id = '141';
jiaoliu_dir = fullfile(eeg_data_dir, subject_id, '交流');
backup_dir = fullfile(eeg_data_dir, subject_id, '原始数据备份');

% 检查是否已处理
existing_files = dir(fullfile(output_dir, sprintf('sub%s_vid*.set', subject_id)));
if length(existing_files) >= 28
    fprintf('  被试 %s 已处理完成（%d个文件），跳过\n\n', subject_id, length(existing_files));
else
    % 复制BDF文件从备份目录
    src_data = fullfile(backup_dir, 'data.bdf');
    src_evt = fullfile(backup_dir, 'evt.bdf');
    dst_data = fullfile(jiaoliu_dir, 'data.bdf');
    dst_evt = fullfile(jiaoliu_dir, 'evt.bdf');
    
    if exist(src_data, 'file') && ~exist(dst_data, 'file')
        fprintf('  复制 data.bdf 从备份目录...\n');
        copyfile(src_data, dst_data);
    end
    if exist(src_evt, 'file') && ~exist(dst_evt, 'file')
        fprintf('  复制 evt.bdf 从备份目录...\n');
        copyfile(src_evt, dst_evt);
    end
    
    % 处理141
    try
        process_single_subject(subject_id, eeg_data_dir, questionnaire_dir, output_dir, cap_file);
        fprintf('  ✓ 被试 %s 处理完成\n\n', subject_id);
    catch ME
        fprintf('  ✗ 被试 %s 处理失败: %s\n\n', subject_id, ME.message);
    end
end

%% ==================== 处理被试112（多BDF文件合并） ====================
fprintf('========================================\n');
fprintf('处理被试 112（多BDF文件合并）\n');
fprintf('========================================\n');

subject_id = '112';
jiaoliu_dir = fullfile(eeg_data_dir, subject_id, '交流');

% 检查是否已处理
existing_files = dir(fullfile(output_dir, sprintf('sub%s_vid*.set', subject_id)));
if length(existing_files) >= 28
    fprintf('  被试 %s 已处理完成（%d个文件），跳过\n\n', subject_id, length(existing_files));
else
    try
        process_subject_with_multiple_bdf(subject_id, eeg_data_dir, questionnaire_dir, output_dir, cap_file);
        fprintf('  ✓ 被试 %s 处理完成\n\n', subject_id);
    catch ME
        fprintf('  ✗ 被试 %s 处理失败: %s\n\n', subject_id, ME.message);
    end
end

%% ==================== 完成 ====================
fprintf('========================================\n');
fprintf('补充处理完成！\n');
fprintf('结束时间: %s\n', datestr(now));
fprintf('========================================\n');

%% ==================== 辅助函数 ====================

function process_single_subject(subject_id, eeg_data_dir, questionnaire_dir, output_dir, cap_file)
    % 处理单个被试（标准流程）
    
    % 查找量表CSV
    if exist('find_questionnaire_csv', 'file')
        csv_file = find_questionnaire_csv(questionnaire_dir, subject_id);
    else
        csv_file = find_exp1_csv(questionnaire_dir, subject_id);
    end
    if isempty(csv_file)
        error('未找到量表CSV文件');
    end
    fprintf('  量表文件: %s\n', csv_file);
    
    % 读取视频编号
    if exist('read_vid_from_csv', 'file')
        [trial_vid_pairs, vid_list] = read_vid_from_csv(csv_file);
    else
        [trial_vid_pairs, vid_list] = read_vid_from_rating_csv(csv_file);
    end
    fprintf('  读取到 %d 个视频\n', length(vid_list));
    
    % 读取BDF数据
    jiaoliu_dir = fullfile(eeg_data_dir, subject_id, '交流');
    data_bdf = fullfile(jiaoliu_dir, 'data.bdf');
    evt_bdf = fullfile(jiaoliu_dir, 'evt.bdf');
    if ~exist(evt_bdf, 'file')
        evt_bdf = '';
    end
    
    % 提取视频段
    if exist('extract_video_segments_from_bdf', 'file')
        video_segments = extract_video_segments_from_bdf(data_bdf, evt_bdf);
    else
        video_segments = extract_video_segments(data_bdf, evt_bdf);
    end
    fprintf('  提取到 %d 个视频段\n', length(video_segments));
    
    % 匹配
    n_segments = min(length(video_segments), length(trial_vid_pairs));
    video_segments = video_segments(1:n_segments);
    trial_vid_pairs = trial_vid_pairs(1:n_segments, :);
    
    % 排序
    [~, sort_idx] = sort(trial_vid_pairs(:, 2));
    trial_vid_pairs = trial_vid_pairs(sort_idx, :);
    video_segments = video_segments(sort_idx);
    
    % 转换为SET
    if exist('align_by_vid_and_convert_to_set', 'file')
        align_by_vid_and_convert_to_set(data_bdf, video_segments, trial_vid_pairs, ...
            subject_id, output_dir, cap_file);
    else
        convert_segments_to_set(data_bdf, video_segments, trial_vid_pairs, ...
            subject_id, output_dir, cap_file);
    end
end

function process_subject_with_multiple_bdf(subject_id, eeg_data_dir, questionnaire_dir, output_dir, cap_file)
    % 处理有多个BDF文件的被试（需要合并）
    
    jiaoliu_dir = fullfile(eeg_data_dir, subject_id, '交流');
    
    % 查找所有BDF文件
    bdf_files = dir(fullfile(jiaoliu_dir, 'data*.bdf'));
    bdf_files = bdf_files(~contains({bdf_files.name}, 'evt'));
    
    % 按文件名排序（data.bdf, data.1.bdf, data.2.bdf...）
    filenames = {bdf_files.name};
    [~, sort_idx] = sort(filenames);
    bdf_files = bdf_files(sort_idx);
    
    fprintf('  找到 %d 个BDF文件:\n', length(bdf_files));
    for i = 1:length(bdf_files)
        fprintf('    - %s\n', bdf_files(i).name);
    end
    
    % 查找量表CSV
    if exist('find_questionnaire_csv', 'file')
        csv_file = find_questionnaire_csv(questionnaire_dir, subject_id);
    else
        csv_file = find_exp1_csv(questionnaire_dir, subject_id);
    end
    if isempty(csv_file)
        error('未找到量表CSV文件');
    end
    
    % 读取视频编号
    if exist('read_vid_from_csv', 'file')
        [trial_vid_pairs, vid_list] = read_vid_from_csv(csv_file);
    else
        [trial_vid_pairs, vid_list] = read_vid_from_rating_csv(csv_file);
    end
    fprintf('  CSV中有 %d 个视频\n', length(vid_list));
    
    % 从所有BDF文件中提取视频段并合并
    all_video_segments = [];
    all_data = [];
    cumulative_samples = 0;
    
    for i = 1:length(bdf_files)
        bdf_path = fullfile(jiaoliu_dir, bdf_files(i).name);
        fprintf('  处理文件: %s\n', bdf_files(i).name);
        
        % 读取头信息
        hdr = ft_read_header(bdf_path);
        
        % 提取这个文件中的视频段
        if exist('extract_video_segments_from_bdf', 'file')
            segments = extract_video_segments_from_bdf(bdf_path, '');
        else
            segments = extract_video_segments(bdf_path, '');
        end
        
        if ~isempty(segments)
            fprintf('    找到 %d 个视频段\n', length(segments));
            
            % 调整采样点位置（加上之前文件的累计采样点）
            for j = 1:length(segments)
                segments(j).startSample = segments(j).startSample + cumulative_samples;
                segments(j).endSample = segments(j).endSample + cumulative_samples;
                segments(j).file_index = i;
                segments(j).original_file = bdf_files(i).name;
            end
            
            if isempty(all_video_segments)
                all_video_segments = segments;
            else
                all_video_segments = [all_video_segments, segments];
            end
        end
        
        cumulative_samples = cumulative_samples + hdr.nSamples;
    end
    
    fprintf('  总共提取到 %d 个视频段\n', length(all_video_segments));
    
    % 匹配
    n_segments = min(length(all_video_segments), length(trial_vid_pairs));
    all_video_segments = all_video_segments(1:n_segments);
    trial_vid_pairs = trial_vid_pairs(1:n_segments, :);
    
    % 排序
    [~, sort_idx] = sort(trial_vid_pairs(:, 2));
    trial_vid_pairs = trial_vid_pairs(sort_idx, :);
    all_video_segments = all_video_segments(sort_idx);
    
    % 读取并合并所有BDF数据
    fprintf('  读取并合并BDF数据...\n');
    all_data = [];
    for i = 1:length(bdf_files)
        bdf_path = fullfile(jiaoliu_dir, bdf_files(i).name);
        data = ft_read_data(bdf_path);
        all_data = [all_data, data];
    end
    
    % 获取第一个文件的头信息（用于标签等）
    hdr = ft_read_header(fullfile(jiaoliu_dir, bdf_files(1).name));
    
    % 转换每个视频段为SET文件
    fprintf('  正在生成SET文件...\n');
    for seg_idx = 1:length(all_video_segments)
        seg = all_video_segments(seg_idx);
        vid = trial_vid_pairs(seg_idx, 2);
        trial = trial_vid_pairs(seg_idx, 1);
        
        % 提取数据段
        start_sample = max(1, seg.startSample);
        end_sample = min(size(all_data, 2), seg.endSample);
        segment_data = all_data(:, start_sample:end_sample);
        
        % 创建EEG结构
        EEG = eeg_emptyset();
        EEG.data = double(segment_data);
        EEG.srate = hdr.Fs;
        EEG.pnts = size(segment_data, 2);
        EEG.nbchan = size(segment_data, 1);
        EEG.xmin = 0;
        EEG.xmax = (EEG.pnts - 1) / EEG.srate;
        
        % 通道标签
        EEG.chanlocs = repmat(struct('labels', ''), EEG.nbchan, 1);
        for ch = 1:min(EEG.nbchan, length(hdr.label))
            if iscell(hdr.label)
                EEG.chanlocs(ch).labels = hdr.label{ch};
            else
                EEG.chanlocs(ch).labels = hdr.label(ch);
            end
        end
        
        % 添加电极位置
        if ~isempty(cap_file) && exist(cap_file, 'file')
            try
                EEG = pop_chanedit(EEG, 'lookup', cap_file);
            catch
            end
        end
        
        % 事件
        EEG.event = struct('type', sprintf('vid%02d', vid), 'latency', 1, ...
            'duration', 0, 'videoIndex', vid);
        
        % 保存
        filename = sprintf('sub%s_vid%02d.set', subject_id, vid);
        EEG = eeg_checkset(EEG);
        pop_saveset(EEG, 'filename', filename, 'filepath', output_dir);
    end
    
    fprintf('  生成了 %d 个SET文件\n', length(all_video_segments));
end

