function step1b_whole_bdf_to_set(cfg)
% STEP1B_WHOLE_BDF_TO_SET  原始 BDF -> 整段连续 EEGLAB .set（Mode B）
%
% 与 step1_bdf_to_set 的区别：
%   - 不调用 extract_video_segments_*，不切分 21/22 段
%   - 直接读取 data.bdf（或多 BDF 合并）为整段连续数据
%   - 保留所有事件（含 21/22 trigger、阻抗标记等），供 step3b 切分使用
%
% 输入约定同 step1：
%   data/<task>/<subID>/data.bdf(+data.1.bdf…) + evt.bdf(可选) + *rating*.csv
%
% 输出：output/set_whole/<task>/subXXX_whole.set

outDir = fullfile(cfg.paths.outputRoot, 'set_whole', cfg.task.name);
if ~exist(outDir, 'dir'), mkdir(outDir); end

taskRoot = fullfile(cfg.paths.dataRoot, cfg.task.name);
if exist(taskRoot, 'dir') ~= 7
    error('[step1b] 数据目录不存在: %s\n请按 README 摆放 data/<task>/<subID>/...', taskRoot);
end

subs = list_subjects(taskRoot, cfg);
if isempty(subs)
    error('[step1b] 未找到被试文件夹: %s', taskRoot);
end

capFile = cfg.paths.capFile;
if exist(capFile, 'file') ~= 2
    warning('[step1b] 电极文件不存在，将跳过 chanlocs: %s', capFile);
    capFile = '';
end

segOpts = build_seg_opts(cfg);

ok = 0; fail = {};
for i = 1:numel(subs)
    subID = subs{i};
    fprintf('--- 被试 %s (%d/%d) ---\n', subID, i, numel(subs));
    subStr = sprintf('sub%03d', str2double(subID));
    if isnan(str2double(subID))
        subStr = ['sub' subID];
    end

    outFile = fullfile(outDir, sprintf('%s_whole.set', subStr));
    if cfg.pipeline.skipExisting && exist(outFile, 'file')
        fprintf('  已存在 %s，跳过。\n', outFile);
        ok = ok + 1;
        continue;
    end

    try
        [bdfPath, csvFile, evtFile] = resolve_subject_files(taskRoot, subID, cfg);
        if isempty(bdfPath)
            fail{end+1} = sprintf('%s: 无 BDF', subID); %#ok<AGROW>
            continue;
        end
        if isempty(csvFile)
            fail{end+1} = sprintf('%s: 无 rating CSV', subID); %#ok<AGROW>
            continue;
        end
        fprintf('  BDF: %s\n', stringify_bdf(bdfPath));
        fprintf('  CSV: %s\n', csvFile);
        if ~isempty(evtFile)
            fprintf('  EVT: %s（优先用作事件源）\n', evtFile);
        else
            fprintf('  EVT: （无 evt.bdf，使用 data 头事件）\n');
        end

        % 读取整段数据（单 BDF 或多 BDF 合并）
        EEG = read_whole_bdf_to_set(bdfPath, evtFile, capFile, segOpts);
        EEG.setname = sprintf('%s_whole', subStr);

        % 保存 CSV 中的 vid 列表到 EEG.etc，供 step3b 对齐
        [trial_vid_pairs, vid_list] = read_vid_from_csv(csvFile, cfg.task.orderColumn); %#ok<ASGLU>
        EEG.etc.trial_vid_pairs = trial_vid_pairs;
        EEG.etc.vid_list = vid_list;
        EEG.etc.csv_file = csvFile;
        EEG.etc.bdf_files = bdfPath;
        EEG.etc.evt_file = evtFile;

        pop_saveset(EEG, 'filename', sprintf('%s_whole.set', subStr), 'filepath', outDir);
        fprintf('  写出 %s (%.2f s, %d ch)\n', outFile, EEG.xmax, EEG.nbchan);
        ok = ok + 1;
    catch ME
        warning('[step1b] %s 失败: %s', subID, ME.message);
        fail{end+1} = sprintf('%s: %s', subID, ME.message); %#ok<AGROW>
    end
end

fprintf('[step1b] 成功 %d / %d\n', ok, numel(subs));
if ~isempty(fail)
    fprintf('[step1b] 失败条目:\n');
    fprintf('  %s\n', fail{:});
end
end

