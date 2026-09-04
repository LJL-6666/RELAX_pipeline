# 问题数据处理 - 多个BDF文件合并

## 问题描述

部分被试（18, 24, 26, 35, 36, 42）的原始数据被分割成多个BDF文件：
- `data.bdf` - 主文件（通常较小，只包含头信息）
- `data.1.bdf` - 第一个数据段
- `data.2.bdf` - 第二个数据段（如果存在）
- ...

这些文件需要合并后才能正确提取视频段和进行后续处理。

## 解决方案

本目录包含专门处理多个BDF文件的代码：

1. **`merge_multiple_bdf_and_process.m`** - 主脚本
   - 自动检测并合并多个BDF文件
   - 提取视频段
   - 按vid对齐并转换为SET格式

2. **`extract_video_segments_from_multiple_bdf.m`** - 从多个BDF文件提取视频段
   - 使用FieldTrip的cell数组功能自动合并多个文件
   - 提取trigger 21/22配对

3. **`align_by_vid_and_convert_to_set_multiple_bdf.m`** - 对齐并转换（支持多文件）
   - 从合并后的数据中提取视频段
   - 转换为SET格式

## 使用方法

在MATLAB中运行：

```matlab
cd('/data/liujialing/TY/预处理/matlab/实验1/code1/问题数据处理');
run('merge_multiple_bdf_and_process.m');
```

或者在命令行中运行：

```bash
cd /data/liujialing/TY/预处理/matlab/实验1/code1/问题数据处理
matlab -batch "run('merge_multiple_bdf_and_process.m')"
```

## 处理流程

1. **检测BDF文件**：自动查找 `data*.bdf` 文件并按顺序排序
2. **合并文件**：使用FieldTrip的cell数组功能自动合并
3. **提取视频段**：从合并后的数据中提取trigger 21/22配对
4. **读取vid信息**：从问卷CSV读取视频编号
5. **按vid排序**：确保所有被试对齐
6. **转换为SET**：生成对齐后的SET文件

## 输出

- **输出目录**：`data/data-tongyong/原始数据/可用原始数据/转化成set的脑电_aligned/`
- **文件命名**：`sub{ID}_vid{VID}.set`（例如：`sub018_vid01.set`）
- **文件格式**：EEGLAB SET格式

## 注意事项

1. **文件顺序**：代码会自动按自然顺序排序（data.bdf, data.1.bdf, data.2.bdf），而不是字母顺序
2. **数据完整性**：合并后的数据总长度应该等于所有文件长度之和
3. **事件信息**：所有文件的事件信息会被合并，采样点会自动调整到合并后的时间轴上

## 问题被试列表

- 被试 18：有 data.bdf, data.1.bdf, data.2.bdf
- 被试 24：有 data.bdf, data.1.bdf
- 被试 26：有 data.bdf, data.1.bdf
- 被试 35：有 data.bdf, data.1.bdf, data.2.bdf
- 被试 36：有 data.bdf, data.1.bdf, data.2.bdf
- 被试 42：有 data.bdf, data.1.bdf

## 技术细节

### FieldTrip多文件支持

FieldTrip支持通过传入cell数组来自动合并多个文件：

```matlab
bdf_files = {'data.bdf', 'data.1.bdf', 'data.2.bdf'};
hdr = ft_read_header(bdf_files);  % 自动合并
data = ft_read_data(bdf_files, 'header', hdr, ...);  % 从合并后的数据读取
```

### 采样点映射

合并后的采样点会自动映射：
- 文件1：采样点 1 到 n1
- 文件2：采样点 n1+1 到 n1+n2
- 文件3：采样点 n1+n2+1 到 n1+n2+n3
- ...

事件中的采样点会自动调整到合并后的时间轴上。

