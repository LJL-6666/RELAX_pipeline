%% RELAX EEG CLEANING PIPELINE, Copyright (C) (2022) Neil Bailey

%     This program is free software: you can redistribute it and/or modify
%     it under the terms of the GNU General Public License as published by
%     the Free Software Foundation, either version 3 of the License, or
%     any later version.
% 
%     This program is distributed in the hope that it will be useful,
%     but WITHOUT ANY WARRANTY; without even the implied warranty of
%     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%     GNU General Public License for more details.
% 
%     You should have received a copy of the GNU General Public License
%     along with this program.  If not, see https://www.gnu.org/licenses/.

%% RELAX_Wrapper:
function [RELAX_cfg, FileNumber, CleanedMetrics, RawMetrics, RELAXProcessingRoundOneAllParticipants, RELAXProcessingRoundTwoAllParticipants, RELAXProcessing_wICA_AllParticipants,...
        RELAXProcessing_ICA_AllParticipants, RELAXProcessingRoundThreeAllParticipants, RELAX_issues_to_check, RELAX_issues_to_check_2nd_run, RELAXProcessingExtremeRejectionsAllParticipants] = RELAX_Wrapper (RELAX_cfg)

% Load pre-processing statistics file for these participants if it already
% exists (note that this can cause errors if the number of variables
% inserted into the output table differs between participants, which can be
% caused by using different parameters in the preceding section):

tic;

RELAX_cfg.OutputPath=[RELAX_cfg.myPath filesep 'RELAXProcessed' filesep];   % use fileseparators for increased compatability 
if ~exist(RELAX_cfg.OutputPath, 'dir'); mkdir(RELAX_cfg.OutputPath); end % make dir if not present

cd(RELAX_cfg.OutputPath);
dirList=dir('*.mat');
for x=1:numel(dirList)
    if  strcmp(dirList(x).name,'ProcessingStatisticsRoundOne.mat')==1
        load('ProcessingStatisticsRoundOne.mat');
    end
end
for x=1:numel(dirList)
    if  strcmp(dirList(x).name,'ProcessingStatisticsRoundTwo.mat')==1
        load('ProcessingStatisticsRoundTwo.mat');
    end
end
for x=1:numel(dirList)
    if  strcmp(dirList(x).name,'ProcessingStatisticsRoundThree.mat')==1
        load('ProcessingStatisticsRoundThree.mat');
    end
end
for x=1:numel(dirList)
    if  strcmp(dirList(x).name,'RawMetrics.mat')==1
        load('RawMetrics.mat');
    end
end
for x=1:numel(dirList)
    if  strcmp(dirList(x).name,'CleanedMetrics.mat')==1
        load('CleanedMetrics.mat');
    end
end
for x=1:numel(dirList)
    if  strcmp(dirList(x).name,'ProcessingStatistics_wICA.mat')==1
        load('ProcessingStatistics_wICA.mat');
    end
end
for x=1:numel(dirList)
    if  strcmp(dirList(x).name,'ProcessingStatistics_ICA.mat')==1
        load('ProcessingStatistics_ICA.mat');
    end
end
for x=1:numel(dirList)
    if  strcmp(dirList(x).name,'RELAX_issues_to_check.mat')==1
        load('RELAX_issues_to_check.mat');
    end
end
for x=1:numel(dirList)
    if  strcmp(dirList(x).name,'RELAXProcessingExtremeRejectionsAllParticipants.mat')==1
        load('RELAXProcessingExtremeRejectionsAllParticipants.mat');
    end
end

if ~isempty(RELAX_cfg.filename)
    RELAX_cfg.FilesToProcess = 1;
    RELAX_cfg.SingleFile = 1; % 1 for single file
else
    RELAX_cfg.SingleFile = 0; % 0 for multiple files
end

% Mode B: mark-only mode (do not physically delete bad segments, write BAD_segment events instead)
if ~isfield(RELAX_cfg, 'MarkOnlyBadSegments') || isempty(RELAX_cfg.MarkOnlyBadSegments)
    RELAX_cfg.MarkOnlyBadSegments = 0;
end

WarningAboutFileNumber=0;
if size(RELAX_cfg.FilesToProcess,2) > size(RELAX_cfg.files,2)
    RELAX_cfg.FilesToProcess=RELAX_cfg.FilesToProcess(1,1):size(RELAX_cfg.files,2);
    WarningAboutFileNumber=1;
end

