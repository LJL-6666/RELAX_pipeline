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

%% RELAX_SET_PARAMETERS_AND_RUN:

%% This pipeline firstly filters your data, then deletes bad electrodes and marks extremely bad periods for exclusion from further processing.
%% It then creates a mask of clean and artifact data specific to the length of your data file, which is submitted to a multiple weiner filter (MWF) in order to clean your data.
%% The MWF cleaned data is then submitted to an independent component analysis, and artifactual components detected by ICLabel are cleaned by wavelet enhanced ICA.
%% The resulting saved files are continuous, very well cleaned of artifacts, while still preserving the neural signal.
%% Note that the pipeline will only work on continuous data.

% RELAX is intended to be fully automated, using the most empirical approaches
% we could find in order to identify periods of EEG data containing
% artifacts, as well as removing channels that are either bad, or contain
% above a specified threshold for the proportion of epochs containing
% muscle artifacts.

% In order to use this script, do the following:

% 1) Install the dependencies listed below, and define the folder where
% they are installed (where required)

% 2) Load the "to be processed" files into a single folder, EEGLAB
% formatted (.set format), and specify this folder location in RELAX_cfg.myPath
% (these files should have triggers recoded to reflect participant accuracy
% if desirable, and not have been re-referenced or have any other
% pre-processing completed yet).

% 3) Specify the parameters in RELAX_cfg. These parameters let you determine
% a range of factors that influence the mask creation, eg. "how many 
% epochs can show muscle activity in a channel before that channel  is
% deleted" (note that a maximum of 20% of channel deletions are allowed 
% after the PREP electrode deletion, "what is the maximum proportion of 
% epochs that can be masked as an artifact for each type of artifact", 
% "should I run the MWF twice or just once", and "what is the threshold 
% of artifact severity,  above which sections are marked as an artifact, 
% below which they are not?". 
% Additionally, particular artifact detection and masking functions
% could be excluded if you're not concerned about those artifacts by
% commenting that function out (adding a % symbol at the start of the
% line). For example, you might only want to include muscle, and
% drift artifacts in the MWF cleaning, and not blink and horizontal 
% eye movements if you are analysing eyes closed resting data.

% 4)Click "Run" in the menu up the top of this script
% The script will then process all participants, taking ~10 min per participant. 
% You can run just a subset of the participants first by altering the
% following line: "for FileNumber=1:numel(RELAX_cfg.files)"

% 5) The script will produce files that contain cleaning quality values for
% relevant processes in this script. Means, SD's (or medians and MADs) 
% and ranges across all participants can be examined to determine 
% the success of the script for the study as a whole, and to identify
% potential issues with specific files (eg. the artifact to residue ratio
% is ~1, suggesting artifacts weren't removed successfully, or >75% of the
% epochs contained muscle activity, suggesting bad data throughout). These
% statistics should be reported in publications.

% Note that it's particularly important to check for files that show rank
% deficiency in the MWF processing, as this could prevent the data from
% being cleaned. If this happens, I've found that adjusting the RELAX_cfg
% parameters can fix the problem. Particularly the amount of data that can
% be included in the mask (the mask needs to contain both enough artifact
% and enough clean data to create artifact and clean templates), and the
% minimum length of a marked patch of clean or artifact data (if
% patches are too short, the MWF can't create an adequate mask. The amount
% of data marked as artifact around eye blinks can particularly affect
% this).

% 6) The script will produce output EEG files that have been cleaned into a
% folder labelled 1xMWF for the first run, 2xMWF, and 3xMWF (if
% you select to save these). Cleaned data will be saved into the Cleaned_data 
% folder. The cleaned files will have electrodes removed, and are referenced to the 
% average reference. From this point, I would interpolate missing electrodes, 
% re-code the task related triggers as to whether the participant
% was correct or not, epoch the data, reject epochs that still show artifacts 
% (the epoch rejection wrapper could be adapted to achieve this)
% and separate different conditions into different files in preparation 
% for analysis.

