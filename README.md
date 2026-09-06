# RELAX_pipeline

MATLAB 端到端 **EEG 自动去伪迹** 流水线：Neuracle BDF → 按视频编号对齐的 `.set` → **RELAX v2** 清洁 → 按被试合并，并输出 SER/ARR 等质量指标。

本仓库**同时包含**：

1. **`reference/`** — 原始参考代码（官方 RELAX + 实验1 Tongyong 实现 + 定稿任务脚本原文 + 文档）  
2. **`src/` + `main.m`** — 可迁移的功能流水线（唯一推荐入口；换数据只改 `data/` 与 `config_default.m`）

依赖（EEGLAB / FieldTrip / RELAX / MWF / ICLabel 等）已放在 `external/`。

---

## 方法摘要

| 步骤 | 功能流水线 | 做什么 |
|---|---|---|
| 1 | `step1_bdf_to_set` | 读 BDF，按起止 trigger（默认 21/22，可在 config 更换）切段，用 rating CSV 的 `videoIndex` 列对齐，写出 `subXXX_vidYY.set` |
| 2 | `step2_relax_clean` | 批处理调用官方 `RELAX_Wrapper`（滤波、坏道、MWF×3、极端段处理、ICA/wICA、指标） |
| 3 | `step3_merge_subjects` | 同被试各 vid 合并为 `subXXX_RELAX_merged.set`（可选缺 vid NaN 占位、vid 标记事件） |

**Mode B（整段清洁，后切分）**：设 `cfg.pipeline.cleanThenSegment = true` 后，流程变为：

| 步骤 | 功能流水线 | 做什么 |
|---|---|---|
| 1B | `step1b_whole_bdf_to_set` | 读 BDF 为整段连续 `.set`，保留全部事件（含 21/22 trigger） |
| 2B | `step2b_relax_clean_whole` | RELAX 清洁整段数据，**只标记坏段为 `BAD_segment` 事件，不物理删除** |
| 3B | `step3b_epoch_after_relax` | 按 21/22 trigger 切分，剔除与 `BAD_segment` 重叠的段，按 vid 写出 |

默认滤波 1–47 Hz、工频 50 Hz、降采样 250 Hz；极端坏段为官方 **删除** 行为。若需等长时间轴，使用 `reference/experiment1/code1`（或 `src/utils`）中的 `restore_deleted_periods_*.m`。

---

## 快速开始（功能流水线）

```matlab
cd RELAX_pipeline
% 编辑 config_default.m：任务名、CSV 特征、是否嵌套任务文件夹等
main
```

### 数据摆放

```text
data/<taskName>/<subID>/
  ├─ data.bdf          （可有 data.1.bdf, data.2.bdf…）
  ├─ evt.bdf           （可选）
  └─ *rating*.csv      （含 videoIndex 或 vid 列）
```

若原始结构是「被试 / 电影 / data.bdf」，设：

```matlab
cfg.task.name = 'movie';
cfg.task.folderName = '电影';   % 或 '交流'
```

---

## 换数据要改什么（都集中在 `config_default.m`）

| 新数据的情况 | 改哪一项 | 示例 |
|---|---|---|
| 起止 trigger 不是 21/22 | `cfg.segment.startTrigger` / `cfg.segment.endTrigger` | 如听觉 block：`= 31; = 32;` |
| 多 BDF（data.bdf + data.1.bdf…） | 自动处理；有 `evt.bdf` 优先用 | 见下「多 BDF」 |
| CSV 中视频编号列不叫 `videoIndex` | `cfg.task.orderColumn` | `= 'stimID';`（若无此列自动回退 `vid` → 第一列） |
| CSV 文件名特征不同 | `cfg.task.csvPattern` | `= 'questionnaire';` |
| 数据在「被试/任务子文件夹」下 | `cfg.task.folderName` | `= '电影';` |
| 只跑部分被试 | `cfg.task.subjects` | `= {'001','002'};` 或 `= [1 2];` |
| 采样率/滤波不同 | `cfg.relax.DownSample_to_X_Hz`、`HighPassFilter`、`LowPassFilter`、`LineNoiseFrequency` | 欧标 50 Hz → 60 Hz 改 `LineNoiseFrequency = 60` |
| 合并时要和定稿一致（缺 vid 补 NaN、保留 vid 事件） | `cfg.merge.*` | 见下 |
| 剔除任务外长休息段 | `cfg.relax.RejNontask = true` 及 `minimum_break_length` / `break_ignore_codes` / `break_buffer` | 默认关闭；需 ERPLAB |
| 启用 CRAP 连续伪迹检测 | `cfg.relax.RejCrap = true` 及 `crapThreshold` / `crapWindowSize` / `crapWindowStep` / `crapNumChanThreshold` | 默认关闭（对齐定稿 FIXED）；需 ERPLAB；Mode A 物理删除，Mode B 标记合并 |
| 启用整段清洁模式（Mode B） | `cfg.pipeline.cleanThenSegment = true` | 见下「Mode B」 |

