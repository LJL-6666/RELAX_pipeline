%% RELAX预处理脚本 - 交流任务
% 
% 基于RELAX EEG CLEANING PIPELINE
% 适配本地Windows路径和"交流"任务数据
%
% 前置条件:
%   1. 已运行 process_jiaoliu_task.m 生成SET文件
%   2. SET文件位于: RELAX输入\交流\
%
% 输出:
%   - 清理后的数据: RELAX输入\交流\RELAXProcessed\Cleaned_Data\

clear all; close all; clc;

fprintf('=== RELAX预处理 - 交流任务 ===\n');
fprintf('开始时间: %s\n\n', datestr(now));

%% ==================== 路径配置 ====================
base_dir = 'E:\ljl\work\通用\RELAX_update\归档\新预处理';

%% ==================== 依赖库配置 ====================
fprintf('正在配置依赖库...\n');

% 检查工具箱并配置路径
toolbox_list = ver;
toolbox_names = {toolbox_list.Name};
has_stats_toolbox = any(strcmp(toolbox_names, 'Statistics and Machine Learning Toolbox'));

% 如果Statistics Toolbox未安装，添加当前目录（包含mad_alternative.m）
if ~has_stats_toolbox
    script_dir = fileparts(mfilename('fullpath'));
    addpath(script_dir);
    fprintf('  警告: Statistics Toolbox未安装，使用替代函数\n');
    fprintf('  当前脚本目录: %s\n', script_dir);
end

% 工具包根目录
toolbox_dir = 'D:\APP\matlab\bao';

% EEGLAB路径（必需）
eeglab_path = fullfile(toolbox_dir, 'eeglab2025.1.0');
if exist(eeglab_path, 'dir')
    addpath(eeglab_path);
    fprintf('  EEGLAB: %s\n', eeglab_path);
else
    error('未找到EEGLAB: %s', eeglab_path);
end

% FieldTrip路径
fieldtrip_path = fullfile(toolbox_dir, 'fieldtrip-20181205');
if exist(fieldtrip_path, 'dir')
    addpath(fieldtrip_path);
    addpath(fullfile(fieldtrip_path, 'fileio'));
    addpath(fullfile(fieldtrip_path, 'utilities'));
    addpath(fullfile(fieldtrip_path, 'preproc'));
    fprintf('  FieldTrip: %s\n', fieldtrip_path);
end

% RELAX插件路径（优先使用bao目录下的新版本）
relax_path = fullfile(toolbox_dir, 'RELAX-RELAX-v2.0.0');
if ~exist(relax_path, 'dir')
    relax_path = fullfile(base_dir, '实验1');  % 备选
end
if exist(relax_path, 'dir')
    addpath(relax_path);
    fprintf('  RELAX: %s\n', relax_path);
else
    error('未找到RELAX插件');
end

% MWF插件
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

% PICARD (ICA算法)
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
    % 排除可能冲突的NaN目录（包含不兼容的mad函数）
    nan_path = fullfile(biosig_path, 'NaN');
    if exist(nan_path, 'dir')
        rmpath(genpath(nan_path));
    end
    % 确保移除所有Biosig中可能冲突的mad函数路径
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
RELAX_cfg.caploc = fullfile(base_dir, '预处理_交流任务', 'standard_1005.elc');
if ~exist(RELAX_cfg.caploc, 'file')
    RELAX_cfg.caploc = [];
    warning('未找到电极位置文件，将跳过电极位置设置');
end

% 输入数据路径（SET文件目录）
RELAX_cfg.myPath = fullfile(base_dir, 'RELAX输入', '交流');

if ~exist(RELAX_cfg.myPath, 'dir')
    error('输入目录不存在: %s\n请先运行 process_jiaoliu_task.m', RELAX_cfg.myPath);
end

% 单文件处理模式（设为空，使用批量处理）
RELAX_cfg.filename = [];

% 列出所有SET文件
cd(RELAX_cfg.myPath);
RELAX_cfg.dirList = dir('*.set');
all_files = {RELAX_cfg.dirList.name};

if isempty(all_files)
    error('未找到SET文件！请先运行 process_jiaoliu_task.m');
end