%% Loop selected files in the directory list:
for FileNumber=RELAX_cfg.FilesToProcess(1,1:size(RELAX_cfg.FilesToProcess,2))
    close all
    if RELAX_cfg.SingleFile == 0
        RELAX_cfg.filename=RELAX_cfg.files{FileNumber};
    end

    clearvars -except 'RELAX_cfg' 'FileNumber' 'CleanedMetrics' 'RawMetrics' 'RELAXProcessingRoundOneAllParticipants' 'RELAXProcessingRoundTwoAllParticipants' 'RELAXProcessing_wICA_AllParticipants'...
        'RELAXProcessing_ICA_AllParticipants' 'RELAXProcessingRoundThreeAllParticipants' 'Warning' 'RELAX_issues_to_check' 'RELAX_issues_to_check_2nd_run'...
        'RELAXProcessingExtremeRejectionsAllParticipants' 'WarningAboutFileNumber';
    %% Load data (assuming the data is in EEGLAB .set format):

    %  1.1.4: fix error where PREP seems to be removed from the path after an
    % EEGLAB update:
    PrepFileLocation = which('pop_prepPipeline','-all');
    PrepFolderLocation=extractBefore(PrepFileLocation,'pop_prepPipeline.m');

    cd(RELAX_cfg.myPath);
    EEG = pop_loadset(RELAX_cfg.filename);

    FileName = extractBefore(RELAX_cfg.filename,".");
    if RELAX_cfg.SingleFile == 1 % RELAX v1.1.3 NWB added to stop RELAX crashing when trying to save due to whole folder being included twice in save file
        last_slash_pos = find(RELAX_cfg.filename == '\', 1, 'last');
        FileName = extractBetween(RELAX_cfg.filename,last_slash_pos+1,".");
        FileName = FileName{1};
    end

    EEG.RELAXProcessing.aFileName=cellstr(FileName);
    EEG.RELAXProcessingExtremeRejections.aFileName=cellstr(FileName);
    
    EEG.RELAX.Data_has_been_averagerereferenced=0;
    EEG.RELAX.Data_has_been_cleaned=0;
    RELAX_cfg.ms_per_sample=(1000/EEG.srate);

    savefileone=[RELAX_cfg.myPath filesep 'RELAXProcessed' filesep 'RELAX_cfg'];
    save(savefileone,'RELAX_cfg')

    %% Select channels 
    if ~isempty(RELAX_cfg.caploc)
        EEG=pop_chanedit(EEG,  'lookup', RELAX_cfg.caploc);
    end

    %% Delete channels that are not relevant if present       
    EEG=pop_select(EEG,'nochannel',RELAX_cfg.ElectrodesToDelete);
    EEG = eeg_checkset( EEG );
    EEG.allchan=EEG.chanlocs; % take list of all included channels before any rejections
    
    %% Band Pass filter data: 
    if strcmp(RELAX_cfg.NotchFilterType,'Butterworth')
        % Use TESA to apply butterworth filter: 
        EEG = RELAX_filtbutter( EEG, RELAX_cfg.LineNoiseFrequency-3, RELAX_cfg.LineNoiseFrequency+3, 4, 'bandstop','acausal');
    end

    if strcmp(RELAX_cfg.LowPassFilterBeforeMWF,'no') % updated implementation, avoiding low pass filtering prior to MWF reduces chances of rank deficiencies, increasing potential values for MWF delay period 
        if strcmp(RELAX_cfg.FilterType,'Butterworth')
            EEG = RELAX_filtbutter( EEG, RELAX_cfg.HighPassFilter, [], 4, 'highpass', RELAX_cfg.causal_or_acausal_filter);
        end
        if strcmp(RELAX_cfg.FilterType,'pop_eegfiltnew')
            EEG = pop_eegfiltnew(EEG,RELAX_cfg.HighPassFilter,[]);
        end
    end

    if strcmp(RELAX_cfg.LowPassFilterBeforeMWF,'yes') % original implementation, not recommended unless downsampling, as increases chances of rank deficiencies
        EEG = RELAX_filtbutter( EEG, RELAX_cfg.HighPassFilter, RELAX_cfg.LowPassFilter, 4, 'bandpass', RELAX_cfg.causal_or_acausal_filter);
    end

    if strcmp(RELAX_cfg.DownSample,'yes')
        EEG = pop_resample(EEG,RELAX_cfg.DownSample_to_X_Hz); % downsample data (if applied, should always be applied after low pass filtering)
        RELAX_cfg.ms_per_sample=(1000/EEG.srate);
    end

    if RELAX_cfg.ms_per_sample<0.7
        warning('The sampling rate for this file is quite high. Depending on your processing power, RELAX may run slowly or even stall, especially if applying MWF cleaning');
        warning('RELAX was validated using 1000Hz sampling rates, which is still a high sample rate for most analyses. You could downsample your data by setting the relevant options in RELAX');
    end

    if strcmp(RELAX_cfg.NotchFilterType,'ZaplinePlus')
        [EEG ] = clean_data_with_zapline_plus_eeglab_wrapper(EEG,struct('plotResults',1,'noisefreqs'));    
    end


    %% Delete CRAP and non-task region

    new_row = length(EEG.event)+1;
    EEG.event(new_row).type = 200;
    EEG.event(new_row).duration = 0;
    % 安全处理offset_in_sec字段：如果前一个事件有该字段则使用，否则从latency计算
    if isfield(EEG.event(new_row-1), 'offset_in_sec') && ~isempty(EEG.event(new_row-1).offset_in_sec)
    EEG.event(new_row).offset_in_sec = EEG.event(new_row-1).offset_in_sec+5;
    else
        % 从latency计算offset_in_sec（秒）
        EEG.event(new_row).offset_in_sec = (EEG.event(new_row-1).latency + 5*EEG.srate) / EEG.srate;
    end
    EEG.event(new_row).latency = EEG.event(new_row-1).latency+5*EEG.srate;
    % 安全处理urevent字段：如果前一个事件有该字段则使用，否则设置为当前行号
    if isfield(EEG.event(new_row-1), 'urevent') && ~isempty(EEG.event(new_row-1).urevent)
    EEG.event(new_row).urevent = EEG.event(new_row-1).urevent+1;
    else
        % 如果前一个事件没有urevent字段，设置为当前行号
        EEG.event(new_row).urevent = new_row;
    end

    if RELAX_cfg.RejNontask
        EEG  = pop_erplabDeleteTimeSegments(EEG , 'displayEEG',  0, 'endEventcodeBufferMS',  RELAX_cfg.minimum_break_length, ...
            'ignoreUseEventcodes',  RELAX_cfg.break_ignore_codes, 'ignoreUseType', 'ignore', ...
            'startEventcodeBufferMS',  RELAX_cfg.break_buffer, 'timeThresholdMS',  RELAX_cfg.break_buffer );
    end
%%

    if RELAX_cfg.RejCrap
        EEG.RELAXProcessingExtremeRejections.CRAPratio=[];

        % 同时超过阈值的通道数门槛（官方硬编码 6；可配置）
        if isfield(RELAX_cfg, 'crapNumChanThreshold') && ~isempty(RELAX_cfg.crapNumChanThreshold)
            numChanThreshold = RELAX_cfg.crapNumChanThreshold;
        else
            numChanThreshold = 6;
        end

        channelsRaw = RELAX_cfg.AR_parameters{1,'Channels'};
        if iscell(channelsRaw) && numel(channelsRaw) == 1
            channelsRaw = channelsRaw{1}; % table 花括号索引可能返回 cell，先解包
        end
        if (ischar(channelsRaw) || isstring(channelsRaw)) && strcmpi(strtrim(char(channelsRaw)), 'all')
            channels = 1:EEG.nbchan; % 'all' = 全部通道
        else
            channels = str2num(char(channelsRaw)); %#ok<ST2NM> % List of channels
        end
        if isempty(channels)
            error('RELAX:CRAPChannels', 'CRAP 通道列表解析为空（AR_parameters.Channels = %s），请检查配置', char(string(channelsRaw)));
        end
        threshold = RELAX_cfg.AR_parameters{1,'Threshold'};
        window_size = RELAX_cfg.AR_parameters{1,'Window_Size'};
        window_step = RELAX_cfg.AR_parameters{1,'Window_Step'};
        % 直接调用 ERPLAB 底层 basicrap 获取 CRAP 窗口（不删除数据）。
        % 新版 ERPLAB 的 pop_continuousartdet 在 script 模式下会直接 eeg_eegrej
        % 删除且不再写 EEG.CRAPwin；RELAX 需要自己掌控删除时机（Mode B 下只标记），
        % 因此这里只取窗口，删除/标记由下方 RELAX 逻辑决定。
        [WinRej, chanrej] = basicrap(EEG, channels, threshold, window_size, window_step, ...
            0, [], [], 'peak-to-peak', numChanThreshold); % firstdet=0（对应 pop 层的 'off'）
        if ~isempty(WinRej)
            shortisisam = floor(RELAX_cfg.reject_short_periods * EEG.srate/1000);
            [WinRej, ~] = joinclosesegments(WinRej, chanrej, shortisisam);
            fprintf('\n %g CRAP segments were marked.\n\n', size(WinRej,1));
        else
            fprintf('\n CRAP criterion was not found. No rejection was performed.\n');
        end
        EEG.CRAPwin = WinRej;

        % Display CRAP area
        if RELAX_cfg.PlotCRAPRejection
                colormatrej = repmat([1.0000 0.9765 0.5294], size(EEG.CRAPwin,1),1);
                chanrej = repmat(zeros(1, EEG.nbchan),size(EEG.CRAPwin,1),1);
                matrixrej   = [EEG.CRAPwin colormatrej chanrej];
                eegplot(EEG.data, 'title','CRAPrej','winrej', matrixrej,'srate',EEG.srate,'events',EEG.event, 'winlength', 20, 'spacing', 50); % call EEGPLOT GUI
        end

        %Merge interleaved segments and calculate CRAP ratio
        CRAPpts = 0;
        CRAPwin = [];
        if ~isempty(EEG.CRAPwin)
            combined_segments = [];  
            segments = sortrows(EEG.CRAPwin);  

            current_start = segments(1, 1);  
            current_end = segments(1, 2);  

            for iseg = 2:size(segments, 1)  
                start_time = segments(iseg, 1);  
                end_time = segments(iseg, 2);  

                if start_time <= current_end + 1  % If they overlap or touch  
                    current_end = max(current_end, end_time);  % Extend the current segment  
                else  
                    combined_segments = [combined_segments; current_start, current_end];  
                    current_start = start_time;  % Start a new segment  
                    current_end = end_time;      % Update to the new segment's end  
                end  
            end  

            CRAPwin = [combined_segments; current_start, current_end];  
            for kseg = 1:size(CRAPwin,1)
                CRAPpts = CRAPpts + CRAPwin(kseg,2)-CRAPwin(kseg,1);
            end
        end
        EEG.RELAXProcessingExtremeRejections.CRAPratio = CRAPpts/length(EEG.times);
        if RELAX_cfg.MarkOnlyBadSegments
            % Mode B（对齐参考实现）：CRAP 段不删除、不单独记录，
            % 稍后合并进官方极端坏段标记（NaN mask + 待剔除列表），之后全走官方流程
            EEG.RELAX.CRAPwinMarked = CRAPwin;
            fprintf('  [Mode B] 标记 %d 个 CRAP 段（稍后合并进极端坏段标记）\n', size(CRAPwin, 1));
        else
            EEG = eeg_eegrej(EEG, EEG.CRAPwin);
        end

        % Skip subjects that have more than 20% CRAP area
        if EEG.RELAXProcessingExtremeRejections.CRAPratio >= 0.2
            warning('>=20% CRAP area, stop running');
            continue
        end
    end 



    %% Clean flat channels and bad channels showing improbable data:
    % PREP pipeline: https://www.ncbi.nlm.nih.gov/pmc/articles/PMC4471356/
    % 在添加PREP路径之前，先移除有问题的mad函数路径（Biosig的NaN目录）
    % 确保使用MATLAB工具箱的mad函数
    mad_paths = which('mad', '-all');
    problematic_mad_paths = {};
    for i = 1:length(mad_paths)
        if ~contains(mad_paths{i}, matlabroot) && contains(mad_paths{i}, 'NaN')
            problematic_mad_paths{end+1} = fileparts(mad_paths{i});
        end
    end
    % 临时移除有问题的路径
    for i = 1:length(problematic_mad_paths)
        rmpath(problematic_mad_paths{i});
    end
    
    addpath(genpath(PrepFolderLocation{1,1})); %  1.1.4: fix error where PREP seems to be removed from the path after an EEGLAB update
    noisyin.badTimeThreshold = 0.02;
    noisyin.highFrequencyNoiseThreshold = 8;
    noisyin.ransacOff = true;
    noisyOut = findNoisyChannels(EEG,noisyin);  

    EEG.RELAXProcessingExtremeRejections.PREPBasedChannelToReject={};
    for x=1:size(noisyOut.noisyChannels.all,2) % loop through output of PREP's findNoisyChannels and take a record of noisy electrodes for deletion:
        PREPBasedChannelToReject{x}=EEG.chanlocs(noisyOut.noisyChannels.all(x)).labels;
        EEG.RELAXProcessingExtremeRejections.PREPBasedChannelToReject = PREPBasedChannelToReject';
    end
    % noisyOut.noisyChannels.all = setdiff(noisyOut.noisyChannels.all,[1,2]);
    EEG=pop_select(EEG,'nochannel',noisyOut.noisyChannels.all); % delete noisy electrodes detected by PREP

    continuousEEG=EEG;

    [continuousEEG, epochedEEG] = RELAX_excluding_channels_and_epoching(continuousEEG, RELAX_cfg); % Epoch data, detect extremely bad data, delete channels if over the set threshold for proportion of data affected by extreme outlier for each electrode
    [continuousEEG, epochedEEG] = RELAX_excluding_extreme_values(continuousEEG, epochedEEG, RELAX_cfg); % Mark extreme periods for exclusion from MWF cleaning, and deletion before wICA cleaning

    % Mode B（对齐参考实现）：把 CRAP 标记段合并进官方极端坏段标记，
    % 之后 MWF 模板屏蔽 / ICA 前处理 / BAD_segment 事件写出都走同一套官方流程
    if RELAX_cfg.MarkOnlyBadSegments && isfield(continuousEEG.RELAX, 'CRAPwinMarked') ...
            && ~isempty(continuousEEG.RELAX.CRAPwinMarked)
        crap = continuousEEG.RELAX.CRAPwinMarked;
        % 1) 合并进 NaN mask（MWF 模板估计会忽略这些时间点）
        if isfield(continuousEEG.RELAX, 'NaNsForExtremeOutlierPeriods') ...
                && ~isempty(continuousEEG.RELAX.NaNsForExtremeOutlierPeriods)
            for ci = 1:size(crap, 1)
                a = max(1, crap(ci,1));
                b = min(numel(continuousEEG.RELAX.NaNsForExtremeOutlierPeriods), crap(ci,2));
                if a <= b
                    continuousEEG.RELAX.NaNsForExtremeOutlierPeriods(a:b) = NaN;
                end
            end
        end
        % 2) 合并进待剔除列表（重叠区间合并）
        if ~isfield(continuousEEG.RELAX, 'ExtremelyBadPeriodsForDeletion')
            continuousEEG.RELAX.ExtremelyBadPeriodsForDeletion = [];
        end
        continuousEEG.RELAX.ExtremelyBadPeriodsForDeletion = RELAX_merge_bad_periods(...
            [continuousEEG.RELAX.ExtremelyBadPeriodsForDeletion; crap], size(continuousEEG.data, 2));
        fprintf('  [Mode B] 已将 %d 个 CRAP 段合并进极端坏段标记（合并后共 %d 段）\n', ...
            size(crap, 1), size(continuousEEG.RELAX.ExtremelyBadPeriodsForDeletion, 1));
    end

    if RELAX_cfg.PlotAfterExtremeRejection
       tmpBadPeriods = continuousEEG.RELAXProcessingExtremeRejections.ExtremelyBadPeriodsForDeletion;

       colormatrej = repmat([1.0000 0.9765 0.5294], size(tmpBadPeriods,1),1);
       chanvec = ismember({EEG.allchan.labels},continuousEEG.RELAXProcessingExtremeRejections.ExtremeDataBasedChannelToReject)...
       |ismember({EEG.allchan.labels},continuousEEG.RELAXProcessingExtremeRejections.MuscleBasedElectrodesToReject);
       chanrej = repmat(chanvec,size(tmpBadPeriods,1),1);

       matrixrej   = [tmpBadPeriods colormatrej chanrej];
       eegplot(EEG.data,'title','ExtremeRej', 'winrej', matrixrej,'srate',EEG.srate,'events',EEG.event, 'winlength',20,'spacing', 50);
    end

    % Use the continuous data to detect eye blinks and mark
    % these in the EEG.event as well as in the mask. The output is
    % continuous data but includes all the previous extreme period 
    % markings from the epoched data.
    if RELAX_cfg.ProbabilityDataHasNoBlinks<2
        [continuousEEG, epochedEEG] = RELAX_blinks_IQR_method(continuousEEG, epochedEEG, RELAX_cfg); % use an IQR threshold method to detect and mark blinks
        if continuousEEG.RELAX.IQRmethodDetectedBlinks(1,1)==0 % If a participants doesn't show any blinks, make a note
            NoBlinksDetected{FileNumber,1}=FileName; 
            warning('No blinks were detected - if blinks are expected then you should visually inspect the file');
        end
        if RELAX_cfg.computerawmetrics==1
        [continuousEEG, epochedEEG] = RELAX_metrics_blinks(continuousEEG, epochedEEG); % record blink amplitude ratio from raw data for comparison.
        end
    end

    % Record extreme artifact rejection details for all participants in single table:
    newExtremeRow = struct2table(epochedEEG.RELAXProcessingExtremeRejections,'AsArray',true);
    if exist('RELAXProcessingExtremeRejectionsAllParticipants', 'var') ...
            && istable(RELAXProcessingExtremeRejectionsAllParticipants) ...
            && ~isequal(RELAXProcessingExtremeRejectionsAllParticipants.Properties.VariableNames, newExtremeRow.Properties.VariableNames)
        % 配置变化（如 RejCrap 开关）导致字段数与续跑加载的旧表不一致时，重建汇总表
        warning('RELAXProcessingExtremeRejectionsAllParticipants 字段与当前配置不一致，重建汇总表（旧表内容丢弃）');
        clear RELAXProcessingExtremeRejectionsAllParticipants
    end
    RELAXProcessingExtremeRejectionsAllParticipants(FileNumber,:) = newExtremeRow;

    rawEEG=continuousEEG; % Take a copy of the not yet cleaned data for calculation of all cleaning SER and ARR at the end

    %% Mark artifacts for calculating SER and ARR, regardless of whether MWF is performed (RELAX v1.1.3 update): 
    if RELAX_cfg.computecleanedmetrics==1 && (RELAX_cfg.Do_MWF_Once==0 || RELAX_cfg.Do_MWF_Twice==0 || RELAX_cfg.Do_MWF_Thrice==0)
        [Marking_artifacts_for_SER_ARR, ~] = RELAX_muscle(continuousEEG, epochedEEG, RELAX_cfg); 
        Marking_all_artifacts_for_SER_ARR.RELAXProcessing.Details.NoiseMaskFullLength(Marking_artifacts_for_SER_ARR.RELAXProcessing.Details.NoiseMaskFullLength==1)=1; 
        [Marking_artifacts_for_SER_ARR] = RELAX_horizontaleye(continuousEEG, RELAX_cfg); 
        Marking_all_artifacts_for_SER_ARR.RELAXProcessing.Details.NoiseMaskFullLength(Marking_artifacts_for_SER_ARR.RELAXProcessing.Details.NoiseMaskFullLength==1)=1; 
        [Marking_artifacts_for_SER_ARR, ~] = RELAX_drift(continuousEEG, epochedEEG, RELAX_cfg); % Use epoched data to add periods showing excessive drift to the mask 
        Marking_all_artifacts_for_SER_ARR.RELAXProcessing.Details.NoiseMaskFullLength(Marking_artifacts_for_SER_ARR.RELAXProcessing.Details.NoiseMaskFullLength==1)=1; 
        Marking_all_artifacts_for_SER_ARR.RELAX.NaNsForExtremeOutlierPeriods=continuousEEG.RELAX.NaNsForExtremeOutlierPeriods; 
        [Marking_all_artifacts_for_SER_ARR] = RELAX_pad_brief_mask_periods (Marking_all_artifacts_for_SER_ARR, RELAX_cfg, 'notblinks'); % If period has been marked as shorter than RELAX_cfg.MinimumArtifactDuration, then pad it out. 
        if isfield(continuousEEG.RELAX,'eyeblinkmask')
                Marking_all_artifacts_for_SER_ARR.RELAXProcessing.Details.NoiseMaskFullLength(continuousEEG.RELAX.eyeblinkmask==1)=1; 
                [Marking_all_artifacts_for_SER_ARR] = RELAX_pad_brief_mask_periods (Marking_all_artifacts_for_SER_ARR, RELAX_cfg, 'blinks'); 
        end
        continuousEEG.RELAX.NoiseMaskFullLengthR1=Marking_all_artifacts_for_SER_ARR.RELAXProcessing.Details.NoiseMaskFullLength; 
        rawEEG.RELAX.NoiseMaskFullLengthR1=Marking_all_artifacts_for_SER_ARR.RELAXProcessing.Details.NoiseMaskFullLength; 
    end

    if RELAX_cfg.saveextremesrejected==1
        if ~exist([RELAX_cfg.myPath, filesep 'RELAXProcessed' filesep 'Extremes_Rejected'], 'dir')
            mkdir([RELAX_cfg.myPath, filesep 'RELAXProcessed' filesep 'Extremes_Rejected'])
        end
        SaveSetExtremes_Rejected =[RELAX_cfg.myPath, filesep 'RELAXProcessed' filesep 'Extremes_Rejected', filesep FileName '_Extremes_Rejected.set'];    
        EEG = pop_saveset( rawEEG, SaveSetExtremes_Rejected ); % If desired, save data here with bad channels deleted, filtering applied, extreme outlying data periods marked
    end

    %% THIS SECTION CONTAINS FUNCTIONS WHICH MARK AND CLEAN MUSCLE ARTIFACTS
    % Any one of these functions can be commented out to ignore those artifacts
    % when creating the mask    
    if RELAX_cfg.Do_MWF_Once==1

        % Use epoched data and FFT to detect slope of log frequency log
        % power, add periods exceeding muscle threshold to mask:
        [continuousEEG, epochedEEG] = RELAX_muscle(continuousEEG, epochedEEG, RELAX_cfg);  
        if RELAX_cfg.computerawmetrics==1
            [continuousEEG, epochedEEG] = RELAX_metrics_muscle(continuousEEG, epochedEEG, RELAX_cfg); % record muscle contamination metrics from raw data for comparison.
        end

        EEG=continuousEEG; % Return continuousEEG to the "EEG" variable for MWF processing

        % If including eye blink cleaning in first round MWF, then insert
        % eye blink mask into noise mask:
        if RELAX_cfg.MWFRoundToCleanBlinks==1
            EEG.RELAXProcessing.Details.NoiseMaskFullLength(EEG.RELAX.eyeblinkmask==1)=1;
            EEG.RELAX.eyeblinkmask(isnan(EEG.RELAXProcessing.Details.NaNsForNonEvents))=NaN;
            EEG.RELAXProcessing.ProportionMarkedBlinks=mean(EEG.RELAX.eyeblinkmask,'omitnan');
        end

        % The following pads very brief lengths of mask periods
        % in the template (without doing this, very short periods can
        % lead to rank deficiency), and excludes extreme artifacts from the
        % cleaning template (so the MWF cleaning step just ignores extreme
        % artifacts in it's template - doesn't include them in either the
        % clean or artifact mask, but does apply cleaning to them).
        [EEG] = RELAX_pad_brief_mask_periods (EEG, RELAX_cfg, 'notblinks'); % If period has been marked as shorter than RELAX_cfg.MinimumArtifactDuration, then pad it out.

        EEG.RELAX.NoiseMaskFullLengthR1=EEG.RELAXProcessing.Details.NoiseMaskFullLength;
        EEG.RELAXProcessing.ProportionMarkedInMWFArtifactMaskTotal=mean(EEG.RELAXProcessing.Details.NoiseMaskFullLength,'omitnan');
        EEG.RELAX.ProportionMarkedInMWFArtifactMaskTotalR1=EEG.RELAXProcessing.ProportionMarkedInMWFArtifactMaskTotal; 

        %% RUN MWF TO CLEAN DATA BASED ON MASKS CREATED ABOVE:
        RELAX_cfg.MWFDelayPeriod=RELAX_cfg.MWFDelayPeriod_for_muscle_artifacts; 
        RELAX_cfg.MWF_delay_spacing=RELAX_cfg.MWF_delay_spacing_for_muscle_artifacts;

        [EEG] = RELAX_perform_MWF_cleaning (EEG, RELAX_cfg);  

        if RELAX_cfg.PlotAfterMwf1
            eegplot(EEG.data,'title','mwf1','srate',EEG.srate,'events',EEG.event, 'winlength',20,'spacing', 50);
        end

        EEG.RELAXProcessingRoundOne=EEG.RELAXProcessing; % Record MWF cleaning details from round 1 in EEG file          
        RELAXProcessingRoundOne=EEG.RELAXProcessingRoundOne; % Record MWF cleaning details from round 1 into file for all participants

        if isfield(RELAXProcessingRoundOne,'Details')
            RELAXProcessingRoundOne=rmfield(RELAXProcessingRoundOne,'Details');
        end
        if RELAX_cfg.KeepAllInfo==0
            if isfield(EEG.RELAXProcessingRoundOne,'Details')
                EEG.RELAXProcessingRoundOne=rmfield(EEG.RELAXProcessingRoundOne,'Details');
            end
        end

        % Record processing statistics for all participants in single table:
        RELAXProcessingRoundOneAllParticipants(FileNumber,:) = struct2table(RELAXProcessingRoundOne,'AsArray',true);
        EEG = rmfield(EEG,'RELAXProcessing');
        % Save round 1 MWF pre-processing:
        if RELAX_cfg.saveround1==1
            if ~exist([RELAX_cfg.myPath, filesep 'RELAXProcessed' filesep '1xMWF'], 'dir')
                mkdir([RELAX_cfg.myPath, filesep 'RELAXProcessed' filesep '1xMWF'])
            end
            SaveSetMWF1 =[RELAX_cfg.myPath, filesep 'RELAXProcessed' filesep '1xMWF', filesep FileName '_MWF1.set'];    
            EEG = pop_saveset( EEG, SaveSetMWF1 ); 
        end
    end

    %% PERFORM A SECOND ROUND OF MWF. THIS IS HELPFUL IF THE FIRST ROUND DOESN'T SUFFICIENTLY CLEAN ARTIFACTS. 

    % This has been suggested to be useful by Somers et al (2018)
    % (particularly when used in a cascading fashion). 

    % However, I can see risks. If artifact masks fall on task relevant
    % activity in both rounds of the MWF, it may be that the task relevant data
    % is just cleaned right out of the signal.

    if RELAX_cfg.Do_MWF_Twice==1

        EEG.RELAXProcessing.aFileName=cellstr(FileName);
        EEG.RELAXProcessing.ProportionMarkedBlinks=0;

        % If blinks weren't initially detected because they were 
        % disguised by the the muscle artifact, detect them here
        % (this happens in <1/200 cases, but is a good back up).
        if RELAX_cfg.ProbabilityDataHasNoBlinks==0
            if EEG.RELAX.IQRmethodDetectedBlinks(1,1)==0
                continuousEEG=EEG;
                [continuousEEG, epochedEEG] = RELAX_blinks_IQR_method(continuousEEG, epochedEEG, RELAX_cfg);
                EEG=continuousEEG;
            end
        end

        % If including eye blink cleaning in second round MWF, then insert
        % eye blink mask into noise mask:
        if isfield(EEG.RELAX, 'eyeblinkmask')
            if RELAX_cfg.MWFRoundToCleanBlinks==2
                EEG.RELAXProcessing.Details.NoiseMaskFullLength(EEG.RELAX.eyeblinkmask==1)=1;
                EEG.RELAX.eyeblinkmask(isnan(EEG.RELAX.NaNsForExtremeOutlierPeriods))=NaN;
                EEG.RELAXProcessing.ProportionMarkedBlinks=mean(EEG.RELAX.eyeblinkmask,'omitnan');
            end
        end

        % The following pads very brief lengths of mask periods
        % in the template (without doing this, very short periods can
        % lead to rank deficiency), and excludes extreme artifacts from the
        % cleaning template (so the MWF cleaning step just ignores extreme
        % artifacts in it's template - doesn't include them in either the
        % clean or artifact mask, but does apply cleaning to them).
        [EEG] = RELAX_pad_brief_mask_periods (EEG, RELAX_cfg, 'blinks');

        EEG.RELAX.NoiseMaskFullLengthR2=EEG.RELAXProcessing.Details.NoiseMaskFullLength;
        EEG.RELAXProcessing.ProportionMarkedInMWFArtifactMaskTotal=mean(EEG.RELAXProcessing.Details.NoiseMaskFullLength,'omitnan');
        EEG.RELAX.ProportionMarkedInMWFArtifactMaskTotalR2=EEG.RELAXProcessing.ProportionMarkedInMWFArtifactMaskTotal; 

        %% RUN MWF TO CLEAN DATA BASED ON MASKS CREATED ABOVE:
        RELAX_cfg.MWFDelayPeriod=RELAX_cfg.MWFDelayPeriod_for_eye_movements; 
        RELAX_cfg.MWF_delay_spacing=RELAX_cfg.MWF_delay_spacing_for_eye_movements; % set how sparsely the delay stacking is spread

        [EEG] = RELAX_perform_MWF_cleaning (EEG, RELAX_cfg);           

        if RELAX_cfg.PlotAfterMwf2
            eegplot(EEG.data,'title','mwf2','srate',EEG.srate,'events',EEG.event, 'winlength',20,'spacing', 50); % call EEGPLOT GUI
        end

        EEG.RELAXProcessingRoundTwo=EEG.RELAXProcessing; % Record MWF cleaning details from round 2 in EEG file
        RELAXProcessingRoundTwo=EEG.RELAXProcessingRoundTwo; % Record MWF cleaning details from round 2 into file for all participants
        if isfield(RELAXProcessingRoundTwo,'Details')
            RELAXProcessingRoundTwo=rmfield(RELAXProcessingRoundTwo,'Details');
        end
        if RELAX_cfg.KeepAllInfo==0
            if isfield(EEG.RELAXProcessingRoundTwo,'Details')
                EEG.RELAXProcessingRoundTwo=rmfield(EEG.RELAXProcessingRoundTwo,'Details');
            end
        end
        % Record processing statistics for all participants in single table:
        RELAXProcessingRoundTwoAllParticipants(FileNumber,:) = struct2table(RELAXProcessingRoundTwo,'AsArray',true);
        EEG = rmfield(EEG,'RELAXProcessing');
        % Save round 2 MWF pre-processing:
        if RELAX_cfg.saveround2==1
            if ~exist([RELAX_cfg.myPath, filesep 'RELAXProcessed' filesep '2xMWF'], 'dir')
                mkdir([RELAX_cfg.myPath, filesep 'RELAXProcessed' filesep '2xMWF'])
            end
            SaveSetMWF2 =[RELAX_cfg.myPath, filesep 'RELAXProcessed' filesep '2xMWF', filesep FileName '_MWF2.set'];    
            EEG = pop_saveset( EEG, SaveSetMWF2 ); 
        end     
    end

    %% PERFORM A THIRD ROUND OF MWF.    
    if RELAX_cfg.Do_MWF_Thrice==1

        EEG.RELAXProcessing.aFileName=cellstr(FileName);
        EEG.RELAXProcessing.ProportionMarkedBlinks=0;
        % If less than 5% of data was masked as eye blink cleaning in second round MWF, then insert
        % eye blink mask into noise mask in round 3:
        if isfield(EEG.RELAX,'ProportionMarkedInMWFArtifactMaskTotalR2') % NWB added to make sure function doesn't bug when trying to check this variable if it doesn't exist
            if EEG.RELAX.ProportionMarkedInMWFArtifactMaskTotalR2<0.05
                if isfield(EEG.RELAX, 'eyeblinkmask')
                    EEG.RELAXProcessing.Details.NoiseMaskFullLength(EEG.RELAX.eyeblinkmask==1)=1;
                    EEG.RELAX.eyeblinkmask(isnan(EEG.RELAX.NaNsForExtremeOutlierPeriods))=NaN;
                    EEG.RELAXProcessing.ProportionMarkedBlinks=mean(EEG.RELAX.eyeblinkmask,'omitnan');
                end
            end
        end

        % Epoch the data into 1 second epochs with a 500ms overlap. Outputs
        % both the ContinuousEEG (which has been filtered above by this
        % point) and the epoched data as EEG.
        [continuousEEG, epochedEEG] = RELAX_epoching(EEG, RELAX_cfg);

        %% THIS SECTION CONTAINS FUNCTIONS WHICH MARK ARTIFACTS

        [continuousEEG, epochedEEG] = RELAX_drift(continuousEEG, epochedEEG, RELAX_cfg); % Use epoched data to add periods showing excessive drift to the mask

        % Use the filtered continuous data to detect horizontal eye
        % movements and mark these in the EEG.event as well as in the mask.
        % You may want to simply reject horizontal eye movements at a later
        % stage if your task requires participants to look straight ahead
        % for the entire task. Alternatively, if your task requires
        % participants to complete horizontal eye movements time locked to
        % a stimuli, this section will mark every event with these
        % horizontal eye movements as an artifact, and should not be
        % implemented.

        % The output is continuous data:
        [continuousEEG] = RELAX_horizontaleye(continuousEEG, RELAX_cfg);

        %% Return to the "EEG" variable for MWF processing:
        EEG=continuousEEG;

        % If including eye blink cleaning in third round MWF, then insert
        % eye blink mask into noise mask:
        if RELAX_cfg.MWFRoundToCleanBlinks==3
            EEG.RELAXProcessing.Details.NoiseMaskFullLength(EEG.RELAX.eyeblinkmask==1)=1;
            EEG.RELAX.eyeblinkmask(isnan(EEG.RELAXProcessing.Details.NaNsForNonEvents))=NaN;
            EEG.RELAXProcessing.ProportionMarkedBlinks=mean(EEG.RELAX.eyeblinkmask,'omitnan');
        end

        % The following pads very brief lengths of mask periods
        % in the template (without doing this, very short periods can
        % lead to rank deficiency), and excludes extreme artifacts from the
        % cleaning template (so the MWF cleaning step just ignores extreme
        % artifacts in it's template - doesn't include them in either the
        % clean or artifact mask, but does apply cleaning to them).
        [EEG] = RELAX_pad_brief_mask_periods (EEG, RELAX_cfg, 'notblinks');

        EEG.RELAX.NoiseMaskFullLengthR3=EEG.RELAXProcessing.Details.NoiseMaskFullLength;
        EEG.RELAXProcessing.ProportionMarkedInMWFArtifactMaskTotal=mean(EEG.RELAXProcessing.Details.NoiseMaskFullLength,'omitnan');
        EEG.RELAX.ProportionMarkedInMWFArtifactMaskTotalR3=EEG.RELAXProcessing.ProportionMarkedInMWFArtifactMaskTotal; 

        %% RUN MWF TO CLEAN DATA BASED ON MASKS CREATED ABOVE:
        RELAX_cfg.MWFDelayPeriod=RELAX_cfg.MWFDelayPeriod_for_eye_movements; 
        RELAX_cfg.MWF_delay_spacing=RELAX_cfg.MWF_delay_spacing_for_eye_movements; % set how sparsely the delay stacking is spread

        [EEG] = RELAX_perform_MWF_cleaning (EEG, RELAX_cfg);               

        if RELAX_cfg.PlotAfterMwf3
            eegplot(EEG.data,'title','mwf3','srate',EEG.srate,'events',EEG.event, 'winlength',20,'spacing', 50);
        end

        if isfield(EEG.RELAX, 'eyeblinkmask') % if eyeblinkmask has been created, do the following (thanks to Jane Tan for the suggested bug fix when eyeblinkmask is not created)
            EEG.RELAX=rmfield(EEG.RELAX,'eyeblinkmask'); % remove variables that are no longer necessary
        end

        EEG.RELAXProcessingRoundThree=EEG.RELAXProcessing; % Record MWF cleaning details from round 3 in EEG file
        RELAXProcessingRoundThree=EEG.RELAXProcessing; % Record MWF cleaning details from round 3 into file for all participants

        if isfield(RELAXProcessingRoundThree,'Details')
            RELAXProcessingRoundThree=rmfield(RELAXProcessingRoundThree,'Details');
        end
        if RELAX_cfg.KeepAllInfo==0
            if isfield(EEG.RELAXProcessingRoundThree,'Details')
                EEG.RELAXProcessingRoundThree=rmfield(EEG.RELAXProcessingRoundThree,'Details');
            end
        end
        % Record processing statistics for all participants in single table:
        RELAXProcessingRoundThreeAllParticipants(FileNumber,:) = struct2table(RELAXProcessingRoundThree,'AsArray',true);
        EEG = rmfield(EEG,'RELAXProcessing');

        if RELAX_cfg.saveround3==1
            if ~exist([RELAX_cfg.myPath, filesep 'RELAXProcessed' filesep '3xMWF'], 'dir')
                mkdir([RELAX_cfg.myPath, filesep 'RELAXProcessed' filesep '3xMWF'])
            end
            SaveSetMWF3 =[RELAX_cfg.myPath,filesep 'RELAXProcessed' filesep '3xMWF', filesep FileName '_MWF3.set'];    
            EEG = pop_saveset( EEG, SaveSetMWF3 ); 
        end         
    end

    %% Perform robust average re-referencing of the data, reject periods marked as extreme outliers    
    if RELAX_cfg.Do_MWF_Once==0
        EEG=continuousEEG;
    end

    % Reject periods that were marked as NaNs in the MWF masks because they
    % showed extreme shift within the epoch or extremely improbable data:
% 保存删除前的原始信息，用于最后保存时恢复长度并用NaN占位
    if ~isempty(EEG.RELAX.ExtremelyBadPeriodsForDeletion)
        EEG.RELAX.OriginalDataLength = size(EEG.data, 2);  % 保存原始数据长度
        EEG.RELAX.BadPeriodsBeforeDeletion = EEG.RELAX.ExtremelyBadPeriodsForDeletion;  % 保存坏段位置
        fprintf('  标记 %d 个极端坏段（保存位置信息用于最后恢复）\n', size(EEG.RELAX.ExtremelyBadPeriodsForDeletion, 1));
    end

    if RELAX_cfg.MarkOnlyBadSegments
        % Mode B: 不物理删除，仅记录；后续保存时写入 BAD_segment 事件
        fprintf('  [Mode B] 极端坏段仅标记，不删除\n');
    else
        % 使用原始的删除方法（这样ICA等算法不受NaN影响）
        EEG = eeg_eegrej( EEG, EEG.RELAX.ExtremelyBadPeriodsForDeletion);

        % 同时也删除rawEEG中的坏段，保持长度一致（用于后续指标计算）
        if exist('rawEEG', 'var') && ~isempty(EEG.RELAX.ExtremelyBadPeriodsForDeletion)
            rawEEG = eeg_eegrej( rawEEG, EEG.RELAX.BadPeriodsBeforeDeletion);
        end
    end

    if strcmp(RELAX_cfg.LowPassFilterBeforeMWF,'no') % if low pass filtering wasn't applied before MWF cleaning (recommended) apply it here
        if strcmp(RELAX_cfg.FilterType,'Butterworth')
            EEG = RELAX_filtbutter( EEG, [], RELAX_cfg.LowPassFilter, 4, 'lowpass', RELAX_cfg.causal_or_acausal_filter);
        end
        if strcmp(RELAX_cfg.FilterType,'pop_eegfiltnew')
            EEG = pop_eegfiltnew(EEG,[],RELAX_cfg.LowPassFilter);
        end
    end

    [EEG] = RELAX_average_rereference(EEG);
    EEG = eeg_checkset( EEG );  

    %% Perform wICA on ICLabel identified artifacts that remain:
    if RELAX_cfg.Perform_targeted_wICA==1
        % The following cleans eye movements and muscle artifacts in the
        % independent component space by a combination of wavelet enhanced
        % ICA cleaning and targeting to restrict the cleaning to only 
        % artifact periods for eye movement components, and high pass 
        % filtering muscle components at 15Hz:
        EEG.RELAXProcessing_wICA.aFileName=cellstr(FileName);
        [EEG] = RELAX_targeted_wICA(EEG,RELAX_cfg);
        % setting 'RELAX_cfg.Report_all_wICA_info' to 1 will report proportion of ICs categorized as each category, and variance explained by ICs from each category (function is ~20s slower if this is implemented)
        EEG = eeg_checkset( EEG );
        RELAXProcessing_wICA=EEG.RELAXProcessing_wICA;
        % Record processing statistics for all participants in single table:
        RELAXProcessing_wICA_AllParticipants(FileNumber,:) = struct2table(RELAXProcessing_wICA,'AsArray',true);
    end

    %% Perform wICA on ICLabel identified artifacts that remain:
    if RELAX_cfg.Perform_wICA_on_ICLabel==1
        % The following performs wICA, implemented on only the components
        % marked as artifact by ICLabel.
        EEG.RELAXProcessing_wICA.aFileName=cellstr(FileName);
        try
        % Mode B（对齐参考实现的 copy-prune-back-copy）：
        % 连续数据不删坏段；先在删除坏段的临时副本上计算 ICA 权重，
        % 再把权重复制回连续数据，由 RELAX_wICA_on_ICLabel_artifacts 直接使用
        % （该函数检测到已有 icaweights 时跳过内部 ICA，避免坏段污染分解）。
        if RELAX_cfg.MarkOnlyBadSegments && isfield(EEG.RELAX, 'ExtremelyBadPeriodsForDeletion') ...
                && ~isempty(EEG.RELAX.ExtremelyBadPeriodsForDeletion)
            if strcmp(RELAX_cfg.ICA_method, 'picard')
                EEG_for_ICA = eeg_eegrej(EEG, EEG.RELAX.ExtremelyBadPeriodsForDeletion);
                EEG_for_ICA = pop_runica_nwb(EEG_for_ICA, 'picard', 'mode','ortho','tol',1e-6,'maxiter',500);
                EEG.icaweights  = EEG_for_ICA.icaweights;
                EEG.icasphere   = EEG_for_ICA.icasphere;
                EEG.icawinv     = EEG_for_ICA.icawinv;
                EEG.icachansind = EEG_for_ICA.icachansind;
                EEG.icaact = [];
                fprintf('  [Mode B] ICA 权重在删除坏段的临时副本上计算（%d -> %d 点），已复制回连续数据\n', ...
                    EEG.pnts, EEG_for_ICA.pnts);
                clear EEG_for_ICA;
            else
                warning('[Mode B] copy-prune-back-copy 目前仅支持 ICA_method=''picard''，当前为 ''%s''，ICA 将在含坏段的连续数据上计算', RELAX_cfg.ICA_method);
            end
        end
        [EEG,~, ~, ~, ~] = RELAX_wICA_on_ICLabel_artifacts(EEG,RELAX_cfg.ICA_method, 1, 0, EEG.srate, 5,'coif5',RELAX_cfg.Report_all_ICA_info,RELAX_cfg.ICLabel_thresholds,RELAX_cfg.Clean_other_comps); 
        % pop_eegplot(EEG)
        % setting 'RELAX_cfg.Report_all_wICA_info' to 1 will report proportion of ICs categorized as each category, and variance explained by ICs from each category (function is ~20s slower if this is implemented)
        EEG = eeg_checkset( EEG );
        RELAXProcessing_wICA=EEG.RELAXProcessing_wICA;
        % Record processing statistics for all participants in single table:
        RELAXProcessing_wICA_AllParticipants(FileNumber,:) = struct2table(RELAXProcessing_wICA,'AsArray',true);
        catch wICA_err
            warning('wICA处理失败，跳过文件 %s: %s', FileName, wICA_err.message);
            fprintf('\n跳过文件: %s (wICA失败)\n', FileName);
            continue;  % 跳过当前文件，继续处理下一个
        end
    end

    %% Perform ICA subtract on ICLabel identified artifacts that remain:
    if RELAX_cfg.Perform_ICA_subtract==1
        % The following performs ICA sutraction, implemented on only the components
        % marked as artifact by ICLabel.
        EEG.RELAXProcessing_ICA.aFileName=cellstr(FileName);
        EEG = RELAX_ICA_subtract(EEG,RELAX_cfg);
        EEG = eeg_checkset( EEG );
        RELAXProcessing_ICA=EEG.RELAXProcessing_ICA;
        % Record processing statistics for all participants in single table:
        RELAXProcessing_ICA_AllParticipants(FileNumber,:) = struct2table(RELAXProcessing_ICA,'AsArray',true);
    end

    EEG.RELAX.Data_has_been_cleaned=1;

    if RELAX_cfg.PlotAfterwICA
       eegplot(EEG.data,'title','wICA','srate',EEG.srate,'events',EEG.event, 'winlength',20,'spacing', 50);
    end

    %% COMPUTE CLEANED METRICS:
    if RELAX_cfg.computecleanedmetrics==1    
        [continuousEEG, epochedEEG] = RELAX_epoching(EEG, RELAX_cfg);
        [continuousEEG, ~] = RELAX_metrics_blinks(continuousEEG, epochedEEG);
        [continuousEEG, ~] = RELAX_metrics_muscle(continuousEEG, epochedEEG, RELAX_cfg);

        try
            [continuousEEG] = RELAX_metrics_final_SER_and_ARR(rawEEG, continuousEEG); % this is only a good metric for testing only the cleaning of artifacts marked for cleaning by MWF, see notes in function.
        catch ME
            warning('RELAX_metrics_final_SER_and_ARR failed (continue to save cleaned file): %s', ME.message);
        end

        EEG=continuousEEG;
        EEG = rmfield(EEG,'RELAXProcessing');

        if isfield(EEG,'RELAX_Metrics')
            if isfield(EEG.RELAX_Metrics, 'Cleaned')
                if isfield(EEG.RELAX_Metrics.Cleaned,'BlinkAmplitudeRatio')
                    CleanedMetrics.BlinkAmplitudeRatio(1:size(EEG.RELAX_Metrics.Cleaned.BlinkAmplitudeRatio,1),FileNumber)=EEG.RELAX_Metrics.Cleaned.BlinkAmplitudeRatio;
                    CleanedMetrics.BlinkAmplitudeRatio(CleanedMetrics.BlinkAmplitudeRatio==0)=NaN;
                end
                if isfield(EEG.RELAX_Metrics.Cleaned,'MeanMuscleStrengthFromOnlySuperThresholdValues')
                    CleanedMetrics.MeanMuscleStrengthFromOnlySuperThresholdValues(FileNumber)=EEG.RELAX_Metrics.Cleaned.MeanMuscleStrengthFromOnlySuperThresholdValues; 
                    CleanedMetrics.ProportionOfEpochsShowingMuscleAboveThresholdAnyChannel(FileNumber)=EEG.RELAX_Metrics.Cleaned.ProportionOfEpochsShowingMuscleAboveThresholdAnyChannel;
                end
                if isfield(EEG.RELAX_Metrics.Cleaned,'All_SER')
                    CleanedMetrics.All_SER(FileNumber)=EEG.RELAX_Metrics.Cleaned.All_SER;
                    CleanedMetrics.All_ARR(FileNumber)=EEG.RELAX_Metrics.Cleaned.All_ARR;
                end
            end
            if isfield(EEG.RELAX_Metrics, 'Raw')
                if isfield(EEG.RELAX_Metrics.Raw,'BlinkAmplitudeRatio')
                    RawMetrics.BlinkAmplitudeRatio(1:size(EEG.RELAX_Metrics.Raw.BlinkAmplitudeRatio,1),FileNumber)=EEG.RELAX_Metrics.Raw.BlinkAmplitudeRatio;
                    RawMetrics.BlinkAmplitudeRatio(RawMetrics.BlinkAmplitudeRatio==0)=NaN;
                end
                if isfield(EEG.RELAX_Metrics.Raw,'MeanMuscleStrengthFromOnlySuperThresholdValues')
                    RawMetrics.MeanMuscleStrengthFromOnlySuperThresholdValues(FileNumber)=EEG.RELAX_Metrics.Raw.MeanMuscleStrengthFromOnlySuperThresholdValues; 
                    RawMetrics.ProportionOfEpochsShowingMuscleAboveThresholdAnyChannel(FileNumber)=EEG.RELAX_Metrics.Raw.ProportionOfEpochsShowingMuscleAboveThresholdAnyChannel;
                end
            end   
        end
    end

    %% Record warnings about potential issues:
    EEG.RELAX_issues_to_check.aFileName=cellstr(FileName);
    if size(EEG.RELAXProcessingExtremeRejections.PREPBasedChannelToReject,1)>RELAX_cfg.MaxProportionOfElectrodesThatCanBeDeleted*size(EEG.allchan,2)
        EEG.RELAX_issues_to_check.PREP_rejected_too_many_electrodes=size(EEG.RELAXProcessingExtremeRejections.PREPBasedChannelToReject,1); % 1.1.4: fix dimension specification error
    else
        EEG.RELAX_issues_to_check.PREP_rejected_too_many_electrodes=0;
    end
    if (EEG.RELAXProcessingExtremeRejections.NumberOfMuscleContaminatedChannelsRecomendedToDelete...
            +EEG.RELAXProcessingExtremeRejections.NumberOfExtremeNoiseChannelsRecomendedToDelete...
            +size(EEG.RELAXProcessingExtremeRejections.PREPBasedChannelToReject,1))...
            >=RELAX_cfg.MaxProportionOfElectrodesThatCanBeDeleted*size(EEG.allchan,2)
        EEG.RELAX_issues_to_check.ElectrodeRejectionRecommendationsMetOrExceededThreshold=...
            (EEG.RELAXProcessingExtremeRejections.NumberOfMuscleContaminatedChannelsRecomendedToDelete...
            +EEG.RELAXProcessingExtremeRejections.NumberOfExtremeNoiseChannelsRecomendedToDelete...
            +size(EEG.RELAXProcessingExtremeRejections.PREPBasedChannelToReject,1));
    else
        EEG.RELAX_issues_to_check.ElectrodeRejectionRecommendationsMetOrExceededThreshold=0;
    end
    if EEG.RELAXProcessingExtremeRejections.ProportionExcludedForExtremeOutlier>0.20
        EEG.RELAX_issues_to_check.HighProportionExcludedAsExtremeOutlier=EEG.RELAXProcessingExtremeRejections.ProportionExcludedForExtremeOutlier;
    else 
        EEG.RELAX_issues_to_check.HighProportionExcludedAsExtremeOutlier=0;
    end
    if isfield(EEG.RELAX, 'IQRmethodDetectedBlinks') % if IQRmethodDetectedBlinks has been created, do the following (thanks to Jane Tan for the suggested bug fix when IQRmethodDetectedBlinks is not created)
        EEG.RELAX_issues_to_check.NoBlinksDetected=(EEG.RELAX.IQRmethodDetectedBlinks==0);
    end
    if RELAX_cfg.Do_MWF_Once==1
        EEG.RELAX_issues_to_check.MWF_eigenvector_deficiency_R1=isa(EEG.RELAXProcessingRoundOne.RankDeficiency,'char');
    end
    if RELAX_cfg.Do_MWF_Twice==1
        EEG.RELAX_issues_to_check.MWF_eigenvector_deficiency_R2=isa(EEG.RELAXProcessingRoundTwo.RankDeficiency,'char');
    end
    if RELAX_cfg.Do_MWF_Thrice==1
        EEG.RELAX_issues_to_check.MWF_eigenvector_deficiency_R3=isa(EEG.RELAXProcessingRoundThree.RankDeficiency,'char');
    end
    if RELAX_cfg.Perform_wICA_on_ICLabel==1
        if EEG.RELAXProcessing_wICA.Proportion_artifactICs_reduced_by_wICA>0.80
            EEG.RELAX_issues_to_check.HighProportionOfArtifact_ICs=EEG.RELAXProcessing_wICA.Proportion_artifactICs_reduced_by_wICA;
        else
            EEG.RELAX_issues_to_check.HighProportionOfArtifact_ICs=0;
        end
        EEG.RELAX_issues_to_check.DataMaybeTooShortForValidICA = EEG.RELAXProcessing_wICA.DataMaybeTooShortForValidICA;
        EEG.RELAX_issues_to_check.fastica_symm_Didnt_Converge=EEG.RELAXProcessing_wICA.fastica_symm_Didnt_Converge(1,3);
    end
    if RELAX_cfg.Perform_ICA_subtract==1
        if EEG.RELAXProcessing_ICA.Proportion_artifactICs_reduced_by_ICA>0.80
            EEG.RELAX_issues_to_check.HighProportionOfArtifact_ICs=EEG.RELAXProcessing_ICA.Proportion_artifactICs_reduced_by_ICA;
        else
            EEG.RELAX_issues_to_check.HighProportionOfArtifact_ICs=0;
        end
        EEG.RELAX_issues_to_check.DataMaybeTooShortForValidICA = EEG.RELAXProcessing_ICA.DataMaybeTooShortForValidICA;
        EEG.RELAX_issues_to_check.fastica_symm_Didnt_Converge=EEG.RELAXProcessing_ICA.fastica_symm_Didnt_Converge(1,3);
    end

    if strcmp(RELAX_cfg.InterpolateRejectedElectrodesAfterCleaning,'yes')
        EEG = pop_interp(EEG, EEG.allchan, 'spherical');
    end

    %% SAVE FILE:
    if ~exist([RELAX_cfg.myPath, filesep 'RELAXProcessed' filesep 'Cleaned_Data'], 'dir')
        mkdir([RELAX_cfg.myPath, filesep 'RELAXProcessed' filesep 'Cleaned_Data'])
    end
    SaveSet_CleanedFile =[RELAX_cfg.myPath,filesep 'RELAXProcessed' filesep 'Cleaned_Data', filesep FileName '_RELAX.set'];  
    EEG.RELAX_settings_used_to_clean_this_file=RELAX_cfg;

    %% Mode B: write BAD_segment events instead of deleting
    if RELAX_cfg.MarkOnlyBadSegments
        if isfield(EEG.RELAX, 'BadPeriodsBeforeDeletion') && ~isempty(EEG.RELAX.BadPeriodsBeforeDeletion)
            bad_periods = EEG.RELAX.BadPeriodsBeforeDeletion;
            % 确保 event 字段存在
            if ~isfield(EEG, 'event') || isempty(EEG.event)
                EEG.event = struct('type', {}, 'latency', {}, 'duration', {});
            end
            if ~isfield(EEG.event, 'duration')
                [EEG.event.duration] = deal([]);
            end
            % 用现有事件做模板，保证字段完全一致（EEGLAB 可能带 urevent 等字段）
            templateEv = EEG.event(end);
            fn = fieldnames(templateEv);
            nBad = size(bad_periods, 1);
            for b = 1:nBad
                ev = templateEv;
                for f = 1:numel(fn)
                    ev.(fn{f}) = [];
                end
                ev.type = 'BAD_segment';
                ev.latency = bad_periods(b,1);
                if isfield(ev, 'duration')
                    ev.duration = bad_periods(b,2) - bad_periods(b,1);
                end
                EEG.event(end+1) = ev; %#ok<AGROW>
            end
            fprintf('  [Mode B] 已写入 %d 个 BAD_segment 事件\n', nBad);
        end
        % 跳过 NaN 还原（Mode B 不删除，无需还原）
        RELAX_cfg.RestoreDeletedPeriodsAsNaN = 0;
    end

    %% Optional: restore deleted extreme periods as NaN (OFF by default = official delete)
    % 官方 RELAX 删除极端坏段后直接保存。等长 NaN 还原默认关闭，避免长度不一致时崩溃；
    % 需要时设 RELAX_cfg.RestoreDeletedPeriodsAsNaN = 1，或事后用 restore_deleted_periods_*.m。
    if ~isfield(RELAX_cfg, 'RestoreDeletedPeriodsAsNaN') || isempty(RELAX_cfg.RestoreDeletedPeriodsAsNaN)
        RELAX_cfg.RestoreDeletedPeriodsAsNaN = 0;
    end
    if RELAX_cfg.RestoreDeletedPeriodsAsNaN == 1 ...
            && isfield(EEG.RELAX, 'BadPeriodsBeforeDeletion') && ~isempty(EEG.RELAX.BadPeriodsBeforeDeletion) ...
            && isfield(EEG.RELAX, 'OriginalDataLength') && ~isempty(EEG.RELAX.OriginalDataLength)
        try
            current_length = size(EEG.data, 2);
            original_length = EEG.RELAX.OriginalDataLength;
            bad_periods = EEG.RELAX.BadPeriodsBeforeDeletion;
            is_bad = false(1, original_length);
            for i = 1:size(bad_periods, 1)
                a = max(1, bad_periods(i,1));
                b = min(original_length, bad_periods(i,2));
                if a <= b
                    is_bad(a:b) = true;
                end
            end
            good_indices = find(~is_bad);
            if length(good_indices) == current_length
                restored_data = nan(size(EEG.data, 1), original_length);
                restored_data(:, good_indices) = EEG.data;
                EEG.data = restored_data;
                EEG.pnts = original_length;
                EEG.xmax = (original_length - 1) / EEG.srate;
                EEG.times = (0:original_length-1) / EEG.srate * 1000;
                fprintf('  已将 %d 个坏段还原为 NaN（长度 %d -> %d）\n', ...
                    size(bad_periods, 1), current_length, original_length);
            else
                warning('跳过 NaN 还原：好段索引数(%d)与当前点数(%d)不一致', ...
                    length(good_indices), current_length);
            end
        catch ME
            warning('NaN 还原失败，仍保存删除后的数据: %s', ME.message);
        end
    end
    
    EEG = pop_saveset( EEG, SaveSet_CleanedFile ); 

    % Record warnings for all participants in single table:
    try
        RELAX_issues_to_check(FileNumber,:) = struct2table(EEG.RELAX_issues_to_check,'AsArray',true);
    catch
        RELAX_issues_to_check_2nd_run(FileNumber,:) = struct2table(EEG.RELAX_issues_to_check,'AsArray',true);
        warning('The variable: "RELAX_issues_to_check" already exists and includes different settings from your current settings')
        warning('This is likely from a previous run of RELAX. Saving variable as "RELAX_issues_to_check_2nd_run" instead');
    end

    %% Save statistics for each participant and across participants, graph cleaning metrics:

    % Also set empty output variables in case these are not produced because certain
    % parameters have been switched off:

    savefileone=[RELAX_cfg.myPath filesep 'RELAXProcessed' filesep 'RELAXProcessingExtremeRejectionsAllParticipants'];
    save(savefileone,'RELAXProcessingExtremeRejectionsAllParticipants')
    if RELAX_cfg.Do_MWF_Once==1
        savefileone=[RELAX_cfg.myPath filesep 'RELAXProcessed' filesep 'ProcessingStatisticsRoundOne'];
        save(savefileone,'RELAXProcessingRoundOneAllParticipants')
    else
        RELAXProcessingRoundOneAllParticipants={};
    end
    if RELAX_cfg.Do_MWF_Twice==1
        savefiletwo=[RELAX_cfg.myPath filesep 'RELAXProcessed' filesep 'ProcessingStatisticsRoundTwo'];
        save(savefiletwo,'RELAXProcessingRoundTwoAllParticipants')
    else
        RELAXProcessingRoundTwoAllParticipants={};
    end
    if RELAX_cfg.Do_MWF_Thrice==1
        savefilethree=[RELAX_cfg.myPath filesep 'RELAXProcessed' filesep 'ProcessingStatisticsRoundThree'];
        save(savefilethree,'RELAXProcessingRoundThreeAllParticipants')
    else
        RELAXProcessingRoundThreeAllParticipants={};
    end
    if RELAX_cfg.Perform_wICA_on_ICLabel==1 || RELAX_cfg.Perform_targeted_wICA==1
        savefilefour=[RELAX_cfg.myPath filesep 'RELAXProcessed' filesep 'ProcessingStatistics_wICA'];
        save(savefilefour,'RELAXProcessing_wICA_AllParticipants')
    else
        RELAXProcessing_wICA_AllParticipants={}; 
    end
    if RELAX_cfg.Perform_ICA_subtract==1
        savefilefour=[RELAX_cfg.myPath filesep 'RELAXProcessed' filesep 'ProcessingStatistics_ICA'];
        save(savefilefour,'RELAXProcessing_ICA_AllParticipants')
    else
        RELAXProcessing_ICA_AllParticipants={}; 
    end
    if exist('CleanedMetrics','var')
        savemetrics=[RELAX_cfg.myPath filesep 'RELAXProcessed' filesep 'CleanedMetrics'];
        save(savemetrics,'CleanedMetrics')
    else
        CleanedMetrics={};
    end
    if exist('RawMetrics','var')
        savemetrics=[RELAX_cfg.myPath filesep 'RELAXProcessed' filesep 'RawMetrics'];
        save(savemetrics,'RawMetrics')
    else
        RawMetrics={};
    end
    if exist('RELAX_issues_to_check','var')
        savemetrics=[RELAX_cfg.myPath filesep 'RELAXProcessed' filesep 'RELAX_issues_to_check'];
        save(savemetrics,'RELAX_issues_to_check')
    end
    if exist('RELAX_issues_to_check_2nd_run','var')
        savemetrics=[RELAX_cfg.myPath filesep 'RELAXProcessed' filesep 'RELAX_issues_to_check_2nd_run'];
        save(savemetrics,'RELAX_issues_to_check_2nd_run')
    end
    RELAX_cfg.filename=[];
    savefileone=[RELAX_cfg.myPath filesep 'RELAXProcessed' filesep 'RELAX_cfg'];
    save(savefileone,'RELAX_cfg')    
