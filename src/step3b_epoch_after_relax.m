function step3b_epoch_after_relax(cfg)
% STEP3B_EPOCH_AFTER_RELAX  对整段 RELAX 清洁后的数据按 21/22 trigger 切分，
%   并根据 BAD_segment 事件剔除坏段（Mode B）
%
% 输入：output/relax_whole/<task>/RELAXProcessed/Cleaned_Data/subXXX_whole_RELAX.set
%   或 output/set_whole/<task>/RELAXProcessed/Cleaned_Data/subXXX_whole_RELAX.set
% 输出：output/epochs_by_vid/<task>/subXXX_vidYY.set
%
% 逻辑：
%   1. 从整段 set 中提取 21/22 trigger 事件，配对为视频段
%   2. 提取 BAD_segment 事件（RELAX 标记的坏段）
%   3. 对每个视频段，若与 BAD_segment 重叠则剔除（或标记）
%   4. 按 vid 对齐 CSV 并写出 set

candidates = {
    fullfile(cfg.paths.outputRoot, 'relax_whole', cfg.task.name, 'RELAXProcessed', 'Cleaned_Data')
    fullfile(cfg.paths.outputRoot, 'set_whole', cfg.task.name, 'RELAXProcessed', 'Cleaned_Data')
    };
input_dir = '';
for i = 1:numel(candidates)
    if exist(candidates{i}, 'dir') == 7
        input_dir = candidates{i};
        break;
    end
end
if isempty(input_dir)
    error('[step3b] 未找到 Cleaned_Data，请先完成 step2b。');
end

output_dir = fullfile(cfg.paths.outputRoot, 'epochs_by_vid', cfg.task.name);
if ~exist(output_dir, 'dir'), mkdir(output_dir); end

% 是否剔除坏段（默认 true）
rejectBad = true;
if isfield(cfg.pipeline, 'modeB_rejectBadEpochs')
    rejectBad = cfg.pipeline.modeB_rejectBadEpochs;
end

all_files = dir(fullfile(input_dir, 'sub*_whole_RELAX.set'));
if isempty(all_files)
    error('[step3b] 无 sub*_whole_RELAX.set: %s', input_dir);
end

segOpts = build_seg_opts(cfg);
startTrig = cfg.segment.startTrigger;
endTrig = cfg.segment.endTrigger;

ok = 0; fail = {};
for f = 1:numel(all_files)
    fn = all_files(f).name;
    tok = regexp(fn, '^(sub\d+)_whole_RELAX\.set$', 'tokens', 'once');
    if isempty(tok), continue; end
    subStr = tok{1};
    subID = regexprep(subStr, '^sub', '');

    fprintf('--- 被试 %s (%d/%d) ---\n', subStr, f, numel(all_files));

    % 检查是否已存在
    existing = dir(fullfile(output_dir, sprintf('%s_vid*.set', subStr)));
    if cfg.pipeline.skipExisting && ~isempty(existing)
        fprintf('  已存在 %d 个 set，跳过。\n', numel(existing));
        ok = ok + 1;
        continue;
    end

    try
        EEG = pop_loadset('filename', fn, 'filepath', input_dir);
        fs = EEG.srate;
        nSamples = EEG.pnts;

        % 1. 提取 21/22 trigger 并配对为视频段
        trigger_positions = extract_trigger_positions_from_eeg(EEG, startTrig, endTrig);
        if isempty(trigger_positions)
            fail{end+1} = sprintf('%s: 无 21/22 trigger', subStr); %#ok<AGROW>
            continue;
        end
        video_segments = pair_segments_from_triggers(trigger_positions, fs, nSamples, startTrig, endTrig, segOpts);
        if isempty(video_segments)
            fail{end+1} = sprintf('%s: 无法配对视频段', subStr); %#ok<AGROW>
            continue;
        end

        % 2. 提取 BAD_segment 事件
        bad_periods = extract_bad_segments_from_eeg(EEG);
        fprintf('  视频段=%d，BAD_segment=%d\n', numel(video_segments), size(bad_periods, 1));

        % 3. 读取 CSV 获取 vid 列表
        csvFile = '';
        if isfield(EEG.etc, 'csv_file') && exist(EEG.etc.csv_file, 'file')
            csvFile = EEG.etc.csv_file;
        else
            % 回退：从 data 目录查找
            taskRoot = fullfile(cfg.paths.dataRoot, cfg.task.name);
            subDir = fullfile(taskRoot, subID);
            if ~isempty(cfg.task.folderName)
                subDir = fullfile(subDir, cfg.task.folderName);
            end
            cands = dir(fullfile(subDir, sprintf('*%s*.csv', cfg.task.csvPattern)));
            if isempty(cands)
                cands = dir(fullfile(subDir, '*.csv'));
            end
            if ~isempty(cands)
                csvFile = fullfile(subDir, cands(1).name);
            end
        end
        if isempty(csvFile)
            fail{end+1} = sprintf('%s: 无 CSV', subStr); %#ok<AGROW>
            continue;
        end
        [trial_vid_pairs, vid_list] = read_vid_from_csv(csvFile, cfg.task.orderColumn); %#ok<ASGLU>

        % 4. 对齐段数与 CSV 行数
        n = min(numel(video_segments), size(trial_vid_pairs, 1));
        if numel(video_segments) ~= size(trial_vid_pairs, 1)
            warning('被试 %s: 视频段数(%d)与 CSV 行数(%d)不一致，取较小值 %d', ...
                subStr, numel(video_segments), size(trial_vid_pairs, 1), n);
        end
        video_segments = video_segments(1:n);
        trial_vid_pairs = trial_vid_pairs(1:n, :);

        % 按 vid 排序
        [~, sort_idx] = sort(trial_vid_pairs(:, 2));
        trial_vid_pairs = trial_vid_pairs(sort_idx, :);
        video_segments = video_segments(sort_idx);

        % 5. 逐段提取并写出
        nWritten = 0;
        nRejected = 0;
        for i = 1:numel(video_segments)
            seg = video_segments(i);
            vid = trial_vid_pairs(i, 2);

            % 检查是否与 BAD_segment 重叠
            isBad = segment_overlaps_bad(seg.startSample, seg.endSample, bad_periods);
            if isBad && rejectBad
                fprintf('  vid%02d: 与 BAD_segment 重叠，剔除\n', vid);
                nRejected = nRejected + 1;
                continue;
            end

            % 提取数据
            data = EEG.data(:, seg.startSample:seg.endSample);
            EEG_seg = eeg_emptyset();
            EEG_seg.data = data;
            EEG_seg.srate = fs;
            EEG_seg.pnts = size(data, 2);
            EEG_seg.nbchan = EEG.nbchan;
            EEG_seg.chanlocs = EEG.chanlocs;
            EEG_seg.xmin = 0;
            EEG_seg.xmax = (EEG_seg.pnts - 1) / fs;

            % 事件：添加 videoStart 标记
            EEG_seg.event = struct('type', {}, 'latency', {}, 'duration', {}, 'videoIndex', {});
            EEG_seg.event(1).type = 'videoStart';
            EEG_seg.event(1).latency = 1;
            EEG_seg.event(1).duration = 0;
            EEG_seg.event(1).videoIndex = vid;

            % 若该段与 BAD_segment 重叠但不剔除，则标记
            if isBad
                EEG_seg.event(end+1).type = 'BAD_segment_overlap';
                EEG_seg.event(end).latency = 1;
                EEG_seg.event(end).duration = 0;
            end

            EEG_seg = eeg_checkset(EEG_seg);
            outFile = sprintf('%s_vid%02d.set', subStr, vid);
            pop_saveset(EEG_seg, 'filename', outFile, 'filepath', output_dir);
            nWritten = nWritten + 1;
        end
        fprintf('  写出 %d 个 set（剔除 %d 个坏段）\n', nWritten, nRejected);
        ok = ok + 1;
    catch ME
        warning('[step3b] %s 失败: %s', subStr, ME.message);
        fail{end+1} = sprintf('%s: %s', subStr, ME.message); %#ok<AGROW>
    end
