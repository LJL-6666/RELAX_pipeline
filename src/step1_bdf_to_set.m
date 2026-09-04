function step1_bdf_to_set(cfg)
% STEP1_BDF_TO_SET  原始 BDF -> 按 videoIndex 对齐的 EEGLAB .set
%
% 输入约定（二选一）：
%   A) data/<task>/<subID>/data.bdf + *rating*.csv
%   B) data/<task>/<subID>/<folderName>/data.bdf ，CSV 同层或被试目录
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
        [bdfPath, csvFile] = resolve_subject_files(taskRoot, subID, cfg);
        if isempty(bdfPath)
            fail{end+1} = sprintf('%s: 无 BDF', subID); %#ok<AGROW>
            continue;
        end
        if isempty(csvFile)
            fail{end+1} = sprintf('%s: 无 rating CSV', subID); %#ok<AGROW>
            continue;
        end
        fprintf('  BDF/CSV: %s | %s\n', stringify_bdf(bdfPath), csvFile);

        [trial_vid_pairs, vid_list] = read_vid_from_csv(csvFile); %#ok<ASGLU>
        if isempty(vid_list)
            fail{end+1} = sprintf('%s: CSV 无 vid', subID); %#ok<AGROW>
            continue;
        end

        if iscell(bdfPath)
            if exist('extract_video_segments_from_multiple_bdf', 'file')
                video_segments = extract_video_segments_from_multiple_bdf(bdfPath);
            else
                error('多 BDF 需要 problem_data_tools/extract_video_segments_from_multiple_bdf');
            end
            primaryBdf = bdfPath{1};
        else
            video_segments = extract_video_segments_from_bdf(bdfPath, '');
            primaryBdf = bdfPath;
        end
        if isempty(video_segments)
            fail{end+1} = sprintf('%s: 无 trigger 段', subID); %#ok<AGROW>
            continue;
        end

        n = min(numel(video_segments), size(trial_vid_pairs, 1));
        video_segments = video_segments(1:n);
        trial_vid_pairs = trial_vid_pairs(1:n, :);

        aligned = align_by_vid_and_convert_to_set( ...
            primaryBdf, video_segments, trial_vid_pairs, subID, outDir, capFile);
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

function [bdfPath, csvFile] = resolve_subject_files(taskRoot, subID, cfg)
subDir = fullfile(taskRoot, subID);
searchDirs = {subDir};
if ~isempty(cfg.task.folderName)
    searchDirs = [{fullfile(subDir, cfg.task.folderName)}, searchDirs];
end
bdfPath = [];
for k = 1:numel(searchDirs)
    bd = searchDirs{k};
    files = dir(fullfile(bd, 'data*.bdf'));
    if isempty(files), continue; end
    names = {files.name};
    nums = zeros(size(names));
    for i = 1:numel(names)
        tok = regexp(names{i}, 'data\.(\d+)\.bdf', 'tokens');
        if ~isempty(tok), nums(i) = str2double(tok{1}{1}); else, nums(i) = 0; end
    end
    [~, ord] = sort(nums);
    files = files(ord);
    paths = fullfile(bd, {files.name});
    if numel(paths) == 1
        bdfPath = paths{1};
    else
        bdfPath = paths;
    end
    break;
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