% 统计每个被试的文件数量
fprintf('正在统计每个被试的文件数量...\n');
subject_file_count = containers.Map('KeyType', 'char', 'ValueType', 'double');

for i = 1:length(all_files)
    filename = all_files{i};
    % 提取被试ID（格式：subXXX_vidYY.set）
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

% 找出文件数少于14个（少于一半）的被试
half_count = 14;  % 28的一半
excluded_subjects = {};
excluded_file_count = 0;

fprintf('\n被试文件统计:\n');
subject_ids = subject_file_count.keys;
for i = 1:length(subject_ids)
    sub_id = subject_ids{i};
    count = subject_file_count(sub_id);
    if count < half_count
        excluded_subjects{end+1} = sub_id;
        excluded_file_count = excluded_file_count + count;
        fprintf('  被试 %s: %d 个文件 (少于%d个，将被排除)\n', sub_id, count, half_count);
    else
        fprintf('  被试 %s: %d 个文件 (保留)\n', sub_id, count);
    end
end

if ~isempty(excluded_subjects)
    fprintf('\n排除的被试 (文件数 < %d): %s\n', half_count, strjoin(excluded_subjects, ', '));
else
    fprintf('\n所有被试的文件数都 >= %d，无需排除\n', half_count);
end

% 筛选文件：排除文件数少于一半的被试的文件
RELAX_cfg.files = {};
for i = 1:length(all_files)
    filename = all_files{i};
    % 提取被试ID
    tokens = regexp(filename, '^sub(\d+)_', 'tokens');
    if ~isempty(tokens)
        sub_id = tokens{1}{1};
        % 检查是否是被排除被试的文件
        should_exclude = any(strcmp(excluded_subjects, sub_id));
        if ~should_exclude
            RELAX_cfg.files{end+1} = filename;
        end
    else
        % 如果无法提取被试ID，保留文件（可能是其他格式）
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

% MWF清理轮数
RELAX_cfg.Do_MWF_Once = 1;
RELAX_cfg.Do_MWF_Twice = 1;
RELAX_cfg.Do_MWF_Thrice = 1;

% ICA和wICA
RELAX_cfg.Perform_targeted_wICA = 0;
RELAX_cfg.Perform_wICA_on_ICLabel = 1;
RELAX_cfg.Perform_ICA_subtract = 0;
RELAX_cfg.ICA_method = 'fastica_symm';  % 使用fastica，比picard更兼容

% ICLabel阈值
RELAX_cfg.ICLabel_thresholds = [0.5 0.8 0.8 0.5 0.5 0.5 0.5];
RELAX_cfg.Report_all_ICA_info = 'yes';
RELAX_cfg.Clean_other_comps = 'no';

% 计算指标
RELAX_cfg.computerawmetrics = 1;
RELAX_cfg.computecleanedmetrics = 1;

% 眨眼检测
RELAX_cfg.MWFRoundToCleanBlinks = 2;
RELAX_cfg.LowPassFilterAt_6Hz_BeforeDetectingBlinks = 'no';
RELAX_cfg.ProbabilityDataHasNoBlinks = 0;

% 漂移检测
RELAX_cfg.DriftSeverityThreshold = 10;
RELAX_cfg.ProportionWorstEpochsForDrift = 0.30;

% 极端值阈值
RELAX_cfg.ExtremeVoltageShiftThreshold = 8;
RELAX_cfg.ExtremeAbsoluteVoltageThreshold = 500;
RELAX_cfg.ExtremeImprobableVoltageDistributionThreshold = 8;
RELAX_cfg.ExtremeSingleChannelKurtosisThreshold = 8;
RELAX_cfg.ExtremeAllChannelKurtosisThreshold = 8;
RELAX_cfg.ExtremeDriftSlopeThreshold = -4;
RELAX_cfg.ExtremeBlinkShiftThreshold = 3;

% 伪迹标记参数
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

% 滤波参数
RELAX_cfg.LowPassFilterBeforeMWF = 'yes';
RELAX_cfg.DownSample = 'yes';
RELAX_cfg.DownSample_to_X_Hz = 250;
RELAX_cfg.FilterType = 'Butterworth';
RELAX_cfg.causal_or_acausal_filter = 'acausal';
RELAX_cfg.HighPassFilter = 1;
RELAX_cfg.LowPassFilter = 47;
RELAX_cfg.NotchFilterType = 'Butterworth';
RELAX_cfg.LineNoiseFrequency = 50;