end

fprintf('[step3b] 成功 %d / %d\n', ok, numel(all_files));
if ~isempty(fail)
    fprintf('[step3b] 失败条目:\n');
    fprintf('  %s\n', fail{:});
end
end

function trigger_positions = extract_trigger_positions_from_eeg(EEG, startTrig, endTrig)
% 从 EEGLAB event 结构中提取 21/22 trigger 采样点
trigger_positions = [];
if ~isfield(EEG, 'event') || isempty(EEG.event)
    return;
end
for i = 1:numel(EEG.event)
    ev = EEG.event(i);
    val = [];
    if isfield(ev, 'type')
        v = ev.type;
        if isnumeric(v)
            val = double(v);
        elseif ischar(v) || isstring(v)
            val = str2double(v);
            if isnan(val), val = []; end
        end
    end
    if isempty(val) || (val ~= startTrig && val ~= endTrig)
        continue;
    end
    if isfield(ev, 'latency') && ~isempty(ev.latency)
        sample = round(double(ev.latency));
        trigger_positions(end+1, :) = [val, sample]; %#ok<AGROW>
    end
end
if ~isempty(trigger_positions)
    [~, ord] = sort(trigger_positions(:, 2));
    trigger_positions = trigger_positions(ord, :);
end
fprintf('  提取 trigger(%d/%d) 共 %d 个\n', startTrig, endTrig, size(trigger_positions, 1));
end

function bad_periods = extract_bad_segments_from_eeg(EEG)
% 从 EEGLAB event 结构中提取 BAD_segment 事件，返回 [start, end] 采样点矩阵
bad_periods = [];
if ~isfield(EEG, 'event') || isempty(EEG.event)
    return;
end
for i = 1:numel(EEG.event)
    ev = EEG.event(i);
    if ~isfield(ev, 'type') || ~strcmp(ev.type, 'BAD_segment')
        continue;
    end
    if isfield(ev, 'latency') && ~isempty(ev.latency)
        start = round(double(ev.latency));
        if isfield(ev, 'duration') && ~isempty(ev.duration)
            dur = round(double(ev.duration));
        else
            dur = 0;
        end
        bad_periods(end+1, :) = [start, start + dur]; %#ok<AGROW>
    end
end
end

function tf = segment_overlaps_bad(segStart, segEnd, bad_periods)
% 检查段 [segStart, segEnd] 是否与 bad_periods 中任何区间重叠
tf = false;
if isempty(bad_periods)
    return;
end
for i = 1:size(bad_periods, 1)
    bStart = bad_periods(i, 1);
    bEnd = bad_periods(i, 2);
    if segStart <= bEnd && segEnd >= bStart
        tf = true;
        return;
    end
end
end

function segOpts = build_seg_opts(cfg)
segOpts = struct();
if ~isfield(cfg, 'segment'), return; end
s = cfg.segment;
if isfield(s, 'preferEvtBdf'), segOpts.preferEvtBdf = s.preferEvtBdf; end
if isfield(s, 'stripImpedance'), segOpts.stripImpedance = s.stripImpedance; end
if isfield(s, 'pairMode'), segOpts.pairMode = s.pairMode; end
if isfield(s, 'fallbackToEndAnchor'), segOpts.fallbackToEndAnchor = s.fallbackToEndAnchor; end
if isfield(s, 'endAnchorDurationSec'), segOpts.endAnchorDurationSec = s.endAnchorDurationSec; end
end
