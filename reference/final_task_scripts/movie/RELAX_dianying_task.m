%% RELAX预处理脚本 - 电影任务
% 
% 基于RELAX EEG CLEANING PIPELINE
% 适配本地Windows路径和"电影"任务数据
%
% 前置条件:
%   1. 已运行 process_dianying_task.m 生成SET文件
%   2. SET文件位于: RELAX输入\电影\
%
% 输出:
%   - 清理后的数据: RELAX输入\电影\RELAXProcessed\Cleaned_Data\

clear all; close all; clc;

fprintf('=== RELAX预处理 - 电影任务 ===\n');
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
    mad_paths = which('mad', '-all');
    for i = 1:length(mad_paths)
        if contains(mad_paths{i}, biosig_path) && contains(mad_paths{i}, 'NaN')
            problematic_path = fileparts(mad_paths{i});
            rmpath(problematic_path);
            fprintf('  已移除冲突路径: %s\n', problematic_path);
        end
    end
    fprintf('  Biosig: %s\n', biosig_path);
end

fprintf('\n');

%% ==================== 初始化EEGLAB ====================
try
    evalc('eeglab(''nogui'')');
    fprintf('EEGLAB初始化成功\n\n');
catch ME
    error('EEGLAB初始化失败: %s', ME.message);
end

%% ==================== RELAX配置 ====================

% 电极位置文件
RELAX_cfg.caploc = fullfile(fieldtrip_path, 'template', 'electrode', 'standard_1005.elc');
if ~exist(RELAX_cfg.caploc, 'file')
    RELAX_cfg.caploc = [];
    warning('未找到电极位置文件');
end

% 输入数据路径
RELAX_cfg.myPath = fullfile(base_dir, 'RELAX输入', '电影');

if ~exist(RELAX_cfg.myPath, 'dir')
    error('输入目录不存在: %s\n请先运行 process_dianying_task.m', RELAX_cfg.myPath);
end

RELAX_cfg.filename = [];

% 列出所有SET文件
cd(RELAX_cfg.myPath);
RELAX_cfg.dirList = dir('*.set');
all_files = {RELAX_cfg.dirList.name};

if isempty(all_files)
    error('未找到SET文件！请先运行 process_dianying_task.m');
end

% 统计每个被试的文件数量
fprintf('正在统计每个被试的文件数量...\n');
subject_file_count = containers.Map('KeyType', 'char', 'ValueType', 'double');

for i = 1:length(all_files)
    filename = all_files{i};
    tokens = regexp(filename, '^sub(\d+)_', 'tokens');
    if ~isempty(tokens)
        sub_id = tokens{1}{1};
        if subject_file_count.isKey(sub_id)
            subject_file_count(sub_id) = subject_file_count(sub_id) + 1;
        else
            subject_file_count(sub_id) = 1;
        end
    end
end

% 找出文件数少于14个的被试
half_count = 14;
excluded_subjects = {};

fprintf('\n被试文件统计:\n');
subject_ids = subject_file_count.keys;
for i = 1:length(subject_ids)
    sub_id = subject_ids{i};
    count = subject_file_count(sub_id);
    if count < half_count
        excluded_subjects{end+1} = sub_id;
        fprintf('  被试 %s: %d 个文件 (少于%d个，将被排除)\n', sub_id, count, half_count);
    else
        fprintf('  被试 %s: %d 个文件 (保留)\n', sub_id, count);
    end
end

if ~isempty(excluded_subjects)
    fprintf('\n排除的被试 (文件数 < %d): %s\n', half_count, strjoin(excluded_subjects, ', '));
end

% 筛选文件
RELAX_cfg.files = {};
for i = 1:length(all_files)
    filename = all_files{i};
    tokens = regexp(filename, '^sub(\d+)_', 'tokens');
    if ~isempty(tokens)
        sub_id = tokens{1}{1};
        if ~any(strcmp(excluded_subjects, sub_id))
            RELAX_cfg.files{end+1} = filename;
        end
    else
        RELAX_cfg.files{end+1} = filename;
    end
end

fprintf('\n找到 %d 个SET文件（已排除 %d 个不完整被试的文件）\n', ...
    length(RELAX_cfg.files), length(all_files) - length(RELAX_cfg.files));

% 跳过已处理的文件
cleaned_dir = fullfile(RELAX_cfg.myPath, 'RELAXProcessed', 'Cleaned_Data');
if exist(cleaned_dir, 'dir')
    files_to_process = {};
    skipped_count = 0;
    for i = 1:length(RELAX_cfg.files)
        filename = RELAX_cfg.files{i};
        [~, name, ~] = fileparts(filename);
        cleaned_file = fullfile(cleaned_dir, [name '_RELAX.set']);
        if exist(cleaned_file, 'file')
            skipped_count = skipped_count + 1;
        else
            files_to_process{end+1} = filename;
        end
    end
    if skipped_count > 0
        fprintf('跳过已处理的 %d 个文件\n', skipped_count);
    end
    RELAX_cfg.files = files_to_process;
end

fprintf('将处理 %d 个文件\n\n', length(RELAX_cfg.files));

%% ==================== 处理参数 ====================

% MWF轮数
RELAX_cfg.Do_MWF_Once = 1;
RELAX_cfg.Do_MWF_Twice = 1;
RELAX_cfg.Do_MWF_Thrice = 1;

% ICA
RELAX_cfg.Perform_targeted_wICA = 0;
RELAX_cfg.Perform_wICA_on_ICLabel = 1;
RELAX_cfg.Perform_ICA_subtract = 0;
RELAX_cfg.ICA_method = 'fastica_symm';