% Note that if you have very large files (or your computer doesn't have much RAM),
% the MWF cleaning may run out of RAM (and suggest a created array is too large).
% This could be addressed by downsampling the data, or reducing 
% RELAX_cfg.MWFDelayPeriod=8; to 4-5. This will reduce the number of samples 
% that the MWF cleaning takes into account when characterising artifacts, 
% but still cleans very effectively.

% Note that the pipeline does not work well on MATLAB versions <2016,
% we suggest updating to a more recent version of MATLAB if your version is
% pre-2016.

clear all; close all; clc;

%% DEPENDENCIES (toolboxes you need to install, and cite if you use this script):
% use fileseparators 'filesep' for increased compatability if necessary (replace the \ with a filesep [outside of quotes]) 

% MATLAB signal processing toolbox (from MATLAB website)
% MATLAB statistics and machine learning toolbox (from MATLAB website)

% ========== 路径配置 - Tongyong数据集 ==========
base_dir = '<DATA_ROOT>';

% EEGLAB:
% https://sccn.ucsd.edu/eeglab/index.php
% Delorme, A., & Makeig, S. (2004). EEGLAB: an open source toolbox for analysis of single-trial EEG dynamics including independent component analysis. Journal of neuroscience methods, 134(1), 9-21.
eeglab_path = '<EEGLAB_ROOT>';
if exist(eeglab_path, 'dir')
    addpath(eeglab_path);
    eeglab('nogui');
else
    warning('EEGLAB路径不存在: %s', eeglab_path);
end

% PREP pipeline to reject bad electrodes (install plugin to EEGLAB, or via the github into the EEGLAB plugin folder): 
% https://www.ncbi.nlm.nih.gov/pmc/articles/PMC4471356/
% Bigdely-Shamlo, N., Mullen, T., Kothe, C., Su, K. M., & Robbins, K. A. (2015). The PREP pipeline: standardized preprocessing for large-scale EEG analysis. Frontiers in neuroinformatics, 9, 16.
% http://vislab.github.io/EEG-Clean-Tools/ or install via EEGLAB extensions

% Specify the MWF path:
% https://github.com/exporl/mwf-artifact-removal
% Somers, B., Francart, T., & Bertrand, A. (2018). A generic EEG artifact removal algorithm based on the multi-channel Wiener filter. Journal of neural engineering, 15(3), 036007.
eeglabPath = fileparts(which('eeglab'));
MWFPluginPath = fullfile(eeglabPath, 'plugins', 'mwf-artifact-removal-master');
if exist(MWFPluginPath, 'dir')
    addpath(genpath(MWFPluginPath));
else
    % 尝试使用项目中的MWF插件
    MWFPluginPath2 = fullfile(base_dir, '预处理/matlab/mwf-artifact-removal');
    if exist(MWFPluginPath2, 'dir')
        addpath(genpath(MWFPluginPath2));
        fprintf('使用项目中的MWF插件: %s\n', MWFPluginPath2);
    else
        warning('MWF插件路径不存在: %s 和 %s', MWFPluginPath, MWFPluginPath2);
    end
end

% Fieldtrip:
% http://www.fieldtriptoolbox.org/
% Robert Oostenveld, Pascal Fries, Eric Maris, and Jan-Mathijs Schoffelen. FieldTrip: Open Source Software for Advanced Analysis of MEG, EEG, and Invasive Electrophysiological Data. Computational Intelligence and Neuroscience, vol. 2011, Article ID 156869, 9 pages, 2011. doi:10.1155/2011/156869.
if ~isempty(eeglabPath)
    FieldTripPath = fullfile(eeglabPath, 'plugins', 'Fieldtrip-lite20210601');
    if exist(FieldTripPath, 'dir')
        addpath(FieldTripPath);
        % 添加FieldTrip的external/eeglab目录（包含eeglab2fieldtrip函数）
        ft_external_eeglab = fullfile(FieldTripPath, 'external', 'eeglab');
        if exist(ft_external_eeglab, 'dir')
            addpath(ft_external_eeglab);
        end
    else
        % 尝试使用项目中的FieldTrip
        ft_path = fullfile(base_dir, '预处理/matlab/fieldtrip-20181205');
        if exist(ft_path, 'dir')
            addpath(ft_path);
            addpath(fullfile(ft_path, 'fileio'));
            addpath(fullfile(ft_path, 'preproc'));
            addpath(fullfile(ft_path, 'trialfun'));
            addpath(fullfile(ft_path, 'utilities'));
            % 添加FieldTrip的external/eeglab目录（包含eeglab2fieldtrip函数）
            ft_external_eeglab = fullfile(ft_path, 'external', 'eeglab');
            if exist(ft_external_eeglab, 'dir')
                addpath(ft_external_eeglab);
            end
        else
            warning('FieldTrip路径不存在: %s', ft_path);
        end
    end
end

% PREP pipeline:
% https://www.ncbi.nlm.nih.gov/pmc/articles/PMC4471356/
% Bigdely-Shamlo, N., Mullen, T., Kothe, C., Su, K. M., & Robbins, K. A. (2015). The PREP pipeline: standardized preprocessing for large-scale EEG analysis. Frontiers in neuroinformatics, 9, 16.
if ~isempty(eeglabPath)
    PrepPipelinePath = fullfile(eeglabPath, 'plugins', 'PrepPipeline');
    if exist(PrepPipelinePath, 'dir')
        addpath(genpath(PrepPipelinePath));
    else
        % 尝试使用项目中的PREP pipeline
        prep_path = fullfile(base_dir, '预处理/matlab/PrepPipeline');
        if exist(prep_path, 'dir')
            addpath(genpath(prep_path));
            fprintf('使用项目中的PREP pipeline: %s\n', prep_path);
        else
            warning('PREP pipeline路径不存在: %s', prep_path);
        end
    end
end

% PICARD:
% Can be installed from the EEGLAB plugin manager.

% fastica:
% http://research.ics.aalto.fi/ica/fastica/code/dlcode.shtml 
if ~isempty(eeglabPath)
    FastICAPath = fullfile(eeglabPath, 'plugins', 'FastICA_25');
    if exist(FastICAPath, 'dir')
        addpath(FastICAPath);
    else
        % 尝试使用项目中的FastICA
        FastICAPath2 = fullfile(base_dir, '预处理/matlab/FastICA_25');
        if exist(FastICAPath2, 'dir')
            addpath(FastICAPath2);
            fprintf('使用项目中的FastICA: %s\n', FastICAPath2);
        end
    end
end

% ICLabel:
% https://github.com/sccn/ICLabel
if ~isempty(eeglabPath)
    ICLabelPath = fullfile(eeglabPath, 'plugins', 'ICLabel');
    if exist(ICLabelPath, 'dir')
        addpath(genpath(ICLabelPath));
    else
        % 尝试使用项目中的ICLabel
        ICLabelPath2 = fullfile(base_dir, '预处理/matlab/ICLabel');
        if exist(ICLabelPath2, 'dir')
            addpath(genpath(ICLabelPath2));
            fprintf('使用项目中的ICLabel: %s\n', ICLabelPath2);
        end
    end
end

% PICARD:
% Can be installed from the EEGLAB plugin manager.
if ~isempty(eeglabPath)
    PICARDPath = fullfile(eeglabPath, 'plugins', 'PICARD');
    if exist(PICARDPath, 'dir')
        addpath(genpath(PICARDPath));
    else
        % 尝试使用项目中的PICARD
        PICARDPath2 = fullfile(base_dir, '预处理/matlab/PICARD1.0');
        if exist(PICARDPath2, 'dir')
            addpath(genpath(PICARDPath2));
            fprintf('使用项目中的PICARD: %s\n', PICARDPath2);
        end
    end
end

% Firfilt (用于降采样):
if ~isempty(eeglabPath)
    FirfiltPath = fullfile(eeglabPath, 'plugins', 'firfilt');
    if exist(FirfiltPath, 'dir')
        addpath(genpath(FirfiltPath));
    else
        % 尝试使用项目中的Firfilt
        FirfiltPath2 = fullfile(base_dir, '预处理/matlab/firfilt');
        if exist(FirfiltPath2, 'dir')
            addpath(genpath(FirfiltPath2));
            fprintf('使用项目中的Firfilt: %s\n', FirfiltPath2);
        end
    end
end

% DIPFIT (用于源定位):
if ~isempty(eeglabPath)
    DIPFITPath = fullfile(eeglabPath, 'plugins', 'dipfit');
    if exist(DIPFITPath, 'dir')
        addpath(genpath(DIPFITPath));
    else
        % 尝试使用项目中的DIPFIT
        DIPFITPath2 = fullfile(base_dir, '预处理/matlab/dipfit');
        if exist(DIPFITPath2, 'dir')
            addpath(genpath(DIPFITPath2));
            fprintf('使用项目中的DIPFIT: %s\n', DIPFITPath2);
        end
    end
end

% Clean Rawdata (用于数据清理):
if ~isempty(eeglabPath)
    CleanRawdataPath = fullfile(eeglabPath, 'plugins', 'clean_rawdata');
    if exist(CleanRawdataPath, 'dir')
        addpath(genpath(CleanRawdataPath));
    else
        % 尝试使用项目中的clean_rawdata
        CleanRawdataPath2 = fullfile(base_dir, '预处理/matlab/clean_rawdata');
        if exist(CleanRawdataPath2, 'dir')
            addpath(genpath(CleanRawdataPath2));
            fprintf('使用项目中的clean_rawdata: %s\n', CleanRawdataPath2);
        else
            % 尝试clean_rawdata-master
            CleanRawdataPath3 = fullfile(base_dir, '预处理/matlab/clean_rawdata-master');
            if exist(CleanRawdataPath3, 'dir')
                addpath(genpath(CleanRawdataPath3));
                fprintf('使用项目中的clean_rawdata-master: %s\n', CleanRawdataPath3);
            end
        end
    end
end

% Biosig (用于读取多种EEG格式):
if ~isempty(eeglabPath)
    BiosigPath = fullfile(eeglabPath, 'plugins', 'Biosig');
    if exist(BiosigPath, 'dir')
        addpath(genpath(BiosigPath));
    else
        % 尝试使用项目中的Biosig（排除maybe-missing和NaN目录以避免函数冲突）
        BiosigPath2 = fullfile(base_dir, '预处理/matlab/Biosig3.8.4');
        if exist(BiosigPath2, 'dir')
            % 先添加整个路径
            addpath(genpath(BiosigPath2));
            % 然后从路径中移除maybe-missing目录
            maybe_missing_path = fullfile(BiosigPath2, 'biosig', 'maybe-missing');
            if exist(maybe_missing_path, 'dir')
                rmpath(genpath(maybe_missing_path));
            end
            % 移除NaN目录（包含不兼容的mad函数）
            nan_path = fullfile(BiosigPath2, 'NaN');
            if exist(nan_path, 'dir')
                rmpath(genpath(nan_path));
            end
            fprintf('使用项目中的Biosig: %s（已排除maybe-missing和NaN目录以避免函数冲突）\n', BiosigPath2);
        end
    end
end

% Specify RELAX folder location (this toolbox):
relax_path = fullfile(base_dir, '预处理/matlab/实验1');
if exist(relax_path, 'dir')
    addpath(relax_path);
else
    warning('RELAX路径不存在: %s', relax_path);
end

% Specify your electrode locations with the correct cap file:
RELAX_cfg.caploc = fullfile(base_dir, '预处理/matlab/配置环境/standard_1005.elc'); % path containing electrode positions. Set to =[] if electrode locations are already in your EEG file.

% Specify the to be processed file locations:
RELAX_cfg.myPath = fullfile(base_dir, 'data/data-tongyong/原始数据/可用原始数据/转化成set的脑电_aligned');

% Or specify the single file to be processed:
RELAX_cfg.filename=[]; % (including folder path)

%% List all files in directory
cd(RELAX_cfg.myPath);
RELAX_cfg.dirList=dir('*.set');
RELAX_cfg.files={RELAX_cfg.dirList.name};
if isempty(RELAX_cfg.files)
    disp('No files found..')
end

%% Parameters that can be specified:

% The following selections determine how many epochs of each type of
% artifact to include in the mask. It's not obvious what the best choices are.
% I have selected as defaults the parameters that work best for our data.
% If only performing one MWF run, perhaps including all artifacts in the mask
% is best (as long as that leaves enough clean data for the clean data
% mask). Somers et al. (2018) suggest that it doesn't hurt to
% include clean data in the artifact mask, and so it's helpful to have wide
% boundaries around artifacts. 

% However, I wonder if some files might include the majority of trials in the artifact
% mask could mean that most of the task related ERPs might be considered
% artifacts, and cleaned out from the data. Including ERP trials in the clean
% mask reduces this issue, as the clean mask defines what the good
% data should look like, and if it has ERPs, then the artifact periods will
% be cleaned of only the difference between the clean mask and the artifact
% mask, leaving the ERP in the data. This relies upon a consistent
% ERP across both the clean and artifact masks however. An alternative fix
% could be to implement NaNs (which the MWF mask ignores) over ERP periods
% instead of marking them as artifacts, so the ERP is not included in the
% artifact mask, but this would mean any artifacts that are present in the
% ERPs but not outside the ERP periods aren't cleaned.

% Lastly, you may want to delete more unused electrodes than specified by
% this script. If so, modify the section titled: "Delete channels that
% are not relevant if present" to include the electrodes you would like to
% delete.
RELAX_cfg.Perform_targeted_wICA=0; % This is the recommended artifact reduction method.

RELAX_cfg.Do_MWF_Once=1; % 1 = Perform the MWF cleaning a second time (1 for yes, 0 for no).
RELAX_cfg.Do_MWF_Twice=1; % 1 = Perform the MWF cleaning a second time (1 for yes, 0 for no).
RELAX_cfg.Do_MWF_Thrice=1; % 1 = Perform the MWF cleaning a second time (1 for yes, 0 for no). I think cleaning drift in this is a good idea.
RELAX_cfg.Perform_wICA_on_ICLabel=1; % 1 = Perform wICA on artifact components marked by ICLabel (1 for yes, 0 for no).
RELAX_cfg.Perform_ICA_subtract=0; % 1 = Perform ICA subtract on artifact components marked by ICLabel (1 for yes, 0 for no) (non-optimal, intended to be optionally used separately to wICA rather than additionally)
RELAX_cfg.ICA_method='picard';
RELAX_cfg.Report_all_ICA_info='yes'; % set to yes to provide detailed report of ICLabel artifact information. Runs ~20s slower per file.
RELAX_cfg.Clean_other_comps='no'; % set to yes to clean independent components other than blinks and muscle activity

RELAX_cfg.ICLabel_thresholds=[0.5 0.8 0.8 0.5 0.5 0.5 0.5]; 
% e.g. [0.5 0.8 0.8 0.5 0.5 0.5 0.5]; with values specifying comp types in the following order: ['Brain' 'Muscle' 'Eye'	'Heart'	'Line Noise' 'Channel Noise' 'Other']
% set these to a decimal > 0 if you want components to only be considered as 
% potential artifacts if ICLabel provides a higher decimal than that for the 
% classification confidence. If multiple components are above the threshold, 
% then the maximal value is used to categorize the component

RELAX_cfg.computerawmetrics=1; % Compute blink and muscle metrics from the raw data?
RELAX_cfg.computecleanedmetrics=1; % Compute SER, ARR, blink and muscle metrics from the cleaned data?

RELAX_cfg.MWFRoundToCleanBlinks=2; % Which round to clean blinks in (1 for the first, 2 for the second...)
RELAX_cfg.LowPassFilterAt_6Hz_BeforeDetectingBlinks='no'; % low pass filters the data @ 6Hz prior to blink detection (helps if high power alpha is disrupting blink detection, not necessary in the vast majority of cases, default = 'no')
RELAX_cfg.ProbabilityDataHasNoBlinks=0; % 0 = data almost certainly has blinks, 1 = data might not have blinks, 2 = data definitely doesn't have blinks.
% 0 = eg. task related data where participants are focused with eyes open, 
% 1 = eg. eyes closed recordings, but with participants who might still open their eyes at times, 
% 2 = eg. eyes closed resting with highly compliant participants and recordings that were strictly made only when participants had their eyes closed.

RELAX_cfg.DriftSeverityThreshold=10; %MAD from the median of all electrodes. This could be set lower and would catch less severe drift 
RELAX_cfg.ProportionWorstEpochsForDrift=0.30; % Maximum proportion of epochs to include in the mask from drift artifact type.

RELAX_cfg.ExtremeVoltageShiftThreshold=8; % Threshold MAD from the median all epochs for each electrode against the same electrode in different epochs. This could be set lower and would catch less severe voltage shifts within the epoch
RELAX_cfg.ExtremeAbsoluteVoltageThreshold=500; % microvolts max or min above which will be excluded from cleaning and deleted from data
RELAX_cfg.ExtremeImprobableVoltageDistributionThreshold=8; % Threshold SD from the mean of all epochs for each electrode against the same electrode in different epochs. This could be set lower and would catch less severe improbable data
RELAX_cfg.ExtremeSingleChannelKurtosisThreshold=8; % Threshold kurtosis of each electrode against the same electrode in different epochs. This could be set lower and would catch less severe kurtosis 
RELAX_cfg.ExtremeAllChannelKurtosisThreshold=8; % Threshold kurtosis across all electrodes. This could be set lower and would catch less severe kurtosis
RELAX_cfg.ExtremeDriftSlopeThreshold=-4; % slope of log frequency log power below which to reject as drift without neural activity
RELAX_cfg.ExtremeBlinkShiftThreshold=3; % How many MAD from the median across blink affected epochs to exclude as extreme data 
% (applies the higher value out of this value and the
% RELAX_cfg.ExtremeVoltageShiftThreshold above as the
% threshold, which caters for the fact that blinks don't affect
% the median, so without this, if data is clean and blinks are
% large, blinks can get excluded as extreme outliers)
            
% Clean periods that last for a shorter duration than the following value to be marked as artifacts, 
% and pad short artifact periods out into artifact periods of at least the following length when 
% they are shorter than this value to reduce rank deficiency issues in MWF cleaning). 
% Note that it's better to include clean periods in the artifact mask rather than the including artifact in the clean mask.
RELAX_cfg.MinimumArtifactDuration=1200; % in ms. It's better to make this value longer than 1000ms, as doing so will catch diminishing artifacts that aren't detected in a neighbouring 1000ms period, which might still be bad
RELAX_cfg.MinimumBlinkArtifactDuration=800; % blink marking is based on the maximum point of the blink rather than the 1000ms divisions for muscle artifacts, so this can be shorter than the value above (blinks do not typically last >500ms)

