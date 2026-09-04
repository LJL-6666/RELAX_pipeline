%% RELAX预处理脚本 - 电影任务（修复版）
%
% 基于RELAX EEG CLEANING PIPELINE
% 参考实验1的正确实现方式
%
% 关键修复：
%   - 使用RELAX_Wrapper的批处理模式，不需要外层循环
%   - RELAX_Wrapper内部会循环处理所有文件
%   - 每个文件完成后立即保存到Cleaned_Data目录
%
% 输出:
%   - 清理后的数据: RELAX输入\电影\RELAXProcessed\Cleaned_Data\

clear all; close all; clc;

fprintf('=== RELAX预处理 - 电影任务（修复版）===\n');
fprintf('开始时间: %s\n\n', datestr(now));

%% ==================== 路径配置 ====================
base_dir = 'E:\ljl\work\通用\RELAX_update\归档\新预处理';

%% ==================== 依赖库配置 ====================
fprintf('正在配置依赖库...\n');

toolbox_dir = 'D:\APP\matlab\bao';

% EEGLAB
eeglab_path = fullfile(toolbox_dir, 'eeglab2025.1.0');
if exist(eeglab_path, 'dir')
    addpath(eeglab_path);
    fprintf('  EEGLAB: %s\n', eeglab_path);
else
    error('未找到EEGLAB: %s', eeglab_path);
end

% FieldTrip
fieldtrip_path = fullfile(toolbox_dir, 'fieldtrip-20181205');
if exist(fieldtrip_path, 'dir')
    addpath(fieldtrip_path);
    addpath(fullfile(fieldtrip_path, 'fileio'));
    addpath(fullfile(fieldtrip_path, 'utilities'));
    addpath(fullfile(fieldtrip_path, 'preproc'));
    fprintf('  FieldTrip: %s\n', fieldtrip_path);
end

% RELAX
relax_path = fullfile(toolbox_dir, 'RELAX-RELAX-v2.0.0');
if exist(relax_path, 'dir')
    addpath(relax_path);
    fprintf('  RELAX: %s\n', relax_path);
else
    error('未找到RELAX插件');
end

% MWF
mwf_path = fullfile(toolbox_dir, 'mwf-artifact-removal');
if exist(mwf_path, 'dir')
    addpath(genpath(mwf_path));
    fprintf('  MWF: %s\n', mwf_path);
end

% PrepPipeline
prep_path = fullfile(toolbox_dir, 'PrepPipeline');
if exist(prep_path, 'dir')
    addpath(genpath(prep_path));
    fprintf('  PrepPipeline: %s\n', prep_path);
end

% ICLabel
iclabel_path = fullfile(toolbox_dir, 'ICLabel');
if exist(iclabel_path, 'dir')
    addpath(genpath(iclabel_path));
    fprintf('  ICLabel: %s\n', iclabel_path);
end

% PICARD
picard_path = fullfile(toolbox_dir, 'PICARD1.0');
if exist(picard_path, 'dir')
    addpath(picard_path);
    fprintf('  PICARD: %s\n', picard_path);
end

% FastICA
fastica_path = fullfile(toolbox_dir, 'FastICA_25');
if exist(fastica_path, 'dir')
    addpath(fastica_path);
    fprintf('  FastICA: %s\n', fastica_path);
end

% Biosig
biosig_path = fullfile(toolbox_dir, 'Biosig3.8.4');
if exist(biosig_path, 'dir')
    addpath(genpath(biosig_path));
    nan_path = fullfile(biosig_path, 'NaN');
    if exist(nan_path, 'dir')
        rmpath(genpath(nan_path));
    end
    fprintf('  Biosig: %s\n', biosig_path);
end

% 启动EEGLAB
eeglab nogui;

fprintf('\n依赖库配置完成！\n\n');

%% ==================== RELAX配置 ====================
fprintf('配置RELAX参数...\n');

% 电极位置文件
RELAX_cfg.caploc = 'D:\APP\matlab\bao\eeglab2025.1.0\plugins\dipfit\standard_BEM\elec\standard_1005.elc';

% 输入数据路径
RELAX_cfg.myPath = fullfile(base_dir, 'RELAX输入', '电影');