end

set(groot, 'defaultAxesTickLabelInterpreter','none');
if RELAX_cfg.computecleanedmetrics==1
    try
        figure('Name','BlinkAmplitudeRatio','units','normalized','outerposition',[0.05 0.05 0.95 0.95]);
        boxplot(CleanedMetrics.BlinkAmplitudeRatio);
        xticklabels(RELAX_cfg.files); xtickangle(90);
        set(gca,'FontSize',16, 'FontWeight', 'bold') % Creates an axes and sets its FontSize to 21
    catch
    end
    try
        figure('Name','MeanMuscleStrengthFromOnlySuperThresholdValues','units','normalized','outerposition',[0.05 0.05 0.95 0.95]);
        b=bar(CleanedMetrics.MeanMuscleStrengthFromOnlySuperThresholdValues); 
        xtickangle(90); xticks([1:1:size(RELAX_cfg.files,2)]); b(1).BaseValue = RELAX_cfg.MuscleSlopeThreshold;
        xticklabels(RELAX_cfg.files); ylim([RELAX_cfg.MuscleSlopeThreshold max(CleanedMetrics.MeanMuscleStrengthFromOnlySuperThresholdValues)+1]);b.ShowBaseLine='off';
        set(gca,'FontSize',16, 'FontWeight', 'bold') % Creates an axes and sets its FontSize to 21
    catch
    end
    try
        figure('Name','ProportionOfEpochsShowingMuscleAboveThresholdAnyChannel','units','normalized','outerposition',[0.05 0.05 0.95 0.95]);
        bar(CleanedMetrics.ProportionOfEpochsShowingMuscleAboveThresholdAnyChannel);
        set(gca,'FontSize',16, 'FontWeight', 'bold') % Creates an axes and sets its FontSize to 21
        xtickangle(90); xticks([1:1:size(RELAX_cfg.files,2)]);
        xticklabels(RELAX_cfg.files);
    catch
    end