function EEG = read_whole_bdf_to_set(bdfPath, evtFile, capFile, segOpts)
% 读取整段 BDF（单文件或多文件合并）为 EEGLAB set

if iscell(bdfPath)
    fprintf('  多 BDF 合并模式（%d 个文件）\n', numel(bdfPath));
    hdr = ft_read_header(bdfPath);
    data = ft_read_data(bdfPath, 'header', hdr, 'chanindx', []);
else
    hdr = ft_read_header(bdfPath);
    data = ft_read_data(bdfPath, 'header', hdr, 'chanindx', []);
end

EEG = eeg_emptyset();
EEG.data = double(data);
EEG.srate = hdr.Fs;
EEG.pnts = size(data, 2);
EEG.nbchan = size(data, 1);
EEG.xmin = 0;
EEG.xmax = (EEG.pnts - 1) / EEG.srate;

% 通道标签
if isfield(hdr, 'label') && ~isempty(hdr.label) && iscell(hdr.label)
    n_chans = min(EEG.nbchan, length(hdr.label));
    chan_labels = cell(EEG.nbchan, 1);
    for ch = 1:n_chans
        if ischar(hdr.label{ch})
            chan_labels{ch} = hdr.label{ch};
        elseif iscell(hdr.label{ch})
            chan_labels{ch} = char(hdr.label{ch});
        else
            chan_labels{ch} = char(string(hdr.label{ch}));
        end
    end
    for ch = n_chans+1:EEG.nbchan
        chan_labels{ch} = sprintf('Ch%d', ch);
    end
else
    chan_labels = cell(EEG.nbchan, 1);
    for ch = 1:EEG.nbchan
        chan_labels{ch} = sprintf('Ch%d', ch);
    end
end
EEG.chanlocs = repmat(struct('labels', ''), EEG.nbchan, 1);
for ch = 1:EEG.nbchan
    EEG.chanlocs(ch).labels = chan_labels{ch};
end

% 电极位置
if exist(capFile, 'file') && ~isempty(EEG.chanlocs)
    try
        EEG = pop_chanedit(EEG, 'lookup', capFile);
        if ~isstruct(EEG.chanlocs) || length(EEG.chanlocs) ~= EEG.nbchan
            warning('pop_chanedit 返回 chanlocs 结构异常，使用原始标签');
            EEG.chanlocs = repmat(struct('labels', ''), EEG.nbchan, 1);
            for ch = 1:EEG.nbchan
                EEG.chanlocs(ch).labels = chan_labels{ch};
            end
        end
    catch ME
        warning('无法加载电极位置: %s', ME.message);
    end
end

% 事件：优先 evt.bdf，否则 data 头事件；保留全部事件供 step3b 使用
events = [];
eventSource = 'data';
useEvt = segOpts.preferEvtBdf && ~isempty(evtFile) && exist(evtFile, 'file') == 2;
if useEvt
    try
        hdrE = ft_read_header(evtFile);
        if ~isempty(hdrE.event)
            events = hdrE.event;
            eventSource = 'evt.bdf';
        end
    catch ME
        warning('读取 evt.bdf 失败，回退 data 事件: %s', ME.message);
    end
end
if isempty(events)
    events = hdr.event;
    eventSource = 'data';
end
fprintf('  事件源=%s，原始事件数=%d\n', eventSource, numel(events));

% 转换 FieldTrip 事件为 EEGLAB event 结构
EEG.event = fieldtrip_events_to_eeglab(events, EEG.srate);
EEG = eeg_checkset(EEG, 'eventconsistency');
end

function events_out = fieldtrip_events_to_eeglab(events_in, fs)
% 将 FieldTrip 事件结构转换为 EEGLAB event 结构
if isempty(events_in)
    events_out = struct('type', {}, 'latency', {}, 'duration', {});
    return;
