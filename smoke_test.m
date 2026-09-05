% SMOKE_TEST  端到端冒烟：1–2 被试，step1 全量；step2 仅 2 个 .set；再 step3
% 用法：在 RELAX_pipeline 根目录运行
%   smoke_test
% 或：matlab -batch "cd('.../RELAX_pipeline'); smoke_test"
%
% 数据约定：data/smoke/<subID>/data.bdf + evt.bdf + *rating*.csv
% 本脚本不修改 config_default.m 默认值。

clear; clc; close all;
root = fileparts(mfilename('fullpath'));
cd(root);
diary(fullfile(root, 'output', 'smoke_test_diary.txt'));
diary on;
fprintf('===== SMOKE TEST start %s =====\n', datestr(now));

setup();
cfg = config_default();
cfg.task.name = 'smoke';
cfg.task.folderName = '';
cfg.task.csvPattern = 'rating';
cfg.task.orderColumn = 'videoIndex';
cfg.task.subjects = {'002', '003'};
cfg.pipeline.skipExisting = false;  % 冒烟强制重跑
cfg.pipeline.doStep1 = true;
cfg.pipeline.doStep2 = true;
cfg.pipeline.doStep3 = true;
cfg.merge.addVidMarkerEvent = true;
cfg.merge.padMissingVid = false;

smokeData = fullfile(cfg.paths.dataRoot, 'smoke');
if exist(smokeData, 'dir') ~= 7
    error('缺少冒烟数据目录: %s\n请先放入 1–2 个被试的 data.bdf / evt.bdf / rating CSV', smokeData);
end

t0 = tic;
results = struct('step1', false, 'step2', false, 'step3', false, 'notes', {{}});

%% ---- STEP 1 ----
fprintf('\n========== SMOKE STEP 1 ==========\n');
try
    step1_bdf_to_set(cfg);
    setDir = fullfile(cfg.paths.outputRoot, 'set_by_vid', 'smoke');
    nSet = numel(dir(fullfile(setDir, 'sub*_vid*.set')));
    fprintf('[smoke] step1 产出 %d 个 .set\n', nSet);
    if nSet < 1
        error('step1 未产出任何 .set');
    end
    results.step1 = true;
catch ME
    results.notes{end+1} = ['step1 FAIL: ' ME.message];
    fprintf(2, '[smoke] step1 失败: %s\n', ME.message);
end

%% ---- STEP 2（仅处理前 2 个 .set，避免全量 RELAX 数小时）----
fprintf('\n========== SMOKE STEP 2 (max 2 files) ==========\n');
if results.step1
    try
        inDir = fullfile(cfg.paths.outputRoot, 'set_by_vid', 'smoke');
        outTask = fullfile(cfg.paths.outputRoot, 'relax', 'smoke');
        if ~exist(outTask, 'dir'), mkdir(outTask); end

        RELAX_cfg = [];
        RELAX_cfg.myPath = inDir;
        RELAX_cfg.filename = [];
        RELAX_cfg.caploc = cfg.paths.capFile;
        cd(RELAX_cfg.myPath);
        dlist = dir('*.set');
        names = {dlist.name};
        names = names(~endsWith(names, '_RELAX.set'));
        names = sort(names);
        nTake = min(2, numel(names));
        RELAX_cfg.files = names(1:nTake);
        fprintf('[smoke] RELAX 仅处理: %s\n', strjoin(RELAX_cfg.files, ', '));

        % 与 step2 定稿参数对齐（精简复制关键项）
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
        RELAX_cfg.saveround1 = 0;
        RELAX_cfg.saveround2 = 0;
        RELAX_cfg.saveround3 = 0;
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
        RELAX_cfg.RejCrap = false;
        RELAX_cfg.BlinkDetectThreshould = 1.5;
        RELAX_cfg.PlotCRAPRejection = false;
        RELAX_cfg.PlotAfterExtremeRejection = false;
        RELAX_cfg.PlotAfterMwf1 = false;
        RELAX_cfg.PlotAfterMwf2 = false;
        RELAX_cfg.PlotAfterMwf3 = false;
        RELAX_cfg.PlotAfterwICA = false;
        RELAX_cfg.RestoreDeletedPeriodsAsNaN = 0;
        RELAX_cfg.FilesToProcess = 1:numel(RELAX_cfg.files);

        RELAX_Wrapper(RELAX_cfg);

        cleaned = fullfile(inDir, 'RELAXProcessed', 'Cleaned_Data');
        nClean = numel(dir(fullfile(cleaned, '*_RELAX.set')));
        fprintf('[smoke] step2 产出 %d 个 *_RELAX.set\n', nClean);
        if nClean < 1
            error('step2 未产出 Cleaned_Data');
        end
        % mirror 到 output/relax/smoke
        srcTree = fullfile(inDir, 'RELAXProcessed');
        dstTree = fullfile(outTask, 'RELAXProcessed');
        if exist(dstTree, 'dir'), try, rmdir(dstTree, 's'); catch, end; end
        copyfile(srcTree, dstTree);
        results.step2 = true;
        results.notes{end+1} = sprintf('step2 limited to %d files', nTake);
    catch ME
        results.notes{end+1} = ['step2 FAIL: ' ME.message];
        fprintf(2, '[smoke] step2 失败: %s\n', ME.message);
    end
else
    results.notes{end+1} = 'step2 skipped (step1 failed)';
end

%% ---- STEP 3 ----
fprintf('\n========== SMOKE STEP 3 ==========\n');
cd(root);
if results.step2
    try
        step3_merge_subjects(cfg);
        mergDir = fullfile(cfg.paths.outputRoot, 'merged', 'smoke');
        nMerg = numel(dir(fullfile(mergDir, '*_RELAX_merged.set')));
        fprintf('[smoke] step3 产出 %d 个 merged.set\n', nMerg);
        if nMerg < 1
            error('step3 未产出 merged');
        end
        results.step3 = true;
    catch ME
        results.notes{end+1} = ['step3 FAIL: ' ME.message];
        fprintf(2, '[smoke] step3 失败: %s\n', ME.message);
    end
else
    results.notes{end+1} = 'step3 skipped (step2 failed)';
end

%% ---- SUMMARY ----
elapsed = toc(t0);
fprintf('\n===== SMOKE SUMMARY =====\n');
fprintf('step1=%d  step2=%d  step3=%d  elapsed=%.1f min\n', ...
    results.step1, results.step2, results.step3, elapsed/60);
for i = 1:numel(results.notes)
    fprintf('  note: %s\n', results.notes{i});
end
outMat = fullfile(cfg.paths.outputRoot, 'smoke_test_result.mat');
if ~exist(cfg.paths.outputRoot, 'dir'), mkdir(cfg.paths.outputRoot); end
save(outMat, 'results', 'elapsed', 'cfg');
fprintf('结果已保存: %s\n', outMat);

if ~(results.step1 && results.step2 && results.step3)
    diary off;
    error('SMOKE TEST FAILED');
end
fprintf('SMOKE TEST PASSED\n');
diary off;
