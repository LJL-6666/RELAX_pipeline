%% 从合并后的文件中提取指定vid的视频段
% 
% 功能：从合并后的RELAX文件中提取指定vid的视频段
% 
% 输入：
%   - merged_file: 合并后的SET文件路径
%   - vid: 要提取的视频编号（1-28）
% 
% 输出：
%   - EEG_segment: 提取的视频段EEG数据
% 
% 使用示例：
%   EEG_seg = extract_vid_from_merged_file('sub001_RELAX_merged.set', 5);
% 
% Author: EEG Analysis Team
% Date: 2025-01-XX

function EEG_segment = extract_vid_from_merged_file(merged_file, vid)

% EEGLAB路径
eeglab_path = '/data/liujialing/eeglab-develop';
if exist(eeglab_path, 'dir')
    addpath(eeglab_path);
end

% 加载合并后的文件
if ischar(merged_file)
    EEG = pop_loadset('filename', merged_file);
else
    EEG = merged_file; % 如果直接传入EEG结构
end

% 查找指定vid的开始和结束位置
vid_start_sample = [];
vid_end_sample = [];

% 查找vid开始标记（优先检查videoIndex字段，然后检查vid字段，最后检查type字段）
for e = 1:length(EEG.event)
    event = EEG.event(e);
    
    % 检查videoIndex字段（原始SET文件中的字段）
    if isfield(event, 'videoIndex') && event.videoIndex == vid
        vid_start_sample = round(event.latency);
        break;
    end
    % 检查vid字段（合并时添加的字段）
    if isfield(event, 'vid') && event.vid == vid
        vid_start_sample = round(event.latency);
        break;
    end
    % 检查type字段
    if isfield(event, 'type')
        if strcmp(event.type, sprintf('vid%02d', vid)) || ...
           (strcmp(event.type, 'videoStart') && isfield(event, 'videoIndex') && event.videoIndex == vid)
            vid_start_sample = round(event.latency);
            break;
        end
    end
end

if isempty(vid_start_sample)
    error('未找到vid %d 的开始标记', vid);
end

% 查找下一个vid的开始位置（作为当前vid的结束位置）
next_vid_start = EEG.pnts + 1; % 默认到文件末尾
for e = 1:length(EEG.event)
    event = EEG.event(e);
    event_latency = round(event.latency);
    
    if event_latency > vid_start_sample
        % 检查videoIndex字段
        if isfield(event, 'videoIndex') && event.videoIndex > vid
            next_vid_start = event_latency;
            break;
        end
        % 检查vid字段
        if isfield(event, 'vid') && event.vid > vid
            next_vid_start = event_latency;
            break;
        end
        % 检查type字段
        if isfield(event, 'type')
            type_str = event.type;
            if length(type_str) >= 4 && strcmp(type_str(1:3), 'vid')
                next_vid_num = str2double(type_str(4:end));
                if ~isnan(next_vid_num) && next_vid_num > vid
                    next_vid_start = event_latency;
                    break;
                end
            end
        end
    end
end

vid_end_sample = next_vid_start - 1;

% 提取数据段
EEG_segment = pop_select(EEG, 'point', [vid_start_sample, vid_end_sample]);

% 调整事件latency（相对于新数据段的开始）
if ~isempty(EEG_segment.event)
    for e = 1:length(EEG_segment.event)
        EEG_segment.event(e).latency = EEG_segment.event(e).latency - vid_start_sample + 1;
    end
end

% 更新EEG结构
EEG_segment = eeg_checkset(EEG_segment);
EEG_segment.extracted_vid = vid;
EEG_segment.original_start_sample = vid_start_sample;
EEG_segment.original_end_sample = vid_end_sample;

fprintf('提取vid %d: 采样点 %d-%d (共 %d 采样点, %.2f 秒)\n', ...
    vid, vid_start_sample, vid_end_sample, ...
    EEG_segment.pnts, EEG_segment.pnts/EEG_segment.srate);

end

