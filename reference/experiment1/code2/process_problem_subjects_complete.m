%% 问题被试RELAX预处理流程
%
% 功能：对6个问题被试（18, 24, 26, 35, 36, 42）进行RELAX预处理
%
% 输入：
%   - SET文件：data/data-tongyong/原始数据/可用原始数据/转化成set的脑电_aligned/sub0XX_vidYY.set
%   - 这6个被试的SET文件已经通过code1/问题数据处理生成
%
% 输出：
%   - SET文件（RELAX清理后）：转化成set的脑电_aligned/RELAXProcessed/Cleaned_Data/
%   - SET文件（合并后）：转化成set的脑电_aligned/RELAXProcessed/Cleaned_Data_Merged/
%
% 使用方法：
%   cd /data/liujialing/TY/预处理/matlab/实验1/code2
%   matlab -batch "run('process_problem_subjects_complete.m')"
%
% 说明：
%   本脚本与主代码RELAX_SET_PARAMETERS_AND_RUN.m完全一致，
%   只是添加了文件过滤，仅处理6个问题被试的SET文件。
%
% Author: EEG Analysis Team
% Date: 2025-01-29

clear all; close all; clc;

%% ========== 路径配置 ==========
base_dir = '/data/liujialing/TY';

% EEGLAB路径
eeglab_path = '/data/liujialing/eeglab-develop';
if exist(eeglab_path, 'dir')
    addpath(eeglab_path);
    eeglab('nogui');
else
    error('EEGLAB路径不存在: %s', eeglab_path);
end

% 获取EEGLAB路径
eeglabPath = fileparts(which('eeglab'));

%% ========== 添加所有必要的依赖 ==========
fprintf('=== 配置依赖路径 ===\n');

% MWF插件
MWFPluginPath = fullfile(eeglabPath, 'plugins', 'mwf-artifact-removal-master');
if exist(MWFPluginPath, 'dir')
    addpath(genpath(MWFPluginPath));
else
    MWFPluginPath2 = fullfile(base_dir, '预处理/matlab/mwf-artifact-removal');
    if exist(MWFPluginPath2, 'dir')
        addpath(genpath(MWFPluginPath2));
        fprintf('✓ 使用项目中的MWF插件: %s\n', MWFPluginPath2);
    else
        warning('MWF插件路径不存在');
    end
end

% FieldTrip
if ~isempty(eeglabPath)
    FieldTripPath = fullfile(eeglabPath, 'plugins', 'Fieldtrip-lite20210601');
    if exist(FieldTripPath, 'dir')
        addpath(FieldTripPath);
        ft_external_eeglab = fullfile(FieldTripPath, 'external', 'eeglab');
        if exist(ft_external_eeglab, 'dir')
            addpath(ft_external_eeglab);
        end
    else
        ft_path = fullfile(base_dir, '预处理/matlab/fieldtrip-20181205');
        if exist(ft_path, 'dir')
            addpath(ft_path);
            addpath(fullfile(ft_path, 'fileio'));
            addpath(fullfile(ft_path, 'preproc'));
            addpath(fullfile(ft_path, 'trialfun'));
            addpath(fullfile(ft_path, 'utilities'));
            ft_external_eeglab = fullfile(ft_path, 'external', 'eeglab');
            if exist(ft_external_eeglab, 'dir')
                addpath(ft_external_eeglab);
            end
        end
    end
end

% PREP pipeline
if ~isempty(eeglabPath)
    PrepPipelinePath = fullfile(eeglabPath, 'plugins', 'PrepPipeline');
    if exist(PrepPipelinePath, 'dir')
        addpath(genpath(PrepPipelinePath));
    else
        prep_path = fullfile(base_dir, '预处理/matlab/PrepPipeline');
        if exist(prep_path, 'dir')
            addpath(genpath(prep_path));
            fprintf('✓ 使用项目中的PREP pipeline: %s\n', prep_path);
        end
    end
end

