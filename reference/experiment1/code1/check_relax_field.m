% 检查RELAX字段中的ExtremelyBadPeriodsForDeletion
clear; clc;

% 添加EEGLAB路径
if ~exist('eeglab', 'file')
    addpath('<EEGLAB_ROOT>');
    eeglab('nogui');
end

merged_dir = '<ALIGNED_SET_DIR>/RELAXProcessed/Cleaned_Data_Merged';

fprintf('检查 sub018_RELAX_merged.set\n\n');
EEG = pop_loadset('filename', 'sub018_RELAX_merged.set', 'filepath', merged_dir);

fprintf('数据长度: %d 采样点\n', EEG.pnts);
fprintf('采样率: %.0f Hz\n\n', EEG.srate);

% 检查RELAX字段
if isfield(EEG, 'RELAX')
    fprintf('RELAX字段列表:\n');
    relax_fields = fieldnames(EEG.RELAX);
    for i = 1:length(relax_fields)
        fprintf('  - %s\n', relax_fields{i});
    end
    fprintf('\n');

    % 检查是否有ExtremelyBadPeriodsForDeletion
    if isfield(EEG.RELAX, 'ExtremelyBadPeriodsForDeletion')
        bad_periods = EEG.RELAX.ExtremelyBadPeriodsForDeletion;
        fprintf('✓ 找到 ExtremelyBadPeriodsForDeletion\n');
        fprintf('  大小: %dx%d\n', size(bad_periods, 1), size(bad_periods, 2));
        fprintf('  前10个删除时间段:\n');
        for j = 1:min(10, size(bad_periods, 1))
            fprintf('    [%d] 起始=%d, 结束=%d, 长度=%d\n', ...
                j, bad_periods(j, 1), bad_periods(j, 2), bad_periods(j, 2) - bad_periods(j, 1) + 1);
        end

        total_deleted = 0;
        for j = 1:size(bad_periods, 1)
            total_deleted = total_deleted + (bad_periods(j, 2) - bad_periods(j, 1) + 1);
        end
        fprintf('\n  删除总长度: %d 采样点\n', total_deleted);
        fprintf('  估算原始长度: %d 采样点\n', EEG.pnts + total_deleted);
    else
        fprintf('✗ 未找到 ExtremelyBadPeriodsForDeletion\n');
    end
else
    fprintf('✗ 未找到 RELAX 字段\n');
end

fprintf('\n');
