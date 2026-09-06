function cfg = config_default()
% CONFIG_DEFAULT  RELAX 功能流水线全部参数（换数据主要改这里）

cfg = struct();

%% 路径
cfg.paths.root       = fileparts(mfilename('fullpath'));
cfg.paths.dataRoot   = fullfile(cfg.paths.root, 'data');
cfg.paths.outputRoot = fullfile(cfg.paths.root, 'output');
cfg.paths.capFile    = fullfile(cfg.paths.root, 'resources', 'standard_1005.elc');

%% 任务与数据约定
% data/<taskName>/<subID>/ 下放置 data.bdf（及 data.1.bdf…）与 rating CSV
% 也可使用嵌套：data/<taskName>/<subID>/<taskFolderName>/data.bdf （兼容旧「电影/交流」布局）
cfg.task.name           = 'movie';     % 输出子目录名，可改为 communication 等
cfg.task.folderName     = '';         % 若非空，则在被试目录下再进这一层（如 '电影'/'交流'）
cfg.task.csvPattern     = 'rating';    % 被试目录（或量表旁路）中 CSV 文件名特征
cfg.task.orderColumn    = 'videoIndex';% 视频编号列名；CSV 若无此列，自动回退 vid -> 第一列
cfg.task.subjects       = 'all';      % 'all' 或编号 cell/数值向量

%% 分段 trigger（换数据时在这里改：默认 21 开始，22 结束）
cfg.segment.startTrigger = 21;
cfg.segment.endTrigger   = 22;
% 多 BDF / 事件稳健性（对齐 multi-bdf 预处理经验）
cfg.segment.preferEvtBdf = true;          % 有 evt.bdf 时优先用其绝对时间事件（避免分文件 T0 乱）
cfg.segment.stripImpedance = true;        % 删除 Start/Stop Impedance 后继续，不因此拒被试
cfg.segment.pairMode = 'adjacent';        % 'adjacent'=21后紧跟22；'end_anchor'=以22向前取固定时长
cfg.segment.fallbackToEndAnchor = true;   % 21/22 数量不一致或配对为空时，自动回退 end_anchor
cfg.segment.endAnchorDurationSec = 30;    % end_anchor 向前取的秒数（需与任务段时长匹配）

%% RELAX 清洁参数（对齐定稿 FIXED 脚本）
cfg.relax.HighPassFilter = 1;
cfg.relax.LowPassFilter  = 47;
cfg.relax.LineNoiseFrequency = 50;
cfg.relax.DownSample = 'yes';
cfg.relax.DownSample_to_X_Hz = 250;
cfg.relax.Do_MWF_Once = 1;
cfg.relax.Do_MWF_Twice = 1;
cfg.relax.Do_MWF_Thrice = 1;
cfg.relax.Perform_wICA_on_ICLabel = 1;
cfg.relax.Perform_ICA_subtract = 0;
cfg.relax.ICA_method = 'picard';
cfg.relax.Report_all_ICA_info = 'no';
cfg.relax.computerawmetrics = 1;
cfg.relax.computecleanedmetrics = 1;
cfg.relax.saveround1 = 0;
cfg.relax.saveround2 = 0;
cfg.relax.saveround3 = 0;
cfg.relax.InterpolateRejectedElectrodesAfterCleaning = 'yes';
cfg.relax.ElectrodesToDelete = {};
% 极端坏段：'delete' = 官方 eeg_eegrej；长度对齐请用 reference 中 restore 工具另做
cfg.relax.extremeBadMode = 'delete';
cfg.relax.RestoreDeletedPeriodsAsNaN = 0; % 0=官方删除后直接保存；1=Wrapper 内尝试 NaN 填回（不推荐，易因长度不一致失败）
% 非任务段剔除（对齐定稿 FIXED；默认关闭，仅打开 RejNontask 时生效）
cfg.relax.RejNontask = false;
cfg.relax.minimum_break_length = 2000;
cfg.relax.break_ignore_codes = setdiff(1:160, [60 61 62 63 64 65 66 67 142 143 144 145 160 200]);
cfg.relax.break_buffer = 1500;

%% 合并选项（step3；对齐定稿 merge_*_postrelax.m 的行为）
cfg.merge.padMissingVid     = false;  % 缺 vid 时是否用 NaN 段占位（需同时设 vidRange）
cfg.merge.vidRange          = [];     % 完整 vid 范围，如 1:28；[] = 只合并已有 vid
cfg.merge.padDurationSec    = 30;     % 占位 NaN 段时长（秒）
cfg.merge.addVidMarkerEvent = true;   % 每段开头加 vidXX 标记事件，便于后续按 vid 提取
cfg.merge.method            = 'pop_mergeset'; % 'pop_mergeset' 或 'concat'（定稿手工拼接）

%% 流程开关
cfg.pipeline.doStep1 = true;
cfg.pipeline.doStep2 = true;
cfg.pipeline.doStep3 = true;
cfg.pipeline.skipExisting = true;

%% 方案 B：整段清洁，后切分（clean-then-segment）
% 设为 true 时启用 Mode B：step1 不切段直接转整段 set，RELAX 只标记坏段不删除，
% step3 按 BAD_segment 事件 + 21/22 trigger 切分并剔除坏段。
cfg.pipeline.cleanThenSegment = false;
% Mode B 专用输出目录（避免与 Mode A 混淆）
cfg.pipeline.modeB_outputSuffix = '_modeB';
% Mode B 切分时是否剔除 BAD_segment 覆盖的试次（true=剔除，false=保留但标记）
cfg.pipeline.modeB_rejectBadEpochs = true;

end