% ICLabel阈值
RELAX_cfg.ICLabel_thresholds = [0.5 0.8 0.8 0.5 0.5 0.5 0.5];
RELAX_cfg.Report_all_ICA_info = 'yes';
RELAX_cfg.Clean_other_comps = 'no';

% 指标
RELAX_cfg.computerawmetrics = 1;
RELAX_cfg.computecleanedmetrics = 1;

% 眨眼
RELAX_cfg.MWFRoundToCleanBlinks = 2;
RELAX_cfg.LowPassFilterAt_6Hz_BeforeDetectingBlinks = 'no';
RELAX_cfg.ProbabilityDataHasNoBlinks = 0;

% 漂移
RELAX_cfg.DriftSeverityThreshold = 10;
RELAX_cfg.ProportionWorstEpochsForDrift = 0.30;

% 极端值
RELAX_cfg.ExtremeVoltageShiftThreshold = 8;
RELAX_cfg.ExtremeAbsoluteVoltageThreshold = 500;
RELAX_cfg.ExtremeImprobableVoltageDistributionThreshold = 8;
RELAX_cfg.ExtremeSingleChannelKurtosisThreshold = 8;
RELAX_cfg.ExtremeAllChannelKurtosisThreshold = 8;
RELAX_cfg.ExtremeDriftSlopeThreshold = -4;
RELAX_cfg.ExtremeBlinkShiftThreshold = 3;

% 伪迹
RELAX_cfg.MinimumArtifactDuration = 1200;
RELAX_cfg.MinimumBlinkArtifactDuration = 800;

% 眨眼电极
RELAX_cfg.BlinkElectrodes = {'Fp1'; 'Fp2'; 'F3'; 'Fz'; 'F4'};
% 水平眼动电极（与参考代码一致）
RELAX_cfg.HEOGLeftpattern = ["F7", "F3", "T3"];
RELAX_cfg.HEOGRightpattern = ["F8", "F4", "T4"];
RELAX_cfg.BlinkMaskFocus = 150;

% 水平眼动
RELAX_cfg.HorizontalEyeMovementType = 2;
RELAX_cfg.HorizontalEyeMovementThreshold = 2;
RELAX_cfg.HorizontalEyeMovementThresholdIQR = 1.5;
RELAX_cfg.HorizontalEyeMovementTimepointsExceedingThreshold = 25;
RELAX_cfg.HorizontalEyeMovementTimepointsTestWindow = 49;
RELAX_cfg.HorizontalEyeMovementFocus = 200;

% 滤波
RELAX_cfg.LowPassFilterBeforeMWF = 'yes';
RELAX_cfg.DownSample = 'yes';
RELAX_cfg.DownSample_to_X_Hz = 250;
RELAX_cfg.FilterType = 'Butterworth';
RELAX_cfg.causal_or_acausal_filter = 'acausal';
RELAX_cfg.HighPassFilter = 1;
RELAX_cfg.LowPassFilter = 47;
RELAX_cfg.NotchFilterType = 'Butterworth';
RELAX_cfg.LineNoiseFrequency = 50;

% 电极
RELAX_cfg.ElectrodesToDelete = {};
RELAX_cfg.MaxProportionOfElectrodesThatCanBeDeleted = 0.20;
RELAX_cfg.InterpolateRejectedElectrodesAfterCleaning = 'yes';

% 肌肉
RELAX_cfg.MuscleSlopeThreshold = -0.31;
RELAX_cfg.MaxProportionOfDataCanBeMarkedAsMuscle = 0.50;
RELAX_cfg.ProportionOfMuscleContaminatedEpochsAboveWhichToRejectChannel = 0.05;
RELAX_cfg.ProportionOfExtremeNoiseAboveWhichToRejectChannel = 0.05;

% MWF延迟
RELAX_cfg.MWFDelayPeriod_for_eye_movements = 4;
RELAX_cfg.MWFDelayPeriod_for_muscle_artifacts = 6;
RELAX_cfg.MWF_delay_spacing_for_eye_movements = 8;
RELAX_cfg.MWF_delay_spacing_for_muscle_artifacts = 1;

% 保存
RELAX_cfg.KeepAllInfo = 0;
RELAX_cfg.saveextremesrejected = 0;
RELAX_cfg.saveround1 = 0;
RELAX_cfg.saveround2 = 0;
RELAX_cfg.saveround3 = 1;

% 其他
RELAX_cfg.OnlyIncludeTaskRelatedEpochs = 0;
RELAX_cfg.RejNontask = false;
RELAX_cfg.RejCrap = false;
RELAX_cfg.BlinkDetectThreshould = 1.5;

% 可视化
RELAX_cfg.PlotCRAPRejection = false;
RELAX_cfg.PlotAfterExtremeRejection = false;
RELAX_cfg.PlotAfterMwf1 = false;
RELAX_cfg.PlotAfterMwf2 = false;
RELAX_cfg.PlotAfterMwf3 = false;
RELAX_cfg.PlotAfterwICA = false;

%% ==================== 运行RELAX ====================
fprintf('开始RELAX处理...\n');
fprintf('========================================\n\n');


% ========== 使用RELAX批处理模式（参考实验1代码） ==========
% RELAX_Wrapper内部会循环处理所有文件，不需要外层循环

% 设置要处理的所有文件
RELAX_cfg.files = all_files_to_process;
RELAX_cfg.FilesToProcess = 1:numel(RELAX_cfg.files);

fprintf('\n========================================\n');
fprintf('开始批处理 %d 个文件\n', length(RELAX_cfg.files));
fprintf('========================================\n\n');

% 调用RELAX_Wrapper进行批处理
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

