# 问题被试RELAX预处理

## 功能说明

本目录包含专门处理6个问题被试（18, 24, 26, 35, 36, 42）的RELAX预处理脚本。

**重要**：这6个被试的SET文件已经通过`code1/问题数据处理/`生成，所以本脚本只需要做 **SET→RELAX清理**。

## 主要文件

- **`process_problem_subjects_complete.m`**：问题被试的RELAX预处理主脚本
  - 读取这6个被试的SET文件
  - 使用RELAX进行伪迹清理
  - 自动合并同一被试的所有vid文件

## 工作流程

```
SET文件（已存在）
    ↓
[RELAX预处理] 滤波、伪迹清理、ICA等
    ↓
subXXX_vidYY_RELAX.set (清理后的数据，28个文件/被试)
    ↓
[自动合并] 同一被试的所有vid文件
    ↓
subXXX_RELAX_merged.set (每个被试一个文件)
```

## 使用方法

### 运行命令（推荐）

```bash
cd /data/liujialing/TY/预处理/matlab/实验1/code2
matlab -batch "run('process_problem_subjects_complete.m')"
```

cd /data/liujialing/TY/预处理/matlab/实验1/code2
nohup matlab -nodisplay -nosplash -r "run('process_problem_subjects_complete.m'); exit" > relax_processing.log 2>&1 &



### 在MATLAB中运行

```matlab
cd('/data/liujialing/TY/预处理/matlab/实验1/code2');
run('process_problem_subjects_complete.m');
```

## 输入数据

### SET文件（已生成）

- **路径**：`data/data-tongyong/原始数据/可用原始数据/转化成set的脑电_aligned/`
- **文件格式**：`subXXX_vidYY.set`
- **被试列表**：18, 24, 26, 35, 36, 42
- **文件数量**：约336个（6个被试 × 每个被试若干个vid）

**说明**：这些SET文件已经通过`code1/问题数据处理/merge_multiple_bdf_and_process.m`生成，无需再次转换。

## 输出数据

### 1. RELAX清理后的数据

- **路径**：`data/data-tongyong/原始数据/可用原始数据/转化成set的脑电_aligned/RELAXProcessed/Cleaned_Data/`
- **文件命名**：`subXXX_vidYY_RELAX.set`
- **说明**：经过RELAX清理后的数据，每个被试若干个文件（对应若干个视频）

### 2. 合并后的数据

- **路径**：`data/data-tongyong/原始数据/可用原始数据/转化成set的脑电_aligned/RELAXProcessed/Cleaned_Data_Merged/`
- **文件命名**：`subXXX_RELAX_merged.set`
- **说明**：同一被试的所有vid按顺序合并为一个文件，包含vid标记事件

### 3. 处理统计文件

- **路径**：`data/data-tongyong/原始数据/可用原始数据/转化成set的脑电_aligned/RELAXProcessed/`
- **文件列表**：
  - `ProcessingStatisticsRoundOne.mat`
  - `ProcessingStatisticsRoundTwo.mat`
  - `ProcessingStatisticsRoundThree.mat`
  - `RawMetrics.mat`
  - `CleanedMetrics.mat`
  - `RELAX_issues_to_check.mat`

## RELAX参数配置

本脚本的参数与主代码`RELAX_SET_PARAMETERS_AND_RUN.m`完全一致：

### 滤波参数

- **高通滤波**：1 Hz
- **低通滤波**：47 Hz
- **降采样**：250 Hz
- **工频陷波**：50 Hz（中国标准）

### MWF清理

- **第一轮MWF**：开启
- **第二轮MWF**：开启
- **第三轮MWF**：开启

### 伪迹检测

- **肌肉伪迹阈值**：-0.31（宽松）
- **眨眼检测**：自动检测
- **眼动检测**：自动检测

### 电极处理

- **最大删除比例**：20%
- **删除后插值**：是

## 处理时间估算

- **每个vid文件**：约10-15分钟
- **6个被试**：约336个文件
- **总时间**：约56-84小时

建议使用后台运行：
```bash
nohup matlab -batch "run('process_problem_subjects_complete.m')" > output.log 2>&1 &
```

## 与其他代码的关系

### 与主代码的关系

**主代码**：`RELAX_SET_PARAMETERS_AND_RUN.m`
- 处理所有被试（包括44个普通被试 + 6个问题被试）
- 如果6个问题被试的SET文件已准备好，也可以用主代码一次性处理所有50个被试

**本code2**：`process_problem_subjects_complete.m`
- **只处理6个问题被试**（18, 24, 26, 35, 36, 42）
- 与主代码的区别仅在于**文件过滤**
- RELAX参数完全相同
- 适合单独处理这6个问题被试

### 与code1的关系

**code1**：BDF→SET转换
- `code1/问题数据处理/merge_multiple_bdf_and_process.m`已经将6个问题被试的多个BDF文件转换为SET格式
- **本code2的输入**就是code1的输出

### 与code3的关系

**code3**：合并vid文件
- 本code2在处理完成后自动调用合并功能
- 无需单独运行code3脚本

## 完整处理流程

如果从头开始处理所有50个被试：