end

clearvars -except 'RELAX_cfg' 'FileNumber' 'CleanedMetrics' 'RawMetrics' 'RELAXProcessingRoundOneAllParticipants' 'RELAXProcessingRoundTwoAllParticipants' 'RELAXProcessing_wICA_AllParticipants'...
        'RELAXProcessing_ICA_AllParticipants' 'RELAXProcessingRoundThreeAllParticipants' 'Warning' 'RELAX_issues_to_check' 'RELAX_issues_to_check_2nd_run'...
        'RELAXProcessingExtremeRejectionsAllParticipants' 'WarningAboutFileNumber';

if ~exist('RELAX_issues_to_check_2nd_run','var')    
    warning('Check "RELAX_issues_to_check" to see if any issues were noted for specific files');
    RELAX_issues_to_check_2nd_run=['This variable is only here as a placeholder in case you have already run RELAX once,...' ...
        ' and had previously left the output variables in the same folder as the folder where you have saved the currently cleaned data.' ...
        'This was not an issue with the current run, so this placeholder variable was not filled'];
elseif exist('RELAX_issues_to_check_2nd_run','var')
    warning('Check "RELAX_issues_to_check_2nd_run" to see if any issues were noted for specific files');
end

if WarningAboutFileNumber==1
    warning('You instructed RELAX to clean more files than were in your data folder. Check all your expected files were there?');
