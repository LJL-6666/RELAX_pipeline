% 恢复删除时间段为NaN - data-tongyong数据集
% 从Cleaned_Data读取单个视频段文件，恢复删除时间段为NaN，保存到Cleaned_Data-3
%
% 输入：data/data-tongyong/Cleaned_Data/*_RELAX.set
% 输出：data/data-tongyong/Cleaned_Data-3/*_restored.set

clear; clc;

% 设置路径
base_dir = '<DATA_ROOT>';
input_dir = fullfile(base_dir, 'data/data-tongyong/Cleaned_Data');
output_dir = fullfile(base_dir, 'data/data-tongyong/Cleaned_Data-3');

% 创建输出目录
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

% 添加EEGLAB路径
if ~exist('eeglab', 'file')
    addpath('<EEGLAB_ROOT>');
    eeglab('nogui');
end

fprintf('============================================================\n');
fprintf('恢复删除时间段为NaN - data-tongyong数据集\n');
fprintf('============================================================\n');
fprintf('输入目录: %s\n', input_dir);
fprintf('输出目录: %s\n\n', output_dir);

% 获取所有_RELAX.set文件
files = dir(fullfile(input_dir, '*_RELAX.set'));
if isempty(files)
    error('未找到任何_RELAX.set文件');
end

fprintf('找到 %d 个文件\n\n', length(files));

success_count = 0;
skip_count = 0;
error_count = 0;

% 遍历所有文件
for i = 1:length(files)
    input_filename = files(i).name;
    input_filepath = fullfile(input_dir, input_filename);
    
    fprintf('[%d/%d] 处理文件: %s\n', i, length(files), input_filename);
    
    try
        % 加载SET文件
        EEG = pop_loadset('filename', input_filename, 'filepath', input_dir);
        
        fprintf('  采样率: %.0f Hz\n', EEG.srate);
        fprintf('  当前数据长度: %d 采样点 (%.2f秒)\n', EEG.pnts, EEG.pnts/EEG.srate);
        fprintf('  通道数: %d\n', EEG.nbchan);
        
        % 检查是否有RELAX字段和删除时间段信息
        bad_periods = [];
        if isfield(EEG, 'RELAX') && isfield(EEG.RELAX, 'ExtremelyBadPeriodsForDeletion')
            bad_periods = EEG.RELAX.ExtremelyBadPeriodsForDeletion;
        end
        
        if isempty(bad_periods) || size(bad_periods, 1) == 0
            fprintf('  警告: 未找到删除时间段信息，直接复制文件\n');
            % 如果没有删除时间段，直接复制并重命名
            output_filename = strrep(input_filename, '_RELAX.set', '_restored.set');
            output_filepath = fullfile(output_dir, output_filename);
            pop_saveset(EEG, 'filename', output_filename, 'filepath', output_dir);
            fprintf('  ✓ 已复制文件: %s\n', output_filename);
            skip_count = skip_count + 1;
            continue;
        end
        
        fprintf('  删除时间段数: %d\n', size(bad_periods, 1));
        
        % 计算删除的总长度
        total_deleted = 0;
        for j = 1:size(bad_periods, 1)
            total_deleted = total_deleted + (bad_periods(j, 2) - bad_periods(j, 1) + 1);
        end
        
        original_length = EEG.pnts + total_deleted;
        fprintf('  删除总长度: %d 采样点 (%.2f秒)\n', total_deleted, total_deleted/EEG.srate);
        fprintf('  估计原始长度: %d 采样点 (%.2f秒)\n', original_length, original_length/EEG.srate);
        
        % 恢复删除时间段
        % 创建恢复后的数据矩阵（通道数 x 原始长度），初始化为NaN
        restored_data = NaN(EEG.nbchan, original_length);
        
        % 按顺序处理删除时间段（按起始位置排序）
        sorted_periods = sortrows(bad_periods, 1);
        
        % 将删除后的数据映射回删除前的位置
        % 删除后的数据位置
        data_pos = 1;
        
        % 遍历删除前的每个位置
        for orig_pos = 1:original_length
            % 检查当前位置是否在删除时间段内
            is_deleted = false;
            for j = 1:size(sorted_periods, 1)
                if orig_pos >= sorted_periods(j, 1) && orig_pos <= sorted_periods(j, 2)
                    is_deleted = true;
                    break;
                end
            end
            
            if ~is_deleted
                % 不在删除时间段内，从删除后的数据中复制
                if data_pos <= EEG.pnts
                    restored_data(:, orig_pos) = EEG.data(:, data_pos);
                    data_pos = data_pos + 1;
                end
            end
            % 如果在删除时间段内，保持NaN（已在初始化时设置）
        end
        
        % 更新EEG结构
        EEG.data = restored_data;
        EEG.pnts = size(restored_data, 2);
        EEG.xmax = (EEG.pnts - 1) / EEG.srate;
        EEG.times = (0:EEG.pnts-1) / EEG.srate * 1000;
        
        % 更新事件时间（如果有事件）
        if ~isempty(EEG.event)
            for e = 1:length(EEG.event)
                % 计算事件在恢复后的数据中的位置
                original_latency = EEG.event(e).latency;
                
                % 计算在original_latency之前删除了多少采样点
                deleted_before = 0;
                for j = 1:size(sorted_periods, 1)
                    if sorted_periods(j, 2) < original_latency
                        deleted_before = deleted_before + (sorted_periods(j, 2) - sorted_periods(j, 1) + 1);
                    elseif sorted_periods(j, 1) <= original_latency && sorted_periods(j, 2) >= original_latency
                        % 事件在删除时间段内，标记为NaN或删除
                        deleted_before = deleted_before + (original_latency - sorted_periods(j, 1) + 1);
                        break;
                    end
                end
                
                new_latency = original_latency + deleted_before;
                EEG.event(e).latency = new_latency;
            end
        end
        
        fprintf('  恢复后数据长度: %d 采样点 (%.2f秒)\n', EEG.pnts, EEG.pnts/EEG.srate);
        
        % 保存恢复后的文件
        output_filename = strrep(input_filename, '_RELAX.set', '_restored.set');
        output_filepath = fullfile(output_dir, output_filename);
        pop_saveset(EEG, 'filename', output_filename, 'filepath', output_dir);
        fprintf('  ✓ 已保存: %s\n', output_filename);
        
        success_count = success_count + 1;
        
    catch ME
        fprintf('  ✗ 错误: %s\n', ME.message);
        error_count = error_count + 1;
        continue;
    end
    
    fprintf('\n');
end

fprintf('============================================================\n');
fprintf('处理完成\n');
fprintf('成功: %d 个文件\n', success_count);
fprintf('跳过（无删除时间段）: %d 个文件\n', skip_count);
fprintf('错误: %d 个文件\n', error_count);
fprintf('总计: %d 个文件\n', length(files));
fprintf('============================================================\n');

