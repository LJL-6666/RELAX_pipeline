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
cfg.task.orderColumn    = 'videoIndex';% 视频编号列（兼容 vid）
cfg.task.subjects       = 'all';      % 'all' 或编号 cell/数值向量

%% 分段 trigger（21 开始，22 结束）
cfg.segment.startTrigger = 21;
cfg.segment.endTrigger   = 22;

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

%% 流程开关
cfg.pipeline.doStep1 = true;
cfg.pipeline.doStep2 = true;
cfg.pipeline.doStep3 = true;
cfg.pipeline.skipExisting = true;

end
