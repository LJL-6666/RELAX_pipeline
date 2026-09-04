# BDF到RELAX预处理输入转换工具

## 功能说明

本目录包含将Tongyong数据集的原始BDF数据转换为RELAX预处理输入格式的完整流程。

### 主要功能

1. **读取BDF原始数据**：从`data/data-tongyong/原始数据/可用原始数据/脑电/{ID}/data.bdf`读取脑电数据
2. **提取视频段**：基于trigger 21/22配对提取视频段
3. **读取视频编号**：从问卷CSV文件（`data/data-tongyong/原始数据/问卷/{ID}/exp1_*_rating.csv`）读取视频编号（vid）
4. **按vid对齐**：将所有被试的数据按视频编号（而非播放顺序）对齐
5. **转换为SET格式**：将BDF数据转换为EEGLAB SET格式，作为RELAX预处理的输入

## 文件说明

- `process_tongyong_bdf_to_relax_input.m`：主脚本，执行完整流程
- `find_questionnaire_csv.m`：查找指定被试的问卷CSV文件
- `read_vid_from_csv.m`：从CSV文件读取视频编号信息
- `extract_video_segments_from_bdf.m`：从BDF文件提取视频段（trigger 21/22配对）
- `align_by_vid_and_convert_to_set.m`：按vid对齐并转换为SET格式

## 使用方法

### 前置要求

1. **MATLAB环境**：需要安装MATLAB（建议R2016b或更高版本）
2. **EEGLAB工具箱**：需要安装EEGLAB（路径：`/data/liujialing/eeglab-develop`）
3. **FieldTrip工具箱**：需要安装FieldTrip（路径：`/data/liujialing/TY/预处理/matlab/fieldtrip-20181205`）
4. **电极位置文件**：`/data/liujialing/TY/预处理/matlab/配置环境/standard_1005.elc`

### 运行方法

在MATLAB中运行：

```matlab
cd('/data/liujialing/TY/预处理/matlab/实验1/code1');
run('process_tongyong_bdf_to_relax_input.m');
```

或者在命令行中运行：

```bash
cd /data/liujialing/TY/预处理/matlab/实验1/code1
matlab -batch "run('process_tongyong_bdf_to_relax_input.m')"
```

### 输入数据要求

1. **BDF数据**：
   - 路径：`data/data-tongyong/原始数据/可用原始数据/脑电/{ID}/data.bdf`
   - 格式：BDF格式的脑电数据文件
   - 事件：包含trigger 21（视频开始）和trigger 22（视频结束）的事件信息

2. **问卷CSV**：
   - 路径：`data/data-tongyong/原始数据/问卷/{ID}/exp1_*_rating.csv`
   - 格式：CSV文件，第一列为`videoIndex`（视频编号）
   - 说明：CSV的第一行是表头，数据行从第二行开始，trial从1开始对应CSV数据行

### 输出说明

- **输出目录**：`data/data-tongyong/原始数据/可用原始数据/转化成set的脑电_aligned/`
- **文件命名**：`sub{ID}_vid{VID}.set`（例如：`sub001_vid18.set`）
- **文件格式**：EEGLAB SET格式
- **数据对齐**：所有被试的相同vid数据已对齐（按vid从小到大排序）

### 输出文件结构

每个SET文件包含：
- `EEG.data`：连续脑电数据（通道 × 时间点）
- `EEG.srate`：采样率
- `EEG.chanlocs`：通道位置信息
- `EEG.event`：事件信息（包含`videoStart`事件，标记视频编号）

## 注意事项

1. **视频段提取**：代码基于trigger 21/22配对提取视频段。如果数据中没有这些trigger，将无法提取视频段。

2. **vid对齐**：代码按照CSV文件中的`videoIndex`列（第一列）进行对齐，而不是按照播放顺序（trial）。

3. **数据长度**：不同被试的相同vid数据长度可能不同（取决于原始视频段长度）。后续RELAX预处理会处理这个问题。

4. **错误处理**：如果某个被试的数据处理失败，代码会记录错误信息并继续处理下一个被试。

## 后续步骤

处理完成后，生成的SET文件可以作为RELAX预处理的输入。

### RELAX预处理

**主运行脚本**：`/data/liujialing/TY/预处理/matlab/实验1/RELAX_SET_PARAMETERS_AND_RUN.m`

**运行命令**：
```bash
cd /data/liujialing/TY/预处理/matlab/实验1
matlab -batch "run('RELAX_SET_PARAMETERS_AND_RUN.m')"
```

**详细使用说明**：请参考 `/data/liujialing/TY/预处理/matlab/实验1/RELAX_使用说明_Tongyong.md`