end
events_out = struct('type', {}, 'latency', {}, 'duration', {});
for i = 1:numel(events_in)
    if iscell(events_in)
        ev = events_in{i};
    else
        ev = events_in(i);
    end
    if ~isstruct(ev), continue; end
    % type（兼容 FieldTrip value 与 biosig eventvalue）
    if isfield(ev, 'value') && ~isempty(ev.value)
        v = ev.value;
        if isnumeric(v)
            typeStr = num2str(v);
        else
            typeStr = char(string(v));
        end
    elseif isfield(ev, 'eventvalue') && ~isempty(ev.eventvalue)
        v = ev.eventvalue;
        if isnumeric(v)
            typeStr = num2str(v);
        else
            typeStr = char(string(v));
        end
    elseif isfield(ev, 'type') && ~isempty(ev.type)
        typeStr = char(string(ev.type));
    elseif isfield(ev, 'eventtype') && ~isempty(ev.eventtype)
        typeStr = char(string(ev.eventtype));
    else
        typeStr = 'unknown';
    end
    % latency (samples, 1-based)
    if isfield(ev, 'sample') && ~isempty(ev.sample)
        latency = double(ev.sample);
    elseif isfield(ev, 'offset_in_sec') && ~isempty(ev.offset_in_sec)
        latency = round(double(ev.offset_in_sec) * fs) + 1;
    elseif isfield(ev, 'timestamp') && ~isempty(ev.timestamp)
        latency = round(double(ev.timestamp) * fs) + 1;
    else
        continue;
    end
    % duration
    if isfield(ev, 'duration') && ~isempty(ev.duration)
        duration = double(ev.duration);
    else
        duration = 0;
    end
    events_out(end+1).type = typeStr; %#ok<AGROW>
    events_out(end).latency = latency;
    events_out(end).duration = duration;
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

function subs = list_subjects(taskRoot, cfg)
d = dir(taskRoot);
subs = {};
for i = 1:numel(d)
    if ~d(i).isdir || startsWith(d(i).name, '.'), continue; end
    if ~isempty(regexp(d(i).name, '^\d+$', 'once')) || startsWith(d(i).name, 'sub')
        subs{end+1} = d(i).name; %#ok<AGROW>
    end
end
subs = sort(subs);
if isnumeric(cfg.task.subjects)
    want = arrayfun(@num2str, cfg.task.subjects, 'UniformOutput', false);
    subs = subs(ismember(subs, want) | ismember(subs, strcat('sub', want)));
elseif iscell(cfg.task.subjects)
    subs = cfg.task.subjects;
end
end

function [bdfPath, csvFile, evtFile] = resolve_subject_files(taskRoot, subID, cfg)
subDir = fullfile(taskRoot, subID);
searchDirs = {subDir};
if ~isempty(cfg.task.folderName)
    searchDirs = [{fullfile(subDir, cfg.task.folderName)}, searchDirs];
end
bdfPath = [];
evtFile = '';
dataDir = '';
for k = 1:numel(searchDirs)
    bd = searchDirs{k};
    files = dir(fullfile(bd, 'data*.bdf'));
    if isempty(files), continue; end
    keep = true(1, numel(files));
    for i = 1:numel(files)
        nm = lower(files(i).name);
        if contains(nm, 'evt') || ~startsWith(nm, 'data')
            keep(i) = false;
        end
    end
    files = files(keep);
    if isempty(files), continue; end
    names = {files.name};
    nums = zeros(size(names));
    for i = 1:numel(names)
        tok = regexp(names{i}, '^data\.(\d+)\.bdf$', 'tokens', 'once');
        if ~isempty(tok)
            nums(i) = str2double(tok{1});
        elseif strcmpi(names{i}, 'data.bdf')
            nums(i) = 0;
        else
            nums(i) = inf;
        end
    end
    [~, ord] = sort(nums);
    files = files(ord);
    paths = fullfile(bd, {files.name});
    if numel(paths) == 1
        bdfPath = paths{1};
    else
        bdfPath = paths;
    end
    dataDir = bd;
    break;
end
if ~isempty(dataDir)
    cand = fullfile(dataDir, 'evt.bdf');
    if exist(cand, 'file') == 2
        evtFile = cand;
    end
end
csvFile = '';
csvDirs = [{subDir}, searchDirs];
for k = 1:numel(csvDirs)
    cands = dir(fullfile(csvDirs{k}, sprintf('*%s*.csv', cfg.task.csvPattern)));
    if isempty(cands)
        cands = dir(fullfile(csvDirs{k}, '*.csv'));
    end
    if ~isempty(cands)
        csvFile = fullfile(csvDirs{k}, cands(1).name);
        break;
    end
end
end

function s = stringify_bdf(bdfPath)
if iscell(bdfPath), s = strjoin(bdfPath, ', '); else, s = bdfPath; end
end