% FastICA
if ~isempty(eeglabPath)
    FastICAPath = fullfile(eeglabPath, 'plugins', 'FastICA_25');
    if exist(FastICAPath, 'dir')
        addpath(FastICAPath);
    else
        FastICAPath2 = fullfile(base_dir, '预处理/matlab/FastICA_25');
        if exist(FastICAPath2, 'dir')
            addpath(FastICAPath2);
            fprintf('✓ 使用项目中的FastICA: %s\n', FastICAPath2);
        end
    end
end

% ICLabel
if ~isempty(eeglabPath)
    ICLabelPath = fullfile(eeglabPath, 'plugins', 'ICLabel');
    if exist(ICLabelPath, 'dir')
        addpath(genpath(ICLabelPath));
    else
        ICLabelPath2 = fullfile(base_dir, '预处理/matlab/ICLabel');
        if exist(ICLabelPath2, 'dir')
            addpath(genpath(ICLabelPath2));
            fprintf('✓ 使用项目中的ICLabel: %s\n', ICLabelPath2);
        end
    end
end

% PICARD
if ~isempty(eeglabPath)
    PICARDPath = fullfile(eeglabPath, 'plugins', 'PICARD');
    if exist(PICARDPath, 'dir')
        addpath(genpath(PICARDPath));
    else
        PICARDPath2 = fullfile(base_dir, '预处理/matlab/PICARD1.0');
        if exist(PICARDPath2, 'dir')
            addpath(genpath(PICARDPath2));
            fprintf('✓ 使用项目中的PICARD: %s\n', PICARDPath2);
        end
    end
end

% Firfilt
if ~isempty(eeglabPath)
    FirfiltPath = fullfile(eeglabPath, 'plugins', 'firfilt');
    if exist(FirfiltPath, 'dir')
        addpath(genpath(FirfiltPath));
    else
        FirfiltPath2 = fullfile(base_dir, '预处理/matlab/firfilt');
        if exist(FirfiltPath2, 'dir')
            addpath(genpath(FirfiltPath2));
            fprintf('✓ 使用项目中的Firfilt: %s\n', FirfiltPath2);
        end
    end
end

% DIPFIT
if ~isempty(eeglabPath)
    DIPFITPath = fullfile(eeglabPath, 'plugins', 'dipfit');
    if exist(DIPFITPath, 'dir')
        addpath(genpath(DIPFITPath));
    else
        DIPFITPath2 = fullfile(base_dir, '预处理/matlab/dipfit');
        if exist(DIPFITPath2, 'dir')
            addpath(genpath(DIPFITPath2));
            fprintf('✓ 使用项目中的DIPFIT: %s\n', DIPFITPath2);
        end
    end
end

% Clean Rawdata
if ~isempty(eeglabPath)
    CleanRawdataPath = fullfile(eeglabPath, 'plugins', 'clean_rawdata');
    if exist(CleanRawdataPath, 'dir')
        addpath(genpath(CleanRawdataPath));
    else
        CleanRawdataPath2 = fullfile(base_dir, '预处理/matlab/clean_rawdata');
        if exist(CleanRawdataPath2, 'dir')
            addpath(genpath(CleanRawdataPath2));
            fprintf('✓ 使用项目中的clean_rawdata: %s\n', CleanRawdataPath2);
        else
            CleanRawdataPath3 = fullfile(base_dir, '预处理/matlab/clean_rawdata-master');
            if exist(CleanRawdataPath3, 'dir')
                addpath(genpath(CleanRawdataPath3));
                fprintf('✓ 使用项目中的clean_rawdata-master: %s\n', CleanRawdataPath3);
            end
        end
    end
end

% Biosig
if ~isempty(eeglabPath)
    BiosigPath = fullfile(eeglabPath, 'plugins', 'Biosig');
    if exist(BiosigPath, 'dir')
        addpath(genpath(BiosigPath));
    else
        BiosigPath2 = fullfile(base_dir, '预处理/matlab/Biosig3.8.4');
        if exist(BiosigPath2, 'dir')
            addpath(genpath(BiosigPath2));
            maybe_missing_path = fullfile(BiosigPath2, 'biosig', 'maybe-missing');
            if exist(maybe_missing_path, 'dir')
                rmpath(genpath(maybe_missing_path));
            end
            nan_path = fullfile(BiosigPath2, 'NaN');
            if exist(nan_path, 'dir')
                rmpath(genpath(nan_path));
            end
            fprintf('✓ 使用项目中的Biosig: %s\n', BiosigPath2);
        end
    end
