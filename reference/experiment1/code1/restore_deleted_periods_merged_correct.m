% 正确恢复合并文件中的删除时间段
%
% 关键逻辑：
%   1. 读取每个单个vid文件的RELAX删除信息
%   2. 将删除位置映射到合并后的时间轴
%   3. 在对应vid段恢复删除时间段为NaN
%   4. 保证每个被试的同一vid编号恢复后时长一致

clear; clc;

% 设置路径
base_dir = '<DATA_ROOT>';
single_vid_dir = fullfile(base_dir, 'data/data-tongyong/原始数据/可用原始数据/转化成set的脑电_aligned/RELAXProcessed/Cleaned_Data');
merged_dir = fullfile(base_dir, 'data/data-tongyong/原始数据/可用原始数据/转化成set的脑电_aligned/RELAXProcessed/Cleaned_Data_Merged');
output_dir = fullfile(base_dir, 'data/data-tongyong/原始数据/可用原始数据/转化成set的脑电_aligned/RELAXProcessed/Cleaned_Data_Merged_Restored');

% 创建输出目录
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

% 添加EEGLAB路径
if ~exist('eeglab', 'file')
    addpath('<EEGLAB_ROOT>');
    eeglab('nogui');
end

fprintf('============================================================\n');
fprintf('正确恢复合并文件中的删除时间段\n');
fprintf('============================================================\n');
fprintf('单个vid目录: %s\n', single_vid_dir);
fprintf('合并文件目录: %s\n', merged_dir);
fprintf('输出目录: %s\n\n', output_dir);

% 获取所有合并后的文件
merged_files = dir(fullfile(merged_dir, '*_RELAX_merged.set'));
if isempty(merged_files)
    error('未找到任何合并文件');
end

fprintf('找到 %d 个合并文件\n\n', length(merged_files));

success_count = 0;
error_count = 0;

