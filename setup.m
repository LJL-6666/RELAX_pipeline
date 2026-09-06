function setup()
% SETUP  配置功能流水线路径并自检依赖（main 自动调用）

root = fileparts(mfilename('fullpath'));
ext  = fullfile(root, 'external');

%% EEGLAB
eeglabDir = fullfile(ext, 'eeglab2025.1.0');
if exist(eeglabDir, 'dir') ~= 7
    error('未找到 EEGLAB：%s', eeglabDir);
end
addpath(eeglabDir);

%% FieldTrip
ftDir = fullfile(ext, 'fieldtrip-20181205');
if exist(ftDir, 'dir') ~= 7
    error('未找到 FieldTrip：%s', ftDir);
end
addpath(ftDir);
ft_defaults;

%% RELAX + 依赖
add_if_exists(fullfile(ext, 'RELAX-RELAX-v2.0.0'));
add_if_exists(fullfile(ext, 'mwf-artifact-removal'), true);
add_if_exists(fullfile(ext, 'PrepPipeline'), true);
add_if_exists(fullfile(ext, 'ICLabel'), true);
add_if_exists(fullfile(ext, 'PICARD1.0'));
add_if_exists(fullfile(ext, 'FastICA_25'));
biosig = fullfile(ext, 'Biosig3.8.4');
if exist(biosig, 'dir') == 7
    addpath(genpath(biosig));
    nanPath = fullfile(biosig, 'NaN');
    if exist(nanPath, 'dir') == 7
        rmpath(genpath(nanPath));
    end
end
add_if_exists(fullfile(ext, 'NeuracleEEGFileReader1.2'));

%% ERPLAB（可选；RejCrap / RejNontask 需要 pop_continuousartdet 等）
erplab = fullfile(ext, 'erplab12.20');
if exist(erplab, 'dir') == 7
    addpath(fullfile(erplab, 'pop_functions'));
    addpath(fullfile(erplab, 'functions'));
end

%% 本项目
addpath(fullfile(root, 'src'));
addpath(fullfile(root, 'src', 'utils'));
prob = fullfile(root, 'src', 'utils', 'problem_data_tools');
if exist(prob, 'dir') == 7
    addpath(prob);
end

%% EEGLAB nogui
try
    evalc('eeglab(''nogui'')');
catch ME
    warning('EEGLAB nogui 初始化失败，将继续: %s', ME.message);
end

required = {'RELAX_Wrapper', 'ft_read_header', 'pop_saveset', ...
            'extract_video_segments_from_bdf', 'read_vid_from_csv', ...
            'align_by_vid_and_convert_to_set', ...
            'collect_trigger_positions', 'pair_segments_from_triggers', ...
            'extract_video_segments_from_multiple_bdf', ...
            'align_by_vid_and_convert_to_set_multiple_bdf', ...
            'step1b_whole_bdf_to_set', 'step2b_relax_clean_whole', 'step3b_epoch_after_relax'};
missing = required(cellfun(@(f) exist(f, 'file') ~= 2, required));
if ~isempty(missing)
    error('缺少函数：\n  %s', strjoin(missing, '\n  '));
end

fprintf('[setup] RELAX 功能流水线环境就绪。\n');
end

function add_if_exists(p, recursive)
if nargin < 2, recursive = false; end
if exist(p, 'dir') ~= 7, return; end
if recursive
    addpath(genpath(p));
else
    addpath(p);
end
end