### Mode B：整段清洁，后切分

```matlab
cfg.pipeline.cleanThenSegment = true;       % 启用 Mode B
cfg.pipeline.modeB_badSegmentHandling = 'reject';  % 坏段处理：'reject'整段剔除 | 'keep'保留+标记 | 'trim'只删坏段区间（对齐参考实现）
```

Mode B 流程：
1. `step1b`：BDF → 整段连续 `.set`（保留全部事件）
2. `step2b`：RELAX 清洁整段，坏段标记为 `BAD_segment` 事件（不删除）
3. `step3b`：按 21/22 trigger 切分，按 `modeB_badSegmentHandling` 处理坏段，按 vid 写出

适用场景：需要整场共享伪迹模型（MWF/ICA 更充分）、或后续分析需要完整时间轴对齐。

step3b 坏段处理三档对比：

| 选项 | 行为 | 段长 | 数据利用率 |
|---|---|---|---|
| `'reject'`（默认） | 重叠即整段剔除 | 保持 trigger 间隔，跨被试一致 | 最低 |
| `'keep'` | 整段保留 + `BAD_segment_overlap` 标记 | 保持 trigger 间隔 | 最高（下游自行裁决） |
| `'trim'` | `eeg_eegrej` 只删坏段区间（与参考实现 MD 一致） | 变短，跨被试不一 | 中等 |

### 合并选项（对齐定稿 `merge_*_postrelax.m`）

```matlab
cfg.merge.padMissingVid     = true;   % 缺 vid 用 NaN 段占位
cfg.merge.vidRange          = 1:28;   % 本任务的完整 vid 范围
cfg.merge.addVidMarkerEvent = true;   % 每段开头加 vidXX 事件（后续可再按 vid 提取）
cfg.merge.method            = 'concat'; % 定稿脚本的手工拼接方式
```

默认（`padMissingVid=false`, `method='pop_mergeset'`）为「有啥合啥」的 EEGLAB 合并，适合 vid 齐全的数据。

### 多 BDF（`data.bdf` / `data.1.bdf` / …）

采集被拆成多个文件时，step1 会：

1. 按 `data.bdf → data.1.bdf → data.2.bdf` 排序拼接（FieldTrip cell 合并）  
2. **优先读同目录 `evt.bdf` 的整段绝对时间事件**（避免分文件 T0 / interval 乱）  
3. **删除** `Start Impedance` / `Stop Impedance` 等分界标记后继续，**不因此拒被试**  
4. 默认 `21` 后紧跟 `22` 配对；若数量不一致或配对为空，自动以 `22` 为锚点向前取 `endAnchorDurationSec` 秒  
5. 写出 `.set` 时用多文件对齐函数，**不会只读第一个 data.bdf**

相关开关在 `cfg.segment`（`preferEvtBdf` / `stripImpedance` / `pairMode` / `fallbackToEndAnchor` / `endAnchorDurationSec`）。

### 输出

**Mode A（默认，先切再清洁）：**

```text
output/
  set_by_vid/<task>/           % step1
  relax/<task>/RELAXProcessed/ % step2：Cleaned_Data + metrics
  merged/<task>/               % step3
```

**Mode B（整段清洁，后切分）：**

```text
output/
  set_whole/<task>/                % step1b：整段连续 set
  relax_whole/<task>/RELAXProcessed/ % step2b：Cleaned_Data（含 BAD_segment 事件）+ metrics
  epochs_by_vid/<task>/            % step3b：按 vid 切分后的 set
```

---

## 先切再清洁 vs 先清洁再切：结果影响大吗？

本仓库**默认是 A：先按 vid 切开，再对每个短连续段跑 RELAX**（与定稿 `*_FIXED.m` 一致）。  
**Mode B（先清洁再切）已实现**：设 `cfg.pipeline.cleanThenSegment = true` 即可启用。

