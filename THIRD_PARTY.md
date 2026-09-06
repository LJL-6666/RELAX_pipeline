# 第三方组件清单

本仓库在 `external/` 下**随仓库分发**多个第三方工具箱，以保证流水线在任意机器上取得一致结果。
本文件说明每个组件的来源、许可、以及本仓库对其所做的改动与裁剪。

> 顶层 `LICENSE`（MIT）**只适用于本仓库自有代码**：`src/`、`main.m`、`setup.m`、
> `config_default.m`、`smoke_*.m`。`external/` 与 `reference/` 下的代码适用各自原许可，
> 其中含 GPL 组件——因此**本仓库整体的再分发受 GPL 条款约束**。

## 一、随仓库分发的组件

| 组件 | 版本 | 许可 | 上游 |
|---|---|---|---|
| EEGLAB | 2025.1.0 | GPL-2.0 | https://github.com/sccn/eeglab |
| FieldTrip | 见下方「二」 | GPL-3.0 | https://github.com/fieldtrip/fieldtrip |
| RELAX | v2.0.0 | GPL-3.0 | https://github.com/NeilwBailey/RELAX |
| ERPLAB | 12.20 | GPL-3.0 | https://github.com/ucdavis/erplab |
| Biosig | 3.8.4 | GPL-3.0 | https://biosig.sourceforge.net |
| MWF artifact removal | — | 见其 LICENSE | https://github.com/exporl/mwf-artifact-removal |
| PrepPipeline | — | BSD-3-Clause | https://github.com/VisLab/EEG-Clean-Tools |
| PICARD | 1.0 | BSD-3-Clause | https://github.com/pierreablin/picard |
| FastICA | 2.5 | GPL-2.0 | https://research.ics.aalto.fi/ica/fastica/ |
| Neuracle EEG File Reader | 1.2 | 厂商提供，随采集系统分发 | 博睿康 |

各组件的完整许可文本保留在其自身目录内（`COPYING` / `LICENSE`），未做改动。

## 二、对 vendored 组件的本地改动（重要）

`external/fieldtrip-20181205/` 这份副本**并非上游某个 tag 的原样拷贝**，已核实存在下列情况：

1. **一处功能性改动。** `ft_componentanalysis.m:513`

   ```matlab
   % 上游 2018-12-05 版本：
   optarg = [ft_cfg2keyval(cfg.runica) {'reset_randomseed' 0}];
   % 本副本：
   optarg = [ft_cfg2keyval(cfg.runica) {'rndreset' 'yes'}];
   ```

   该参数控制 ICA 的随机种子处理方式。**换回上游版本会改变 ICA 分解结果**，
   因而也会改变 RELAX 的 wICA / ICLabel 伪迹剔除结果。保留此副本是有意为之。

2. **快照日期与目录名不完全对应。** 目录名为 `fieldtrip-20181205`，但比对上游同日提交
   （`a078b9fe`）发现 `ft_channelrepair.m` 等文件存在差异（仅为换行排版，无功能影响），
   说明该快照实际早于 2018-12-05。**未核实其确切上游修订号。**

以上两点是本仓库不改用「自动下载上游工具箱」方案的原因：那样做会静默改变已产出的结果。

## 三、为控制体积而移除的内容

下列内容与本流水线（BDF 读取 → 分段 → RELAX 清洁 → 合并）无关，已从仓库及其历史中移除。
如需使用相关功能，请从上游获取对应工具箱的完整版本覆盖到 `external/` 下。

| 移除项 | 原因 |
|---|---|
| `fieldtrip/external/spm12/` | SPM12 的 MRI 模板与 DARTEL 工具箱，本流水线不做源定位 |
| `fieldtrip/template/anatomy,atlas,sourcemodel/` | 解剖模板与图谱，同上 |
| `fieldtrip/external/{ricoh,yokogawa}_meg_reader/` | **专有 EULA 组件，不可再分发** |
| `fieldtrip/external/{mffmatlabio,egi_mff}/` | EGI MFF 格式读取器（含 Java jar），本流水线读 BDF |
| `eeglab/plugins/dipfit/standard_{BEM,BESA}/` | 偶极子拟合头模型，本流水线不做源定位 |
| `eeglab/functions/supportfiles/head_modelColin27_*.mat` | 同上 |
| `eeglab/sample_data/`、`ICLabel/tests/` | 官方示例与测试数据 |
| `*/ica_linux` | binica 独立二进制；本流水线使用 `runica` |
| `external/ICLabel/`（独立副本） | 与 `eeglab/plugins/ICLabel/` 逐字节相同；代码引用的是后者 |
| `mwf-artifact-removal/.git_disabled/` | 误提交的 git 对象库 |
| `*.mexw32`、`*.mexglx`、`*.mexmac`、`*.mexmaci` | 32 位与 PowerPC 平台的预编译二进制 |
| 各处 `*.pdf` | 论文与手册 PDF，**不可再分发**；改为在 README 中给出引用 |

**保留**：`eeglab/plugins/ICLabel/netICL*.mat`（约 31 MB）——ICLabel 分类网络是流水线运行的必需品。

## 四、引用

使用本流水线产出结果时，请引用被实际调用的方法：

- Bailey, N. W., et al. (2023). Introducing RELAX: An automated pre-processing pipeline for cleaning EEG data — Part 1. *Clinical Neurophysiology*.
- Bailey, N. W., et al. (2023). RELAX — Part 2: ERPs. *Clinical Neurophysiology*.
- Delorme, A., & Makeig, S. (2004). EEGLAB. *Journal of Neuroscience Methods*.
- Oostenveld, R., et al. (2011). FieldTrip. *Computational Intelligence and Neuroscience*.
- Somers, B., Francart, T., & Bertrand, A. (2018). A generic EEG artifact removal algorithm based on the multi-channel Wiener filter. *Journal of Neural Engineering*.
- Pion-Tonachini, L., Kreutz-Delgado, K., & Makeig, S. (2019). ICLabel. *NeuroImage*.

论文本身请从出版方获取，本仓库不再分发 PDF。
