%% 合并RELAX清理后的各vid为单个被试文件 - 交流任务
%
% 输入:
%   E:\...\RELAX输入\交流\RELAXProcessed\Cleaned_Data\subXXX_vidYY_RELAX.set
% 输出:
%   E:\...\数据\脑电预处理后\交流\subXXX_RELAX_merged.set

clear; close all; clc;

fprintf('=== 合并RELAX结果 - 交流任务 ===\n');
fprintf('开始时间: %s\n\n', datestr(now));

base_dir = 'E:\ljl\work\通用\RELAX_update\归档\新预处理';
task_name = '交流';

input_dir  = fullfile(base_dir, 'RELAX输入', task_name, 'RELAXProcessed', 'Cleaned_Data');
output_dir = fullfile(base_dir, '数据', '脑电预处理后', task_name);

if ~exist(input_dir, 'dir')
    error('输入目录不存在: %s', input_dir);
end
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

% ===== 依赖：EEGLAB =====
toolbox_dir = 'D:\APP\matlab\bao';
eeglab_path = fullfile(toolbox_dir, 'eeglab2025.1.0');
if ~exist(eeglab_path, 'dir')
    error('未找到EEGLAB: %s', eeglab_path);
end
addpath(eeglab_path);
try
    evalc('eeglab(''nogui'')');
catch ME
    warning('EEGLAB初始化失败，将继续尝试合并: %s', ME.message);
end

% ===== 扫描输入文件 =====
cd(input_dir);
all_files = dir('*_RELAX.set');
if isempty(all_files)
    error('未找到RELAX清理后的set文件: %s', input_dir);
end

sub_map = containers.Map('KeyType', 'char', 'ValueType', 'any');
for i = 1:numel(all_files)
    fn = all_files(i).name;
    tok = regexp(fn, '^(sub\d+)_vid(\d+)_RELAX\.set$', 'tokens', 'once');
    if isempty(tok)
        continue;
    end
    sub_id = tok{1};
    vid = str2double(tok{2});
    if isnan(vid)
        continue;
    end
    if ~isKey(sub_map, sub_id)
        sub_map(sub_id) = struct('vid', [], 'file', {{}});
    end
    s = sub_map(sub_id);
    s.vid(end+1) = vid; %#ok<AGROW>
    s.file{end+1} = fn; %#ok<AGROW>
    sub_map(sub_id) = s;
end

subject_ids = keys(sub_map);
% sort by numeric part
sub_nums = zeros(size(subject_ids));
for i = 1:numel(subject_ids)
    t = regexp(subject_ids{i}, '^sub(\d+)$', 'tokens', 'once');
    sub_nums(i) = str2double(t{1});
end
[~, order] = sort(sub_nums);
subject_ids = subject_ids(order);

fprintf('输入目录: %s\n', input_dir);
fprintf('输出目录: %s\n', output_dir);
fprintf('找到 %d 个被试需要合并\n\n', numel(subject_ids));

success = 0;
failed = {};

