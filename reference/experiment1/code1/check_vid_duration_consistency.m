% 统计每个视频编号在所有被试中的时长是否一致
%
% 功能：
%   - 读取所有恢复后的合并文件
%   - 提取每个vid的时间段（基于事件标记）
%   - 统计每个vid在不同被试中的时长
%   - 检查时长是否一致
%
% 输入：Cleaned_Data_Merged_Restored/*_RELAX_merged_restored.set
% 输出：统计报告（显示在命令行 + 保存为CSV）

clear; clc;

% 设置路径
base_dir = '<DATA_ROOT>';
input_dir = fullfile(base_dir, 'data/data-tongyong/原始数据/可用原始数据/转化成set的脑电_aligned/RELAXProcessed/Cleaned_Data_Merged_Restored');
output_dir = fullfile(base_dir, '预处理/matlab/实验1/code1');

% 添加EEGLAB路径
if ~exist('eeglab', 'file')
    addpath('<EEGLAB_ROOT>');
    eeglab('nogui');
end

fprintf('============================================================\n');
fprintf('统计每个视频编号在所有被试中的时长是否一致\n');
fprintf('============================================================\n');
fprintf('输入目录: %s\n\n', input_dir);

% 获取所有恢复后的文件
files = dir(fullfile(input_dir, '*_RELAX_merged_restored.set'));
if isempty(files)
    error('未找到任何_RELAX_merged_restored.set文件');
end

fprintf('找到 %d 个被试的文件\n\n', length(files));

% 数据结构：存储所有被试的vid时长信息
% vid_durations{vid}(subject_idx) = duration_in_samples
vid_durations = cell(1, 28); % 假设最多28个vid
for v = 1:28
    vid_durations{v} = [];
end

% 存储被试ID列表
subject_ids = cell(1, length(files));
subject_srates = zeros(1, length(files)); % 采样率

% 遍历所有文件
for f_idx = 1:length(files)
    filename = files(f_idx).name;
    fprintf('[%d/%d] 处理文件: %s\n', f_idx, length(files), filename);

    try
        % 加载文件
        EEG = pop_loadset('filename', filename, 'filepath', input_dir);

        % 提取被试ID
        parts = strsplit(filename, '_');
        subject_id = parts{1};
        subject_ids{f_idx} = subject_id;
        subject_srates(f_idx) = EEG.srate;

        fprintf('  被试: %s, 采样率: %.0f Hz, 总时长: %.2f 秒\n', ...
            subject_id, EEG.srate, EEG.pnts/EEG.srate);

        % 提取所有vid事件
        vid_events = [];
        if ~isempty(EEG.event)
            for e = 1:length(EEG.event)
                % 查找vid标记事件
                vid_num = [];

                % 方法1: 通过vid字段
                if isfield(EEG.event(e), 'vid')
                    vid_num = EEG.event(e).vid;
                % 方法2: 通过videoIndex字段
                elseif isfield(EEG.event(e), 'videoIndex')
                    vid_num = EEG.event(e).videoIndex;
                % 方法3: 通过type字段解析（如'vid01', 'vid02'）
                elseif isfield(EEG.event(e), 'type') && ischar(EEG.event(e).type)
                    if startsWith(EEG.event(e).type, 'vid')
                        try
                            vid_num = str2double(EEG.event(e).type(4:end));
                        catch
                            % 解析失败，跳过
                        end
                    end
                end

                if ~isempty(vid_num) && ~isnan(vid_num)
                    vid_events(end+1).vid = vid_num;
                    vid_events(end).latency = round(EEG.event(e).latency);
                end
            end
        end

        if isempty(vid_events)
            warning('  警告: 未找到vid事件标记');
            continue;
        end

        % 按latency排序
        [~, sort_idx] = sort([vid_events.latency]);
        vid_events = vid_events(sort_idx);

        fprintf('  找到 %d 个vid事件\n', length(vid_events));

        % 计算每个vid的时长
        for v_idx = 1:length(vid_events)
            vid_num = vid_events(v_idx).vid;
            start_sample = vid_events(v_idx).latency;

            % 确定结束位置
            if v_idx < length(vid_events)
                % 不是最后一个vid，结束位置是下一个vid的开始位置-1
                end_sample = vid_events(v_idx + 1).latency - 1;
            else
                % 最后一个vid，结束位置是数据末尾
                end_sample = EEG.pnts;
            end

            % 计算时长（采样点数）
            duration = end_sample - start_sample + 1;

            % 存储到对应的vid
            if vid_num >= 1 && vid_num <= 28
                vid_durations{vid_num}(end+1) = duration;
            end

            fprintf('    vid%02d: 起始=%d, 结束=%d, 时长=%d 采样点 (%.2f 秒)\n', ...
                vid_num, start_sample, end_sample, duration, duration/EEG.srate);
        end

    catch ME
        warning('  错误: %s', ME.message);
        continue;
    end

    fprintf('\n');
end

fprintf('============================================================\n');
fprintf('统计结果\n');
fprintf('============================================================\n\n');

% 检查采样率是否一致
unique_srates = unique(subject_srates(subject_srates > 0));
if length(unique_srates) == 1
    fprintf('✓ 所有被试的采样率一致: %.0f Hz\n\n', unique_srates(1));
    common_srate = unique_srates(1);
else
    fprintf('✗ 警告: 被试采样率不一致!\n');
    for i = 1:length(unique_srates)
        fprintf('  采样率 %.0f Hz: %d 个被试\n', unique_srates(i), sum(subject_srates == unique_srates(i)));
    end
    fprintf('\n');
    common_srate = mode(subject_srates(subject_srates > 0)); % 使用最常见的采样率
end

% 统计每个vid的时长
fprintf('%-8s %-10s %-12s %-12s %-12s %-12s %s\n', ...
    'Vid', '被试数', '时长(秒)', '最小(秒)', '最大(秒)', '标准差(秒)', '一致性');
fprintf('------------------------------------------------------------------------\n');

% 用于保存到CSV
stats_table = {};
stats_table{1, 1} = 'vid';
stats_table{1, 2} = 'subject_count';
stats_table{1, 3} = 'mean_duration_sec';
stats_table{1, 4} = 'min_duration_sec';
stats_table{1, 5} = 'max_duration_sec';
stats_table{1, 6} = 'std_duration_sec';
stats_table{1, 7} = 'consistent';
stats_table{1, 8} = 'all_durations_samples';

vid_count = 0;
inconsistent_vids = [];

for v = 1:28
    durations = vid_durations{v};

    if isempty(durations)
        continue; % 跳过没有数据的vid
    end

    vid_count = vid_count + 1;

    % 计算统计量（以秒为单位）
    durations_sec = durations / common_srate;
    mean_dur = mean(durations_sec);
    min_dur = min(durations_sec);
    max_dur = max(durations_sec);
    std_dur = std(durations_sec);

    % 判断是否一致（允许小误差，如1个采样点）
    is_consistent = (max(durations) - min(durations)) <= 1;
    if is_consistent
        consistency_str = '✓ 一致';
    else
        consistency_str = '✗ 不一致';
    end

    if ~is_consistent
        inconsistent_vids(end+1) = v;
    end

    % 显示结果
    fprintf('vid%02d    %-10d %-12.2f %-12.2f %-12.2f %-12.4f %s\n', ...
        v, length(durations), mean_dur, min_dur, max_dur, std_dur, consistency_str);

    % 保存到表格
    row = vid_count + 1;
    stats_table{row, 1} = sprintf('vid%02d', v);
    stats_table{row, 2} = length(durations);
    stats_table{row, 3} = mean_dur;
    stats_table{row, 4} = min_dur;
    stats_table{row, 5} = max_dur;
    stats_table{row, 6} = std_dur;
    stats_table{row, 7} = is_consistent;
    stats_table{row, 8} = sprintf('[%s]', num2str(durations));
end

fprintf('------------------------------------------------------------------------\n\n');

% 总结
fprintf('总结:\n');
fprintf('  - 被试总数: %d\n', length(files));
fprintf('  - vid总数: %d\n', vid_count);
fprintf('  - 一致的vid数: %d\n', vid_count - length(inconsistent_vids));
fprintf('  - 不一致的vid数: %d\n', length(inconsistent_vids));

if ~isempty(inconsistent_vids)
    fprintf('\n不一致的vid列表:\n');
    for i = 1:length(inconsistent_vids)
        v = inconsistent_vids(i);
        durations = vid_durations{v};
        durations_sec = durations / common_srate;
        fprintf('  vid%02d: ', v);
        fprintf('范围=%.2f-%.2f秒, ', min(durations_sec), max(durations_sec));
        fprintf('差异=%.2f秒 (%.0f 采样点)\n', max(durations_sec)-min(durations_sec), max(durations)-min(durations));

        % 显示每个被试的具体时长
        fprintf('    详细信息:\n');
        for s_idx = 1:length(durations)
            if s_idx <= length(subject_ids)
                fprintf('      %s: %.2f秒 (%d 采样点)\n', ...
                    subject_ids{s_idx}, durations_sec(s_idx), durations(s_idx));
            end
        end
    end
else
    fprintf('\n✓ 所有vid在所有被试中的时长都一致!\n');
end

% 保存统计结果到CSV
output_csv = fullfile(output_dir, 'vid_duration_statistics.csv');
try
    % 转换为table并保存
    T = cell2table(stats_table(2:end, 1:7), 'VariableNames', stats_table(1, 1:7));
    writetable(T, output_csv);
    fprintf('\n统计结果已保存到: %s\n', output_csv);
catch ME
    warning('保存CSV失败: %s', ME.message);
end

% 生成详细的被试-vid时长矩阵
fprintf('\n生成被试-vid时长矩阵...\n');
subject_vid_matrix = fullfile(output_dir, 'subject_vid_duration_matrix.csv');
try
    % 创建矩阵：行=被试，列=vid
    max_subjects = length(subject_ids);
    matrix_data = nan(max_subjects, 28);

    for v = 1:28
        durations = vid_durations{v};
        for s_idx = 1:min(length(durations), max_subjects)
            matrix_data(s_idx, v) = durations(s_idx) / common_srate; % 转换为秒
        end
    end

    % 创建列名
    col_names = cell(1, 28);
    for v = 1:28
        col_names{v} = sprintf('vid%02d', v);
    end

    % 创建行名（被试ID）
    valid_subjects = subject_ids(~cellfun(@isempty, subject_ids));

    % 创建table
    if ~isempty(valid_subjects)
        T_matrix = array2table(matrix_data, 'VariableNames', col_names, 'RowNames', valid_subjects);
        writetable(T_matrix, subject_vid_matrix, 'WriteRowNames', true);
        fprintf('被试-vid时长矩阵已保存到: %s\n', subject_vid_matrix);
    end
catch ME
    warning('保存矩阵失败: %s', ME.message);
end

fprintf('\n============================================================\n');
fprintf('统计完成\n');
fprintf('============================================================\n');