% 电极删除
RELAX_cfg.ElectrodesToDelete = {};
RELAX_cfg.MaxProportionOfElectrodesThatCanBeDeleted = 0.20;
RELAX_cfg.InterpolateRejectedElectrodesAfterCleaning = 'yes';

% 肌肉伪迹
RELAX_cfg.MuscleSlopeThreshold = -0.31;
RELAX_cfg.MaxProportionOfDataCanBeMarkedAsMuscle = 0.50;
RELAX_cfg.ProportionOfMuscleContaminatedEpochsAboveWhichToRejectChannel = 0.05;
RELAX_cfg.ProportionOfExtremeNoiseAboveWhichToRejectChannel = 0.05;

% MWF延迟
RELAX_cfg.MWFDelayPeriod_for_eye_movements = 4;
RELAX_cfg.MWFDelayPeriod_for_muscle_artifacts = 6;
RELAX_cfg.MWF_delay_spacing_for_eye_movements = 8;
RELAX_cfg.MWF_delay_spacing_for_muscle_artifacts = 1;

% 保存选项
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

% 可视化（建议关闭以加快处理）
RELAX_cfg.PlotCRAPRejection = false;
RELAX_cfg.PlotAfterExtremeRejection = false;
RELAX_cfg.PlotAfterMwf1 = false;
RELAX_cfg.PlotAfterMwf2 = false;
RELAX_cfg.PlotAfterMwf3 = false;
RELAX_cfg.PlotAfterwICA = false;

%% ==================== 选择处理文件 ====================
% 设置要处理的文件范围（可修改）
% RELAX_cfg.FilesToProcess = 1:5;  % 测试：只处理前5个
files_to_process = 1:numel(RELAX_cfg.files);  % 处理所有

%% ==================== 运行RELAX ====================
fprintf('开始RELAX处理...\n');
fprintf('========================================\n\n');

% 初始化统计变量
processed_count = 0;
failed_files = {};
failed_count = 0;

% 循环处理每个文件，添加错误处理
for file_idx = 1:length(files_to_process)
    file_num = files_to_process(file_idx);
    current_file = RELAX_cfg.files{file_num};
    
    fprintf('\n处理文件 %d/%d: %s\n', file_idx, length(files_to_process), current_file);
    
    % 检查文件是否已处理
    [~, FileName, ~] = fileparts(current_file);
    cleaned_data_dir = fullfile(RELAX_cfg.myPath, 'RELAXProcessed', 'Cleaned_Data');
    output_file = fullfile(cleaned_data_dir, [FileName '_RELAX.set']);
    
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
    
    try
        % 处理单个文件（不捕获输出参数，避免wICA失败时的输出参数错误）
        RELAX_Wrapper(RELAX_cfg_single);
        processed_count = processed_count + 1;
        fprintf('  ✓ 文件处理成功\n');
    catch ME
        fprintf('  ✗ 文件处理失败: %s\n', ME.message);
        if ~isempty(ME.stack)
            fprintf('    错误位置: %s (第 %d 行)\n', ME.stack(1).name, ME.stack(1).line);
        end
        failed_files{end+1} = current_file;
        failed_count = failed_count + 1;
        % 继续处理下一个文件，不中断整个流程
    end
end

fprintf('\n========================================\n');
fprintf('RELAX处理完成！\n');
fprintf('成功: %d/%d 文件\n', processed_count, length(files_to_process));
if failed_count > 0
    fprintf('失败: %d 文件\n', failed_count);
    fprintf('失败文件列表:\n');
    for i = 1:length(failed_files)
        fprintf('  - %s\n', failed_files{i});
    end
end
fprintf('结束时间: %s\n', datestr(now));
fprintf('========================================\n');

%% ==================== 输出信息 ====================
output_path = fullfile(RELAX_cfg.myPath, 'RELAXProcessed', 'Cleaned_Data');
fprintf('\n清理后的数据位于: %s\n', output_path);
fprintf('处理统计位于: %s\n', fullfile(RELAX_cfg.myPath, 'RELAXProcessed'));

