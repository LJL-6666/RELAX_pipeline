# RELAX预处理使用说明 - Tongyong数据集

## 主运行代码

**推荐使用**：`RELAX_SET_PARAMETERS_AND_RUN.m`

这是RELAX的完整参数配置与运行脚本，包含所有配置选项。

## 使用方法

### 方法1：直接运行（推荐）

```bash
cd /data/liujialing/TY/预处理/matlab/实验1
matlab -batch "run('RELAX_SET_PARAMETERS_AND_RUN.m')"
```

**注意**：运行后会自动完成以下步骤：
1. RELAX预处理所有vid文件
2. **自动合并**同一被试的所有vid文件为一个文件

### 方法2：在MATLAB中运行

```matlab
cd('/data/liujialing/TY/预处理/matlab/实验1');
run('RELAX_SET_PARAMETERS_AND_RUN.m');
```

### 方法3：使用EEGLAB GUI（交互式）

```matlab
cd('/data/liujialing/TY/预处理/matlab/实验1');
eeglab;
% 然后在EEGLAB界面中选择：Tools > RELAX
```

## 自动合并功能

**默认启用**：RELAX处理完成后会自动合并同一被试的所有vid文件。

### 合并设置

在`RELAX_SET_PARAMETERS_AND_RUN.m`中（约第483行）：

```matlab
RELAX_cfg.MergeVidFilesAfterProcessing = 1; % 1 = 自动合并, 0 = 不合并
```

- **1**：自动合并（默认，推荐）
- **0**：不合并，只保留单个vid文件

### 合并后的文件特点

- **文件命名**：`subXXX_RELAX_merged.set`
- **数据组织**：按vid顺序连接（vid01 → vid02 → ... → vid28）
- **事件标记**：每个vid开始位置都有标记事件（`vid01`, `vid02`, ...）
- **方便提取**：可以使用`extract_vid_from_merged_file.m`提取特定vid段

## 已配置的路径

脚本已自动配置以下路径（针对Tongyong数据集）：

- **EEGLAB路径**：`/data/liujialing/eeglab-develop`
- **RELAX路径**：`/data/liujialing/TY/预处理/matlab/实验1`
- **输入数据路径**：`/data/liujialing/TY/data/data-tongyong/原始数据/可用原始数据/转化成set的脑电_aligned`
- **电极位置文件**：`/data/liujialing/TY/预处理/matlab/配置环境/standard_1005.elc`

## 需要修改的参数（根据需求调整）

### 1. 降采样设置（可选）

如果原始数据已经是500Hz，可以不降采样：

```matlab
RELAX_cfg.DownSample = 'no';  % 改为'no'不降采样
```

### 2. 滤波参数（已配置为1-47Hz）

```matlab
RELAX_cfg.HighPassFilter = 1;   % 高通滤波1Hz（已配置）
RELAX_cfg.LowPassFilter = 47;   % 低通滤波47Hz（已配置）
RELAX_cfg.DownSample_to_X_Hz = 250; % 降采样到250Hz（已配置）
```

**注意**：当前配置为1-47Hz滤波范围，降采样到250Hz。如需修改，请编辑`RELAX_SET_PARAMETERS_AND_RUN.m`。

### 3. MWF清理轮数（影响处理时间）

```matlab
RELAX_cfg.Do_MWF_Once = 1;   % 第一轮（必须）
RELAX_cfg.Do_MWF_Twice = 1;  % 第二轮（推荐）
RELAX_cfg.Do_MWF_Thrice = 1; % 第三轮（最彻底但最慢，默认开启）
```

### 4. 测试运行（建议先测试）

在脚本中找到这一行（约第445行）：

```matlab
RELAX_cfg.FilesToProcess = 1:numel(RELAX_cfg.files); % 处理所有文件
```

改为只处理前几个文件进行测试：

```matlab
RELAX_cfg.FilesToProcess = 1:5; % 只处理前5个文件
```

## 输出说明

### 输出目录

- **主输出目录**：`data/data-tongyong/原始数据/可用原始数据/转化成set的脑电_aligned/RELAXProcessed/`
- **清理后的数据**：`RELAXProcessed/Cleaned_data/`
- **处理统计**：`RELAXProcessed/ProcessingStatistics*.mat`

### 输出文件

**输出格式**：**SET文件**（EEGLAB格式，不是pkl文件）

1. **清理后的SET文件（单个vid）**：
   - 命名：`{原文件名}_RELAX.set`
   - 位置：`RELAXProcessed/Cleaned_Data/`
   - **输出方式**：**一个ID多个文件**（每个vid一个文件）
   - 例如：
     - `sub001_vid01_RELAX.set`
     - `sub001_vid02_RELAX.set`
     - ...
     - `sub001_vid28_RELAX.set`
   - 每个被试（ID）会有28个文件（对应28个视频）

2. **合并后的SET文件（自动生成）**：
   - 命名：`subXXX_RELAX_merged.set`
   - 位置：`RELAXProcessed/Cleaned_Data_Merged/`
   - **输出方式**：**一个ID一个文件**（所有vid按顺序合并）
   - 例如：`sub001_RELAX_merged.set`（包含vid01到vid28，按顺序连接）
   - **自动生成**：RELAX处理完成后自动合并，无需单独运行合并脚本

