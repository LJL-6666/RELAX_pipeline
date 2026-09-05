function video_segments = pair_segments_from_triggers(trigger_positions, fs, nSamples, startTrig, endTrig, segOpts)
% PAIR_SEGMENTS_FROM_TRIGGERS  将 trigger 序列配对为视频段
% segOpts.pairMode:
%   'adjacent'   — start 后紧跟 end（默认）
%   'end_anchor' — 以 end 为锚点，向前取 endAnchorDurationSec
% segOpts.fallbackToEndAnchor (default true):
%   adjacent 得到的段数与 end 数不一致或配对为空时，改用 end_anchor

if nargin < 6 || isempty(segOpts), segOpts = struct(); end
if ~isfield(segOpts, 'pairMode') || isempty(segOpts.pairMode)
    segOpts.pairMode = 'adjacent';
end
if ~isfield(segOpts, 'fallbackToEndAnchor') || isempty(segOpts.fallbackToEndAnchor)
    segOpts.fallbackToEndAnchor = true;
end
if ~isfield(segOpts, 'endAnchorDurationSec') || isempty(segOpts.endAnchorDurationSec)
    segOpts.endAnchorDurationSec = 30;
end

video_segments = struct('startSample', {}, 'endSample', {}, 'duration', {}, 'trial', {});
if isempty(trigger_positions)
    return;
end

nStart = sum(trigger_positions(:, 1) == startTrig);
nEnd   = sum(trigger_positions(:, 1) == endTrig);
mode = segOpts.pairMode;

if strcmp(mode, 'adjacent') && segOpts.fallbackToEndAnchor && nEnd > 0 && nStart ~= nEnd
    fprintf('  警告: start(%d) 与 end(%d) 数量不一致，回退为以 end 锚点切段\n', nStart, nEnd);
    mode = 'end_anchor';
end

if strcmp(mode, 'end_anchor')
    video_segments = pair_end_anchor(trigger_positions, fs, nSamples, endTrig, segOpts.endAnchorDurationSec);
    return;
end

seg_count = 0;
for i = 1:size(trigger_positions, 1)-1
    if trigger_positions(i, 1) == startTrig && trigger_positions(i+1, 1) == endTrig
        start_sample = trigger_positions(i, 2);
        end_sample = trigger_positions(i+1, 2);
        if end_sample > nSamples
            warning('段 %d 超出数据范围，跳过', seg_count + 1);
            continue;
        end
        if end_sample <= start_sample, continue; end
        seg_count = seg_count + 1;
        video_segments(seg_count).startSample = start_sample;
        video_segments(seg_count).endSample = end_sample;
        video_segments(seg_count).duration = (end_sample - start_sample) / fs;
        video_segments(seg_count).trial = seg_count;
    end
end

if isempty(video_segments) && segOpts.fallbackToEndAnchor && nEnd > 0
    fprintf('  adjacent 配对为空，回退为以 end 锚点切段\n');
    video_segments = pair_end_anchor(trigger_positions, fs, nSamples, endTrig, segOpts.endAnchorDurationSec);
    return;
end

fprintf('  找到 %d 个视频段（trigger %d-%d 配对）\n', numel(video_segments), startTrig, endTrig);
end

function video_segments = pair_end_anchor(trigger_positions, fs, nSamples, endTrig, durationSec)
video_segments = struct('startSample', {}, 'endSample', {}, 'duration', {}, 'trial', {});
ends = trigger_positions(trigger_positions(:, 1) == endTrig, 2);
lookback = max(1, round(durationSec * fs));
seg_count = 0;
for i = 1:numel(ends)
    end_sample = ends(i);
    start_sample = max(1, end_sample - lookback + 1);
    if end_sample > nSamples
        warning('段 %d 超出数据范围，跳过', i);
        continue;
    end
    if start_sample >= end_sample, continue; end
    seg_count = seg_count + 1;
    video_segments(seg_count).startSample = start_sample;
    video_segments(seg_count).endSample = end_sample;
    video_segments(seg_count).duration = (end_sample - start_sample) / fs;
    video_segments(seg_count).trial = seg_count;
end
fprintf('  找到 %d 个视频段（end=%d 锚点，向前 %.1fs）\n', ...
    numel(video_segments), endTrig, durationSec);
end
