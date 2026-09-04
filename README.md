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
| 1 | `step1_bdf_to_set` | 读 BDF，按 trigger 21/22 切段，用 rating CSV 的 `videoIndex` 对齐，写出 `subXXX_vidYY.set` |
| 2 | `step2_relax_clean` | 批处理调用官方 `RELAX_Wrapper`（滤波、坏道、MWF×3、极端段处理、ICA/wICA、指标） |
| 3 | `step3_merge_subjects` | 同被试各 vid 合并为 `subXXX_RELAX_merged.set` |

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

### 输出

```text
output/
  set_by_vid/<task>/           % step1
  relax/<task>/RELAXProcessed/ % step2：Cleaned_Data + metrics
  merged/<task>/               % step3
```

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

| 组件 | 位置 |
|---|---|
| MATLAB | R2018b+ 建议；需能跑 EEGLAB |
| EEGLAB / FieldTrip / RELAX / MWF / ICLabel / PrepPipeline / PICARD / FastICA / Biosig | `external/` |
| 电极 | `resources/standard_1005.elc` |

`setup.m` 会 `addpath` 并做关键函数自检。

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

---

## 许可证与引用

- 本仓库功能流水线与整理脚本：MIT（见 `LICENSE`），不含改写官方算法版权声明。  
- RELAX：见 `external/RELAX-RELAX-v2.0.0` / 论文要求引用 Bailey et al. 2023（及所用 targeted wICA 时 2024 preprint）。  
- EEGLAB / FieldTrip / 其他第三方：遵守各自许可证（FieldTrip 等为 GPL 组件时，整体再分发请合规）。

请引用：

- Bailey, N. W., et al. (2023). Introducing RELAX… *Clinical Neurophysiology*.  
- Bailey, N. W., et al. (2023). RELAX part 2… *Clinical Neurophysiology*.  
- Oostenveld, R., et al. (2011). FieldTrip… *Computational Intelligence and Neuroscience*.