end

% RELAX路径
relax_path = fullfile(base_dir, '预处理/matlab/实验1');
if exist(relax_path, 'dir')
    addpath(relax_path);
else
    error('RELAX路径不存在: %s', relax_path);
end

%% ========== 配置RELAX参数 ==========
fprintf('\n=== 配置RELAX参数 ===\n');

% 电极位置文件
RELAX_cfg.caploc = fullfile(base_dir, '预处理/matlab/配置环境/standard_1005.elc');

% 输入数据路径
RELAX_cfg.myPath = fullfile(base_dir, 'data/data-tongyong/原始数据/可用原始数据/转化成set的脑电_aligned');

% 单个文件（不使用）
RELAX_cfg.filename = [];

%% 列出所有SET文件并过滤
cd(RELAX_cfg.myPath);
RELAX_cfg.dirList = dir('*.set');
RELAX_cfg.files = {RELAX_cfg.dirList.name};

if isempty(RELAX_cfg.files)
    error('未找到SET文件');
end

% ========== 过滤：只处理6个问题被试的文件 ==========
problem_subjects = {'18', '24', '26', '35', '36', '42'};
problem_subject_patterns = {};
for i = 1:length(problem_subjects)
    sub_id = str2double(problem_subjects{i});
    problem_subject_patterns{end+1} = sprintf('sub%03d_vid', sub_id);
end

filtered_files = {};
for i = 1:length(RELAX_cfg.files)
    filename = RELAX_cfg.files{i};
    for j = 1:length(problem_subject_patterns)
        if ~isempty(strfind(filename, problem_subject_patterns{j}))
            filtered_files{end+1} = filename;
            break;
        end
    end
end

RELAX_cfg.files = filtered_files;
fprintf('找到 %d 个问题被试的SET文件\n', length(RELAX_cfg.files));

if isempty(RELAX_cfg.files)
    error('未找到问题被试的SET文件');
end

%% ========== RELAX核心参数（与主代码完全一致）==========
RELAX_cfg.Perform_targeted_wICA = 0;
RELAX_cfg.Do_MWF_Once = 1;
RELAX_cfg.Do_MWF_Twice = 1;
RELAX_cfg.Do_MWF_Thrice = 1;
RELAX_cfg.Perform_wICA_on_ICLabel = 1;
RELAX_cfg.Perform_ICA_subtract = 0;
RELAX_cfg.ICA_method = 'picard';
RELAX_cfg.Report_all_ICA_info = 'yes';
RELAX_cfg.Clean_other_comps = 'no';

RELAX_cfg.ICLabel_thresholds = [0.5 0.8 0.8 0.5 0.5 0.5 0.5];

RELAX_cfg.computerawmetrics = 1;
RELAX_cfg.computecleanedmetrics = 1;

RELAX_cfg.MWFRoundToCleanBlinks = 2;
RELAX_cfg.LowPassFilterAt_6Hz_BeforeDetectingBlinks = 'no';
RELAX_cfg.ProbabilityDataHasNoBlinks = 0;

RELAX_cfg.DriftSeverityThreshold = 10;
RELAX_cfg.ProportionWorstEpochsForDrift = 0.30;

RELAX_cfg.ExtremeVoltageShiftThreshold = 8;
RELAX_cfg.ExtremeAbsoluteVoltageThreshold = 500;
RELAX_cfg.ExtremeImprobableVoltageDistributionThreshold = 8;
RELAX_cfg.ExtremeSingleChannelKurtosisThreshold = 8;
RELAX_cfg.ExtremeAllChannelKurtosisThreshold = 8;
RELAX_cfg.ExtremeDriftSlopeThreshold = -4;
RELAX_cfg.ExtremeBlinkShiftThreshold = 3;

RELAX_cfg.MinimumArtifactDuration = 1200;
RELAX_cfg.MinimumBlinkArtifactDuration = 800;

