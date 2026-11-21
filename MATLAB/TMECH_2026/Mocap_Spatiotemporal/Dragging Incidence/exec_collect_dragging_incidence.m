%% Inputs: manually scored full-video counts and original detected MAT pairs
DRAGGING_DIRECTORY = "D:\park\01. STEAM\[Paper] Paperwork\2026_TMECH\TMECH Review\Spatiotemporal_Index\Dragging_incidence";
WORKBOOK_PATH = fullfile(DRAGGING_DIRECTORY,'261116_toe dragging incidence.xlsx');
PAW_OUTPUT_DIRECTORY = "D:\park\01. STEAM\[Paper] Paperwork\2026_TMECH\TMECH Review\Spatiotemporal_Index\Paw_clearance\_functional_metrics";
PAW_MAT_PATH = fullfile(PAW_OUTPUT_DIRECTORY,'paw_clearance_plot_data.mat');
OUTPUT_DIRECTORY = fullfile(DRAGGING_DIRECTORY,'_collected');
CONDITIONS = ["LE","LR"];

%% Include shared classes
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

%% Full-video denominator confirmed by user: include observed trailing swing
% Do not use complete IC-to-IC counts from mean trajectory averaging here.
% Existing paw MAT supplies current source-file identities, not its filtered counts.
draggingIncidence = GaitMetricCollector.collectDraggingWorkbook(WORKBOOK_PATH,PAW_MAT_PATH,CONDITIONS);
GaitMetricCollector.saveMetric(draggingIncidence,fullfile(OUTPUT_DIRECTORY,'dragging_incidence.mat'));
writetable(draggingIncidence.PerAnimalSummary,fullfile(OUTPUT_DIRECTORY,'dragging_incidence_by_rat.csv'));
writetable(draggingIncidence.GroupSummary,fullfile(OUTPUT_DIRECTORY,'dragging_incidence_group.csv'));
writetable(draggingIncidence.FileSummary,fullfile(OUTPUT_DIRECTORY,'dragging_incidence_source_counts.csv'));
for condition=CONDITIONS
    conditionData=draggingIncidence.Conditions.(condition);
    conditionData.Condition=condition;
    conditionData.Counts=draggingIncidence.PerAnimalSummary(draggingIncidence.PerAnimalSummary.Condition==condition,:);
    conditionData.DenominatorRule=draggingIncidence.DenominatorRule;
    GaitMetricCollector.saveMetric(conditionData,fullfile(OUTPUT_DIRECTORY,condition+"_dragging_incidence.mat"));
end

%% The central plotting exec reads Dragging_incidence/_collected directly.
fprintf('\nDragging incidence: full-video detected pairs, including open trailing swings.\n');
disp(draggingIncidence.PerAnimalSummary);
disp(draggingIncidence.GroupSummary);
fprintf('Numerator and denominator must cover the same scored steps. No time_range filtering applied.\n');
