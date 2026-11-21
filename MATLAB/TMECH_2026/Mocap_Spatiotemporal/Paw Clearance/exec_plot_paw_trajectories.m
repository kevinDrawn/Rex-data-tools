close all

%% Settings: one rat, all conditions
ROOT_MAT_PATH = "D:\park\01. STEAM\[Paper] Paperwork\2026_TMECH\TMECH Review\Spatiotemporal_Index\Paw_clearance\#12";
CONDITIONS = {'Baseline', 'IE','IR','LE','LR'};
USE_TIME_RANGE_FILES = true; % Optional condition/recording time_range.txt: start end (seconds).
COORDINATE_REFERENCE = 'ilium_x'; % X = TO_x - IL_x; Y = TO_y - one recording-wide stance offset.
PHASE_SAMPLES = 201; % Analysis grid for phase averaging.
DISPLAY_SAMPLES = 1001; % Minimum continuous interpolation points; mean loop samples.
TRAJECTORY_X_LIMITS = [-50 50]; % mm, shared by all trajectory panels.
TRAJECTORY_Y_LIMITS = [-5 30]; % mm, relative toe height.
ENABLE_TRAJECTORY_INSPECTOR = true; % Drag XY or time to locate original samples.
INSPECT_CONDITION = 'Baseline';
CENTER_X = true; % Subtract one mean X offset per recording after IL correction.
HIDE_DUPLICATE_CONDITIONS = true; % Identical source traces need verification.
OUTPUT_DIRECTORY = fullfile(ROOT_MAT_PATH,'_toe_trajectories');

%% Classes relative to the active editor script
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

%% Load stored filtered XY coordinates and complete cycle boundaries
% *_paw_clearance.mat contains cycle indices / preceding stance ground height.
% The sibling MAT (remove _paw_clearance) contains TO_x_filtered / TO_y_filtered.
% All frames inside time_range.txt are displayed continuously; missing file uses full recording.
% Only complete cycles wholly inside the selected range enter the mean.
% The black mean uses only complete IC-to-next-IC cycles.
% X = TO_x_filtered - IL_x_filtered at each original timestamp.
% Y = TO_y_filtered - mean(GroundHeight_mm) for each recording.
% This is ONE constant offset for the full trace: shape and amplitude are unchanged.
% No IL_y subtraction; existing per-cycle peak paw-height metrics are unchanged.
% No per-cycle translation, rotation, amplitude normalization, or extra LPF.
analyzer = PawTrajectoryAnalyzer();
toeTrajectories = analyzer.collect(ROOT_MAT_PATH,'Conditions',CONDITIONS,'PhaseSamples',PHASE_SAMPLES, ...
    'CoordinateReference',COORDINATE_REFERENCE,'UseTimeRangeFiles',USE_TIME_RANGE_FILES);

%% Continuous gray recording; black cycle-averaged trajectory
% Gray: one time-ordered curve per entire source recording, all frames.
% PCHIP interpolates X(t) and Y(t) on one shared dense time grid.
% X centering subtracts one recording-wide mean; shape and amplitude are unchanged.
% No cycle splitting, per-cycle baseline reset, or forced gray-loop closure.
% Only the black mean uses complete-cycle phase normalization.
plotter = DataPlotter();
[toeFigure,toeAxes,toeTrajectoryDisplay] = plotter.plotPawTrajectories(toeTrajectories, ...
    'HideDuplicateConditions',HIDE_DUPLICATE_CONDITIONS,'DisplaySamples',DISPLAY_SAMPLES, ...
    'CenterX',CENTER_X);
set(toeAxes(isgraphics(toeAxes,'axes')), 'XLim',TRAJECTORY_X_LIMITS, ...
    'YLim',TRAJECTORY_Y_LIMITS,'XGrid','off','YGrid','off');

%% Save processed cycles, phase means, and figure
if ~isfolder(OUTPUT_DIRECTORY), mkdir(OUTPUT_DIRECTORY); end
save(fullfile(OUTPUT_DIRECTORY,'toe_trajectories.mat'),'toeTrajectories','toeTrajectoryDisplay');
savefig(toeFigure,fullfile(OUTPUT_DIRECTORY,'toe_trajectories.fig'));
exportgraphics(toeFigure,fullfile(OUTPUT_DIRECTORY,'toe_trajectories.png'),'Resolution',300);
fprintf('Toe trajectories saved to %s\n',OUTPUT_DIRECTORY);

%% Additional overlays: transparency and assistance (keep original figure)
% Same saved X/Y coordinates and full continuous traces; no additional shifts.
% Pale condition colors: continuous recording. Thick colors: cycle means.
[comparisonFigure,comparisonAxes] = plotter.plotPawTrajectoryComparisons(toeTrajectoryDisplay);
set(comparisonAxes(isgraphics(comparisonAxes,'axes')), 'XLim',TRAJECTORY_X_LIMITS, ...
    'YLim',TRAJECTORY_Y_LIMITS,'XGrid','off','YGrid','off');
savefig(comparisonFigure,fullfile(OUTPUT_DIRECTORY,'toe_trajectories_comparisons.fig'));
exportgraphics(comparisonFigure,fullfile(OUTPUT_DIRECTORY,'toe_trajectories_comparisons.png'),'Resolution',300);
exportgraphics(comparisonAxes(1),fullfile(OUTPUT_DIRECTORY,'toe_trajectories_transparency.png'),'Resolution',300);
exportgraphics(comparisonAxes(2),fullfile(OUTPUT_DIRECTORY,'toe_trajectories_assistance.png'),'Resolution',300);
fprintf('Added transparency (Baseline/IE/IR) and assistance (LE/LR) comparison plots.\n');

%% Interactive offset inspection (diagnostic selection only)
% Drag an XY box: list every matching time run and source-row range.
% Drag a time interval: highlight the same original samples in XY and IL/TO traces.
% Export selection writes separate debug files; it never excludes or edits data.
if ENABLE_TRAJECTORY_INSPECTOR
    trajectoryInspector = PawTrajectoryInspector(toeTrajectories,toeTrajectoryDisplay, ...
        'Condition',INSPECT_CONDITION,'OutputDirectory',OUTPUT_DIRECTORY);
end