end

if RELAX_cfg.ProbabilityDataHasNoBlinks<2 && sum(RELAX_issues_to_check.NoBlinksDetected)>1
    f = msgbox('RELAX did not detect any blinks for some files. Open the "RELAX_issues_to_check" struct in the workspace to check which files. We recommend visually inspecting these files to ensure there has not been an error.'...
    ,'No blinks detected for some files');    
    set(f,'Position',[500,500,450,100]);
    ah = get( f, 'CurrentAxes' );
    ch = get( ah, 'Children' );
    set( ch, 'FontSize', 12 ); %makes text bigger
end

if find(RELAX_issues_to_check.ElectrodeRejectionRecommendationsMetOrExceededThreshold>0)>0
    f = msgbox('Some files met or exceeded the electrode rejection threshold. We recommend visually inspecting the raw and cleaned files where this is the case. Open the "RELAX_issues_to_check" struct in the workspace, and check the third column. Files that exceeded the threshold will show a value above 0. Exclude files where raw data seems irretrievably noisy, or cleaned data still contains excessive noise.'...
    ,'Some files met or exceeded the electrode rejection threshold');    
    set(f,'Position',[300,300,450,150]);
    ah = get( f, 'CurrentAxes' );
    ch = get( ah, 'Children' );
    set( ch, 'FontSize', 12 ); %makes text bigger
end

toc
%% POTENTIAL IMPROVEMENTS THAT COULD BE MADE:
% 1) work out a way to threshold horizontal eye movements so the script
% catches the onset and offset, rather than just the absolute +/-2MAD on
% opposite sides of the head?
% 2) adding a requirement that the IQR blink detection method detects that
% positive amplitude shifts are biased towards frontal electrodes?

%% Mode B helper: merge overlapping/adjacent bad-period intervals
function periods = RELAX_merge_bad_periods(periods, nSamples)
% 合并重叠/相邻的 [start end] 区间，并裁剪到 [1, nSamples]
if isempty(periods)
    return;
end
periods = sortrows(periods, 1);
merged = periods(1, :);
for i = 2:size(periods, 1)
    if periods(i, 1) <= merged(end, 2) + 1
        merged(end, 2) = max(merged(end, 2), periods(i, 2));
    else
        merged(end+1, :) = periods(i, :); %#ok<AGROW>
    end
end
merged(:, 1) = max(1, merged(:, 1));
merged(:, 2) = min(nSamples, merged(:, 2));
periods = merged(merged(:, 2) > merged(:, 1), :);