**注意**：脚本已自动配置了Tongyong数据集的路径，包括：
- 输入数据路径：`data/data-tongyong/原始数据/可用原始数据/转化成set的脑电_aligned`
- 电极位置文件：`预处理/matlab/配置环境/standard_1005.elc`
- EEGLAB和RELAX路径

如需调整参数，请直接编辑`RELAX_SET_PARAMETERS_AND_RUN.m`中的相关配置。




成功: 44 / 50
失败的被试:
  - 18: 未找到视频段
  - 24: 未找到视频段
  - 26: 未找到视频段
  - 35: 未找到视频段
  - 36: 未找到视频段
  - 42: 未找到视频段


=== 检查失败被试的原因 ===

被试 18:
new Neuracle file format detected.
 文件存在，总采样点数: 27500, 采样率: 500.0 Hz
 事件数量: 268
 Trigger 21数量: 10, Trigger 22数量: 10

被试 24:
new Neuracle file format detected.
 文件存在，总采样点数: 43000, 采样率: 500.0 Hz
 事件数量: 265
 Trigger 21数量: 10, Trigger 22数量: 10

被试 26:
new Neuracle file format detected.
 文件存在，总采样点数: 3000, 采样率: 500.0 Hz
 事件数量: 272
 Trigger 21数量: 9, Trigger 22数量: 9

被试 35:
new Neuracle file format detected.
 文件存在，总采样点数: 33500, 采样率: 500.0 Hz
 事件数量: 268
 Trigger 21数量: 10, Trigger 22数量: 10

被试 36:
new Neuracle file format detected.
 文件存在，总采样点数: 26000, 采样率: 500.0 Hz
 事件数量: 268
 Trigger 21数量: 10, Trigger 22数量: 10

被试 42:
new Neuracle file format detected.
 文件存在，总采样点数: 25500, 采样率: 500.0 Hz
 事件数量: 266
 Trigger 21数量: 10, Trigger 22数量: 10

 sub011

 === 统计结果 ===

vid14: 不一致 (差异=59.75s)
 sub002: 59.92s
 sub003: 59.92s
 sub004: 59.91s
 sub005: 59.92s
 sub006: 59.91s
 sub007: 59.92s
 sub008: 59.94s
 sub009: 59.93s
 sub011: 0.19s
 sub013: 59.93s
 sub015: 59.92s
 sub016: 59.93s
 sub020: 59.92s
 sub022: 59.92s
 sub023: 59.93s
 sub025: 59.92s
 sub027: 59.92s
 sub028: 59.92s
 sub030: 59.92s
 sub031: 59.92s
 sub032: 59.92s
 sub034: 59.92s
 sub037: 59.92s
 sub038: 59.92s
 sub041: 59.91s
 sub043: 59.92s
 sub044: 59.93s
 sub045: 59.92s
 sub046: 59.92s
 sub047: 59.92s
 sub048: 59.93s
 sub049: 59.92s
 sub050: 59.91s
 sub052: 59.92s
 sub053: 59.92s
 sub054: 59.92s
 sub055: 59.91s
 sub056: 59.92s
 sub057: 59.92s
 sub058: 59.92s
 sub060: 59.92s
 sub061: 59.91s
 sub063: 59.92s
 sub065: 59.92s

vid23: 不一致 (差异=0.19s)
 sub002: 170.50s
 sub003: 170.32s
 sub004: 170.32s
 sub005: 170.33s
 sub006: 170.32s
 sub007: 170.32s
 sub008: 170.31s
 sub009: 170.32s
 sub011: 170.32s
 sub013: 170.32s
 sub015: 170.31s
 sub016: 170.32s
 sub020: 170.32s
 sub022: 170.33s
 sub023: 170.32s
 sub025: 170.31s
 sub027: 170.32s
 sub028: 170.31s
 sub030: 170.32s
 sub031: 170.32s
 sub032: 170.32s
 sub034: 170.33s
 sub037: 170.32s
 sub038: 170.32s
 sub041: 170.32s
 sub043: 170.32s
 sub044: 170.33s
 sub045: 170.32s
 sub046: 170.32s
 sub047: 170.33s
 sub048: 170.32s
 sub049: 170.33s
 sub050: 170.32s
 sub052: 170.31s
 sub053: 170.32s
 sub054: 170.33s
 sub055: 170.31s
 sub056: 170.32s
 sub057: 170.32s
 sub058: 170.31s
 sub060: 170.32s
 sub061: 170.32s
 sub063: 170.31s
 sub065: 170.32s

=== 总结 ===
共检查 28 个视频
发现 2 个视频存在长度不一致问题