for si = 1:numel(subject_ids)
    sub_id = subject_ids{si};
    s = sub_map(sub_id);

    [sorted_vids, idx] = sort(s.vid);
    vid_files = s.file(idx);

    out_name = sprintf('%s_RELAX_merged.set', sub_id);
    out_path = fullfile(output_dir, out_name);

    if exist(out_path, 'file')
        fprintf('[%d/%d] %s 已存在，跳过: %s\n', si, numel(subject_ids), sub_id, out_name);
        success = success + 1;
        continue;
    end

    fprintf('[%d/%d] 合并 %s (%d个存在的vid)\n', si, numel(subject_ids), sub_id, numel(vid_files));

    try
        EEG_merged = [];
        total_samples = 0;
        merged_vid_list = [];

        % 定义完整的vid范围（1-28）
        all_vids = 1:28;

        % 创建vid到文件的映射
        vid_to_file = containers.Map('KeyType', 'double', 'ValueType', 'any');
        for vi = 1:numel(sorted_vids)
            vid_to_file(sorted_vids(vi)) = vid_files{vi};
        end

        % 按完整的vid顺序处理
        for vid = all_vids
            % 检查该vid是否存在RELAX处理后的文件
            if isKey(vid_to_file, vid)
                % 存在：读取真实数据
                fn = vid_to_file(vid);
                EEG = pop_loadset('filename', fn, 'filepath', input_dir);
                if ndims(EEG.data) ~= 2
                    error('数据不是连续2D (nbchan x pnts): %s', fn);
                end

                fprintf('  vid%02d: 读取真实数据 (%s, %.2fs)\n', vid, fn, EEG.pnts/EEG.srate);
            else
                % 不存在：创建nan占位数据
                % 使用第一个有效文件的参数作为模板
                if isempty(EEG_merged)
                    % 如果这是第一个vid且缺失，从第一个存在的文件获取参数
                    first_valid_vid = sorted_vids(1);
                    template_fn = vid_to_file(first_valid_vid);
                    EEG_template = pop_loadset('filename', template_fn, 'filepath', input_dir);
                    nbchan = EEG_template.nbchan;
                    srate = EEG_template.srate;
                    chanlocs = EEG_template.chanlocs;
                    % 估算平均时长（使用30秒作为默认值）
                    default_duration = 30;
                else
                    nbchan = EEG_merged.nbchan;
                    srate = EEG_merged.srate;
                    chanlocs = EEG_merged.chanlocs;
                    default_duration = 30;
                end

                % 创建nan数据
                nan_pnts = round(default_duration * srate);
                EEG = eeg_emptyset();
                EEG.data = nan(nbchan, nan_pnts);
                EEG.srate = srate;
                EEG.pnts = nan_pnts;
                EEG.nbchan = nbchan;
                EEG.chanlocs = chanlocs;
                EEG.xmin = 0;
                EEG.xmax = (EEG.pnts - 1) / EEG.srate;
                EEG.times = (0:EEG.pnts-1) / EEG.srate * 1000;

                fprintf('  vid%02d: 使用NaN占位 (%.2fs)\n', vid, nan_pnts/srate);
            end

            % 给每段开头加vid标记事件，便于后续提取
            EEG = add_vid_marker_event(EEG, vid);

            % 调整事件latency到合并后的时间轴
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

                EEG_merged.data = [EEG_merged.data, EEG.data];
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

        EEG_merged.merged_info = struct();
        EEG_merged.merged_info.task = task_name;
        EEG_merged.merged_info.subject_id = sub_id;
        EEG_merged.merged_info.vid_list = merged_vid_list;
        EEG_merged.merged_info.vid_count = numel(merged_vid_list);
        EEG_merged.merged_info.total_duration_sec = EEG_merged.pnts / EEG_merged.srate;

        pop_saveset(EEG_merged, 'filename', out_name, 'filepath', output_dir);

        fprintf('  -> 保存: %s (%.2f s)\n', out_name, EEG_merged.merged_info.total_duration_sec);
        success = success + 1;

    catch ME
        fprintf('  !! 失败 %s: %s\n', sub_id, ME.message);
        failed{end+1} = sprintf('%s: %s', sub_id, ME.message); %#ok<AGROW>
    end
end

fprintf('\n=== 完成 ===\n');
fprintf('成功: %d / %d\n', success, numel(subject_ids));
if ~isempty(failed)
    fprintf('失败列表:\n');
    for i = 1:numel(failed)
        fprintf('  - %s\n', failed{i});
    end
end
fprintf('结束时间: %s\n', datestr(now));

% ===== local function =====
function EEG = add_vid_marker_event(EEG, vid)
    % Ensure EEG.event exists and has consistent fields so we can append.
    if ~isfield(EEG, 'event') || isempty(EEG.event)
        EEG.event = struct('type', {}, 'latency', {}, 'duration', {}, 'vid', {}, 'videoIndex', {});
    end

    % Ensure these fields exist on every event (some files have additional fields).
    EEG.event = ensure_event_fields(EEG.event, {'type','latency','duration','vid','videoIndex'});
    EEG.event = normalize_event_type(EEG.event);

    % Create a new event with the same field set as EEG.event.
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
