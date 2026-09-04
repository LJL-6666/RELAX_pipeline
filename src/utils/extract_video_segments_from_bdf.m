function video_segments = extract_video_segments_from_bdf(data_bdf, evt_bdf, startTrig, endTrig)
% 从BDF文件中提取视频段（起止 trigger 配对，默认 21/22）
% 输入：
%   data_bdf: data.bdf文件路径
%   evt_bdf: evt.bdf文件路径（可选，如果为空则从data.bdf读取事件）
%   startTrig / endTrig: 段开始/结束 trigger 值（可选，默认 21 / 22）
% 输出：
%   video_segments: 结构体数组，包含字段：
%     - startSample: 开始采样点
%     - endSample: 结束采样点
%     - duration: 持续时间（秒）
%     - trial: 试次序号（从1开始）

if nargin < 3 || isempty(startTrig), startTrig = 21; end
if nargin < 4 || isempty(endTrig),   endTrig   = 22; end

video_segments = struct('startSample', {}, 'endSample', {}, 'duration', {}, 'trial', {});

if ~exist(data_bdf, 'file')
    error('BDF文件不存在: %s', data_bdf);
end

try
    % 使用FieldTrip读取头文件
    cfg = [];
    cfg.headerfile = data_bdf;
    hdr = ft_read_header(cfg.headerfile);
    fs = hdr.Fs;
    
    % 读取事件（从data.bdf读取）
    events = hdr.event;
    
    if isempty(events)
        warning('未找到事件信息');
        return;
    end
    
    % 清理空事件
    valid_events = [];
    for i = 1:length(events)
        if isfield(events{i}, 'eventvalue') && ~isempty(events{i}.eventvalue)
            valid_events(end+1) = i;
        end
    end
    events = events(valid_events);
    
    % 提取起止 trigger 的位置
    trigger_positions = [];
    for i = 1:length(events)
        if isnumeric(events{i}.eventvalue) && ...
           (events{i}.eventvalue == startTrig || events{i}.eventvalue == endTrig)
            % 计算采样点（使用offset_in_sec）
            if isfield(events{i}, 'offset_in_sec')
                sample = round(events{i}.offset_in_sec * fs);
            elseif isfield(events{i}, 'sample')
                sample = events{i}.sample;
            else
                continue;
            end
            trigger_positions(end+1, :) = [events{i}.eventvalue, sample];
        end
    end
    
    if isempty(trigger_positions)
        warning('未找到起止 trigger (%d/%d)', startTrig, endTrig);
        return;
    end
    
    % 按采样点排序
    [~, sort_idx] = sort(trigger_positions(:, 2));
    trigger_positions = trigger_positions(sort_idx, :);
    
    % 配对起止 trigger（start 后面紧跟 end）
    seg_count = 0;
    for i = 1:size(trigger_positions, 1)-1
        if trigger_positions(i, 1) == startTrig && trigger_positions(i+1, 1) == endTrig
            start_sample = trigger_positions(i, 2);
            end_sample = trigger_positions(i+1, 2);
            
            % 检查数据范围
            if end_sample > hdr.nSamples
                warning('段 %d 超出数据范围，跳过', seg_count + 1);
                continue;
            end
            
            % 添加到视频段列表
            seg_count = seg_count + 1;
            video_segments(seg_count).startSample = start_sample;
            video_segments(seg_count).endSample = end_sample;
            video_segments(seg_count).duration = (end_sample - start_sample) / fs;
            video_segments(seg_count).trial = seg_count;
        end
    end
    
    fprintf('  找到 %d 个视频段（trigger %d-%d 配对）\n', length(video_segments), startTrig, endTrig);
    
catch ME
    error('提取视频段失败: %s\n错误: %s', data_bdf, ME.message);
end

end