2. **处理统计文件**：
   - `ProcessingStatisticsRoundOne.mat`：第一轮MWF统计
   - `ProcessingStatisticsRoundTwo.mat`：第二轮MWF统计
   - `ProcessingStatisticsRoundThree.mat`：第三轮MWF统计（最终）
   - `RawMetrics.mat`：原始数据指标
   - `CleanedMetrics.mat`：清理后数据指标
   - `RELAX_issues_to_check.mat`：需要检查的问题

## 重要参数说明

### 滤波参数（当前配置）

- **HighPassFilter = 1**：高通滤波1Hz（适合振荡分析）
- **LowPassFilter = 47**：低通滤波47Hz（1-47Hz范围）
- **DownSample_to_X_Hz = 250**：降采样到250Hz
- **LineNoiseFrequency = 50**：中国工频50Hz

**注意**：低通滤波设置为47Hz（低于75Hz），因此无法使用客观肌肉检测方法，但RELAX仍会使用其他方法检测和清理肌肉伪迹。

### 伪迹检测阈值

- **MuscleSlopeThreshold = -0.31**：宽松（默认）
  - `-0.59`：中等严格
  - `-0.72`：严格
- **MaxProportionOfDataCanBeMarkedAsMuscle = 0.50**：最多50%数据可标记为肌肉伪迹

### 电极删除

- **MaxProportionOfElectrodesThatCanBeDeleted = 0.20**：最多删除20%电极
- **InterpolateRejectedElectrodesAfterCleaning = 'yes'**：清理后插值

## 处理时间估算

- **每个文件**：约10-15分钟
- **1400个文件**（50被试×28视频）：约230-350小时
- **建议**：使用集群或分批处理

## 注意事项

1. **依赖检查**：脚本会自动检查必需的插件和工具箱
2. **内存要求**：大文件可能需要16GB+ RAM
3. **先测试**：建议先用少量文件测试参数设置
4. **检查统计**：处理完成后检查`RELAX_issues_to_check.mat`

## 其他使用方式

### 使用RELAX_Wrapper.m（自定义脚本）

如果需要自定义处理流程，可以在自己的脚本中调用：

```matlab
% 配置RELAX_cfg参数
RELAX_cfg.myPath = '/path/to/your/data';
RELAX_cfg.caploc = '/path/to/cap/file.elc';
% ... 其他参数 ...

% 调用RELAX_Wrapper
[RELAX_cfg, FileNumber, CleanedMetrics, RawMetrics, ...] = ...
    RELAX_Wrapper(RELAX_cfg);
```

### 使用pop_RELAX.m（EEGLAB GUI）

在EEGLAB界面中：
1. 加载数据：`File > Load existing dataset`
2. 打开RELAX：`Tools > RELAX`
3. 在GUI中配置参数并运行

## 常见问题

### 1. Rank deficiency警告

如果出现MWF rank deficiency：
- 增加`RELAX_cfg.MinimumArtifactDuration`（从1200增加到1500-2000）
- 减少`RELAX_cfg.MaxProportionOfDataCanBeMarkedAsMuscle`（从0.50降到0.40）

### 2. 内存不足

如果内存不足：
- 降低`RELAX_cfg.MWFDelayPeriod_for_eye_movements`（从4降到2-3）
- 降低`RELAX_cfg.MWFDelayPeriod_for_muscle_artifacts`（从6降到4-5）
- 或先降采样数据

### 3. 处理速度慢

- 减少MWF清理轮数（只运行1-2轮）
- 关闭绘图选项（`PlotAfterMwf* = false`）
- 使用更快的ICA方法（如`fastica`而不是`picard`）

## 提取vid段（从合并后的文件）

如果需要从合并后的文件中提取特定vid：

```matlab
% 方法1：使用提供的函数
addpath('/data/liujialing/TY/预处理/matlab/实验1/code3');
EEG_vid5 = extract_vid_from_merged_file('sub001_RELAX_merged.set', 5);

% 方法2：使用EEGLAB的epoch功能
EEG = pop_loadset('filename', 'sub001_RELAX_merged.set');
EEG_vid5 = pop_epoch(EEG, {'vid05'}, [0, Inf]);
```

## 后续步骤

RELAX预处理完成后，可以进行：
1. **提取vid段**：从合并后的文件中提取特定vid进行分析
2. **分段（Epoching）**：根据事件标记分段数据
3. **进一步伪迹拒绝**：拒绝仍有伪迹的epoch
4. **条件分离**：将不同条件的数据分离到不同文件
5. **统计分析**：进行ERP或频域分析

## 引用

如果使用RELAX，请引用：
- Bailey, N. W., et al. (2023). RELAX part 1: A tool for automated cleaning of EEG data. *BioRxiv*.
- Bailey, N. W., et al. (2023). RELAX part 2: A tool for automated cleaning of EEG data for ERPs. *BioRxiv*.