% 遍历所有合并文件
for f_idx = 1:length(merged_files)
    merged_filename = merged_files(f_idx).name;
    fprintf('[%d/%d] 处理: %s\n', f_idx, length(merged_files), merged_filename);

    try
        % 提取被试ID
        parts = strsplit(merged_filename, '_');
        subject_id = parts{1}; % subXXX

        % 加载合并文件
        EEG_merged = pop_loadset('filename', merged_filename, 'filepath', merged_dir);
        fprintf('  被试ID: %s\n', subject_id);
        fprintf('  合并文件长度: %d 采样点 (%.2f 秒)\n', EEG_merged.pnts, EEG_merged.pnts/EEG_merged.srate);

        % 提取vid事件，确定每个vid在合并后数据中的位置
        vid_events = [];
        for e = 1:length(EEG_merged.event)
            vid_num = [];
            if isfield(EEG_merged.event(e), 'vid')
                vid_num = EEG_merged.event(e).vid;
            elseif isfield(EEG_merged.event(e), 'videoIndex')
                vid_num = EEG_merged.event(e).videoIndex;
            end

            if ~isempty(vid_num) && ~isnan(vid_num)
                vid_events(end+1).vid = vid_num;
                vid_events(end).latency = round(EEG_merged.event(e).latency);
            end
        end

        if isempty(vid_events)
            warning('  未找到vid事件标记，跳过');
            continue;
        end

        % 按latency排序
        [~, sort_idx] = sort([vid_events.latency]);
        vid_events = vid_events(sort_idx);

        fprintf('  找到 %d 个vid\n', length(vid_events));

        % 收集每个vid的删除信息
        vid_deletion_info = struct();
        total_original_length = 0;

        for v_idx = 1:length(vid_events)
            vid_num = vid_events(v_idx).vid;

            % 构建单个vid文件名
            single_vid_filename = sprintf('%s_vid%02d_RELAX.set', subject_id, vid_num);
            single_vid_path = fullfile(single_vid_dir, single_vid_filename);

            if ~exist(single_vid_path, 'file')
                fprintf('  警告: 未找到 %s\n', single_vid_filename);
                continue;
            end

            % 加载单个vid文件
            EEG_single = pop_loadset('filename', single_vid_filename, 'filepath', single_vid_dir);

            % 获取删除信息
            bad_periods = [];
            if isfield(EEG_single, 'RELAX') && isfield(EEG_single.RELAX, 'ExtremelyBadPeriodsForDeletion')
                bad_periods = EEG_single.RELAX.ExtremelyBadPeriodsForDeletion;
            end

            % 计算原始长度
            if ~isempty(bad_periods) && size(bad_periods, 1) > 0
                deleted_samples = 0;
                for j = 1:size(bad_periods, 1)
                    deleted_samples = deleted_samples + (bad_periods(j, 2) - bad_periods(j, 1) + 1);
                end
                original_length = EEG_single.pnts + deleted_samples;
            else
                original_length = EEG_single.pnts;
            end

            % 存储信息
            vid_deletion_info(v_idx).vid = vid_num;
            vid_deletion_info(v_idx).bad_periods = bad_periods;
            vid_deletion_info(v_idx).cleaned_length = EEG_single.pnts;
            vid_deletion_info(v_idx).original_length = original_length;
            vid_deletion_info(v_idx).deleted_samples = original_length - EEG_single.pnts;

            total_original_length = total_original_length + original_length;

            fprintf('    vid%02d: 清洗后=%d, 原始=%d, 删除=%d (%.2f%%)\n', ...
                vid_num, EEG_single.pnts, original_length, ...
                original_length - EEG_single.pnts, ...
                (original_length - EEG_single.pnts) / original_length * 100);
        end

        fprintf('  总原始长度: %d 采样点 (%.2f 秒)\n', total_original_length, total_original_length/EEG_merged.srate);
        fprintf('  需要增加: %d 采样点\n', total_original_length - EEG_merged.pnts);

        % 创建恢复后的数据矩阵
        restored_data = nan(EEG_merged.nbchan, total_original_length);

        % 逐个vid恢复
        current_restored_pos = 1; % 恢复后数据的当前位置
        current_merged_pos = 1;   % 合并数据的当前位置

        for v_idx = 1:length(vid_deletion_info)
            vid_info = vid_deletion_info(v_idx);
            vid_num = vid_info.vid;
            bad_periods = vid_info.bad_periods;
            original_length = vid_info.original_length;
            cleaned_length = vid_info.cleaned_length;

            fprintf('  恢复 vid%02d...\n', vid_num);

            if isempty(bad_periods) || size(bad_periods, 1) == 0
                % 没有删除，直接复制
                restored_data(:, current_restored_pos:current_restored_pos+original_length-1) = ...
                    EEG_merged.data(:, current_merged_pos:current_merged_pos+cleaned_length-1);
                fprintf('    无删除段，直接复制 %d 采样点\n', original_length);
            else
                % 有删除，需要恢复
                % 按删除时间段排序
                sorted_periods = sortrows(bad_periods, 1);

                % 遍历原始位置，填充数据或NaN
                cleaned_pos = 0; % 在cleaned数据中的相对位置
                for orig_pos = 1:original_length
                    % 检查当前位置是否在删除时间段内
                    is_deleted = false;
                    for j = 1:size(sorted_periods, 1)
                        if orig_pos >= sorted_periods(j, 1) && orig_pos <= sorted_periods(j, 2)
                            is_deleted = true;
                            break;
                        end
                    end

                    if is_deleted
                        % 在删除段内，填充NaN
                        restored_data(:, current_restored_pos + orig_pos - 1) = NaN;
                    else
                        % 不在删除段内，从cleaned数据复制
                        if current_merged_pos + cleaned_pos <= EEG_merged.pnts
                            restored_data(:, current_restored_pos + orig_pos - 1) = ...
                                EEG_merged.data(:, current_merged_pos + cleaned_pos);
                        end
                        cleaned_pos = cleaned_pos + 1;
                    end
                end

                fprintf('    恢复 %d 个删除段，总长度 %d → %d 采样点\n', ...
                    size(sorted_periods, 1), cleaned_length, original_length);
            end

            % 更新位置指针
            current_restored_pos = current_restored_pos + original_length;
            current_merged_pos = current_merged_pos + cleaned_length;
        end

        % 更新EEG结构
        EEG_restored = EEG_merged;
        EEG_restored.data = restored_data;
        EEG_restored.pnts = size(restored_data, 2);
        EEG_restored.xmax = (EEG_restored.pnts - 1) / EEG_restored.srate;
        EEG_restored.times = (0:EEG_restored.pnts-1) / EEG_restored.srate * 1000;

        % 更新vid事件位置
        fprintf('  更新事件位置...\n');
        new_vid_latencies = zeros(1, length(vid_deletion_info));
        cumulative_pos = 1;
        for v_idx = 1:length(vid_deletion_info)
            new_vid_latencies(v_idx) = cumulative_pos;
            cumulative_pos = cumulative_pos + vid_deletion_info(v_idx).original_length;
        end

        % 更新所有事件
        for e = 1:length(EEG_restored.event)
            % 找到这个事件属于哪个vid
            old_latency = EEG_merged.event(e).latency;

            % 确定事件在哪个vid中
            vid_idx_for_event = 0;
            for v_idx = 1:length(vid_events)
                if v_idx < length(vid_events)
                    if old_latency >= vid_events(v_idx).latency && old_latency < vid_events(v_idx+1).latency
                        vid_idx_for_event = v_idx;
                        break;
                    end
                else
                    if old_latency >= vid_events(v_idx).latency
                        vid_idx_for_event = v_idx;
                        break;
                    end
                end
            end

            if vid_idx_for_event > 0
                % 计算事件在vid内的相对位置（cleaned数据中）
                vid_start_cleaned = vid_events(vid_idx_for_event).latency;
                relative_pos_cleaned = old_latency - vid_start_cleaned + 1;

                % 转换到恢复后的位置
                vid_info = vid_deletion_info(vid_idx_for_event);
                bad_periods = vid_info.bad_periods;

                % 计算在原始数据中的位置
                if ~isempty(bad_periods) && size(bad_periods, 1) > 0
                    sorted_periods = sortrows(bad_periods, 1);
                    deleted_before = 0;
                    for j = 1:size(sorted_periods, 1)
                        if sorted_periods(j, 2) < relative_pos_cleaned
                            deleted_before = deleted_before + (sorted_periods(j, 2) - sorted_periods(j, 1) + 1);
                        end
                    end
                    relative_pos_original = relative_pos_cleaned + deleted_before;
                else
                    relative_pos_original = relative_pos_cleaned;
                end

                % 计算新的绝对位置
                new_latency = new_vid_latencies(vid_idx_for_event) + relative_pos_original - 1;
                EEG_restored.event(e).latency = new_latency;
            end
        end

        % 更新merged_info
        if isfield(EEG_restored, 'merged_info')
            EEG_restored.merged_info.total_duration = EEG_restored.pnts / EEG_restored.srate;
            EEG_restored.merged_info.restored = true;
            EEG_restored.merged_info.restoration_method = 'per_vid_restoration';
        end

        % 保存
        output_filename = sprintf('%s_RELAX_merged_restored.set', subject_id);
        output_filepath = fullfile(output_dir, output_filename);

        EEG_restored = eeg_checkset(EEG_restored);
        pop_saveset(EEG_restored, 'filename', output_filename, 'filepath', output_dir);

        fprintf('  ✓ 保存: %s\n', output_filename);
        fprintf('  最终长度: %d 采样点 (%.2f 秒)\n\n', EEG_restored.pnts, EEG_restored.pnts/EEG_restored.srate);

        success_count = success_count + 1;

    catch ME
        fprintf('  ✗ 错误: %s\n', ME.message);
        for s = 1:length(ME.stack)
            fprintf('    %s (行 %d)\n', ME.stack(s).name, ME.stack(s).line);
        end
        error_count = error_count + 1;
    end
end

fprintf('============================================================\n');
fprintf('处理完成\n');
fprintf('成功: %d 个文件\n', success_count);
fprintf('错误: %d 个文件\n', error_count);
fprintf('============================================================\n');