RELAX_cfg.BlinkElectrodes={'Fp1';'Fp2';'F3';'Fz';'F4'}; % sets the electrodes to average for blink detection using the IQR method. These should be frontal electrodes maximally affected by blinks. The order is the order of preference for icablinkmetrics.
% A single HOEG electrode for each side is selected by the script, prioritized in the following order (if the electrode in position 1 isn't present, the script will check for electrode in position 2, and so on...).
RELAX_cfg.HEOGLeftpattern = ["F7","F3","T3"]; % sets left side electrodes to use for horizontal eye movement detection. These should be lateral electrodes maximally effected by blinks.
RELAX_cfg.HEOGRightpattern = ["F8","F4","T4"]; % sets right side electrodes to use for horizontal eye movement detection. These should be lateral electrodes maximally effected by blinks.
RELAX_cfg.BlinkMaskFocus=150; % this value deciEdes how much data before and after the right and left base of the eye blink to mark as part of the blink artifact window. 
% I found 100ms on either side of the blink bases works best with a delay of 7 on the MWF. However, it also seemed to create too short artifact masks at times, which may lead to insufficient rank for MWF, so I left the default as 150ms.
RELAX_cfg.HorizontalEyeMovementType=2; % 1 to use the IQR method, 2 to use the MAD method for identifying threshold. IQR method less effective for smaller sample sizes (shorter files).
RELAX_cfg.HorizontalEyeMovementThreshold=2; % MAD deviation from the median that will be marked as horizontal eye movement if both lateral electrodes show activity above this for a certain duration (duration set below).
RELAX_cfg.HorizontalEyeMovementThresholdIQR=1.5; % If IQR method set above, IQR deviation that will be marked as horizontal eye movement if both lateral electrodes show activity above this for a certain duration (duration set below).
RELAX_cfg.HorizontalEyeMovementTimepointsExceedingThreshold=25; % The number of timepoints (ms) that exceed the horizontal eye movement threshold within the test period (set below) before the period is marked as horizontal eye movement.
RELAX_cfg.HorizontalEyeMovementTimepointsTestWindow=(2*RELAX_cfg.HorizontalEyeMovementTimepointsExceedingThreshold)-1; % Window duration to test for horizontal eye movement, set to 2x the value above by default.
RELAX_cfg.HorizontalEyeMovementFocus=200; % Buffer window, masking periods earlier and later than the time where horizontal eye movements exceed the threshold.

% if (RELAX_cfg.Do_MWF_Once+RELAX_cfg.Do_MWF_Twice+RELAX_cfg.Do_MWF_Thrice)>0
%     RELAX_cfg.LowPassFilterBeforeMWF='no'; % set as no for the updated implementation
% elseif (RELAX_cfg.Do_MWF_Once+RELAX_cfg.Do_MWF_Twice+RELAX_cfg.Do_MWF_Thrice)==0
%     RELAX_cfg.LowPassFilterBeforeMWF='yes';
% end
RELAX_cfg.LowPassFilterBeforeMWF='yes';

% avoiding low pass filtering prior to MWF reduces chances of rank deficiencies increasing potential values for MWF delay period 
% (downsampling the data after filtering also reduces the chances of rank deficiencies) 
RELAX_cfg.DownSample='yes'; % set to 'yes' if you wish to downsample the data
RELAX_cfg.DownSample_to_X_Hz=250; % frequency to downsample to (in samples per second / Hz) - 降采样到250Hz

RELAX_cfg.FilterType='Butterworth'; % set as 'pop_eegfiltnew' to use EEGLAB's filter or 'Butterworth' to use Butterworth filter
RELAX_cfg.causal_or_acausal_filter='acausal'; % set as 'acausal' or 'causal'. 
% Acausal filters are typical, and avoid filter distortions affecting data only forwards in time, whereas causal filters are less typical, cause
% filter distortions only forwards in time, but can protect against spurious conclusions that neural activity precedes stimuli due to filter
% distortions being projected back from post-stimulus activity to pre-stimulus periods. See: https://doi.org/10.3389/fpsyg.2012.00233
RELAX_cfg.HighPassFilter=1; % Sets the high pass filter. 1Hz is best for ICA decomposition if you're examining just oscillatory data, 0.25Hz has been suggested to be the highest before ERPs are adversely affected by filtering 
%(but at least two studies recently have shown better detection of experimental effects with high-pass set at 0.5Hz even for ERPs, and I find a minority of my files show drift at 0.3Hz).
RELAX_cfg.LowPassFilter=47; % Low pass filter at 47Hz (filter range: 1-47Hz). Note: If you filter out data below 75Hz, you can't use the objective muscle detection method, but 47Hz is acceptable for most analyses.

RELAX_cfg.NotchFilterType='Butterworth'; % set as 'Butterworth' to use Butterworth filter or 'ZaplinePlus' to use ZaplinePlus. ZaplinePlus works best on data sampled at 512Hz or below, consider downsampling if above this.
RELAX_cfg.LineNoiseFrequency=50; % Frequencies for bandstop filter in order to address line noise (set to 60 in countries with 60Hz line noise, and 50 in countries with 50Hz line noise).

RELAX_cfg.ElectrodesToDelete={};
% If your EEG recording includes non-scalp electrodes or electrodes that you want to delete before cleaning, you can set them to be deleted here. 
% The RELAX cleaning pipeline does not need eye, heart, or mastoid electrodes for effective cleaning.

RELAX_cfg.KeepAllInfo=0; % setting this value to 1 keeps all the details from the MWF pre-processing and MWF computation. Helpful for debugging if necessary but makes for large file sizes.
RELAX_cfg.saveextremesrejected=0; % setting this value to 1 tells the script to save the data after only filtering, extreme channels have been rejected and extreme periods have been noted
RELAX_cfg.saveround1=0; % setting this value to 1 tells the script to save the first round of MWF pre-processing
RELAX_cfg.saveround2=0; % setting this value to 1 tells the script to save the second round of MWF pre-processing
RELAX_cfg.saveround3=1; % setting this value to 1 tells the script to save the third round of MWF pre-processing

RELAX_cfg.OnlyIncludeTaskRelatedEpochs=0; % If this =1, the MWF clean and artifact templates will only include data within 5 seconds of a task trigger (other periods will be marked as NaN, which the MWF script ignores).

RELAX_cfg.MuscleSlopeThreshold=-0.31; %log-frequency log-power slope threshold for muscle artifact . Less stringent = -0.31, Middle Stringency = -0.59 or more stringent = -0.72, more negative thresholds remove more muscle.
RELAX_cfg.MaxProportionOfDataCanBeMarkedAsMuscle=0.50;  % Maximum amount of data periods to be marked as muscle artifact for cleaning by the MWF. You want at least a reasonable amount of both clean and artifact templates for effective cleaning.
% I set this reasonably high, because otherwise muscle artifacts could considerably influence the clean mask and add noise into the data
RELAX_cfg.ProportionOfMuscleContaminatedEpochsAboveWhichToRejectChannel=0.05; % If the proportion of epochs showing muscle activity from an electrode is higher than this, the electrode is deleted. 
% Set muscle proportion before deletion to 1 to not delete electrodes based on muscle activity
RELAX_cfg.ProportionOfExtremeNoiseAboveWhichToRejectChannel=0.05; % If the proportion of all epochs from a single electrode that are marked as containing extreme artifacts is higher than this, the electrode is deleted

RELAX_cfg.MaxProportionOfElectrodesThatCanBeDeleted=0.20; % Sets the maximum proportion of electrodes that are allowed to be deleted after PREP's bad electrode deletion step
RELAX_cfg.InterpolateRejectedElectrodesAfterCleaning='yes'; % Interpolate rejected electrodes back into the data after each file has been cleaned and before saving the cleaned data?

RELAX_cfg.MWFDelayPeriod_for_eye_movements=4; % The MWF includes both spatial and temporal information when filtering out artifacts. Longer delays apparently improve performance. 
RELAX_cfg.MWFDelayPeriod_for_muscle_artifacts=6; % The MWF includes both spatial and temporal information when filtering out artifacts. Longer delays apparently improve performance.
RELAX_cfg.MWF_delay_spacing_for_eye_movements=8; % set how sparsely the delay stacking is spread when cleaning eye movements.
RELAX_cfg.MWF_delay_spacing_for_muscle_artifacts=1; % set how sparsely the delay stacking is spread when cleaning muscle activity.
% this interacts with the MWFDelayPeriod: the MWFDelayPeriod sets
% how many consecutive samples before and after each timepoint are included 
% in the MWF model (so for example, MWFDelayPeriod = 12 will include 25
% timepoints, with 12 before and 12 after each timepoint included in the
% model). The MWF_delay_spacing sets how sparsely each of the consecutive
% samples are spread. So for example, MWF_delay_spacing = 5 and 
% MWFDelayPeriod = 5 will mean that the MWF cleaning will characterise 5
% separate timepoints before and after each timepoint, with each timepoint 
% separated by 5 samples, for a total of 55 timepoints. Our informal
% testing suggests that a delay period of 8 and a delay spacing of 16 is
% optimal for addressing eye movement artifacts when data are sampled at 
% 1000Hz, possibly reflecting that characterising ~300ms of the data is
% optimal for modelling and cleaning the slower blink activity. In contrast,
% our informal tests showed that for muscle artifacts, a delay spacing of 2 
% and a delay period of ~12 seems best when data are sampled at 1000Hz 
% is better due to the higher frequency nature of muscle artifacts.

%% Added structs for rejecting CRAP and non-task areas
RELAX_cfg.RejNontask = false;
RELAX_cfg.minimum_break_length = 2000; % Breaks are defined as periods of time of at least this length without an event code 
RELAX_cfg.break_ignore_codes = setdiff(1:160,[60 61 62 63 64 65 66 67 142 143 144 145 160 200]); % List of event codes that might occur during a break and should be ignored
RELAX_cfg.break_buffer = 1500; % Buffer time at beginning and end of each break 

RELAX_cfg.RejCrap = false;
RELAX_cfg.reject_short_periods = 1000; % Periods between artifacts that are less than this duration will be rejected
% AR_parameters只在RejCrap=true时使用
RELAX_cfg.AR_parameters = [];
if RELAX_cfg.RejCrap
    % 只有在RejCrap=true时才尝试读取文件
    ar_file = fullfile(base_dir, '预处理/matlab/配置环境', 'ICA_Continuous_AR.xlsx');
    if exist(ar_file, 'file')
        try
            RELAX_cfg.AR_parameters = readtable(ar_file);
        catch ME
            % 如果readtable失败，尝试使用xlsread（旧版本MATLAB）或直接设为空
            warning('无法读取ICA_Continuous_AR.xlsx文件: %s', ME.message);
            try
                % 尝试使用xlsread（如果可用）
                [num, txt, raw] = xlsread(ar_file);
                if ~isempty(raw)
                    % 将raw转换为table格式（简单处理）
                    RELAX_cfg.AR_parameters = [];
                    warning('使用xlsread读取，但无法转换为table格式，AR_parameters设为空');
                else
                    RELAX_cfg.AR_parameters = [];
                end
            catch
                RELAX_cfg.AR_parameters = [];
                warning('无法读取ICA_Continuous_AR.xlsx文件，AR_parameters设为空');
            end
        end
    else
        warning('ICA_Continuous_AR.xlsx文件不存在，但RejCrap=true，可能需要此文件');
    end
end

%% Set threshold for blink detection
RELAX_cfg.BlinkDetectThreshould=1.5;
%% Whether to view EEG after each step
RELAX_cfg.PlotCRAPRejection = false;
RELAX_cfg.PlotAfterExtremeRejection = true;
RELAX_cfg.PlotAfterMwf1 = true;
RELAX_cfg.PlotAfterMwf2 = true;
RELAX_cfg.PlotAfterMwf3 = true;
RELAX_cfg.PlotAfterwICA = true;

%% Check for dependencies:

eeglabPath = fileparts(which('eeglab'));
MWFPluginPath=strcat(eeglabPath,'\plugins\mwf-artifact-removal-master\');
addpath(genpath(MWFPluginPath));
% if (exist('mwf_process_sparse','file')==0)
%     warndlg('MWF toolbox may not be updated to latest version in EEGLAB plugins folder. Toolbox can be installed from: "https://github.com/exporl/mwf-artifact-removal"','MWF Cleaning Not Available');
% end

toolboxlist=ver;
if isempty(find(strcmp({toolboxlist.Name}, 'Signal Processing Toolbox')==1, 1))
    warndlg('Signal Processing Toolbox may not be installed. Toolbox can be installed through MATLAB "Add-Ons" button','Signal Processing Toolbox not installed');
end
if isempty(find(strcmp({toolboxlist.Name}, 'Wavelet Toolbox')==1, 1))
    warndlg('Wavelet Toolbox may not be installed. Toolbox can be installed through MATLAB "Add-Ons" button','Wavelet Toolbox not installed');
end
if isempty(find(strcmp({toolboxlist.Name}, 'Statistics and Machine Learning Toolbox')==1, 1))
    warndlg('Statistics and Machine Learning Toolbox may not be installed. Toolbox can be installed through MATLAB "Add-Ons" button','Statistics and Machine Learning Toolbox not installed');
end

PluginPath=strcat(eeglabPath,'\plugins\');
PluginList=dir(PluginPath);

if (exist('iclabel','file')==0)
    warndlg('ICLabel may not be installed. Plugin can be installed via EEGLAB: "File" > "Manage EEGLAB Extensions"','ICLabel not installed');
end

if (exist('findNoisyChannels','file')==0)
    warndlg('PrepPipeline may not be installed or the folder path for Prep has not been set in MATLAB. Plugin can be installed via EEGLAB: "File" > "Manage EEGLAB Extensions"','PrepPipeline might not be installed');
end

if (exist('ft_freqanalysis','file')==0)
    warndlg('fieldtrip may not be installed, or the folder path for fieldtrip has not been set in MATLAB. Plugin can be installed via EEGLAB: "File" > "Manage EEGLAB Extensions"','fieldtrip might not be installed');
end

if (strcmp(RELAX_cfg.ICA_method,'fastica_symm')||strcmp(RELAX_cfg.ICA_method,'fastica_defl')) && (exist('fastica','file')==0) 
    warndlg('FastICA may not be installed, or the folder path for FastICA has not been set in MATLAB. Plugin can be installed from: "http://research.ics.aalto.fi/ica/fastica/code/dlcode.shtml"','FastICA might not be installed');
end

if (strcmp(RELAX_cfg.ICA_method,'cudaica')) && (exist('cudaica','file')==0)
    warndlg('CudaICA may not be installed. Instructions for installation can be found at: "https://sccn.ucsd.edu/wiki/Makoto%27s_useful_EEGLAB_code". Warning - installation can be difficult','CudaICA not installed');
end

if (strcmp(RELAX_cfg.ICA_method,'amica')) && (exist('runamica15','file')==0)
    warndlg('AMICA may not be installed. Plugin can be installed via EEGLAB: "File" > "Manage EEGLAB Extensions"','AMICA not installed');
end

if (strcmp(RELAX_cfg.NotchFilterType,'ZaplinePlus')) && (exist('clean_data_with_zapline_plus_eeglab_wrapper','file')==0)
    warndlg('ZaplinePlus may not be installed. Plugin can be installed via EEGLAB: "File" > "Manage EEGLAB Extensions"','ZaplinePlus not installed');
end

%% Notes on the above parameter settings:
% OnlyIncludeTaskRelatedEpochs: this means the MWF cleaning templates 
% won't be distracted by potential large artifacts outside of task related
% periods. However, it also may mean that event related periods are
% included in the artifact template (to be removed). If artifact masks land
% disproportionately around triggers (or certain types of triggers), my
% sense is that all the EEG activity time locked to that trigger will be
% considered an artifact and filtered out by the MWF (including ERPs),
% potentially reducing your ERP for example. An alternative solution to
% this would be to record a sufficient amount of activity before / after
% the task related activity, which includes all the same artifacts as
% within the task, but also a sufficient amount of clean data. Then use
% this data to create the artifact masks (then perhaps marking the task 
% related data as only either clean, or NaNs if they contain artifacts
% (which will be cleaned but aren't thought of as artifacts for the
% artifact template). This would prevent the ERP activity of interest from
% being included in the artifact tempalte (and potentially cleaned)

% Delay periods >5 can lead to generalised eigenvector rank deficiency
% in some files, and if this occurs cleaning is ineffective. Delay
% period = 5 was used by Somers et al (2018). The rank deficiency is
% likely to be because data filtering creates a temporal
% dependency between consecutive datapoints, reducing their
% independence when including the temporal aspect in the MWF
% computation. To address this, the MWF function attempts MWF cleaning
% at the delay period set above, but if rank deficiency occurs,
% it reduces the delay period by 1 and try again (for 3
% iterations).

% Using robust detrending (which does not create any temporal
% dependence,unlike filtering) may be an alternative which avoids rank
% deficiency (but our initial test suggested this led to worse cleaning
% than filtering)

% MuscleSlopeThreshold: (-0.31 = data from paralysed participants showed no
% independent components with a slope value more positive than this (so
% excluding slopes above this threshold means only excluding data that we
% know must be influenced by EMG). Using -0.31 as the threshold means
% possibly leaving low level EMG data in, and only eliminating the data we
% know is definitely EMG)
% (-0.59 is where the histograms between paralysed ICs and EMG ICs cross,
% so above this value contains a very small amount of the brain data, 
% and over 50% of the EMG data. Above this point, data is more likely to be
% EMG than brain)
% (-0.72 is the maximum of the histogram of the paralysed IC data, so
% excluding more positive values than this will exclude most of the EMG
% data, but also some brain data).

% Fitzgibbon, S. P., DeLosAngeles, D., Lewis, T. W., Powers, D. M. W., Grummett, T. S., Whitham, E. M., ... & Pope, K. J. (2016). Automatic determination of EMG-contaminated components and validation of independent component analysis using EEG during pharmacologic paralysis. Clinical Neurophysiology, 127(3), 1781-1793.

%% RUN SCRIPT BELOW:

RELAX_cfg.FilesToProcess=1:numel(RELAX_cfg.files); % Set which files to process

% ========== 是否在处理完成后自动合并同一被试的vid文件 ==========
RELAX_cfg.MergeVidFilesAfterProcessing = 1; % 1 = 自动合并, 0 = 不合并

[RELAX_cfg, FileNumber, CleanedMetrics, RawMetrics, ...
    RELAXProcessingRoundOneAllParticipants, RELAXProcessingRoundTwoAllParticipants, ...
    RELAXProcessing_wICA_AllParticipants,RELAXProcessing_ICA_AllParticipants, ...
    RELAXProcessingRoundThreeAllParticipants, RELAX_issues_to_check, ...
    RELAX_issues_to_check_2nd_run, RELAXProcessingExtremeRejectionsAllParticipants] = RELAX_Wrapper (RELAX_cfg);

%% ========== 自动合并同一被试的vid文件（如果启用） ==========
if RELAX_cfg.MergeVidFilesAfterProcessing == 1
    fprintf('\n=== 开始合并同一被试的vid文件 ===\n');
    
    % 获取base_dir（从RELAX_cfg.myPath推断）
    my_path = RELAX_cfg.myPath;
    % 从路径中提取base_dir（假设路径格式为：base_dir/data/...）
    path_parts = strsplit(my_path, filesep);
    base_dir_idx = find(strcmp(path_parts, 'data'), 1) - 1;
    if base_dir_idx > 0
        base_dir = strjoin(path_parts(1:base_dir_idx), filesep);
    else
        % 如果找不到，使用默认路径
        base_dir = '<DATA_ROOT>';
    end
    
    % 添加合并脚本路径
    merge_script_path = fullfile(base_dir, '预处理/matlab/实验1/code3');
    if exist(merge_script_path, 'dir')
        addpath(merge_script_path);
    end
    
    % 调用合并函数
    try
        % 设置合并所需的路径
        cleaned_data_dir = fullfile(RELAX_cfg.myPath, 'RELAXProcessed', 'Cleaned_Data');
        merged_output_dir = fullfile(RELAX_cfg.myPath, 'RELAXProcessed', 'Cleaned_Data_Merged');
        
        % 检查输入目录是否存在
        if exist(cleaned_data_dir, 'dir')
            fprintf('合并输入目录: %s\n', cleaned_data_dir);
            fprintf('合并输出目录: %s\n', merged_output_dir);
            
            % 调用合并脚本的核心逻辑
            cd(cleaned_data_dir);
            all_files = dir('*_RELAX.set');
            
            if ~isempty(all_files)
                % 提取所有唯一的被试ID
                subject_ids = {};
                for i = 1:length(all_files)
                    filename = all_files(i).name;
                    parts = strsplit(filename, '_');
                    if length(parts) >= 2
                        subject_id = parts{1};
                        if ~ismember(subject_id, subject_ids)
                            subject_ids{end+1} = subject_id;
                        end
                    end
                end
                subject_ids = sort(subject_ids);
                
                fprintf('找到 %d 个被试需要合并\n', length(subject_ids));
                
                % 创建输出目录
                if ~exist(merged_output_dir, 'dir')
                    mkdir(merged_output_dir);
                end
                
                % 处理每个被试
                for sub_idx = 1:length(subject_ids)
                    subject_id = subject_ids{sub_idx};
                    fprintf('  处理被试 %s (%d/%d)...\n', subject_id, sub_idx, length(subject_ids));
                    
                    try
                        % 查找该被试的所有vid文件
                        pattern = [subject_id '_vid*_RELAX.set'];
                        vid_files = dir(fullfile(cleaned_data_dir, pattern));
                        
                        if isempty(vid_files)
                            continue;
                        end
                        
                        % 提取vid编号并排序
                        vid_numbers = [];
                        vid_file_list = {};
                        for i = 1:length(vid_files)
                            filename = vid_files(i).name;
                            parts = strsplit(filename, '_');
                            if length(parts) >= 3
                                vid_str = parts{2};
                                vid_num = str2double(vid_str(4:end));
                                if ~isnan(vid_num)
                                    vid_numbers(end+1) = vid_num;
                                    vid_file_list{end+1} = filename;
                                end
                            end
                        end
                        
                        [sorted_vids, sort_idx] = sort(vid_numbers);
                        vid_file_list = vid_file_list(sort_idx);
                        
                        % 按顺序加载并合并
                        EEG_merged = [];
                        total_samples = 0;
                        
                        for vid_idx = 1:length(vid_file_list)
                            vid = sorted_vids(vid_idx);
                            filename = vid_file_list{vid_idx};
                            
                            EEG = pop_loadset('filename', filename, 'filepath', cleaned_data_dir);
                            
                            % 确保事件信息包含vid标记
                            has_vid_marker = false;
                            if isfield(EEG, 'event') && ~isempty(EEG.event)
                                for e = 1:length(EEG.event)
                                    if (isfield(EEG.event(e), 'videoIndex') && EEG.event(e).videoIndex == vid) || ...
                                       (isfield(EEG.event(e), 'vid') && EEG.event(e).vid == vid)
                                        has_vid_marker = true;
                                        break;
                                    end
                                end
                            end
                            
                            if ~has_vid_marker
                                if isempty(EEG.event)
                                    EEG.event = struct('type', {}, 'latency', {}, 'duration', {}, 'videoIndex', {}, 'vid', {});
                                end
                                vid_event = struct();
                                vid_event.type = sprintf('vid%02d', vid);
                                vid_event.latency = 1;
                                vid_event.duration = 0;
                                vid_event.videoIndex = vid;
                                vid_event.vid = vid;
                                EEG.event(end+1) = vid_event;
                            end
                            
                            % 调整事件latency
                            if ~isempty(EEG.event)
                                for e = 1:length(EEG.event)
                                    EEG.event(e).latency = EEG.event(e).latency + total_samples;
                                end
                            end
                            
                            % 合并数据
                            if isempty(EEG_merged)
                                EEG_merged = EEG;
                                total_samples = EEG.pnts;
                            else
                                EEG_merged.data = [EEG_merged.data, EEG.data];
                                EEG_merged.pnts = size(EEG_merged.data, 2);
                                total_samples = EEG_merged.pnts;
                                if ~isempty(EEG.event)
                                    EEG_merged.event = [EEG_merged.event, EEG.event];
                                end
                            end
                        end
                        
                        % 更新合并后的EEG结构
                        EEG_merged.xmax = (EEG_merged.pnts - 1) / EEG_merged.srate;
                        EEG_merged.times = (0:EEG_merged.pnts-1) / EEG_merged.srate * 1000;
                        
                        % 添加合并信息
                        EEG_merged.merged_info = struct();
                        EEG_merged.merged_info.subject_id = subject_id;
                        EEG_merged.merged_info.vid_list = sorted_vids;
                        EEG_merged.merged_info.vid_count = length(sorted_vids);
                        EEG_merged.merged_info.total_duration = EEG_merged.pnts / EEG_merged.srate;
                        
                        % 保存合并后的文件
                        output_filename = sprintf('%s_RELAX_merged.set', subject_id);
                        EEG_merged = eeg_checkset(EEG_merged);
                        pop_saveset(EEG_merged, 'filename', output_filename, 'filepath', merged_output_dir);
                        
                        fprintf('    ✓ 成功合并，包含 %d 个vid，总时长 %.2f 秒\n', ...
                            length(sorted_vids), EEG_merged.pnts/EEG_merged.srate);
                    catch ME
                        warning('合并被试 %s 时出错: %s', subject_id, ME.message);
                    end
                end
                
                fprintf('\n✓ 合并完成！输出目录: %s\n', merged_output_dir);
            else
                warning('未找到RELAX处理后的文件');
            end
        else
            warning('清理后的数据目录不存在: %s', cleaned_data_dir);
        end
    catch ME
        warning('合并vid文件时出错: %s', ME.message);
    end
end

