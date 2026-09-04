%% 统计电影任务RELAX预处理输出文件
clear; clc;

output_dir = 'E:\ljl\work\通用\RELAX_update\归档\新预处理\RELAX输入\电影\RELAXProcessed\Cleaned_Data';

% 获取所有RELAX输出文件
files = dir(fullfile(output_dir, '*_RELAX.set'));

fprintf('=== 电影任务RELAX预处理输出统计 ===\n\n');

% 统计总文件数
total_files = length(files);
fprintf('总文件数: %d 个\n', total_files);

% 提取被试ID和视频编号
subject_ids = {};
video_counts = containers.Map('KeyType', 'char', 'ValueType', 'double');

for i = 1:length(files)
    filename = files(i).name;
    % 匹配格式: subXXX_vidYY_RELAX.set
    tokens = regexp(filename, '^sub(\d+)_vid(\d+)_RELAX\.set$', 'tokens');
    if ~isempty(tokens)
        sub_id = tokens{1}{1};
        vid_id = tokens{1}{2};
        
        % 记录被试ID
        if ~any(strcmp(subject_ids, sub_id))
            subject_ids{end+1} = sub_id;
            video_counts(sub_id) = 0;
        end
        
        % 统计每个被试的视频数
        video_counts(sub_id) = video_counts(sub_id) + 1;
    end
end

% 统计被试数量
num_subjects = length(subject_ids);
fprintf('被试ID数量: %d 个\n', num_subjects);

% 统计每个被试的视频数量
video_nums = [];
fprintf('\n每个被试的视频文件数:\n');
subject_ids_sorted = sort(subject_ids);
for i = 1:length(subject_ids_sorted)
    sub_id = subject_ids_sorted{i};
    count = video_counts(sub_id);
    video_nums(end+1) = count;
    fprintf('  被试 %s: %d 个视频\n', sub_id, count);
end

% 统计信息
fprintf('\n=== 统计摘要 ===\n');
fprintf('平均每个被试的视频数: %.1f 个\n', mean(video_nums));
fprintf('最多视频数: %d 个\n', max(video_nums));
fprintf('最少视频数: %d 个\n', min(video_nums));
fprintf('中位数: %d 个\n', median(video_nums));

% 统计完整被试（28个视频）的数量
complete_subjects = sum(video_nums == 28);
fprintf('\n完整被试数（28个视频）: %d 个\n', complete_subjects);
fprintf('不完整被试数: %d 个\n', num_subjects - complete_subjects);

fprintf('\n统计完成！\n');

