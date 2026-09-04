# 恢复合并文件中的删除时间段

## 脚本说明

`restore_deleted_periods_merged.m` - 恢复已合并文件中被RELAX删除的时间段为NaN值

## 功能

本脚本处理**已经按vid顺序合并**的EEG数据文件：
- 读取合并后的文件（每个被试包含所有vid）
- 恢复RELAX处理时删除的时间段（设置为NaN）
- 保持合并后的数据结构和事件标记
- 正确调整所有事件的时间位置

## 输入输出

### 输入
- **路径**: `TY/data/data-tongyong/原始数据/可用原始数据/转化成set的脑电_aligned/RELAXProcessed/Cleaned_Data_Merged/`
- **格式**: `subXXX_RELAX_merged.set`
- **特点**:
  - 每个文件包含一个被试的所有vid（按顺序连接）
  - 包含RELAX删除时间段信息 (`EEG.RELAX.ExtremelyBadPeriodsForDeletion`)
  - 包含vid事件标记（type='vid01', 'vid02', ...）

### 输出
- **路径**: `TY/data/data-tongyong/原始数据/可用原始数据/转化成set的脑电_aligned/RELAXProcessed/Cleaned_Data_Merged_Restored/`
- **格式**: `subXXX_RELAX_merged_restored.set`
- **特点**:
  - 保持合并后的数据结构
  - 删除的时间段恢复为NaN
  - 事件时间已调整到恢复后的时间轴
  - 保留所有元数据（merged_info等）

## 使用方法

### 在MATLAB中运行

```matlab
cd /data/liujialing/TY/预处理/matlab/实验1/code1
run('restore_deleted_periods_merged.m')
```

### 在命令行中运行

```bash
cd /data/liujialing/TY/预处理/matlab/实验1/code1
matlab -batch "run('restore_deleted_periods_merged.m')"
```

## 处理流程

```
原始数据
  ↓ (按vid拆分)
sub001_vid01.set, sub001_vid02.set, ..., sub001_vid28.set
  ↓ (RELAX处理 - 删除极端噪声时间段)
sub001_vid01_RELAX.set, sub001_vid02_RELAX.set, ...
  ↓ (按vid顺序合并 - merge_vid_files_by_subject.m)
sub001_RELAX_merged.set (所有vid连接，删除段已移除)
  ↓ (恢复删除时间段 - restore_deleted_periods_merged.m)
sub001_RELAX_merged_restored.set (所有vid连接，删除段为NaN)
```

## 核心功能解释

### 1. 删除时间段信息
RELAX处理会记录极端噪声时间段并从数据中删除：
- 记录在 `EEG.RELAX.ExtremelyBadPeriodsForDeletion` 中
- 格式：`[起始位置, 结束位置]`（相对于删除前的时间轴）
- 例如：`[1000, 1500; 3000, 3200]` 表示删除了两个时间段

### 2. 恢复逻辑
本脚本将删除的时间段恢复为NaN：
1. 计算原始数据长度 = 当前长度 + 删除长度
2. 创建恢复后的数据矩阵（初始化为NaN）
3. 将未删除的数据填充到正确位置
4. 删除的时间段保持为NaN

### 3. 事件调整
事件时间会根据删除时间段自动调整：
- 计算每个事件之前删除了多少采样点
- 将事件时间调整到恢复后的时间轴
- 标记在删除时间段内的事件

### 4. 保持数据结构
- 保留合并信息 (`EEG.merged_info`)
- 保留vid事件标记
- 保留所有原始元数据

## 关键问题：能否正确恢复每个vid的删除时间段？

### 答案：可以 ✓

虽然输入文件是合并后的，但恢复功能仍然正确，原因如下：

1. **删除时间段记录是准确的**
   - `ExtremelyBadPeriodsForDeletion` 记录的是相对于**删除前**的位置
   - 无论数据是否合并，这些位置信息都是准确的

2. **恢复是基于位置的**
   - 脚本根据记录的位置信息恢复NaN
   - 不依赖于数据是否合并或来自哪个vid

3. **vid边界信息保留**
   - 事件标记 (vid01, vid02, ...) 会随着时间轴调整
   - 可以通过事件位置确定每个vid的范围

4. **时间轴一致性**
   - 恢复后的时间轴与删除前一致
   - 所有vid的相对位置保持不变

### 示例说明

假设合并后的文件包含2个vid：
```
删除前：vid01(1000点) + vid02(1000点) = 2000点
删除后：vid01(800点) + vid02(900点) = 1700点

删除时间段记录：
  [150, 250]   <- vid01内的删除段（100点）
  [1100, 1200] <- vid02内的删除段（100点）

恢复后：
  - 位置150-250恢复为NaN（vid01的删除段）
  - 位置1100-1200恢复为NaN（vid02的删除段）
  - vid01和vid02的边界通过事件标记确定
  - 总长度恢复为2000点
```

## 输出文件特征

恢复后的文件具有以下特征：

1. **数据长度**: 原始长度（删除前）
2. **NaN区域**: 对应RELAX删除的极端噪声时间段
3. **有效数据**: 未删除的时间段保持原始数据
4. **事件时间**: 已调整到恢复后的时间轴
5. **vid标记**: 位置已调整，仍然标记每个vid的开始

## 后续分析建议

恢复后的数据适合以下分析：

1. **保持时间完整性**: 如需要完整的时间轴（如时频分析）
2. **跨vid分析**: 可以正确处理vid边界
3. **事件相关分析**: 事件时间已正确调整
4. **质量控制**: NaN区域标记了噪声时间段

## 注意事项

1. **NaN处理**: 后续分析需要能处理NaN值
2. **内存占用**: 恢复后文件会比删除后文件大
3. **处理时间**: 大文件可能需要较长处理时间
4. **备份数据**: 建议保留原始合并文件作为备份

## 验证方法

处理完成后，可以通过以下方式验证：

```matlab
% 加载恢复后的文件
EEG = pop_loadset('sub001_RELAX_merged_restored.set');

% 检查基本信息
fprintf('数据长度: %d 采样点\n', EEG.pnts);
fprintf('NaN数量: %d\n', sum(isnan(EEG.data(:))));
fprintf('非NaN数量: %d\n', sum(~isnan(EEG.data(:))));

% 检查合并信息
disp(EEG.merged_info);

% 检查vid事件
vid_events = [];
for i = 1:length(EEG.event)
    if isfield(EEG.event(i), 'vid')
        vid_events(end+1) = EEG.event(i).vid;
    end
end
fprintf('包含的vid: [%s]\n', num2str(unique(vid_events)));
```

## 相关脚本

- `restore_deleted_periods_tongyong.m`: 恢复单个vid文件的删除时间段
- `merge_vid_files_by_subject.m`: 合并同一被试的所有vid文件
- `extract_vid_from_merged_file.m`: 从合并文件中提取特定vid

## 作者信息

- 创建日期: 2025-11-29
- 基于: restore_deleted_periods_tongyong.m
- 适配: 处理合并后的文件格式
