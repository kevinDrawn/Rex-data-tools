%% Settings: 6 rat-level values per condition, plus complete audit data
ROOT_DIRECTORY = "D:\park\01. STEAM\[Paper] Paperwork\2026_TMECH\TMECH Review\Spatiotemporal_Index\Paw_clearance";
OUTPUT_DIRECTORY = fullfile(ROOT_DIRECTORY,'_functional_metrics');
CONDITIONS = {'Baseline','IE','IR','LE','LR'};
PHASE_SAMPLES = 201;
% MeanTrajectoryPeakHeight: height of each rat's condition-average trajectory.
% MeanPeakPawHeight: mean of individual-cycle peak paw heights (different metric).
PRIMARY_PLOT_METRIC = 'MeanTrajectoryPeakHeight';

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

%% Collect current IL-enabled exports, respecting each time_range.txt
pawClearanceMetrics = GaitMetricCollector.collectPaw(ROOT_DIRECTORY,CONDITIONS,PHASE_SAMPLES);
pawClearanceMetrics.PrimaryPlotMetric = string(PRIMARY_PLOT_METRIC);
GaitMetricCollector.saveMetric(pawClearanceMetrics,fullfile(OUTPUT_DIRECTORY,'paw_clearance_plot_data.mat'));
for condition = string(CONDITIONS)
    conditionData.RatIDs = pawClearanceMetrics.RatIDs;
    conditionData.Condition = condition;
    for field = ["MeanPeakPawHeight","MeanTrajectoryPeakHeight","MeanTrajectoryVerticalExcursion","SwingStanceRatio"]
        conditionData.(field) = pawClearanceMetrics.(field).Conditions.(condition);
    end
    GaitMetricCollector.saveMetric(conditionData,fullfile(OUTPUT_DIRECTORY,condition+"_paw_clearance_metrics.mat"));
end
fprintf('\nHeight of each rat-level mean trajectory (mm):\n');
disp(pawClearanceMetrics.MeanTrajectoryPeakHeight.RatMeanTable);
disp(pawClearanceMetrics.MeanTrajectoryPeakHeight.GroupSummary);
fprintf('Mean of per-cycle peak paw heights (mm), for comparison:\n');
disp(pawClearanceMetrics.MeanPeakPawHeight.RatMeanTable);
disp(pawClearanceMetrics.MeanPeakPawHeight.GroupSummary);
writetable(pawClearanceMetrics.MeanTrajectoryPeakHeight.RatMeanTable,fullfile(OUTPUT_DIRECTORY,'paw_height_mean_trajectory_by_rat.csv'));
writetable(pawClearanceMetrics.MeanTrajectoryPeakHeight.GroupSummary,fullfile(OUTPUT_DIRECTORY,'paw_height_mean_trajectory_group.csv'));
writetable(pawClearanceMetrics.MeanPeakPawHeight.RatMeanTable,fullfile(OUTPUT_DIRECTORY,'paw_height_cycle_peaks_by_rat.csv'));