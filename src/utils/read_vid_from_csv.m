function [trial_vid_pairs, vid_list] = read_vid_from_csv(csv_file, orderColumn)
% 从CSV文件读取视频编号（vid）信息
% 输入：
%   csv_file: CSV文件路径
%   orderColumn: 视频编号列名（可选；默认依次探测 videoIndex -> vid -> 第一列）
% 输出：
%   trial_vid_pairs: [(trial, vid)] 列表，trial从1开始（对应CSV数据行，跳过表头）
%   vid_list: vid列表（按CSV行顺序）

trial_vid_pairs = [];
vid_list = [];

if ~exist(csv_file, 'file')
    error('CSV文件不存在: %s', csv_file);
end

% 读取CSV文件
try
    % 使用readtable读取（MATLAB R2013b+）
    if exist('readtable', 'file')
        tbl = readtable(csv_file);
        
        % 按指定列名 -> videoIndex -> vid -> 第一列 依次探测
        vid_col = [];
        if nargin >= 2 && ~isempty(orderColumn) && ismember(orderColumn, tbl.Properties.VariableNames)
            vid_col = tbl.(orderColumn);
        elseif ismember('videoIndex', tbl.Properties.VariableNames)
            vid_col = tbl.videoIndex;
        elseif ismember('vid', tbl.Properties.VariableNames)
            vid_col = tbl.vid;
        elseif nargin >= 2 && ~isempty(orderColumn)
            warning('CSV 中无列 "%s"，回退使用第一列', orderColumn);
        end
        if isempty(vid_col)
            % 使用第一列
            vid_col = tbl{:, 1};
        end
        
        % 转换为数值（处理可能的非数值值）
        if iscell(vid_col)
            vid_col = cellfun(@(x) str2double(x), vid_col, 'UniformOutput', false);
            vid_col = cell2mat(vid_col(~cellfun(@isnan, vid_col)));
        elseif isnumeric(vid_col)
            vid_col = vid_col(~isnan(vid_col));
        else
            vid_col = double(vid_col);
            vid_col = vid_col(~isnan(vid_col));
        end
        
    else
        % 使用fscanf读取（兼容旧版本MATLAB）
        fid = fopen(csv_file, 'r');
        if fid == -1
            error('无法打开CSV文件: %s', csv_file);
        end
        
        % 读取第一行（表头）
        header = fgetl(fid);
        
        % 读取数据
        vid_col = [];
        while ~feof(fid)
            line = fgetl(fid);
            if isempty(line), continue; end
            
            % 解析CSV行（简单处理，假设第一列是vid）
            parts = strsplit(line, ',');
            if length(parts) >= 1
                vid_val = str2double(parts{1});
                if ~isnan(vid_val)
                    vid_col(end+1) = vid_val;
                end
            end
        end
        fclose(fid);
    end
    
    % 建立trial-vid映射（trial从1开始，对应CSV数据行，跳过表头）
    for i = 1:length(vid_col)
        trial_vid_pairs(end+1, :) = [i, vid_col(i)];
    end
    
    vid_list = vid_col;
    
catch ME
    error('读取CSV文件失败: %s\n错误: %s', csv_file, ME.message);
end

end

