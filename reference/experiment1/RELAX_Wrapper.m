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
    % 如果未找到PREP，尝试使用项目中的PREP路径
    if isempty(PrepFolderLocation) || (iscell(PrepFolderLocation) && isempty(PrepFolderLocation{1,1}))
        % 尝试从RELAX_cfg中获取base_dir，或使用默认路径
        try
            base_dir = fileparts(fileparts(fileparts(which('RELAX_Wrapper'))));
        catch
            base_dir = '/data/liujialing/TY';
        end
        prep_path = fullfile(base_dir, '预处理/matlab/PrepPipeline');
        if exist(fullfile(prep_path, 'pop_prepPipeline.m'), 'file')
            PrepFolderLocation = {prep_path};
            fprintf('使用项目中的PREP pipeline: %s\n', prep_path);
        end
    end

    cd(RELAX_cfg.myPath);

    % Check if output file already exists (skip if already processed)
    FileName = extractBefore(RELAX_cfg.filename,".");
    if RELAX_cfg.SingleFile == 1
        last_slash_pos = find(RELAX_cfg.filename == '\', 1, 'last');
        if isempty(last_slash_pos)
            last_slash_pos = find(RELAX_cfg.filename == '/', 1, 'last');
        end
        if ~isempty(last_slash_pos)
        FileName = extractBetween(RELAX_cfg.filename,last_slash_pos+1,".");
        FileName = FileName{1};
    end
    end
    
    % Check if cleaned file already exists
    cleaned_data_dir = [RELAX_cfg.myPath, filesep 'RELAXProcessed', filesep 'Cleaned_Data'];
    output_file = [cleaned_data_dir, filesep, FileName, '_RELAX.set'];
    
    if exist(output_file, 'file')
        fprintf('文件 %s 已处理，跳过...\n', RELAX_cfg.filename);
        continue; % Skip to next file
    end
    
    EEG = pop_loadset(RELAX_cfg.filename);

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
        % 检查是否需要降采样
        if EEG.srate > RELAX_cfg.DownSample_to_X_Hz
            % 尝试使用pop_resample（需要Firfilt插件）
            try
                EEG = pop_resample(EEG,RELAX_cfg.DownSample_to_X_Hz); % downsample data (if applied, should always be applied after low pass filtering)
                fprintf('使用pop_resample降采样到 %.1f Hz\n', EEG.srate);
            catch ME_resample
                % 如果Firfilt插件不可用，使用FieldTrip的resample
                fprintf('Firfilt插件不可用，使用FieldTrip进行降采样...\n');
                try
                    % 检查FieldTrip是否可用
                    if ~exist('ft_resampledata', 'file')
                        % 尝试添加FieldTrip路径
                        ft_path = '/data/liujialing/TY/预处理/matlab/fieldtrip-20181205';
                        if exist(ft_path, 'dir')
                            addpath(ft_path);
                            addpath(fullfile(ft_path, 'preproc'));
                        end
                    end
                    
                    if exist('ft_resampledata', 'file')
                        % 转换为FieldTrip格式
                        data_ft = [];
                        data_ft.trial = {EEG.data};
                        data_ft.time = {(0:EEG.pnts-1)/EEG.srate};
                        % 获取通道标签
                        if isfield(EEG, 'chanlocs') && ~isempty(EEG.chanlocs) && isfield(EEG.chanlocs, 'labels')
                            data_ft.label = cell(EEG.nbchan, 1);
                            for ch = 1:EEG.nbchan
                                if ischar(EEG.chanlocs(ch).labels)
                                    data_ft.label{ch} = EEG.chanlocs(ch).labels;
                                else
                                    data_ft.label{ch} = sprintf('Ch%d', ch);
                                end
                            end
                        else
                            data_ft.label = cellstr(num2str((1:EEG.nbchan)'));
                        end
                        data_ft.fsample = EEG.srate;
                        
                        % 配置降采样
                        cfg = [];
                        cfg.resamplefs = RELAX_cfg.DownSample_to_X_Hz;
                        cfg.detrend = 'no';
                        cfg.demean = 'no';
                        cfg.feedback = 'no';
                        data_ft_resampled = ft_resampledata(cfg, data_ft);
                        
                        % 转换回EEGLAB格式
                        EEG.data = data_ft_resampled.trial{1};
                        EEG.pnts = size(EEG.data, 2);
                        EEG.srate = data_ft_resampled.fsample;
                        EEG.xmax = (EEG.pnts - 1) / EEG.srate;
                        EEG.times = (0:EEG.pnts-1) / EEG.srate * 1000;
                        fprintf('使用FieldTrip成功降采样到 %.1f Hz\n', EEG.srate);
                    else
                        error('FieldTrip的ft_resampledata函数不可用，无法进行降采样');
                    end
                catch ME2
                    error('降采样失败: %s。请安装Firfilt插件或确保FieldTrip可用', ME2.message);
                end
            end
        else
            fprintf('数据采样率(%.1f Hz)已低于或等于目标采样率(%.1f Hz)，跳过降采样\n', EEG.srate, RELAX_cfg.DownSample_to_X_Hz);
        end
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

        channels = str2num(char(RELAX_cfg.AR_parameters{1,'Channels'})); % List of channels
        threshold = RELAX_cfg.AR_parameters{1,'Threshold'};
        window_size = RELAX_cfg.AR_parameters{1,'Window_Size'};
        window_step = RELAX_cfg.AR_parameters{1,'Window_Step'};
        EEG = pop_continuousartdet(EEG , 'ampth',  threshold, 'chanArray',  channels, ...
            'shortisi',  RELAX_cfg.reject_short_periods, 'winms',  window_size, 'stepms',  window_step, ...
            'threshType', 'peak-to-peak' ,'numChanThreshold',6,'firstdet','off');

        % Display CRAP area
        if RELAX_cfg.PlotCRAPRejection
                colormatrej = repmat([1.0000 0.9765 0.5294], size(EEG.CRAPwin,1),1);
                chanrej = repmat(zeros(1, EEG.nbchan),size(EEG.CRAPwin,1),1);
                matrixrej   = [EEG.CRAPwin colormatrej chanrej];
                % 确保事件类型是字符串（eegplot要求）
                EEG_plot = EEG;
                if ~isempty(EEG_plot.event)
                    for evt_idx = 1:length(EEG_plot.event)
                        if isnumeric(EEG_plot.event(evt_idx).type) || (~ischar(EEG_plot.event(evt_idx).type) && ~isstring(EEG_plot.event(evt_idx).type))
                            EEG_plot.event(evt_idx).type = num2str(EEG_plot.event(evt_idx).type);
                        elseif isstring(EEG_plot.event(evt_idx).type)
                            EEG_plot.event(evt_idx).type = char(EEG_plot.event(evt_idx).type);
                        end
                    end
                end
                eegplot(EEG_plot.data, 'title','CRAPrej','winrej', matrixrej,'srate',EEG_plot.srate,'events',EEG_plot.event, 'winlength', 20, 'spacing', 50); % call EEGPLOT GUI
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
        EEG = eeg_eegrej(EEG, EEG.CRAPwin);

        % Skip subjects that have more than 20% CRAP area
        if EEG.RELAXProcessingExtremeRejections.CRAPratio >= 0.2
            warning('>=20% CRAP area, stop running');
            continue
        end
    end 



    %% Clean flat channels and bad channels showing improbable data:
    % PREP pipeline: https://www.ncbi.nlm.nih.gov/pmc/articles/PMC4471356/
    % 安全处理PrepFolderLocation：检查是否为空
    if ~isempty(PrepFolderLocation) && iscell(PrepFolderLocation) && ~isempty(PrepFolderLocation{1,1})
        % 在添加PREP路径之前，先移除有问题的mad函数路径（Biosig的NaN/inst目录）
        % 确保使用MATLAB内置的mad函数
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
    else
        warning('PREP pipeline未找到，跳过PREP通道检测');
        noisyOut.noisyChannels.all = [];
    end  

    EEG.RELAXProcessingExtremeRejections.PREPBasedChannelToReject={};
    if ~isempty(noisyOut.noisyChannels.all) && size(noisyOut.noisyChannels.all,2) > 0
        for x=1:size(noisyOut.noisyChannels.all,2) % loop through output of PREP's findNoisyChannels and take a record of noisy electrodes for deletion:
            PREPBasedChannelToReject{x}=EEG.chanlocs(noisyOut.noisyChannels.all(x)).labels;
            EEG.RELAXProcessingExtremeRejections.PREPBasedChannelToReject = PREPBasedChannelToReject';
        end
        % noisyOut.noisyChannels.all = setdiff(noisyOut.noisyChannels.all,[1,2]);
        EEG=pop_select(EEG,'nochannel',noisyOut.noisyChannels.all); % delete noisy electrodes detected by PREP
    else
        fprintf('未检测到需要删除的PREP通道\n');
    end

    continuousEEG=EEG;

    [continuousEEG, epochedEEG] = RELAX_excluding_channels_and_epoching(continuousEEG, RELAX_cfg); % Epoch data, detect extremely bad data, delete channels if over the set threshold for proportion of data affected by extreme outlier for each electrode
    [continuousEEG, epochedEEG] = RELAX_excluding_extreme_values(continuousEEG, epochedEEG, RELAX_cfg); % Mark extreme periods for exclusion from MWF cleaning, and deletion before wICA cleaning

    if RELAX_cfg.PlotAfterExtremeRejection
       tmpBadPeriods = continuousEEG.RELAXProcessingExtremeRejections.ExtremelyBadPeriodsForDeletion;

       colormatrej = repmat([1.0000 0.9765 0.5294], size(tmpBadPeriods,1),1);
       chanvec = ismember({EEG.allchan.labels},continuousEEG.RELAXProcessingExtremeRejections.ExtremeDataBasedChannelToReject)...
       |ismember({EEG.allchan.labels},continuousEEG.RELAXProcessingExtremeRejections.MuscleBasedElectrodesToReject);
       chanrej = repmat(chanvec,size(tmpBadPeriods,1),1);

       matrixrej   = [tmpBadPeriods colormatrej chanrej];
       % 确保事件类型是字符串（eegplot要求）
       EEG_plot = EEG;
       if ~isempty(EEG_plot.event)
           for evt_idx = 1:length(EEG_plot.event)
               if isnumeric(EEG_plot.event(evt_idx).type) || ~ischar(EEG_plot.event(evt_idx).type)
                   EEG_plot.event(evt_idx).type = num2str(EEG_plot.event(evt_idx).type);
               end
           end
       end
       eegplot(EEG_plot.data,'title','ExtremeRej', 'winrej', matrixrej,'srate',EEG_plot.srate,'events',EEG_plot.event, 'winlength',20,'spacing', 50);
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
    RELAXProcessingExtremeRejectionsAllParticipants(FileNumber,:) = struct2table(epochedEEG.RELAXProcessingExtremeRejections,'AsArray',true);

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
            % 确保事件类型是字符串（eegplot要求）
            EEG_plot = EEG;
            if ~isempty(EEG_plot.event)
                for evt_idx = 1:length(EEG_plot.event)
                    if isnumeric(EEG_plot.event(evt_idx).type) || (~ischar(EEG_plot.event(evt_idx).type) && ~isstring(EEG_plot.event(evt_idx).type))
                        EEG_plot.event(evt_idx).type = num2str(EEG_plot.event(evt_idx).type);
                    elseif isstring(EEG_plot.event(evt_idx).type)
                        EEG_plot.event(evt_idx).type = char(EEG_plot.event(evt_idx).type);
                    end
                end
            end
            eegplot(EEG_plot.data,'title','mwf1','srate',EEG_plot.srate,'events',EEG_plot.event, 'winlength',20,'spacing', 50);
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
            % 确保事件类型是字符串（eegplot要求）
            EEG_plot = EEG;
            if ~isempty(EEG_plot.event)
                for evt_idx = 1:length(EEG_plot.event)
                    if isnumeric(EEG_plot.event(evt_idx).type) || (~ischar(EEG_plot.event(evt_idx).type) && ~isstring(EEG_plot.event(evt_idx).type))
                        EEG_plot.event(evt_idx).type = num2str(EEG_plot.event(evt_idx).type);
                    elseif isstring(EEG_plot.event(evt_idx).type)
                        EEG_plot.event(evt_idx).type = char(EEG_plot.event(evt_idx).type);
                    end
                end
            end
            eegplot(EEG_plot.data,'title','mwf2','srate',EEG_plot.srate,'events',EEG_plot.event, 'winlength',20,'spacing', 50); % call EEGPLOT GUI
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
            % 确保事件类型是字符串（eegplot要求）
            EEG_plot = EEG;
            if ~isempty(EEG_plot.event)
                for evt_idx = 1:length(EEG_plot.event)
                    if isnumeric(EEG_plot.event(evt_idx).type) || (~ischar(EEG_plot.event(evt_idx).type) && ~isstring(EEG_plot.event(evt_idx).type))
                        EEG_plot.event(evt_idx).type = num2str(EEG_plot.event(evt_idx).type);
                    elseif isstring(EEG_plot.event(evt_idx).type)
                        EEG_plot.event(evt_idx).type = char(EEG_plot.event(evt_idx).type);
                    end
                end
            end
            eegplot(EEG_plot.data,'title','mwf3','srate',EEG_plot.srate,'events',EEG_plot.event, 'winlength',20,'spacing', 50);
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
    EEG = eeg_eegrej( EEG, EEG.RELAX.ExtremelyBadPeriodsForDeletion);

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
        [EEG,~, ~, ~, ~] = RELAX_wICA_on_ICLabel_artifacts(EEG,RELAX_cfg.ICA_method, 1, 0, EEG.srate, 5,'coif5',RELAX_cfg.Report_all_ICA_info,RELAX_cfg.ICLabel_thresholds,RELAX_cfg.Clean_other_comps); 
        % pop_eegplot(EEG)
        % setting 'RELAX_cfg.Report_all_wICA_info' to 1 will report proportion of ICs categorized as each category, and variance explained by ICs from each category (function is ~20s slower if this is implemented)
        EEG = eeg_checkset( EEG );
        RELAXProcessing_wICA=EEG.RELAXProcessing_wICA;
        % Record processing statistics for all participants in single table:
        RELAXProcessing_wICA_AllParticipants(FileNumber,:) = struct2table(RELAXProcessing_wICA,'AsArray',true);
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
       % 确保事件类型是字符串（eegplot要求）
       EEG_plot = EEG;
       if ~isempty(EEG_plot.event)
           for evt_idx = 1:length(EEG_plot.event)
               if isnumeric(EEG_plot.event(evt_idx).type) || (~ischar(EEG_plot.event(evt_idx).type) && ~isstring(EEG_plot.event(evt_idx).type))
                   EEG_plot.event(evt_idx).type = num2str(EEG_plot.event(evt_idx).type);
               elseif isstring(EEG_plot.event(evt_idx).type)
                   EEG_plot.event(evt_idx).type = char(EEG_plot.event(evt_idx).type);
               end
           end
       end
       eegplot(EEG_plot.data,'title','wICA','srate',EEG_plot.srate,'events',EEG_plot.event, 'winlength',20,'spacing', 50);
    end

    %% COMPUTE CLEANED METRICS:
    if RELAX_cfg.computecleanedmetrics==1    
        [continuousEEG, epochedEEG] = RELAX_epoching(EEG, RELAX_cfg);
        [continuousEEG, ~] = RELAX_metrics_blinks(continuousEEG, epochedEEG);
        [continuousEEG, ~] = RELAX_metrics_muscle(continuousEEG, epochedEEG, RELAX_cfg);

        [continuousEEG] = RELAX_metrics_final_SER_and_ARR(rawEEG, continuousEEG); % this is only a good metric for testing only the cleaning of artifacts marked for cleaning by MWF, see notes in function.

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