| | A 先切再清洁（默认） | B 先清洁再切（Mode B） |
|---|---|---|
| 清洁上下文 | 单个 vid（短） | 整场（长） |
| 伪迹模型 | 各段独立 | 整场共享 |
| MWF / ICA | 短段可能略不稳 | 通常更充分 |
| 刺激隔离 | 强 | 弱（可能互相影响） |
| 坏段处理 | 清洁时物理删除，长度变短 | 清洁时只标记 `BAD_segment`，长度不变；切分时再剔除 |
| 与定稿 / 当前仓 | 一致 | 新增可选模式 |

**Mode B 关键特性**（已对齐参考实现的自定义策略）：
- RELAX 清洁过程中，极端坏段/CRAP 段**不物理删除**，而是写入 `BAD_segment` 事件
- **CRAP 合并**：开启 `RejCrap` 时，CRAP 标记段会合并进官方极端坏段标记（NaN mask + 待剔除列表），之后 MWF 模板屏蔽走官方流程
- **CRAP 排除出检测统计**：与 CRAP 重叠的 epoch 不参与坏导/极端值检测的中位数/MAD/峰度/漂移等稳健统计（对齐参考实现的 `is_crap_epoch` 做法，避免巨大伪迹抬高检测阈值）
- **copy-prune-back-copy**：wICA 前在删除坏段的**临时副本**上计算 ICA 权重，再复制回连续数据做 wICA——坏段不污染 ICA 分解（目前支持 `ICA_method='picard'`，其他方法会警告并回退）
- 数据长度保持不变，事件时间轴与原始 BDF 一致
- step3b 切分时按 `cfg.pipeline.modeB_badSegmentHandling` 处理坏段：`'reject'` 整段剔除（默认）/ `'keep'` 保留+标记 / `'trim'` 只删坏段区间（与参考实现一致）
- 多 BDF 逻辑自洽：整段读取时优先用 `evt.bdf` 事件，切分时用同一套 trigger 配对逻辑

**结果影响会不会大？**  
会有差别，有时还不小：同一被试同一视频，波形、删段后长度、眨眼/肌电残留、SER/ARR 都可以不同。  
差别大小取决于数据长短、伪迹多少、ICA 是否充分——**不能假定两种预处理可互换**；发文章应固定一种并写清。若要量化，需对同一批数据跑 A/B 对照（看 SER/ARR、眨眼比、下游 TRF/ERP）。

---

## 清洁前后比对指标（RELAX 自动产出）

step2 在 `output/relax/<task>/RELAXProcessed/` 写出（并嵌入每个 `*_RELAX.set`）：

### 最常用的前后对比

| 指标 | 含义 | 怎么看 |
|---|---|---|
| **All_SER**（Signal to Error Ratio） | 信号相对误差 | 清洁后越高越好（保留神经信号） |
| **All_ARR**（Artifact to Residue Ratio） | 伪迹相对残留 | 清洁后越高越好（伪迹清得干净） |
| **BlinkAmplitudeRatio** | 眨眼相关幅度比 | Raw vs Cleaned；清洁后应下降 |
| **MeanMuscleStrength…** | 超阈值肌电强度 | Raw vs Cleaned；清洁后应下降 |
| **ProportionOfEpochsShowingMuscle…** | 肌电污染 epoch 比例 | Raw vs Cleaned；清洁后应下降 |

汇总文件：

- `RawMetrics.mat` — 清洁前  
- `CleanedMetrics.mat` — 清洁后  

单文件内：

```matlab
EEG = pop_loadset('sub001_vid01_RELAX.set', '...');
EEG.RELAX_Metrics.Raw.*       % 清洁前
EEG.RELAX_Metrics.Cleaned.*   % 清洁后（含 All_SER / All_ARR 等）
```

### 其它质控（不是简单「前后一对数字」，但很重要）

| 文件 / 字段 | 内容 |
|---|---|
| `RELAX_issues_to_check.mat` | 删极过多、未检出眨眼、MWF 秩亏、数据可能太短做 ICA 等 |
| `RELAXProcessingExtremeRejectionsAllParticipants.mat` | 极端坏段 / 坏道拒绝统计 |
| `ProcessingStatisticsRoundOne/Two/Three.mat` | 各轮 MWF |
| `ProcessingStatistics_wICA.mat` | wICA / ICLabel 相关 |
| `RELAX_cfg.mat` | 本次完整参数 |

更细的字段说明见 [`reference/docs/RELAX输出指标清单.md`](reference/docs/RELAX输出指标清单.md)。

**注意：** 个别文件在算 SER/ARR 时可能失败（会警告但**仍保存**清洁 `.set`）。此时 `All_SER` / `All_ARR` 可能缺失，可看眨眼/肌电指标与 `RELAX_issues_to_check`。开关：`cfg.relax.computerawmetrics` / `computecleanedmetrics`（默认均为 1）。

