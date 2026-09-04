function step3_merge_subjects(cfg)
% STEP3_MERGE_SUBJECTS  将各 vid 的 *_RELAX.set 合并为每被试一个文件
%
% 输入：output/relax/<task>/RELAXProcessed/Cleaned_Data/subXXX_vidYY_RELAX.set
%   若尚无 mirror，则回退到 output/set_by_vid/<task>/RELAXProcessed/Cleaned_Data
% 输出：output/merged/<task>/subXXX_RELAX_merged.set
%
% 合并行为由 cfg.merge 控制（对齐定稿 merge_*_postrelax.m）：
%   cfg.merge.padMissingVid     缺 vid 时是否用 NaN 段占位（默认 false）
%   cfg.merge.vidRange          完整 vid 范围，如 1:28；[] = 只合已有 vid
%   cfg.merge.padDurationSec    占位 NaN 段时长（秒，默认 30）
%   cfg.merge.addVidMarkerEvent 每段开头加 vidXX 标记事件（默认 true）
%   cfg.merge.method            'pop_mergeset'（默认，EEGLAB 合并）
%                               或 'concat'（定稿脚本的手工拼接+事件校正）

candidates = {
    fullfile(cfg.paths.outputRoot, 'relax', cfg.task.name, 'RELAXProcessed', 'Cleaned_Data')
    fullfile(cfg.paths.outputRoot, 'set_by_vid', cfg.task.name, 'RELAXProcessed', 'Cleaned_Data')
    };
input_dir = '';
for i = 1:numel(candidates)
    if exist(candidates{i}, 'dir') == 7
        input_dir = candidates{i};
        break;
    end
end
if isempty(input_dir)
    error('[step3] 未找到 Cleaned_Data，请先完成 step2。');
end

output_dir = fullfile(cfg.paths.outputRoot, 'merged', cfg.task.name);
if ~exist(output_dir, 'dir'), mkdir(output_dir); end

% ---- 合并选项（含默认值）----
mg = struct( ...
    'padMissingVid', false, ...
    'vidRange', [], ...
    'padDurationSec', 30, ...
    'addVidMarkerEvent', true, ...
    'method', 'pop_mergeset');
if isfield(cfg, 'merge')
    fns = fieldnames(cfg.merge);
    for i = 1:numel(fns)
        mg.(fns{i}) = cfg.merge.(fns{i});
    end
end
if mg.padMissingVid && isempty(mg.vidRange)
    warning('[step3] padMissingVid=true 但 vidRange 为空，将退化为只合并已有 vid。');
    mg.padMissingVid = false;
end

all_files = dir(fullfile(input_dir, '*_RELAX.set'));
if isempty(all_files)
    error('[step3] 无 *_RELAX.set: %s', input_dir);
end

sub_map = containers.Map('KeyType', 'char', 'ValueType', 'any');
for i = 1:numel(all_files)
    fn = all_files(i).name;
    tok = regexp(fn, '^(sub\d+)_vid(\d+)_RELAX\.set$', 'tokens', 'once');
    if isempty(tok), continue; end
    sub_id = tok{1};
    vid = str2double(tok{2});
    if ~isKey(sub_map, sub_id)
        sub_map(sub_id) = struct('vid', [], 'file', {{}});
    end
    rec = sub_map(sub_id);
    rec.vid(end+1) = vid;
    rec.file{end+1} = fullfile(input_dir, fn);
    sub_map(sub_id) = rec;
end

keys = sub_map.keys;
fprintf('[step3] 合并 %d 名被试...（占位=%d, 事件=%d, 方法=%s）\n', ...
    numel(keys), mg.padMissingVid, mg.addVidMarkerEvent, mg.method);
for k = 1:numel(keys)
    sub_id = keys{k};
    outFile = fullfile(output_dir, [sub_id '_RELAX_merged.set']);
    if cfg.pipeline.skipExisting && exist(outFile, 'file')
        fprintf('  %s 已存在，跳过。\n', sub_id);
        continue;
    end
    rec = sub_map(sub_id);
    [vids, ord] = sort(rec.vid);
    files = rec.file(ord);
    try
        if mg.padMissingVid || strcmp(mg.method, 'concat') || mg.addVidMarkerEvent
            EEG = merge_with_markers(input_dir, files, vids, sub_id, mg);
        else
            EEG = merge_simple(files, sub_id);
        end
        EEG.setname = [sub_id '_RELAX_merged'];
        EEG.merged_info = struct('subject_id', sub_id, 'vid_list', vids, ...
            'padMissingVid', mg.padMissingVid, 'srate', EEG.srate, ...
            'total_duration_sec', EEG.pnts / EEG.srate);
        pop_saveset(EEG, 'filename', [sub_id '_RELAX_merged.set'], 'filepath', output_dir);
        fprintf('  %s: %d vids -> %s\n', sub_id, numel(files), outFile);
    catch ME
        warning('[step3] %s 合并失败: %s', sub_id, ME.message);
    end
end
end

% ===== 简单合并（默认）：pop_mergeset 顺序拼接 =====
function EEG = merge_simple(files, sub_id)
EEG = [];
for f = 1:numel(files)
    E = pop_loadset('filename', files{f});
    E.setname = sprintf('%s_seg%02d', sub_id, f);
    if isempty(EEG)
        EEG = E;
    else
        EEG = pop_mergeset(EEG, E, 1);
    end
end
end

% ===== 定稿式合并：NaN 占位缺 vid + vid 标记事件 + 手工拼接 =====
function EEG_merged = merge_with_markers(input_dir, files, vids, sub_id, mg)
vid_to_file = containers.Map('KeyType', 'double', 'ValueType', 'char');
for vi = 1:numel(vids)
    vid_to_file(vids(vi)) = files{vi};
