function [trigger_positions, fs, nSamples, info] = collect_trigger_positions(data_sources, evt_bdf, startTrig, endTrig, segOpts)
% COLLECT_TRIGGER_POSITIONS  从 data 和/或 evt.bdf 收集起止 trigger 采样点
%
% data_sources: 单个路径字符串，或 cell 数组（多 BDF，FieldTrip 自动合并）
% evt_bdf:      evt.bdf 路径；空则仅用 data 头事件
% startTrig/endTrig: 起止 trigger 数值
% segOpts:      可选结构体
%   .preferEvtBdf   (default true)  有 evt.bdf 时优先用其事件（整段绝对时间）
%   .stripImpedance (default true)  删除 Start/Stop Impedance 等标记后继续

if nargin < 5 || isempty(segOpts), segOpts = struct(); end
if ~isfield(segOpts, 'preferEvtBdf') || isempty(segOpts.preferEvtBdf)
    segOpts.preferEvtBdf = true;
end
if ~isfield(segOpts, 'stripImpedance') || isempty(segOpts.stripImpedance)
    segOpts.stripImpedance = true;
end

info = struct('eventSource', '', 'nImpedanceRemoved', 0, 'nEventsRaw', 0);

cfg = [];
cfg.headerfile = data_sources;
hdr = ft_read_header(cfg.headerfile);
fs = hdr.Fs;
nSamples = hdr.nSamples;

events = [];
eventSource = 'data';
useEvt = segOpts.preferEvtBdf && ~isempty(evt_bdf) && exist(evt_bdf, 'file') == 2;
if useEvt
    try
        cfgE = [];
        cfgE.headerfile = evt_bdf;
        hdrE = ft_read_header(cfgE.headerfile);
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
info.eventSource = eventSource;
info.nEventsRaw = numel(events);

% 清理空事件
valid = false(1, numel(events));
for i = 1:numel(events)
    if iscell(events)
        ev = events{i};
    else
        ev = events(i);
    end
    if isstruct(ev) && ((isfield(ev, 'eventvalue') && ~isempty(ev.eventvalue)) || ...
            (isfield(ev, 'value') && ~isempty(ev.value)) || ...
            (isfield(ev, 'type') && ~isempty(ev.type)))
        valid(i) = true;
    end
end
if iscell(events)
    events = events(valid);
else
    events = events(valid);
end

% 阻抗标记：删除后继续（多 BDF 分界处常见，不应拒被试）
if segOpts.stripImpedance
    [events, nRem] = strip_impedance_events(events);
    info.nImpedanceRemoved = nRem;
    if nRem > 0
        fprintf('  已删除 %d 个阻抗/边界标记，继续处理（事件源=%s）\n', nRem, eventSource);
    end
end

trigger_positions = [];
for i = 1:numel(events)
    if iscell(events)
        ev = events{i};
    else
        ev = events(i);
    end
    val = event_numeric_value(ev);
    if isempty(val) || (val ~= startTrig && val ~= endTrig)
        continue;
    end
    sample = event_sample(ev, fs);
    if isempty(sample), continue; end
    trigger_positions(end+1, :) = [val, sample]; %#ok<AGROW>
end

if ~isempty(trigger_positions)
    [~, ord] = sort(trigger_positions(:, 2));
    trigger_positions = trigger_positions(ord, :);
end

fprintf('  事件源=%s，起止 trigger(%d/%d) 共 %d 个标记\n', ...
    eventSource, startTrig, endTrig, size(trigger_positions, 1));
end

function [events, nRem] = strip_impedance_events(events)
nRem = 0;
keep = true(1, numel(events));
for i = 1:numel(events)
    if iscell(events), ev = events{i}; else, ev = events(i); end
    if event_is_impedance(ev)
        keep(i) = false;
        nRem = nRem + 1;
    end
end
if iscell(events)
    events = events(keep);
else
    events = events(keep);
end
end

function tf = event_is_impedance(ev)
tf = false;
fields = {'eventvalue', 'value', 'type', 'eventtype'};
for f = 1:numel(fields)
    if ~isfield(ev, fields{f}), continue; end
    v = ev.(fields{f});
    if isnumeric(v), continue; end
    s = lower(strtrim(char(string(v))));
    if contains(s, 'impedance')
        tf = true;
        return;
    end
end
end

function val = event_numeric_value(ev)
val = [];
if isfield(ev, 'eventvalue') && ~isempty(ev.eventvalue)
    v = ev.eventvalue;
elseif isfield(ev, 'value') && ~isempty(ev.value)
    v = ev.value;
else
    return;
end
if isnumeric(v)
    val = double(v(1));
elseif ischar(v) || isstring(v)
    val = str2double(v);
    if isnan(val), val = []; end
end
end

function sample = event_sample(ev, fs)
sample = [];
if isfield(ev, 'offset_in_sec') && ~isempty(ev.offset_in_sec)
    sample = round(double(ev.offset_in_sec) * fs);
elseif isfield(ev, 'sample') && ~isempty(ev.sample)
    sample = double(ev.sample);
elseif isfield(ev, 'timestamp') && ~isempty(ev.timestamp)
    sample = round(double(ev.timestamp) * fs);
end
end