```bash
# 1. 普通被试（44个）的BDF→SET转换
# （使用code1/process_tongyong_bdf_to_relax_input.m，已完成）

# 2. 问题被试（6个）的BDF→SET转换
# （使用code1/问题数据处理/merge_multiple_bdf_and_process.m，已完成）

# 3. 所有被试的RELAX预处理
# 方法1：分别处理
cd /data/liujialing/TY/预处理/matlab/实验1/code2
matlab -batch "run('process_problem_subjects_complete.m')"  # 处理6个问题被试

cd /data/liujialing/TY/预处理/matlab/实验1
matlab -batch "run('RELAX_SET_PARAMETERS_AND_RUN.m')"  # 处理44个普通被试

# 方法2：一次性处理（推荐）
cd /data/liujialing/TY/预处理/matlab/实验1
matlab -batch "run('RELAX_SET_PARAMETERS_AND_RUN.m')"  # 处理所有50个被试
```

## 依赖关系

本脚本依赖以下工具和插件：

### 必需的工具箱

- **EEGLAB**：`/data/liujialing/eeglab-develop`
- **RELAX**：`/data/liujialing/TY/预处理/matlab/实验1`

### 可选的插件（自动检测）

- FieldTrip
- PREP Pipeline
- FastICA
- ICLabel
- PICARD
- Firfilt
- DIPFIT
- Clean Rawdata
- Biosig

脚本会自动检测并添加这些插件的路径。

## 特点

### 与主代码的一致性

本脚本与`RELAX_SET_PARAMETERS_AND_RUN.m`的**核心部分完全相同**：

1. **RELAX_Wrapper调用**完全一致
2. **所有RELAX参数**完全一致
3. **依赖配置**完全一致
4. **合并逻辑**完全一致

### 唯一的区别

唯一的区别是**文件过滤**：

```matlab
% 主代码：处理所有SET文件
RELAX_cfg.files = {RELAX_cfg.dirList.name};

% code2：只处理6个问题被试的SET文件
problem_subjects = {'18', '24', '26', '35', '36', '42'};
% 过滤文件...
RELAX_cfg.files = filtered_files;
```

## 运行日志

脚本会输出详细的处理日志：

1. **配置阶段**：
   - 检测并添加依赖路径
   - 列出找到的SET文件数量

2. **RELAX处理**：
   - 每个文件的处理进度
   - 伪迹检测和清理统计

3. **合并阶段**：
   - 合并的被试列表
   - 每个被试的vid文件数量

## 故障排除

### 1. 找不到SET文件

检查SET文件是否已生成：
```bash
ls /data/liujialing/TY/data/data-tongyong/原始数据/可用原始数据/转化成set的脑电_aligned/sub018*.set
```

如果没有，需要先运行`code1/问题数据处理/merge_multiple_bdf_and_process.m`。

### 2. RELAX处理失败

**已修复的问题**：
- **段错误（Segmentation violation）**：已关闭所有绘图选项（后台运行必须禁用绘图）
- **单个文件失败导致整体中断**：已改为逐个文件处理模式，单个文件失败不影响其他文件
- **MATLAB卡死在错误提示**：已添加`dbclear`和`dbquit`防止进入调试模式

**其他可能的问题**：
- 检查内存是否足够（建议16GB+）
- 检查EEGLAB和相关插件是否正确安装
- 查看`RELAX_issues_to_check.mat`文件了解具体问题
- 部分文件可能因数据质量过差而处理失败（会在日志中列出）

### 3. 找不到依赖插件

脚本会自动在多个位置查找插件：
- EEGLAB的plugins目录
- 项目的`预处理/matlab/`目录

如果仍然找不到，检查插件是否已安装。

## 参数调整

如需调整RELAX参数，直接编辑`process_problem_subjects_complete.m`：

```matlab
%% ========== RELAX核心参数（与主代码完全一致）==========
RELAX_cfg.HighPassFilter = 1;   % 高通滤波频率
RELAX_cfg.LowPassFilter = 47;   % 低通滤波频率
RELAX_cfg.DownSample_to_X_Hz = 250;  % 降采样频率
RELAX_cfg.Do_MWF_Thrice = 1;    % 是否进行第三轮MWF清理
% ... 更多参数 ...
```

**建议**：保持参数与主代码一致，以确保所有被试的预处理方式相同。

## 注意事项

1. **SET文件必须已存在**：
   - 6个问题被试的SET文件应该已经通过code1生成
   - 如果没有，先运行`code1/问题数据处理/merge_multiple_bdf_and_process.m`

2. **磁盘空间**：
   - 每个被试约需要1-2GB空间
   - 6个被试总共需要约6-12GB空间

3. **运行时间较长**：
   - 建议使用后台运行或nohup命令
   - 可以使用screen或tmux保持会话

4. **检查中间结果**：
   - RELAX完成后检查统计文件
   - 合并完成后检查事件标记

## 后续步骤

处理完成后，可以进行：

1. **提取特定vid段**：从合并文件中提取特定视频段
2. **分段（Epoching）**：根据事件标记分段数据
3. **进一步分析**：ERP分析、频域分析等

## 引用

如果使用RELAX，请引用：

- Bailey, N. W., et al. (2023). RELAX part 1: Algorithm and application to oscillations. *Clinical Neurophysiology*.
- Bailey, N. W., et al. (2023). RELAX part 2: A fully automated EEG data cleaning algorithm that is applicable to Event-Related-Potentials. *Clinical Neurophysiology*.
