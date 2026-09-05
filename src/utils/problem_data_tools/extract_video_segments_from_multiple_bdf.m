function video_segments = extract_video_segments_from_multiple_bdf(bdf_file_paths, startTrig, endTrig, evt_bdf, segOpts)
% 从多个BDF文件中提取视频段（起止 trigger 配对，默认 21/22）
% 输入：
%   bdf_file_paths: BDF文件路径的cell数组，例如 {'data.bdf', 'data.1.bdf', 'data.2.bdf'}
%   startTrig / endTrig: 段开始/结束 trigger（可选，默认 21 / 22）
%   evt_bdf: 可选整段 evt.bdf（优先用其绝对时间事件）
%   segOpts: 可选，见 config_default.cfg.segment

if nargin < 2 || isempty(startTrig), startTrig = 21; end
if nargin < 3 || isempty(endTrig),   endTrig   = 22; end
if nargin < 4, evt_bdf = ''; end
if nargin < 5 || isempty(segOpts), segOpts = struct(); end

video_segments = struct('startSample', {}, 'endSample', {}, 'duration', {}, 'trial', {});

if isempty(bdf_file_paths)
    error('BDF文件路径列表为空');
end
for i = 1:length(bdf_file_paths)
    if ~exist(bdf_file_paths{i}, 'file')
        error('BDF文件不存在: %s', bdf_file_paths{i});
    end
end

try
    fprintf('  读取合并后的BDF头文件（%d个文件）...\n', length(bdf_file_paths));
    [trigger_positions, fs, nSamples] = collect_trigger_positions( ...
        bdf_file_paths, evt_bdf, startTrig, endTrig, segOpts);
    fprintf('  合并后数据: %d 采样点, 采样率 %.1f Hz, 总时长 %.2f 秒\n', ...
        nSamples, fs, nSamples / fs);
    if isempty(trigger_positions)
        warning('未找到起止 trigger (%d/%d)', startTrig, endTrig);
        return;
    end
    video_segments = pair_segments_from_triggers( ...
        trigger_positions, fs, nSamples, startTrig, endTrig, segOpts);
catch ME
    error('提取视频段失败: %s\n错误: %s', bdf_file_paths{1}, ME.message);
end
end