RELAX_cfg.BlinkElectrodes = {'Fp1'; 'Fp2'; 'F3'; 'Fz'; 'F4'};
RELAX_cfg.HEOGLeftpattern = ["F7", "F3", "T3"];
RELAX_cfg.HEOGRightpattern = ["F8", "F4", "T4"];
RELAX_cfg.BlinkMaskFocus = 150;
RELAX_cfg.HorizontalEyeMovementType = 2;
RELAX_cfg.HorizontalEyeMovementThreshold = 2;
RELAX_cfg.HorizontalEyeMovementThresholdIQR = 1.5;
RELAX_cfg.HorizontalEyeMovementTimepointsExceedingThreshold = 25;
RELAX_cfg.HorizontalEyeMovementTimepointsTestWindow = 49;
RELAX_cfg.HorizontalEyeMovementFocus = 200;

RELAX_cfg.LowPassFilterBeforeMWF = 'yes';
RELAX_cfg.DownSample = 'yes';
RELAX_cfg.DownSample_to_X_Hz = 250;
RELAX_cfg.FilterType = 'Butterworth';
RELAX_cfg.causal_or_acausal_filter = 'acausal';
RELAX_cfg.HighPassFilter = 1;
RELAX_cfg.LowPassFilter = 47;
RELAX_cfg.NotchFilterType = 'Butterworth';
RELAX_cfg.LineNoiseFrequency = 50;

RELAX_cfg.ElectrodesToDelete = {};
RELAX_cfg.MaxProportionOfElectrodesThatCanBeDeleted = 0.20;
RELAX_cfg.InterpolateRejectedElectrodesAfterCleaning = 'yes';

RELAX_cfg.MWFDelayPeriod_for_eye_movements = 4;
RELAX_cfg.MWFDelayPeriod_for_muscle_artifacts = 6;
RELAX_cfg.MWF_delay_spacing_for_eye_movements = 8;
RELAX_cfg.MWF_delay_spacing_for_muscle_artifacts = 1;

RELAX_cfg.MuscleSlopeThreshold = -0.31;
RELAX_cfg.MaxProportionOfDataCanBeMarkedAsMuscle = 0.50;
RELAX_cfg.ProportionOfMuscleContaminatedEpochsAboveWhichToRejectChannel = 0.05;
RELAX_cfg.ProportionOfExtremeNoiseAboveWhichToRejectChannel = 0.05;

RELAX_cfg.KeepAllInfo = 0;
RELAX_cfg.saveextremesrejected = 0;
RELAX_cfg.saveround1 = 0;
RELAX_cfg.saveround2 = 0;
RELAX_cfg.saveround3 = 1;

RELAX_cfg.OnlyIncludeTaskRelatedEpochs = 0;
RELAX_cfg.RejNontask = false;
RELAX_cfg.RejCrap = false;

% 眨眼检测阈值（注意：原始拼写就是Threshould，不是Threshold）
RELAX_cfg.BlinkDetectThreshould = 1.5;

% 是否绘图（后台运行时必须关闭）
RELAX_cfg.PlotCRAPRejection = false;
RELAX_cfg.PlotAfterExtremeRejection = false;
RELAX_cfg.PlotAfterMwf1 = false;
RELAX_cfg.PlotAfterMwf2 = false;
RELAX_cfg.PlotAfterMwf3 = false;
RELAX_cfg.PlotAfterwICA = false;

%% ========== 运行RELAX预处理 ==========
fprintf('\n========================================\n');
fprintf('开始RELAX处理（共 %d 个文件）\n', length(RELAX_cfg.files));
fprintf('========================================\n');

% 逐个文件处理，避免单个文件失败影响整体
failed_files = {};
processed_count = 0;

