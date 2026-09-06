% MAIN  RELAX 功能流水线入口（可迁移复现版）
%
% 仓库同时包含：
%   reference/  —— 原始参考代码（官方 RELAX + 实验1 Tongyong 实现）
%   src/        —— 本入口调用的功能流水线（配置化、可换数据）
%
% 用法：cd 到本目录后运行 main

clear; clc; close all;

setup();
cfg = config_default();

t0 = tic;
if cfg.pipeline.cleanThenSegment
    % Mode B: 整段清洁，后切分
    if cfg.pipeline.doStep1
        fprintf('\n========== STEP 1B: BDF -> SET (whole) ==========\n');
        step1b_whole_bdf_to_set(cfg);
    end
    if cfg.pipeline.doStep2
        fprintf('\n========== STEP 2B: RELAX cleaning (mark-only) ==========\n');
        step2b_relax_clean_whole(cfg);
    end
    if cfg.pipeline.doStep3
        fprintf('\n========== STEP 3B: Epoch after RELAX ==========\n');
        step3b_epoch_after_relax(cfg);
    end
else
    % Mode A: 先切分，后清洁（默认）
    if cfg.pipeline.doStep1
        fprintf('\n========== STEP 1: BDF -> SET (by vid) ==========\n');
        step1_bdf_to_set(cfg);
    end
    if cfg.pipeline.doStep2
        fprintf('\n========== STEP 2: RELAX cleaning ==========\n');
        step2_relax_clean(cfg);
    end
    if cfg.pipeline.doStep3
        fprintf('\n========== STEP 3: Merge by subject ==========\n');
        step3_merge_subjects(cfg);
    end
end
fprintf('\n完成，耗时 %.1f 分钟。输出: %s\n', toc(t0)/60, cfg.paths.outputRoot);
