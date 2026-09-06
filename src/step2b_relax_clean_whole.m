function step2b_relax_clean_whole(cfg)
% STEP2B_RELAX_CLEAN_WHOLE  对整段 set 运行 RELAX_Wrapper（Mode B：只标记不删除）
%
% 输入：output/set_whole/<task>/subXXX_whole.set
% 输出：output/relax_whole/<task>/RELAXProcessed/Cleaned_Data/subXXX_whole_RELAX.set
%   其中包含 BAD_segment 事件标记坏段，数据长度保持不变

inDir = fullfile(cfg.paths.outputRoot, 'set_whole', cfg.task.name);
if exist(inDir, 'dir') ~= 7
    error('[step2b] 未找到输入: %s （请先 step1b）', inDir);
end

outTask = fullfile(cfg.paths.outputRoot, 'relax_whole', cfg.task.name);
if ~exist(outTask, 'dir'), mkdir(outTask); end

RELAX_cfg = [];
RELAX_cfg.myPath = inDir;
RELAX_cfg.filename = [];
RELAX_cfg.caploc = cfg.paths.capFile;

cd(RELAX_cfg.myPath);
RELAX_cfg.dirList = dir('*.set');
names = {RELAX_cfg.dirList.name};
names = names(~endsWith(names, '_RELAX.set'));
RELAX_cfg.files = names;
if isempty(RELAX_cfg.files)
    error('[step2b] %s 下没有待处理 .set', inDir);
end

cleanedDir = fullfile(inDir, 'RELAXProcessed', 'Cleaned_Data');
if cfg.pipeline.skipExisting && exist(cleanedDir, 'dir')
    nDone = numel(dir(fullfile(cleanedDir, '*_RELAX.set')));
    if nDone >= numel(RELAX_cfg.files)
        fprintf('[step2b] 已有 %d 个清理文件，跳过。\n', nDone);
        mirror_relax_tree(inDir, outTask);
        return;
    end
end

% ---- 定稿 FIXED 参数（与 step2 相同）----
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
RELAX_cfg.RejNontask = cfg.relax.RejNontask;
RELAX_cfg.minimum_break_length = cfg.relax.minimum_break_length;
RELAX_cfg.break_ignore_codes = cfg.relax.break_ignore_codes;
RELAX_cfg.break_buffer = cfg.relax.break_buffer;
RELAX_cfg.RejCrap = cfg.relax.RejCrap;
if RELAX_cfg.RejCrap
    RELAX_cfg.AR_parameters = table( ...
        {cfg.relax.crapChannels}, cfg.relax.crapThreshold, ...
        cfg.relax.crapWindowSize, cfg.relax.crapWindowStep, ...
        'VariableNames', {'Channels', 'Threshold', 'Window_Size', 'Window_Step'});
    RELAX_cfg.reject_short_periods = cfg.relax.reject_short_periods;
    RELAX_cfg.crapNumChanThreshold = cfg.relax.crapNumChanThreshold;
end
RELAX_cfg.BlinkDetectThreshould = 1.5;
RELAX_cfg.PlotCRAPRejection = false;
RELAX_cfg.PlotAfterExtremeRejection = false;
RELAX_cfg.PlotAfterMwf1 = false;
RELAX_cfg.PlotAfterMwf2 = false;
RELAX_cfg.PlotAfterMwf3 = false;
RELAX_cfg.PlotAfterwICA = false;

% Mode B 关键设置：只标记坏段，不物理删除
RELAX_cfg.MarkOnlyBadSegments = 1;
RELAX_cfg.RestoreDeletedPeriodsAsNaN = 0;

RELAX_cfg.FilesToProcess = 1:numel(RELAX_cfg.files);
fprintf('[step2b] 批处理 %d 个整段文件（Mode B：只标记不删除）...\n', numel(RELAX_cfg.files));

[RELAX_cfg, FileNumber, CleanedMetrics, RawMetrics, ...
    RELAXProcessingRoundOneAllParticipants, RELAXProcessingRoundTwoAllParticipants, ...
    RELAXProcessing_wICA_AllParticipants, RELAXProcessing_ICA_AllParticipants, ...
    RELAXProcessingRoundThreeAllParticipants, RELAX_issues_to_check, ...
    RELAX_issues_to_check_2nd_run, RELAXProcessingExtremeRejectionsAllParticipants] = ...
    RELAX_Wrapper(RELAX_cfg); %#ok<ASGLU>

mirror_relax_tree(inDir, outTask);
fprintf('[step2b] 完成。指标与 Cleaned_Data 见: %s\n', fullfile(outTask, 'RELAXProcessed'));
end

function mirror_relax_tree(inDir, outTask)
src = fullfile(inDir, 'RELAXProcessed');
dst = fullfile(outTask, 'RELAXProcessed');
if exist(src, 'dir') ~= 7, return; end
if ~exist(outTask, 'dir'), mkdir(outTask); end
if strcmpi(src, dst), return; end
if exist(dst, 'dir') == 7
    try, rmdir(dst, 's'); catch, end
end
copyfile(src, dst);
end
