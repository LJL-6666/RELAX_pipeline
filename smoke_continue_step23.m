% SMOKE_CONTINUE_STEP23  在 step1 已成功时，只重跑冒烟的 step2(2文件)+step3
clear; clc; close all;
root = fileparts(mfilename('fullpath'));
cd(root);
diary(fullfile(root, 'output', 'smoke_step23_diary.txt')); diary on;
setup();
cfg = config_default();
cfg.task.name = 'smoke';
cfg.task.subjects = {'002', '003'};
cfg.pipeline.skipExisting = false;
cfg.relax.RestoreDeletedPeriodsAsNaN = 0;
cfg.merge.addVidMarkerEvent = true;

inDir = fullfile(cfg.paths.outputRoot, 'set_by_vid', 'smoke');
assert(exist(inDir,'dir')==7, '请先跑通 step1（smoke_test 或 main）');
outTask = fullfile(cfg.paths.outputRoot, 'relax', 'smoke');
if ~exist(outTask,'dir'), mkdir(outTask); end

% 隔离 2 个 set，避免 FilesToProcess 索引歧义
iso = fullfile(cfg.paths.outputRoot, 'smoke_relax_input');
if exist(iso,'dir'), rmdir(iso,'s'); end
mkdir(iso);
dlist = dir(fullfile(inDir, 'sub*_vid*.set'));
names = sort({dlist.name});
names = names(~endsWith(names, '_RELAX.set'));
nTake = min(2, numel(names));
for i = 1:nTake
    copyfile(fullfile(inDir, names{i}), fullfile(iso, names{i}));
end
fprintf('[smoke23] isolated: %s\n', strjoin(names(1:nTake), ', '));

RELAX_cfg = [];
RELAX_cfg.myPath = iso;
RELAX_cfg.filename = [];
RELAX_cfg.caploc = cfg.paths.capFile;
cd(iso);
RELAX_cfg.dirList = dir('*.set');
RELAX_cfg.files = {RELAX_cfg.dirList.name};
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
RELAX_cfg.BlinkElectrodes = {'Fp1','Fp2','F3','Fz','F4'};
RELAX_cfg.HEOGLeftpattern = ["F7","F3","T3"];
RELAX_cfg.HEOGRightpattern = ["F8","F4","T4"];
RELAX_cfg.BlinkMaskFocus = 150;
RELAX_cfg.HorizontalEyeMovementType = 2;
RELAX_cfg.HorizontalEyeMovementThreshold = 2;
RELAX_cfg.HorizontalEyeMovementThresholdIQR = 1.5;
RELAX_cfg.HorizontalEyeMovementTimepointsExceedingThreshold = 25;
RELAX_cfg.HorizontalEyeMovementTimepointsTestWindow = 49;
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
RELAX_cfg.ElectrodesToDelete = {};
RELAX_cfg.KeepAllInfo = 0;
RELAX_cfg.saveextremesrejected = 0;
RELAX_cfg.saveround1 = 0; RELAX_cfg.saveround2 = 0; RELAX_cfg.saveround3 = 0;
RELAX_cfg.OnlyIncludeTaskRelatedEpochs = 0;
RELAX_cfg.MuscleSlopeThreshold = -0.31;
RELAX_cfg.MaxProportionOfDataCanBeMarkedAsMuscle = 0.50;
RELAX_cfg.ProportionOfMuscleContaminatedEpochsAboveWhichToRejectChannel = 0.05;
RELAX_cfg.ProportionOfExtremeNoiseAboveWhichToRejectChannel = 0.05;
RELAX_cfg.MaxProportionOfElectrodesThatCanBeDeleted = 0.20;
RELAX_cfg.InterpolateRejectedElectrodesAfterCleaning = 'yes';
RELAX_cfg.MWFDelayPeriod_for_eye_movements = 4;
RELAX_cfg.MWFDelayPeriod_for_muscle_artifacts = 6;
RELAX_cfg.MWF_delay_spacing_for_eye_movements = 8;
RELAX_cfg.MWF_delay_spacing_for_muscle_artifacts = 1;
RELAX_cfg.RejNontask = false;
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

t0 = tic;
RELAX_Wrapper(RELAX_cfg);
nClean = numel(dir(fullfile(iso, 'RELAXProcessed', 'Cleaned_Data', '*_RELAX.set')));
fprintf('[smoke23] cleaned=%d\n', nClean);
assert(nClean >= 1, 'step2 produced no cleaned files');

% mirror into places step3 expects
dst = fullfile(outTask, 'RELAXProcessed');
if exist(dst,'dir'), rmdir(dst,'s'); end
copyfile(fullfile(iso,'RELAXProcessed'), dst);
% also put under set_by_vid for fallback
dst2 = fullfile(inDir, 'RELAXProcessed');
if exist(dst2,'dir'), try, rmdir(dst2,'s'); catch, end; end
copyfile(fullfile(iso,'RELAXProcessed'), dst2);

cd(root);
step3_merge_subjects(cfg);
nMerg = numel(dir(fullfile(cfg.paths.outputRoot,'merged','smoke','*_RELAX_merged.set')));
fprintf('[smoke23] merged=%d  elapsed=%.1f min\n', nMerg, toc(t0)/60);
assert(nMerg >= 1, 'step3 produced no merged files');
fprintf('SMOKE STEP2+3 PASSED\n');
diary off;
