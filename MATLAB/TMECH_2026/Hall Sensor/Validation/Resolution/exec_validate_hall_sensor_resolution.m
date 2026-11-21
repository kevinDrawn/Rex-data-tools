%EXEC_VALIDATE_HALL_SENSOR_RESOLUTION Measure 3-sigma static Hall angle noise.
% Select a stationary recording or set RESOLUTION_TIME_RANGE to a stationary interval.

%% Input settings
REX_LOGGING_PATH = "D:\park\01. STEAM\[Paper] Paperwork\2026_TMECH\TMECH Review\Bench-Top Experiment\Hall sensor Validation\Resolution\rex_live_20261110_193255_206.csv";

% Options passed to readtable, e.g. {'ReadVariableNames', false} for headerless CSVs.
REX_CSV_READ_OPTIONS = {};
REX_ANGLE_SIDE = 'Left'; % 'Left' or 'Right'
REX_TIME_SCALE_TO_SECONDS = 0.001; % Rex timestamps are milliseconds.
RESOLUTION_TIME_RANGE = [0 1600]; % [start end] in seconds from recording start; [] uses the full recording.

%% Include classes relative to this script
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

%% Rex: assign 1-based CSV column numbers
rexPacker = DataPacker('Rex');
rexColumnMap = rexPacker.getColumnMap();
rexColumnMap.Time = 1;
rexColumnMap.Left.Angle = 4;
rexColumnMap.Right.Angle = 5;
rexColumnMap.Assisted.Angle = 6;
rexColumnMap.Left.Torque = 8;
rexColumnMap.Right.Torque = 9;
rexColumnMap.Left.TA = 10;
rexColumnMap.Left.GM = 11;
rexColumnMap.Right.TA = 12;
rexColumnMap.Right.GM = 13;
rexColumnMap.sync_state = 14;

%% Load the Rex recording and save beside the source CSV
if strlength(REX_LOGGING_PATH) == 0 || ~isfile(REX_LOGGING_PATH)
    error('HallValidation:MissingRexCSV', ...
        'Set REX_LOGGING_PATH to an existing Rex CSV file.');
end

rexData = rexPacker.pack(REX_LOGGING_PATH, rexColumnMap, ...
    REX_CSV_READ_OPTIONS{:});
[rexDirectory, rexName] = fileparts(REX_LOGGING_PATH);
REX_MAT_PATH = fullfile(rexDirectory, rexName + ".mat");
rexPacker.saveMat(rexData, REX_MAT_PATH);
fprintf('Rex: %d samples saved to %s\n', numel(rexData.Time), char(REX_MAT_PATH));

%% Calculate 3-sigma resolution from the raw static ankle angle
REX_ANGLE_SIDE = validatestring(REX_ANGLE_SIDE, {'Left', 'Right'});
rexTime = (double(rexData.Time) - double(rexData.Time(1))) * REX_TIME_SCALE_TO_SECONDS;
rexAngle = rexData.(REX_ANGLE_SIDE).Angle;

timeRange = RESOLUTION_TIME_RANGE;
if isempty(timeRange)
    timeRange = [rexTime(1), rexTime(end)];
end
validateattributes(timeRange, {'numeric'}, {'vector', 'numel', 2, 'real', 'finite', 'increasing'});

selected = rexTime >= timeRange(1) & rexTime <= timeRange(2);
valid = selected & isfinite(rexAngle);
sampleCount = nnz(valid);
if sampleCount < 2
    error('HallValidation:InsufficientResolutionSamples', ...
        'The static interval must contain at least two finite angle samples.');
end

staticAngles = double(rexAngle(valid));
meanAngleDeg = mean(staticAngles);
sigmaDeg = std(staticAngles, 0); % Sample standard deviation (N - 1).
resolutionDeg = 3 * sigmaDeg;

fprintf('%s Hall static interval: %.3f to %.3f s (%d samples).\n', ...
    REX_ANGLE_SIDE, rexTime(find(valid, 1, 'first')), ...
    rexTime(find(valid, 1, 'last')), sampleCount);
fprintf('Mean: %.6f deg | Sigma: %.6f deg | 3-sigma resolution: %.6f deg\n', ...
    meanAngleDeg, sigmaDeg, resolutionDeg);

%% Plot the selected ankle angle over the analysis interval
plotter = DataPlotter();
[resolutionFigure, resolutionAxes] = plotter.plotGroups( ...
    rexTime, {rexAngle}, timeRange, 'vertical', ...
    'Titles', {sprintf('%s Hall ankle angle (3-sigma resolution: %.4f deg)', ...
        REX_ANGLE_SIDE, resolutionDeg)}, ...
    'YLabels', {'Hall sensor angle (deg)'}, 'XLabel', 'Time (s)', ...
    'Colors',{[0, 0, 0]});
