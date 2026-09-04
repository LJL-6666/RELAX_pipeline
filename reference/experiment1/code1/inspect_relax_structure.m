% 检查RELAX字段结构，理解删除时间段的记录方式
clear; clc;

% 添加EEGLAB路径
if ~exist('eeglab', 'file')
    addpath('/data/liujialing/eeglab-develop');
    eeglab('nogui');
end

% 测试文件路径
merged_dir = '/data/liujialing/TY/data/data-tongyong/原始数据/可用原始数据/转化成set的脑电_aligned/RELAXProcessed/Cleaned_Data_Merged';
restored_dir = '/data/liujialing/TY/data/data-tongyong/原始数据/可用原始数据/转化成set的脑电_aligned/RELAXProcessed/Cleaned_Data_Merged_Restored';

fprintf('============================================================\n');
fprintf('检查RELAX字段结构\n');
fprintf('============================================================\n\n');

% 加载一个合并后的文件（删除前）
fprintf('加载合并文件（删除后）: sub018_RELAX_merged.set\n');
EEG_merged = pop_loadset('filename', 'sub018_RELAX_merged.set', 'filepath', merged_dir);

fprintf('  数据长度: %d 采样点 (%.2f 秒)\n', EEG_merged.pnts, EEG_merged.pnts/EEG_merged.srate);
fprintf('  采样率: %.0f Hz\n', EEG_merged.srate);

% 检查RELAX字段
if isfield(EEG_merged, 'RELAX')
    fprintf('\n✓ 找到 RELAX 字段\n');
    fprintf('  RELAX 字段内容:\n');

    relax_fields = fieldnames(EEG_merged.RELAX);
    for i = 1:length(relax_fields)
        field = relax_fields{i};
        fprintf('    - %s: ', field);

        if strcmp(field, 'ExtremelyBadPeriodsForDeletion')
            bad_periods = EEG_merged.RELAX.(field);
            if ~isempty(bad_periods)
                fprintf('矩阵大小 %dx%d\n', size(bad_periods, 1), size(bad_periods, 2));
                fprintf('      前5个删除时间段:\n');
                for j = 1:min(5, size(bad_periods, 1))
                    fprintf('        [%d] 起始=%d, 结束=%d, 长度=%d\n', ...
                        j, bad_periods(j, 1), bad_periods(j, 2), bad_periods(j, 2) - bad_periods(j, 1) + 1);
                end
                if size(bad_periods, 1) > 5
                    fprintf('        ... 还有 %d 个\n', size(bad_periods, 1) - 5);
                end

                % 计算删除的总长度
                total_deleted = 0;
                for j = 1:size(bad_periods, 1)
                    total_deleted = total_deleted + (bad_periods(j, 2) - bad_periods(j, 1) + 1);
                end
                fprintf('      删除总长度: %d 采样点\n', total_deleted);
                fprintf('      估算原始长度: %d 采样点\n', EEG_merged.pnts + total_deleted);
            else
                fprintf('空\n');
            end
        else
            try
                val = EEG_merged.RELAX.(field);
                if isnumeric(val)
                    fprintf('%s\n', mat2str(val));
                elseif ischar(val)
                    fprintf('"%s"\n', val);
                else
                    fprintf('<%s>\n', class(val));
                end
            catch
                fprintf('无法显示\n');
            end
        end
    end
else
    fprintf('\n✗ 未找到 RELAX 字段\n');
end

% 检查vid事件标记
fprintf('\nvid事件标记:\n');
vid_events = [];
for e = 1:length(EEG_merged.event)
    if isfield(EEG_merged.event(e), 'vid')
        vid_num = EEG_merged.event(e).vid;
        latency = round(EEG_merged.event(e).latency);
        fprintf('  vid%02d: latency=%d\n', vid_num, latency);
        vid_events(end+1).vid = vid_num;
        vid_events(end).latency = latency;
    end
end

% 加载对应的恢复后文件
fprintf('\n------------------------------------------------------------\n');
fprintf('加载恢复后的文件: sub018_RELAX_merged_restored.set\n');
EEG_restored = pop_loadset('filename', 'sub018_RELAX_merged_restored.set', 'filepath', restored_dir);

fprintf('  数据长度: %d 采样点 (%.2f 秒)\n', EEG_restored.pnts, EEG_restored.pnts/EEG_restored.srate);
fprintf('  长度增加: %d 采样点\n', EEG_restored.pnts - EEG_merged.pnts);

% 检查恢复后的vid事件标记
fprintf('\n恢复后的vid事件标记:\n');
vid_events_restored = [];
for e = 1:length(EEG_restored.event)
    if isfield(EEG_restored.event(e), 'vid')
        vid_num = EEG_restored.event(e).vid;
        latency = round(EEG_restored.event(e).latency);
        fprintf('  vid%02d: latency=%d\n', vid_num, latency);
        vid_events_restored(end+1).vid = vid_num;
        vid_events_restored(end).latency = latency;
    end
end

% 计算每个vid的时长（恢复前后对比）
fprintf('\n============================================================\n');
fprintf('每个vid的时长对比（删除后 vs 恢复后）\n');
fprintf('============================================================\n');
fprintf('%-8s %-15s %-15s %-15s\n', 'Vid', '删除后(秒)', '恢复后(秒)', '差异(秒)');
fprintf('------------------------------------------------------------\n');

% 按latency排序
[~, sort_idx] = sort([vid_events.latency]);
vid_events = vid_events(sort_idx);
[~, sort_idx] = sort([vid_events_restored.latency]);
vid_events_restored = vid_events_restored(sort_idx);

for v_idx = 1:length(vid_events)
    vid_num = vid_events(v_idx).vid;

    % 删除后的时长
    start_merged = vid_events(v_idx).latency;
    if v_idx < length(vid_events)
        end_merged = vid_events(v_idx + 1).latency - 1;
    else
        end_merged = EEG_merged.pnts;
    end
    dur_merged = (end_merged - start_merged + 1) / EEG_merged.srate;

    % 恢复后的时长
    if v_idx <= length(vid_events_restored)
        start_restored = vid_events_restored(v_idx).latency;
        if v_idx < length(vid_events_restored)
            end_restored = vid_events_restored(v_idx + 1).latency - 1;
        else
            end_restored = EEG_restored.pnts;
        end
        dur_restored = (end_restored - start_restored + 1) / EEG_restored.srate;
        diff = dur_restored - dur_merged;

        fprintf('vid%02d    %-15.2f %-15.2f %-15.2f\n', vid_num, dur_merged, dur_restored, diff);
    end
end

fprintf('\n============================================================\n');
