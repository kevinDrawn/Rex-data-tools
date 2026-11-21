%% Settings: retain Baseline column even when Hall baseline data are absent
META_LOGGING_PATH = "D:\park\01. STEAM\[Paper] Paperwork\2026_TMECH\TMECH Review\Data\TMECH_meta_data\exp_data.mat";
PAW_ROOT_DIRECTORY = "D:\park\01. STEAM\[Paper] Paperwork\2026_TMECH\TMECH Review\Spatiotemporal_Index\Paw_clearance";
OUTPUT_DIRECTORY = fullfile(fileparts(PAW_ROOT_DIRECTORY),'Dorsiflexion_angle','_collected');
CONDITIONS = ["Baseline","IE","IR","LE","LR"];
ANGLE_SIDE = 'left';
% Optional additional exp_data MAT with Baseline Hall angle and IC/TO events.
% Same record schema as META_LOGGING_PATH; record.cond = "Baseline".
BASELINE_META_PATH = "";

%% Include shared classes relative to this exec script
% Locate MATLAB/Class from this script; sections use Current Folder.
filePath = mfilename('fullpath');
execDirectory = pwd;
if ~isempty(filePath)
    execDirectory = fileparts(filePath);
end
matlabDirectory = execDirectory;
while ~isfile(fullfile(matlabDirectory, 'Class', 'DataPacker.m'))
    parentDirectory = fileparts(matlabDirectory);
    if isempty(parentDirectory) || strcmp(parentDirectory, matlabDirectory)
        error('RexTools:MissingClassDirectory', ...
            'Cannot find MATLAB/Class above %s. Set Current Folder inside this MATLAB project.', execDirectory);
    end
    matlabDirectory = parentDirectory;
end
classDirectory = fullfile(matlabDirectory, 'Class');
addpath(classDirectory);

%% Use rat folder order so both MAT files have identical rat and condition axes
folders=dir(PAW_ROOT_DIRECTORY); rats=string({folders([folders.isdir]).name})';
rats=rats(~cellfun(@isempty,regexp(cellstr(rats),'^#\d+$','once')));
[~,order]=sort(str2double(extractAfter(rats,1))); rats=rats(order);
swingDorsiflexionMetrics = GaitMetricCollector.collectDorsiflexion( ...
    META_LOGGING_PATH,BASELINE_META_PATH,ANGLE_SIDE,rats,CONDITIONS);
GaitMetricCollector.saveMetric(swingDorsiflexionMetrics,fullfile(OUTPUT_DIRECTORY,'peak_swing_dorsiflexion_plot_data.mat'));
for condition = CONDITIONS
    conditionData = swingDorsiflexionMetrics.Conditions.(condition);
    conditionData.Condition = condition;
    conditionData.AngleConvention = swingDorsiflexionMetrics.AngleConvention;
    GaitMetricCollector.saveMetric(conditionData,fullfile(OUTPUT_DIRECTORY,condition+"_peak_swing_dorsiflexion_metrics.mat"));
end
fprintf('\nPeak swing dorsiflexion: mean of per-swing minimum Hall angles (deg). Lower = greater dorsiflexion.\n');
disp(swingDorsiflexionMetrics.RatMeanTable);
disp(swingDorsiflexionMetrics.GroupSummary);
if any(swingDorsiflexionMetrics.GroupSummary.N==0)
    fprintf('Missing conditions remain NaN / N=0. Baseline is not estimated from other conditions.\n');
end
writetable(swingDorsiflexionMetrics.RatMeanTable,fullfile(OUTPUT_DIRECTORY,'peak_swing_dorsiflexion_by_rat.csv'));
writetable(swingDorsiflexionMetrics.GroupSummary,fullfile(OUTPUT_DIRECTORY,'peak_swing_dorsiflexion_group.csv'));
writetable(swingDorsiflexionMetrics.PerSwing,fullfile(OUTPUT_DIRECTORY,'peak_swing_dorsiflexion_all_swings.csv'));
