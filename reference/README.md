# reference/ — 原始参考代码（只读归档）

本目录保留**未被配置化改写**的原始参考，便于对照论文与实验1实现。  
**日常换数据请跑仓库根目录的 `main.m`（功能流水线），不要改这里的绝对路径脚本当生产入口。**

## 内容

| 路径 | 含义 |
|---|---|
| `RELAX-v2.0.0/` | Bailey 等开源 **RELAX v2** 工具箱快照（与 `external/RELAX-RELAX-v2.0.0` 同源） |
| `experiment1/` | Tongyong / **实验1** 参考工程：官方风格参数脚本 + `code1/2/3`（BDF→SET、问题数据、合并） |
| `experiment1/RELAX_使用说明_Tongyong.md` | 实验1 使用说明（推荐入口曾为 `RELAX_SET_PARAMETERS_AND_RUN.m`） |
| `experiment1/code1/` | `process_tongyong_bdf_to_relax_input`、切段、vid 对齐、restore 坏段长度等 |
| `final_task_scripts/` | 你后期定稿的电影/交流任务脚本原文（含 `*_FIXED.m`、`process_*`、`merge_*`） |
| `docs/` | 新预处理阶段的中文说明（最终执行指南、参数说明、验证报告、指标清单） |

## 与功能流水线的关系

- **算法**：功能流水线 `step2` 调用的是 `external/` 里同一套 `RELAX_Wrapper`（官方删除极端坏段行为）。
- **工程**：功能流水线把 `final_task_scripts` + `experiment1/code1` 收成 `src/step1–3` + `config_default.m`，去掉本机绝对路径。
- **长度对齐**：实验1 `code1` 中的 `restore_deleted_periods_*.m` 仍放在 reference / `src/utils`，需要等长时再显式调用，不默认改 Wrapper。

## 如何仅“按参考原样”跑（不推荐新数据）

见 `experiment1/RELAX_使用说明_Tongyong.md`；需自行改脚本内路径，或改用根目录功能流水线。