---

## 原始参考怎么用

见 [`reference/README.md`](reference/README.md)。

| 想看什么 | 去哪 |
|---|---|
| 官方算法与 Wrapper | `reference/RELAX-v2.0.0/` 或 `external/RELAX-RELAX-v2.0.0/` |
| 实验1 完整说明与入口 | `reference/experiment1/RELAX_使用说明_Tongyong.md` |
| 定稿电影/交流原文 | `reference/final_task_scripts/` |
| 参数与执行备忘 | `reference/docs/` |

功能流水线与 `*_FIXED.m` 逻辑一致：一次 `RELAX_Wrapper` 批处理、关闭冗余 ICA 报告与中间 round 存盘。

---

## 环境

克隆后**不必再装插件**。`setup.m` 只使用仓库内相对路径（`fileparts(mfilename('fullpath'))`）。

| 组件 | 仓库位置 |
|---|---|
| MATLAB | 本机需已安装（建议 R2018b+，能跑 EEGLAB） |
| EEGLAB 2025.1.0（含 firfilt / dipfit / ICLabel 等 plugins） | `external/eeglab2025.1.0/` |
| FieldTrip 20181205 | `external/fieldtrip-20181205/` |
| RELAX v2 | `external/RELAX-RELAX-v2.0.0/` |
| MWF / PrepPipeline / ICLabel / PICARD / FastICA / Biosig / Neuracle reader | `external/` 对应子目录 |
| ERPLAB 12.20（可选；仅 `RejCrap` / `RejNontask` 需要） | `external/erplab12.20/` |
| 电极 | `resources/standard_1005.elc` |

**仍需自备：** 原始 EEG（`data/`，不入库）。没有数据时 `main` 无法端到端跑通，但依赖检查在 `setup` 即可完成。

本地冒烟（可选）：准备 `data/smoke/<subID>/` 后运行 `smoke_test`（step1 全量 + step2 仅 2 个文件 + step3）。若 step1 已完成可只跑 `smoke_continue_step23`。

`reference/` 为历史脚本，其中本机绝对路径已替换为 `<TASK_ROOT>` 等占位符；**新数据请只跑根目录 `main.m`。**

---

## 仓库里有什么 / 没有什么

**有：** 功能代码、原始参考、工具箱、README。  
**无：** 原始 BDF / 海量 `.set`（请自备 `data/`）。`data/` 与大体量 `output/` 默认 gitignore。

---

## 常见问题

**Q: 克隆后直接 main 报没有数据？**  
A: 正常。先按约定放入 `data/`，或先阅读 `reference/` 对照旧路径。

**Q: 和 mTRF_pipeline 什么关系？**  
A: 本仓做 RELAX 预处理；mTRF 仓做包络→TRF。可用本仓 `merged/*.set` 再进入后续分析。

**Q: 为什么 reference 和 external 都有 RELAX？**  
A: `reference` 便于文献级对照与实验1 脚本共存；`external` 供功能流水线稳定调用。以 `external` 为运行时版本。

**Q: 极端段 NaN 文档与官方删除不一致？**  
A: 功能流水线默认官方删除。等长需求用 restore 工具显式处理，避免静默改算法。

**Q: 先切再清洁和论文推荐的先清洁再切，结果差很多吗？**  
A: 可能有实质差别（见上文对照表）。默认 A 为与定稿一致；论文更贴近 B。两者不要混用后直接比下游结果。

**Q: 清洁有没有前后对比指标？**  
A: 有。优先看 `RawMetrics` / `CleanedMetrics` 里的 SER、ARR、眨眼比、肌电指标；详见上文「清洁前后比对指标」。

---

## 许可证与引用

- 本仓库功能流水线与整理脚本：MIT（见 `LICENSE`），不含改写官方算法版权声明。  
- RELAX：见 `external/RELAX-RELAX-v2.0.0` / 论文要求引用 Bailey et al. 2023（及所用 targeted wICA 时 2024 preprint）。  
- EEGLAB / FieldTrip / 其他第三方：遵守各自许可证（FieldTrip 等为 GPL 组件时，整体再分发请合规）。

请引用：

- Bailey, N. W., et al. (2023). Introducing RELAX… *Clinical Neurophysiology*.  
- Bailey, N. W., et al. (2023). RELAX part 2… *Clinical Neurophysiology*.  
- Oostenveld, R., et al. (2011). FieldTrip… *Computational Intelligence and Neuroscience*.