% 文件名（留空表示批处理）
RELAX_cfg.filename = [];

%% 列出所有待处理文件
cd(RELAX_cfg.myPath);
RELAX_cfg.dirList = dir('*.set');
RELAX_cfg.files = {RELAX_cfg.dirList.name};

if isempty(RELAX_cfg.files)
    error('未找到.set文件！');
end

fprintf('找到 %d 个文件\n', length(RELAX_cfg.files));

%% RELAX参数设置（与原脚本保持一致）
RELAX_cfg.Perform_targeted_wICA = 0;
RELAX_cfg.Do_MWF_Once = 1;
RELAX_cfg.Do_MWF_Twice = 1;
RELAX_cfg.Do_MWF_Thrice = 1;
RELAX_cfg.Perform_wICA_on_ICLabel = 1;
RELAX_cfg.Perform_ICA_subtract = 0;
RELAX_cfg.ICA_method = 'picard';
RELAX_cfg.Report_all_ICA_info = 'no';  % 关闭详细ICA报告以加速15-20%
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
RELAX_cfg.HorizontalEyeMovementTimepointsTestWindow = (2 * RELAX_cfg.HorizontalEyeMovementTimepointsExceedingThreshold) - 1;
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

RELAX_cfg.KeepAllInfo = 0;
RELAX_cfg.saveextremesrejected = 0;
RELAX_cfg.saveround1 = 0;
RELAX_cfg.saveround2 = 0;
RELAX_cfg.saveround3 = 0;  % 不保存第3轮MWF以节省空间

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
RELAX_cfg.minimum_break_length = 2000;
RELAX_cfg.break_ignore_codes = setdiff(1:160, [60 61 62 63 64 65 66 67 142 143 144 145 160 200]);
RELAX_cfg.break_buffer = 1500;

RELAX_cfg.RejCrap = false;
RELAX_cfg.BlinkDetectThreshould = 1.5;

% 可视化（建议关闭以加快处理）
RELAX_cfg.PlotCRAPRejection = false;
RELAX_cfg.PlotAfterExtremeRejection = false;
RELAX_cfg.PlotAfterMwf1 = false;
RELAX_cfg.PlotAfterMwf2 = false;
RELAX_cfg.PlotAfterMwf3 = false;
RELAX_cfg.PlotAfterwICA = false;

%% ==================== 运行RELAX（参考实验1的正确方式）====================
% 关键修复：直接使用RELAX_Wrapper的批处理模式
% RELAX_Wrapper会自动循环处理所有文件，每个文件完成后立即保存到Cleaned_Data

RELAX_cfg.FilesToProcess = 1:numel(RELAX_cfg.files);

fprintf('\n========================================\n');
fprintf('开始RELAX批处理\n');
fprintf('将处理 %d 个文件\n', length(RELAX_cfg.FilesToProcess));
fprintf('========================================\n\n');

[RELAX_cfg, FileNumber, CleanedMetrics, RawMetrics, ...
    RELAXProcessingRoundOneAllParticipants, RELAXProcessingRoundTwoAllParticipants, ...
    RELAXProcessing_wICA_AllParticipants, RELAXProcessing_ICA_AllParticipants, ...
    RELAXProcessingRoundThreeAllParticipants, RELAX_issues_to_check, ...
    RELAX_issues_to_check_2nd_run, RELAXProcessingExtremeRejectionsAllParticipants] = RELAX_Wrapper(RELAX_cfg);

fprintf('\n========================================\n');
fprintf('RELAX处理完成！\n');
fprintf('结束时间: %s\n', datestr(now));
fprintf('========================================\n');

%% ==================== 输出信息 ====================
output_path = fullfile(RELAX_cfg.myPath, 'RELAXProcessed', 'Cleaned_Data');
fprintf('\n清理后的数据位于: %s\n', output_path);

% 统计生成的文件
if exist(output_path, 'dir')
    output_files = dir(fullfile(output_path, '*_RELAX.set'));
    fprintf('成功处理 %d 个文件\n', length(output_files));
else
    fprintf('警告：Cleaned_Data目录不存在！\n');
end