end

if mg.padMissingVid
    all_vids = mg.vidRange;
else
    all_vids = vids;
end

EEG_merged = [];
total_samples = 0;
merged_vid_list = [];

for vid = all_vids
    if isKey(vid_to_file, vid)
        fn = vid_to_file(vid);
        [~, fnBase, fnExt] = fileparts(fn);
        EEG = pop_loadset('filename', [fnBase fnExt], 'filepath', input_dir);
        if ndims(EEG.data) ~= 2
            error('数据不是连续2D (nbchan x pnts): %s', fn);
        end
        fprintf('  vid%02d: 读取真实数据 (%.2fs)\n', vid, EEG.pnts / EEG.srate);
    else
        % 缺失 vid：NaN 占位（模板参数取自已有数据或首个文件）
        if ~isempty(EEG_merged)
            nbchan = EEG_merged.nbchan; srate = EEG_merged.srate;
            chanlocs = EEG_merged.chanlocs;
        else
            first_fn = vid_to_file(vids(1));
            [~, fb, fe] = fileparts(first_fn);
            T = pop_loadset('filename', [fb fe], 'filepath', input_dir);
            nbchan = T.nbchan; srate = T.srate; chanlocs = T.chanlocs;
        end
        nan_pnts = round(mg.padDurationSec * srate);
        EEG = eeg_emptyset();
        EEG.data = nan(nbchan, nan_pnts);
        EEG.srate = srate;
        EEG.pnts = nan_pnts;
        EEG.nbchan = nbchan;
        EEG.chanlocs = chanlocs;
        EEG.xmin = 0;
        EEG.xmax = (EEG.pnts - 1) / EEG.srate;
        EEG.times = (0:EEG.pnts-1) / EEG.srate * 1000;
        fprintf('  vid%02d: 使用NaN占位 (%.2fs)\n', vid, nan_pnts / srate);
    end

    if mg.addVidMarkerEvent
        EEG = add_vid_marker_event(EEG, vid);
    end

    % 事件 latency 平移到合并时间轴
    if isfield(EEG, 'event') && ~isempty(EEG.event)
        for e = 1:numel(EEG.event)
            if isfield(EEG.event(e), 'latency') && ~isempty(EEG.event(e).latency)
                EEG.event(e).latency = EEG.event(e).latency + total_samples;
            end
        end
    end

    if isempty(EEG_merged)
        EEG_merged = EEG;
        total_samples = EEG.pnts;
    else
        if EEG.nbchan ~= EEG_merged.nbchan
            error('通道数不一致: merged=%d, cur=%d (vid=%d)', EEG_merged.nbchan, EEG.nbchan, vid);
        end
        if abs(EEG.srate - EEG_merged.srate) > 1e-6
            error('采样率不一致: merged=%.6f, cur=%.6f (vid=%d)', EEG_merged.srate, EEG.srate, vid);
        end
        EEG_merged.data = [EEG_merged.data, EEG.data]; %#ok<AGROW>
        EEG_merged.pnts = size(EEG_merged.data, 2);
        total_samples = EEG_merged.pnts;
        if isfield(EEG, 'event') && ~isempty(EEG.event)
            if ~isfield(EEG_merged, 'event') || isempty(EEG_merged.event)
                EEG_merged.event = EEG.event;
            else
                EEG_merged.event = concat_events(EEG_merged.event, EEG.event);
            end
        end
        EEG_merged.xmax = (EEG_merged.pnts - 1) / EEG_merged.srate;
        EEG_merged.times = (0:EEG_merged.pnts-1) / EEG_merged.srate * 1000;
    end

    merged_vid_list(end+1) = vid; %#ok<AGROW>
end

EEG_merged = eeg_checkset(EEG_merged, 'eventconsistency');
EEG_merged.merged_vid_list = merged_vid_list;
end

function EEG = add_vid_marker_event(EEG, vid)
if ~isfield(EEG, 'event') || isempty(EEG.event)
    EEG.event = struct('type', {}, 'latency', {}, 'duration', {}, 'vid', {}, 'videoIndex', {});
end
EEG.event = ensure_event_fields(EEG.event, {'type','latency','duration','vid','videoIndex'});
EEG.event = normalize_event_type(EEG.event);
fields = fieldnames(EEG.event);
ev = cell2struct(repmat({[]}, numel(fields), 1), fields, 1);
ev.type = sprintf('vid%02d', vid);
ev.latency = 1;
if ismember('duration', fields); ev.duration = 0; end
if ismember('vid', fields); ev.vid = vid; end
if ismember('videoIndex', fields); ev.videoIndex = vid; end
EEG.event(end+1) = ev;
end

function events = ensure_event_fields(events, required_fields)
for k = 1:numel(required_fields)
    f = required_fields{k};
    if ~isfield(events, f)
        [events.(f)] = deal([]);
    end
end
end

function events = normalize_event_type(events)
if ~isfield(events, 'type'); return; end
for i = 1:numel(events)
    if isnumeric(events(i).type)
        events(i).type = num2str(events(i).type);
    elseif isstring(events(i).type)
        events(i).type = char(events(i).type);
    end
end
end

function out = concat_events(a, b)
if isempty(a); out = b; return; end
if isempty(b); out = a; return; end
fa = fieldnames(a);
fb = fieldnames(b);
allFields = unique([fa; fb], 'stable');
a = ensure_event_fields(a, allFields);
b = ensure_event_fields(b, allFields);
a = orderfields(a, allFields);
b = orderfields(b, allFields);
out = [a, b];
end
