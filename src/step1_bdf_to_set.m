function step1_bdf_to_set(cfg)
% STEP1_BDF_TO_SET  原始 BDF -> 按 videoIndex 对齐的 EEGLAB .set
%
% 输入约定（二选一）：
%   A) data/<task>/<subID>/data.bdf(+data.1.bdf…) + evt.bdf(可选) + *rating*.csv
%   B) data/<task>/<subID>/<folderName>/... 同上
%
% 多 BDF：按 data.bdf → data.1.bdf → … 排序拼接；优先用整段 evt.bdf 事件；
% 删除分界处阻抗标记后继续；写出时用 multi-BDF 对齐函数读完整波形。
%
% 输出：output/set_by_vid/<task>/subXXX_vidYY.set

outDir = fullfile(cfg.paths.outputRoot, 'set_by_vid', cfg.task.name);
if ~exist(outDir, 'dir'), mkdir(outDir); end

taskRoot = fullfile(cfg.paths.dataRoot, cfg.task.name);
if exist(taskRoot, 'dir') ~= 7
    error('[step1] 数据目录不存在: %s\n请按 README 摆放 data/<task>/<subID>/...', taskRoot);
end

subs = list_subjects(taskRoot, cfg);
if isempty(subs)
    error('[step1] 未找到被试文件夹: %s', taskRoot);
end

capFile = cfg.paths.capFile;
if exist(capFile, 'file') ~= 2
    warning('[step1] 电极文件不存在，将跳过 chanlocs: %s', capFile);
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

    if cfg.pipeline.skipExisting
        existing = dir(fullfile(outDir, sprintf('%s_vid*.set', subStr)));
        if ~isempty(existing)
            fprintf('  已存在 %d 个 set，跳过。\n', numel(existing));
            ok = ok + 1;
            continue;
        end
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

        [trial_vid_pairs, vid_list] = read_vid_from_csv(csvFile, cfg.task.orderColumn); %#ok<ASGLU>
        if isempty(vid_list)
            fail{end+1} = sprintf('%s: CSV 无 vid', subID); %#ok<AGROW>
            continue;
        end

        if iscell(bdfPath)
            fprintf('  多 BDF 合并模式（%d 个文件）\n', numel(bdfPath));
            video_segments = extract_video_segments_from_multiple_bdf( ...
                bdfPath, cfg.segment.startTrigger, cfg.segment.endTrigger, evtFile, segOpts);
        else
            video_segments = extract_video_segments_from_bdf( ...
                bdfPath, evtFile, cfg.segment.startTrigger, cfg.segment.endTrigger, segOpts);
        end
        if isempty(video_segments)
            fail{end+1} = sprintf('%s: 无 trigger 段', subID); %#ok<AGROW>
            continue;
        end

        n = min(numel(video_segments), size(trial_vid_pairs, 1));
        if numel(video_segments) ~= size(trial_vid_pairs, 1)
            warning('被试 %s: 视频段数(%d)与 CSV 行数(%d)不一致，取较小值 %d', ...
                subID, numel(video_segments), size(trial_vid_pairs, 1), n);
        end
        video_segments = video_segments(1:n);
        trial_vid_pairs = trial_vid_pairs(1:n, :);

        % 按 vid 排序后再写出（与定稿 process_* 一致）
        [~, sort_idx] = sort(trial_vid_pairs(:, 2));
        trial_vid_pairs = trial_vid_pairs(sort_idx, :);
        video_segments = video_segments(sort_idx);

        if iscell(bdfPath)
            if exist('align_by_vid_and_convert_to_set_multiple_bdf', 'file') ~= 2
                error('多 BDF 需要 align_by_vid_and_convert_to_set_multiple_bdf');
            end
            aligned = align_by_vid_and_convert_to_set_multiple_bdf( ...
                bdfPath, video_segments, trial_vid_pairs, subID, outDir, capFile);
        else
            aligned = align_by_vid_and_convert_to_set( ...
                bdfPath, video_segments, trial_vid_pairs, subID, outDir, capFile);
        end
        fprintf('  写出 %d 个 set\n', numel(aligned));
        ok = ok + 1;
    catch ME
        warning('[step1] %s 失败: %s', subID, ME.message);
        fail{end+1} = sprintf('%s: %s', subID, ME.message); %#ok<AGROW>
    end
end

fprintf('[step1] 成功 %d / %d\n', ok, numel(subs));
if ~isempty(fail)
    fprintf('[step1] 失败条目:\n');
    fprintf('  %s\n', fail{:});
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
    % 排除 evt / 非数据文件
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
            nums(i) = inf; % 未知命名靠后
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