for file_idx = 1:length(RELAX_cfg.files)
    current_file = RELAX_cfg.files{file_idx};
    fprintf('\n处理文件 %d/%d: %s\n', file_idx, length(RELAX_cfg.files), current_file);

    % 检查文件是否已处理
    FileName = extractBefore(current_file, ".");
    cleaned_data_dir = [RELAX_cfg.myPath, filesep, 'RELAXProcessed', filesep, 'Cleaned_Data'];
    output_file = [cleaned_data_dir, filesep, FileName, '_RELAX.set'];

    if exist(output_file, 'file')
        fprintf('  → 文件已处理，跳过\n');
        processed_count = processed_count + 1;
        continue;
    end

    % 配置当前文件
    RELAX_cfg_single = RELAX_cfg;
    RELAX_cfg_single.filename = current_file;
    RELAX_cfg_single.FilesToProcess = 1;
    RELAX_cfg_single.SingleFile = 1;
    RELAX_cfg_single.MergeVidFilesAfterProcessing = 0;  % 单文件模式不合并

    try
        % 处理单个文件（不捕获输出参数，避免已处理文件的错误）
        RELAX_Wrapper(RELAX_cfg_single);
        processed_count = processed_count + 1;
        fprintf('  ✓ 文件处理成功\n');
    catch ME
        fprintf('  ✗ 文件处理失败: %s\n', ME.message);
        if ~isempty(ME.stack)
            fprintf('    错误位置: %s (第 %d 行)\n', ME.stack(1).name, ME.stack(1).line);
        end
        failed_files{end+1} = current_file;
    end
end

fprintf('\n========================================\n');
fprintf('RELAX处理完成\n');
fprintf('成功: %d/%d 文件\n', processed_count, length(RELAX_cfg.files));
if ~isempty(failed_files)
    fprintf('失败: %d 文件\n', length(failed_files));
    fprintf('失败文件列表:\n');
    for i = 1:length(failed_files)
        fprintf('  - %s\n', failed_files{i});
    end
end
fprintf('========================================\n');

%% ========== 自动合并同一被试的vid文件 ==========
fprintf('\n========================================\n');
fprintf('开始合并同一被试的vid文件\n');
fprintf('========================================\n');

    % 获取输出目录
    my_path = RELAX_cfg.myPath;
    path_parts = strsplit(my_path, filesep);
    base_dir_idx = find(strcmp(path_parts, 'data'), 1) - 1;
    if base_dir_idx > 0
        base_dir = strjoin(path_parts(1:base_dir_idx), filesep);
    else
        base_dir = '/data/liujialing/TY';
    end

    % 添加合并脚本路径
    code3_dir = fullfile(base_dir, '预处理/matlab/实验1/code3');
    if exist(code3_dir, 'dir')
        addpath(code3_dir);
    end

    % 设置输入输出目录
    relax_output_dir = fullfile(my_path, 'RELAXProcessed', 'Cleaned_Data');
    merged_output_dir = fullfile(my_path, 'RELAXProcessed', 'Cleaned_Data_Merged');

    if ~exist(merged_output_dir, 'dir')
        mkdir(merged_output_dir);
    end

    % 获取所有RELAX处理后的文件
    cd(relax_output_dir);
    relax_files = dir('sub*_vid*_RELAX.set');

    % 过滤：只合并6个问题被试的文件
    filtered_relax_files = [];
    for i = 1:length(relax_files)
        filename = relax_files(i).name;
        for j = 1:length(problem_subject_patterns)
            if ~isempty(strfind(filename, problem_subject_patterns{j}))
                filtered_relax_files = [filtered_relax_files; relax_files(i)];
                break;
            end
        end
    end

    if isempty(filtered_relax_files)
        warning('未找到问题被试的RELAX处理后文件');
    else
        % 按被试分组
        subject_groups = containers.Map();
        for i = 1:length(filtered_relax_files)
            filename = filtered_relax_files(i).name;
            sub_match = regexp(filename, '^(sub\d+)_vid', 'tokens');
            if ~isempty(sub_match)
                sub_id = sub_match{1}{1};
                if ~isKey(subject_groups, sub_id)
                    subject_groups(sub_id) = {};
                end
                subject_groups(sub_id) = [subject_groups(sub_id), {filename}];
            end
        end

        % 合并每个被试的数据
        all_subjects = keys(subject_groups);
        fprintf('找到 %d 个问题被试需要合并\n', length(all_subjects));

        for i = 1:length(all_subjects)
            sub_id = all_subjects{i};
            files = subject_groups(sub_id);

            fprintf('\n合并被试 %s (%d/%d)，共 %d 个vid文件...\n', ...
                sub_id, i, length(all_subjects), length(files));

            try
                % 调用合并函数
                merge_vid_files_for_subject(sub_id, relax_output_dir, merged_output_dir);
                fprintf('  ✓ 合并完成: %s_RELAX_merged.set\n', sub_id);
            catch ME
                warning('合并被试 %s 失败: %s', sub_id, ME.message);
            end
        end

        fprintf('\n✓ 所有被试合并完成\n');
        fprintf('合并文件保存在: %s\n', merged_output_dir);
    end

