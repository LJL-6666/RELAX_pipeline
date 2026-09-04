function step3_merge_subjects(cfg)
% STEP3_MERGE_SUBJECTS  将各 vid 的 *_RELAX.set 合并为每被试一个文件
%
% 输入：output/relax/<task>/RELAXProcessed/Cleaned_Data/subXXX_vidYY_RELAX.set
%   若尚无 mirror，则回退到 output/set_by_vid/<task>/RELAXProcessed/Cleaned_Data
% 输出：output/merged/<task>/subXXX_RELAX_merged.set

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
fprintf('[step3] 合并 %d 名被试...\n', numel(keys));
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
        EEG = [];
        for f = 1:numel(files)
            E = pop_loadset('filename', files{f});
            E.setname = sprintf('%s_vid%02d', sub_id, vids(f));
            if isempty(EEG)
                EEG = E;
            else
                EEG = pop_mergeset(EEG, E, 1);
            end
        end
        EEG.setname = [sub_id '_RELAX_merged'];
        pop_saveset(EEG, 'filename', [sub_id '_RELAX_merged.set'], 'filepath', output_dir);
        fprintf('  %s: %d vids -> %s\n', sub_id, numel(files), outFile);
    catch ME
        warning('[step3] %s 合并失败: %s', sub_id, ME.message);
    end
end
end
