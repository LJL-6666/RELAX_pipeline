function step2_relax_clean(cfg)
% STEP2_RELAX_CLEAN  对 set_by_vid 批处理运行官方 RELAX_Wrapper
%
% 输入：output/set_by_vid/<task>/*.set
% 输出：output/relax/<task>/RELAXProcessed/Cleaned_Data/*_RELAX.set + metrics

inDir = fullfile(cfg.paths.outputRoot, 'set_by_vid', cfg.task.name);
if exist(inDir, 'dir') ~= 7
    error('[step2] 未找到输入: %s （请先 step1）', inDir);
end

% RELAX_Wrapper 约定：myPath 下直接放 *.set，结果写到 myPath/RELAXProcessed/
outTask = fullfile(cfg.paths.outputRoot, 'relax', cfg.task.name);
if ~exist(outTask, 'dir'), mkdir(outTask); end

% 将输入复制/链接策略：直接把 myPath 指到 set_by_vid（只读输入也可写 RELAXProcessed 子目录）
RELAX_cfg = [];
RELAX_cfg.myPath = inDir;
RELAX_cfg.filename = [];
RELAX_cfg.caploc = cfg.paths.capFile;

cd(RELAX_cfg.myPath);
RELAX_cfg.dirList = dir('*.set');
% 排除已是 *_RELAX.set 的输出误入
names = {RELAX_cfg.dirList.name};
names = names(~endsWith(names, '_RELAX.set'));
RELAX_cfg.files = names;
if isempty(RELAX_cfg.files)
    error('[step2] %s 下没有待处理 .set', inDir);
end

cleanedDir = fullfile(inDir, 'RELAXProcessed', 'Cleaned_Data');
if cfg.pipeline.skipExisting && exist(cleanedDir, 'dir')
    nDone = numel(dir(fullfile(cleanedDir, '*_RELAX.set')));
    if nDone >= numel(RELAX_cfg.files)
        fprintf('[step2] 已有 %d 个清理文件，跳过。\n', nDone);
        mirror_relax_tree(inDir, outTask);
        return;
    end
end

% ---- 定稿 FIXED 参数 ----
RELAX_cfg.Perform_targeted_wICA = 0;
RELAX_cfg.Do_MWF_Once = cfg.relax.Do_MWF_Once;
RELAX_cfg.Do_MWF_Twice = cfg.relax.Do_MWF_Twice;
RELAX_cfg.Do_MWF_Thrice = cfg.relax.Do_MWF_Thrice;
RELAX_cfg.Perform_wICA_on_ICLabel = cfg.relax.Perform_wICA_on_ICLabel;
RELAX_cfg.Perform_ICA_subtract = cfg.relax.Perform_ICA_subtract;
RELAX_cfg.ICA_method = cfg.relax.ICA_method;
RELAX_cfg.Report_all_ICA_info = cfg.relax.Report_all_ICA_info;
RELAX_cfg.Clean_other_comps = 'no';
RELAX_cfg.ICLabel_thresholds = [0.5 0.8 0.8 0.5 0.5 0.5 0.5];
RELAX_cfg.computerawmetrics = cfg.relax.computerawmetrics;
RELAX_cfg.computecleanedmetrics = cfg.relax.computecleanedmetrics;
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
RELAX_cfg.HorizontalEyeMovementTimepointsTestWindow = ...
    (2 * RELAX_cfg.HorizontalEyeMovementTimepointsExceedingThreshold) - 1;
RELAX_cfg.HorizontalEyeMovementFocus = 200;
RELAX_cfg.LowPassFilterBeforeMWF = 'yes';
RELAX_cfg.DownSample = cfg.relax.DownSample;
RELAX_cfg.DownSample_to_X_Hz = cfg.relax.DownSample_to_X_Hz;
RELAX_cfg.FilterType = 'Butterworth';
RELAX_cfg.causal_or_acausal_filter = 'acausal';
RELAX_cfg.HighPassFilter = cfg.relax.HighPassFilter;
RELAX_cfg.LowPassFilter = cfg.relax.LowPassFilter;
RELAX_cfg.NotchFilterType = 'Butterworth';
RELAX_cfg.LineNoiseFrequency = cfg.relax.LineNoiseFrequency;
RELAX_cfg.ElectrodesToDelete = cfg.relax.ElectrodesToDelete;
RELAX_cfg.KeepAllInfo = 0;
RELAX_cfg.saveextremesrejected = 0;
RELAX_cfg.saveround1 = cfg.relax.saveround1;
RELAX_cfg.saveround2 = cfg.relax.saveround2;
RELAX_cfg.saveround3 = cfg.relax.saveround3;
RELAX_cfg.OnlyIncludeTaskRelatedEpochs = 0;
RELAX_cfg.MuscleSlopeThreshold = -0.31;
RELAX_cfg.MaxProportionOfDataCanBeMarkedAsMuscle = 0.50;
RELAX_cfg.ProportionOfMuscleContaminatedEpochsAboveWhichToRejectChannel = 0.05;
RELAX_cfg.ProportionOfExtremeNoiseAboveWhichToRejectChannel = 0.05;
RELAX_cfg.MaxProportionOfElectrodesThatCanBeDeleted = 0.20;
RELAX_cfg.InterpolateRejectedElectrodesAfterCleaning = ...
    cfg.relax.InterpolateRejectedElectrodesAfterCleaning;
RELAX_cfg.MWFDelayPeriod_for_eye_movements = 4;
RELAX_cfg.MWFDelayPeriod_for_muscle_artifacts = 6;
RELAX_cfg.MWF_delay_spacing_for_eye_movements = 8;
RELAX_cfg.MWF_delay_spacing_for_muscle_artifacts = 1;
RELAX_cfg.RejNontask = false;
RELAX_cfg.RejCrap = false;
RELAX_cfg.BlinkDetectThreshould = 1.5;
RELAX_cfg.PlotCRAPRejection = false;
RELAX_cfg.PlotAfterExtremeRejection = false;
RELAX_cfg.PlotAfterMwf1 = false;
RELAX_cfg.PlotAfterMwf2 = false;
RELAX_cfg.PlotAfterMwf3 = false;
RELAX_cfg.PlotAfterwICA = false;

RELAX_cfg.FilesToProcess = 1:numel(RELAX_cfg.files);
fprintf('[step2] 批处理 %d 个文件（官方 RELAX_Wrapper）...\n', numel(RELAX_cfg.files));
fprintf('[step2] extremeBadMode=%s（功能流水线默认 delete=官方行为）\n', cfg.relax.extremeBadMode);

[RELAX_cfg, FileNumber, CleanedMetrics, RawMetrics, ...
    RELAXProcessingRoundOneAllParticipants, RELAXProcessingRoundTwoAllParticipants, ...
    RELAXProcessing_wICA_AllParticipants, RELAXProcessing_ICA_AllParticipants, ...
    RELAXProcessingRoundThreeAllParticipants, RELAX_issues_to_check, ...
    RELAX_issues_to_check_2nd_run, RELAXProcessingExtremeRejectionsAllParticipants] = ...
    RELAX_Wrapper(RELAX_cfg); %#ok<ASGLU>

mirror_relax_tree(inDir, outTask);
fprintf('[step2] 完成。指标与 Cleaned_Data 见: %s\n', fullfile(outTask, 'RELAXProcessed'));
end

function mirror_relax_tree(inDir, outTask)
% 把 set 目录下生成的 RELAXProcessed 同步到 output/relax/<task>/
src = fullfile(inDir, 'RELAXProcessed');
dst = fullfile(outTask, 'RELAXProcessed');
if exist(src, 'dir') ~= 7, return; end
if ~exist(outTask, 'dir'), mkdir(outTask); end
% 若已在目标，跳过；否则复制树（Windows）
if strcmpi(src, dst), return; end
if exist(dst, 'dir') == 7
    try, rmdir(dst, 's'); catch, end
end
copyfile(src, dst);
end
