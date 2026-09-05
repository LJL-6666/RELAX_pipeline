function video_segments = extract_video_segments_from_bdf(data_bdf, evt_bdf, startTrig, endTrig, segOpts)
% 从BDF文件中提取视频段（起止 trigger 配对，默认 21/22）
% 输入：
%   data_bdf: data.bdf文件路径
%   evt_bdf: evt.bdf文件路径（可选；优先用其绝对时间事件）
%   startTrig / endTrig: 段开始/结束 trigger（可选，默认 21 / 22）
%   segOpts: 可选，见 config_default.cfg.segment / collect_trigger_positions

if nargin < 2, evt_bdf = ''; end
if nargin < 3 || isempty(startTrig), startTrig = 21; end
if nargin < 4 || isempty(endTrig),   endTrig   = 22; end
if nargin < 5 || isempty(segOpts),   segOpts   = struct(); end

video_segments = struct('startSample', {}, 'endSample', {}, 'duration', {}, 'trial', {});

if ~exist(data_bdf, 'file')
    error('BDF文件不存在: %s', data_bdf);
end

try
    [trigger_positions, fs, nSamples] = collect_trigger_positions( ...
        data_bdf, evt_bdf, startTrig, endTrig, segOpts);
    if isempty(trigger_positions)
        warning('未找到起止 trigger (%d/%d)', startTrig, endTrig);
        return;
    end
    video_segments = pair_segments_from_triggers( ...
        trigger_positions, fs, nSamples, startTrig, endTrig, segOpts);
catch ME
    error('提取视频段失败: %s\n错误: %s', data_bdf, ME.message);
end
end
