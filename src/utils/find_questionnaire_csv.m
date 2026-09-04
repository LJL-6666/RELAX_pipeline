function csv_file = find_questionnaire_csv(questionnaire_dir, subject_id)
% 在问卷目录中查找指定被试的CSV文件
% 输入：
%   questionnaire_dir: 问卷目录路径
%   subject_id: 被试ID（字符串，如'2', '3'等）
% 输出：
%   csv_file: CSV文件完整路径，如果未找到则返回空字符串

csv_file = '';

% 被试的问卷目录
sub_quest_dir = fullfile(questionnaire_dir, subject_id);
if ~exist(sub_quest_dir, 'dir')
    return;
end

% 查找rating.csv文件
files = dir(fullfile(sub_quest_dir, '*rating.csv'));
if isempty(files)
    return;
end

% 优先选择exp1_*_rating.csv格式的文件
for i = 1:length(files)
    if ~isempty(regexp(files(i).name, '^exp1_.*_rating\.csv$', 'once'))
        csv_file = fullfile(sub_quest_dir, files(i).name);
        return;
    end
end

% 如果没有找到，使用第一个rating.csv文件
csv_file = fullfile(sub_quest_dir, files(1).name);

end

