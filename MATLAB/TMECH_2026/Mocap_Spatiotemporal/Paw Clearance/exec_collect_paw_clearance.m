%% Input settings
ROOT_DIRECTORY = "D:\park\01. STEAM\[Paper] Paperwork\2026_TMECH\TMECH Review\Spatiotemporal_Index\Paw_clearance";
OUTPUT_DIRECTORY = fullfile(ROOT_DIRECTORY, '_collected');
CONDITIONS = {'IE','LE','LR'};
EXPECTED_RAT_COUNT = 6;
INCLUDE_OPEN_SWINGS = true; % Retain observed trailing swings, as in individual analyses.
% All finite cycles are used; there is no automatic outlier deletion.

%% Include shared classes from the MATLAB project
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

%% Collect all per-cycle result MAT files, including subfolders 1 / 2
collector = PawClearanceCollector();
pawCollection = collector.collect(ROOT_DIRECTORY, 'Conditions', CONDITIONS, ...
    'IncludeOpenSwings', INCLUDE_OPEN_SWINGS, 'ExpectedRatCount', EXPECTED_RAT_COUNT);
collector.printSummary(pawCollection);

%% Paired condition statistics on rat means (requires Statistics Toolbox)
pawStatistics = collector.analyzeStatistics(pawCollection);
pawCollection.Statistics = pawStatistics;

%% Save one combined struct and one struct per condition
if ~isfolder(OUTPUT_DIRECTORY)
    [created,message] = mkdir(OUTPUT_DIRECTORY);
    if ~created
        error('PawCollector:CreateOutputFailed','Cannot create output directory: %s',message);
    end
end
collector.saveMat(pawStatistics, fullfile(OUTPUT_DIRECTORY,'paw_clearance_statistics.mat'));
writetable(pawStatistics.Pairwise,fullfile(OUTPUT_DIRECTORY,'paw_clearance_statistics.csv'));
ALL_MAT_PATH = fullfile(OUTPUT_DIRECTORY,'paw_clearance_collection_all.mat');
collector.saveMat(pawCollection, ALL_MAT_PATH);
for conditionIndex = 1:numel(pawCollection.ConditionNames)
    conditionName = char(pawCollection.ConditionNames(conditionIndex));
    conditionData = pawCollection.Conditions.(conditionName);
    conditionData.RootDirectory = pawCollection.RootDirectory;
    conditionData.IncludeOpenSwings = INCLUDE_OPEN_SWINGS;
    conditionData.WithinRatRule = pawCollection.WithinRatRule;
    conditionData.GroupRule = pawCollection.GroupRule;
    collector.saveMat(conditionData, fullfile(OUTPUT_DIRECTORY, ...
        string(conditionName) + "_paw_clearance_collection.mat"));
end

%% Plot per-condition subplots and a combined condition comparison
plotter = DataPlotter();
[individualFigure, groupFigure] = plotter.plotPawClearanceCollection(pawCollection);
drawnow;
savefig(individualFigure,fullfile(OUTPUT_DIRECTORY,'paw_clearance_individual.fig'));
exportgraphics(individualFigure,fullfile(OUTPUT_DIRECTORY,'paw_clearance_individual.png'),'Resolution',300);
savefig(groupFigure,fullfile(OUTPUT_DIRECTORY,'paw_clearance_group.fig'));
exportgraphics(groupFigure,fullfile(OUTPUT_DIRECTORY,'paw_clearance_group.png'),'Resolution',300);
fprintf('\nCollection MAT files and figures saved to %s\n', char(OUTPUT_DIRECTORY));