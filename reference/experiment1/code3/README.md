# 合并vid文件 - Tongyong数据集

## 功能说明

本目录包含将RELAX处理后的同一被试的所有vid文件合并为一个文件的工具。

### 主要功能

1. **合并vid文件**：将同一被试的所有vid文件按vid顺序合并为一个文件
2. **保留事件信息**：在合并时保留vid标记事件，方便后续提取
3. **提取vid段**：从合并后的文件中提取指定vid的视频段

## 文件说明

- `merge_vid_files_by_subject.m`：主脚本，合并同一被试的所有vid文件
- `extract_vid_from_merged_file.m`：从合并后的文件中提取指定vid的视频段

## 使用方法

### 步骤1：合并vid文件

在MATLAB中运行：

```matlab
cd('/data/liujialing/TY/预处理/matlab/实验1/code3');
run('merge_vid_files_by_subject.m');
```

或者在命令行中运行：

```bash
cd /data/liujialing/TY/预处理/matlab/实验1/code3
matlab -batch "run('merge_vid_files_by_subject.m')"
```

### 步骤2：提取vid段（可选）

如果需要从合并后的文件中提取特定vid：

```matlab
% 加载合并后的文件
EEG_merged = pop_loadset('filename', 'sub001_RELAX_merged.set', ...
    'filepath', '/path/to/merged/files');

% 提取vid 5
EEG_vid5 = extract_vid_from_merged_file(EEG_merged, 5);

% 或者直接使用文件路径
EEG_vid5 = extract_vid_from_merged_file('sub001_RELAX_merged.set', 5);
```

## 输入输出

### 输入

- **RELAX处理后的文件**：
  - 路径：`data/data-tongyong/原始数据/可用原始数据/转化成set的脑电_aligned/RELAXProcessed/Cleaned_Data/`
  - 文件格式：`subXXX_vidYY_RELAX.set`

### 输出

- **合并后的文件**：
  - 路径：`data/data-tongyong/原始数据/可用原始数据/转化成set的脑电_aligned/RELAXProcessed/Cleaned_Data_Merged/`
  - 文件格式：`subXXX_RELAX_merged.set`
  - **每个被试一个文件**，包含所有vid（按vid顺序连接）

## 输出文件特点

### 1. 数据组织

- **按vid顺序连接**：vid01, vid02, ..., vid28
- **连续数据**：所有vid按时间顺序连接成一个连续的数据流
- **保留采样率**：与原始数据相同的采样率

### 2. 事件信息

每个vid的开始位置都有标记事件：
- **事件类型**：`vid01`, `vid02`, ..., `vid28`
- **事件位置**：每个vid的第一个采样点
- **vid编号**：存储在事件的`vid`字段中

### 3. 元数据

合并后的文件包含以下元数据：
- `EEG.merged_info.subject_id`：被试ID
- `EEG.merged_info.vid_list`：包含的vid列表
- `EEG.merged_info.vid_count`：vid数量
- `EEG.merged_info.total_duration`：总时长（秒）

## 提取vid段的方法

### 方法1：使用提供的函数

```matlab
EEG_vid = extract_vid_from_merged_file('sub001_RELAX_merged.set', 5);
```

### 方法2：手动提取

```matlab
% 加载合并后的文件
EEG = pop_loadset('filename', 'sub001_RELAX_merged.set');

% 查找vid 5的开始位置
vid5_start = [];
for e = 1:length(EEG.event)
    if isfield(EEG.event(e), 'vid') && EEG.event(e).vid == 5
        vid5_start = round(EEG.event(e).latency);
        break;
    end
end

% 查找vid 6的开始位置（作为vid 5的结束）
vid6_start = EEG.pnts + 1;
for e = 1:length(EEG.event)
    if isfield(EEG.event(e), 'vid') && EEG.event(e).vid == 6
        vid6_start = round(EEG.event(e).latency);
        break;
    end
end

% 提取vid 5的数据
EEG_vid5 = pop_select(EEG, 'point', [vid5_start, vid6_start-1]);
```

### 方法3：使用EEGLAB的epoch功能

```matlab
% 加载合并后的文件
EEG = pop_loadset('filename', 'sub001_RELAX_merged.set');

% 根据vid事件分段
EEG = pop_epoch(EEG, {'vid05'}, [0, Inf]); % 提取vid 5
```

## 注意事项

1. **事件标记**：合并脚本会自动在每个vid的开始位置添加标记事件
2. **vid顺序**：文件按vid从小到大顺序合并
3. **数据完整性**：合并后的数据是连续的，没有时间间隔
4. **采样率**：保持原始采样率（RELAX处理后的采样率，通常是250Hz）

## 处理流程

```
RELAX处理
  ↓
sub001_vid01_RELAX.set
sub001_vid02_RELAX.set
...
sub001_vid28_RELAX.set
  ↓
合并脚本
  ↓
sub001_RELAX_merged.set (包含所有vid，按顺序连接)
  ↓
提取vid段（可选）
  ↓
sub001_vid05_extracted.set
```

## 优势

1. **方便分析**：一个被试一个文件，便于批量处理
2. **保留信息**：事件标记完整，可以随时提取特定vid
3. **节省空间**：相比保存28个单独文件，合并后更节省空间
4. **灵活提取**：可以根据需要提取任意vid段进行分析

