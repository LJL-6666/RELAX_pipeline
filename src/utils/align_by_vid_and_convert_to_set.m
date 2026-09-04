function aligned_files = align_by_vid_and_convert_to_set(...
    data_bdf, video_segments, trial_vid_pairs, subject_id, output_dir, cap_file)
% 按vid对齐视频段并转换为SET格式
% 输入：
%   data_bdf: BDF数据文件路径
%   video_segments: 视频段结构体数组
%   trial_vid_pairs: [(trial, vid)] 列表
%   subject_id: 被试ID
%   output_dir: 输出目录
%   cap_file: 电极位置文件路径
% 输出：
%   aligned_files: 生成的文件路径列表

aligned_files = {};

try
    % 读取BDF数据
    fprintf('  读取BDF数据...\n');
    cfg = [];
    cfg.dataset = data_bdf;
    cfg.headerfile = data_bdf;
    hdr = ft_read_header(cfg.headerfile);
    
    % 由于数据已经按vid排序，直接按vid分组（处理可能的重复vid）
    % video_segments和trial_vid_pairs现在是一一对应的
    if length(video_segments) ~= size(trial_vid_pairs, 1)
        error('video_segments和trial_vid_pairs长度不匹配');
    end
    
    % 按vid分组视频段（数据已排序，直接遍历即可）
    vid_to_segments = containers.Map('KeyType', 'double', 'ValueType', 'any');
    for i = 1:length(video_segments)
        vid = trial_vid_pairs(i, 2);  % 直接使用排序后的vid
        if ~isKey(vid_to_segments, vid)
            vid_to_segments(vid) = [];
        end
        vid_to_segments(vid) = [vid_to_segments(vid), i];
    end
    
    % 获取所有vid（已经排序，但为了确保，再次排序）
    all_vids = cell2mat(vid_to_segments.keys);
    all_vids = sort(all_vids);
    
    fprintf('  按vid对齐，共 %d 个不同的vid\n', length(all_vids));
    
    % 对每个vid，提取数据并转换为SET
    for vid_idx = 1:length(all_vids)
        vid = all_vids(vid_idx);
        seg_indices = vid_to_segments(vid);
        
        if isempty(seg_indices)
            continue;
        end
        
        % 使用第一个段（如果有多个段对应同一个vid，使用第一个）
        seg_idx = seg_indices(1);
        seg = video_segments(seg_idx);
        
        % 读取段数据
        % 使用正确的ft_read_data调用方式：传入文件名和键值对参数
        data = ft_read_data(data_bdf, 'header', hdr, ...
            'begsample', seg.startSample, ...
            'endsample', seg.endSample, ...
            'chanindx', []);
        
        % 转换为EEGLAB格式
        EEG = eeg_emptyset();
        EEG.data = double(data);
        EEG.srate = hdr.Fs;
        EEG.pnts = size(data, 2);
        EEG.nbchan = size(data, 1);
        EEG.xmin = 0;
        EEG.xmax = (EEG.pnts - 1) / EEG.srate;
        
        % 设置通道标签
        if isfield(hdr, 'label') && ~isempty(hdr.label) && iscell(hdr.label)
            n_chans = min(EEG.nbchan, length(hdr.label));
            % 创建通道标签数组
            chan_labels = cell(EEG.nbchan, 1);
            for ch = 1:n_chans
                if ischar(hdr.label{ch})
                    chan_labels{ch} = hdr.label{ch};
                elseif iscell(hdr.label{ch})
                    chan_labels{ch} = char(hdr.label{ch});
                else
                    chan_labels{ch} = char(string(hdr.label{ch}));
                end
            end
            % 如果通道数多于标签数，为剩余通道创建默认标签
            for ch = n_chans+1:EEG.nbchan
                chan_labels{ch} = sprintf('Ch%d', ch);
            end
        else
            % 如果没有标签，创建默认标签
            chan_labels = cell(EEG.nbchan, 1);
            for ch = 1:EEG.nbchan
                chan_labels{ch} = sprintf('Ch%d', ch);
            end
        end
        
        % 创建chanlocs结构体数组
        EEG.chanlocs = repmat(struct('labels', ''), EEG.nbchan, 1);
        for ch = 1:EEG.nbchan
            EEG.chanlocs(ch).labels = chan_labels{ch};
        end
        
        % 添加电极位置信息
        if exist(cap_file, 'file') && ~isempty(EEG.chanlocs)
            try
                % 确保chanlocs结构正确
                if ~isstruct(EEG.chanlocs) || ~isfield(EEG.chanlocs, 'labels')
                    warning('chanlocs结构不正确，跳过电极位置加载');
                else
                    EEG = pop_chanedit(EEG, 'lookup', cap_file);
                    % 验证pop_chanedit返回的结构
                    if ~isstruct(EEG.chanlocs) || length(EEG.chanlocs) ~= EEG.nbchan
                        warning('pop_chanedit返回的chanlocs结构不正确，使用原始结构');
                        % 重新创建chanlocs
                        EEG.chanlocs = repmat(struct('labels', ''), EEG.nbchan, 1);
                        for ch = 1:EEG.nbchan
                            EEG.chanlocs(ch).labels = chan_labels{ch};
                        end
                    end
                end
            catch ME
                warning('无法加载电极位置文件: %s', ME.message);
                % 确保chanlocs仍然有效
                if ~isstruct(EEG.chanlocs) || length(EEG.chanlocs) ~= EEG.nbchan
                    EEG.chanlocs = repmat(struct('labels', ''), EEG.nbchan, 1);
                    for ch = 1:EEG.nbchan
                        EEG.chanlocs(ch).labels = chan_labels{ch};
                    end
                end
            end
        end
        
        % 添加事件信息（标记视频开始）
        EEG.event = struct('type', {}, 'latency', {}, 'duration', {}, 'videoIndex', {});
        EEG.event(1).type = 'videoStart';
        EEG.event(1).latency = double(1);
        EEG.event(1).duration = double(0);
        EEG.event(1).videoIndex = double(vid);
        
        % 设置文件名
        sub_str = sprintf('sub%03d', str2double(subject_id));
        filename = sprintf('%s_vid%02d.set', sub_str, vid);
        filepath = fullfile(output_dir, filename);
        
        % 保存SET文件
        try
            % 验证关键字段类型
            if ~isnumeric(EEG.srate) || ~isnumeric(EEG.pnts) || ~isnumeric(EEG.nbchan)
                error('EEG基本字段类型错误');
            end
            if ~isstruct(EEG.chanlocs) || length(EEG.chanlocs) ~= EEG.nbchan
                error('EEG.chanlocs结构不正确');
            end
            if ~isstruct(EEG.event) || isempty(EEG.event)
                error('EEG.event结构不正确');
            end
            
            % 调用eeg_checkset
            EEG = eeg_checkset(EEG);
            
            % 再次验证
            if ~isstruct(EEG.chanlocs) || length(EEG.chanlocs) ~= EEG.nbchan
                error('eeg_checkset后chanlocs结构被破坏');
            end
            
            % 保存文件
            pop_saveset(EEG, 'filename', filename, 'filepath', output_dir);
            aligned_files{end+1} = filepath;
        catch ME2
            fprintf('  保存文件时出错 (vid=%d, file=%s): %s\n', vid, filename, ME2.message);
            if ~isempty(ME2.stack)
                fprintf('  错误位置: %s (第 %d 行)\n', ME2.stack(1).name, ME2.stack(1).line);
            end
            rethrow(ME2);
        end
    end
    
    fprintf('  ✓ 生成 %d 个对齐后的SET文件\n', length(aligned_files));
    
catch ME
    fprintf('错误堆栈:\n');
    for k = 1:min(5, length(ME.stack))
        if isfield(ME.stack(k), 'file')
            fprintf('  %s (第 %d 行)\n', ME.stack(k).file, ME.stack(k).line);
        else
            fprintf('  %s (第 %d 行)\n', ME.stack(k).name, ME.stack(k).line);
        end
    end
    error('对齐和转换失败: %s', ME.message);
end

end

