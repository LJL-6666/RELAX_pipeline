% SMOKE_TEST_MODEB  Mode B（整段清洁后切分）端到端冒烟测试
% 数据：data/modeB_smoke/000/（硬链接自 Fcaed sub000，28 段，trigger 101/102）
% 用法：cd RELAX_pipeline; smoke_test_modeB
%
% 注意：main.m 内部会 clear 并重新 config_default()，所以这里不复用 main，
% 而是按 main 的 Mode B 分支逐步调用，以便注入测试配置。

setup();
cfg = config_default();

% Mode B 开关
cfg.pipeline.cleanThenSegment = true;
cfg.pipeline.modeB_rejectBadEpochs = true;

% 任务与被试
cfg.task.name = 'modeB_smoke';
cfg.task.subjects = {'000'};

% 本数据的 trigger：101=视频开始，102=视频结束（28 对）
cfg.segment.startTrigger = 101;
cfg.segment.endTrigger   = 102;

cfg.pipeline.doStep1 = true;
cfg.pipeline.doStep2 = true;
cfg.pipeline.doStep3 = true;
cfg.pipeline.skipExisting = false;

t0 = tic;
fprintf('\n========== STEP 1B: BDF -> SET (whole) ==========\n');
step1b_whole_bdf_to_set(cfg);
fprintf('\n========== STEP 2B: RELAX cleaning (mark-only) ==========\n');
step2b_relax_clean_whole(cfg);
fprintf('\n========== STEP 3B: Epoch after RELAX ==========\n');
step3b_epoch_after_relax(cfg);
fprintf('\n完成，耗时 %.1f 分钟。输出: %s\n', toc(t0)/60, cfg.paths.outputRoot);