%% ========== 完成总结 ==========
fprintf('\n========================================\n');
fprintf('问题被试预处理完成\n');
fprintf('========================================\n');
fprintf('处理的被试: %s\n', strjoin(problem_subjects, ', '));
fprintf('处理的文件数: %d (成功: %d, 失败: %d)\n', length(RELAX_cfg.files), processed_count, length(failed_files));
fprintf('\n输出目录:\n');
fprintf('  - RELAX清理后: %s\n', fullfile(RELAX_cfg.myPath, 'RELAXProcessed', 'Cleaned_Data'));
fprintf('  - 合并后数据: %s\n', fullfile(RELAX_cfg.myPath, 'RELAXProcessed', 'Cleaned_Data_Merged'));
fprintf('========================================\n');

%% ========== 辅助函数：合并vid文件 ==========
function merge_vid_files_for_subject(subject_id, input_dir, output_dir)
    % 合并指定被试的所有vid文件

    % 获取该被试的所有vid文件
    vid_files = dir(fullfile(input_dir, sprintf('%s_vid*_RELAX.set', subject_id)));

    if isempty(vid_files)
        error('未找到被试 %s 的vid文件', subject_id);
    end

    % 按vid编号排序
    vid_numbers = zeros(length(vid_files), 1);
    for i = 1:length(vid_files)
        match = regexp(vid_files(i).name, 'vid(\d+)', 'tokens');
        if ~isempty(match)
            vid_numbers(i) = str2double(match{1}{1});
        end
    end
    [~, sort_idx] = sort(vid_numbers);
    vid_files = vid_files(sort_idx);

    % 加载第一个文件
    EEG_merged = pop_loadset('filename', vid_files(1).name, 'filepath', input_dir);

    % 添加vid标记事件
    EEG_merged.event(end+1).type = sprintf('vid%02d', vid_numbers(sort_idx(1)));
    EEG_merged.event(end).latency = 1;
    EEG_merged.event(end).vid = vid_numbers(sort_idx(1));

    % 合并其余文件
    for i = 2:length(vid_files)
        EEG_temp = pop_loadset('filename', vid_files(i).name, 'filepath', input_dir);

        % 记录当前数据长度
        current_length = EEG_merged.pnts;

        % 连接数据
        EEG_merged.data = [EEG_merged.data, EEG_temp.data];
        EEG_merged.pnts = size(EEG_merged.data, 2);
        EEG_merged.xmax = (EEG_merged.pnts - 1) / EEG_merged.srate;

        % 添加vid标记事件
        EEG_merged.event(end+1).type = sprintf('vid%02d', vid_numbers(sort_idx(i)));
        EEG_merged.event(end).latency = current_length + 1;
        EEG_merged.event(end).vid = vid_numbers(sort_idx(i));
    end

    % 添加合并信息
    EEG_merged.merged_info.subject_id = subject_id;
    EEG_merged.merged_info.vid_list = vid_numbers(sort_idx);
    EEG_merged.merged_info.vid_count = length(vid_files);
    EEG_merged.merged_info.total_duration = EEG_merged.pnts / EEG_merged.srate;

    % 保存合并后的文件
    EEG_merged = eeg_checkset(EEG_merged);
    merged_filename = sprintf('%s_RELAX_merged.set', subject_id);
    pop_saveset(EEG_merged, 'filename', merged_filename, 'filepath', output_dir);
end
