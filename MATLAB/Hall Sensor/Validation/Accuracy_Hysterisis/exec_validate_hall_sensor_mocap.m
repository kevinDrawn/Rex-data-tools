%EXEC_VALIDATE_HALL_SENSOR_MOCAP Load Rex and Mocap CSVs for Hall validation.
% Set both CSV paths and column mappings, then run the entire script.
% Each MAT file contains a variable named data beside its source CSV.

%% Input settings
REX_LOGGING_PATH = "C:\Users\qoxmf\OneDrive\바탕 화면\PSH\TMECH 2026\Review\Hall sensor\Hysterisis_Accuracy\logging\rex_live_20261111_010620_728.csv";
MOCAP_LOGGING_PATH = "C:\Users\qoxmf\OneDrive\바탕 화면\PSH\TMECH 2026\Review\Hall sensor\Hysterisis_Accuracy\video\test_4\views\left\joint_data\2026-11-11 01-06-18_jointpixeldata_tracker_AK_angle_trigger.csv";

% Options passed to readtable. For CSVs without headers, use:
% {'ReadVariableNames', false}. Set NumHeaderLines as needed for Mocap.
REX_CSV_READ_OPTIONS = {};
MOCAP_CSV_READ_OPTIONS = {};

% Convert each source time unit to seconds (Rex timestamps are milliseconds).
REX_TIME_SCALE_TO_SECONDS = 0.001;
MOCAP_TIME_SCALE_TO_SECONDS = 0.001; % Mocap CSV: time_ms.
REX_ANGLE_SIDE = 'Left'; % 'Left' or 'Right'
PLOT_TIME_RANGE = []; % Seconds relative to sync onset; [] shows both full traces.
SYNC_THRESHOLD = 0.5; % sync_state > threshold means on (0/1 input).

%% Include classes relative to this script
filePath = matlab.desktop.editor.getActiveFilename;
execDirectory = fileparts(filePath);
% Accuracy_Hysterisis -> Validation -> Hall Sensor -> MATLAB
matlabDirectory = fileparts(fileparts(fileparts(execDirectory)));
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
% Optional for loading; assign the actual column for later synchronization.
rexColumnMap.sync_state = 14;

%% Mocap: replace all three NaNs with actual CSV column numbers
mocapPacker = DataPacker('Mocap_Hall');
mocapColumnMap = mocapPacker.getColumnMap();
mocapColumnMap.Time = 1;
mocapColumnMap.mocap_angle = 3;
mocapColumnMap.sync_state = 4;

%% Validate paths before loading or saving either dataset
if strlength(REX_LOGGING_PATH) == 0 || ~isfile(REX_LOGGING_PATH)
    error('HallValidation:MissingRexCSV', ...
        'Set REX_LOGGING_PATH to an existing Rex CSV file.');
end
if strlength(MOCAP_LOGGING_PATH) == 0 || ~isfile(MOCAP_LOGGING_PATH)
    error('HallValidation:MissingMocapCSV', ...
        'Set MOCAP_LOGGING_PATH to an existing Mocap CSV file.');
end

%% Load both datasets (raw time axes and signal units are preserved)
rexData = rexPacker.pack(REX_LOGGING_PATH, rexColumnMap, ...
    REX_CSV_READ_OPTIONS{:});
mocapData = mocapPacker.pack(MOCAP_LOGGING_PATH, mocapColumnMap, ...
    MOCAP_CSV_READ_OPTIONS{:});

%% Save beside each CSV using the same base name and a .mat extension
[rexDirectory, rexName] = fileparts(REX_LOGGING_PATH);
REX_MAT_PATH = fullfile(rexDirectory, rexName + ".mat");
[mocapDirectory, mocapName] = fileparts(MOCAP_LOGGING_PATH);
MOCAP_MAT_PATH = fullfile(mocapDirectory, mocapName + ".mat");

rexPacker.saveMat(rexData, REX_MAT_PATH);
mocapPacker.saveMat(mocapData, MOCAP_MAT_PATH);
fprintf('Rex: %d samples saved to %s\n', numel(rexData.Time), char(REX_MAT_PATH));
fprintf('Mocap: %d samples saved to %s\n', numel(mocapData.Time), char(MOCAP_MAT_PATH));

%% Synchronize: first observed off-to-on transition is t = 0 for each source
% Preserve the original data and saved MAT files; use separate plot time axes.
validateattributes(REX_TIME_SCALE_TO_SECONDS, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'positive'});
validateattributes(MOCAP_TIME_SCALE_TO_SECONDS, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'positive'});
validateattributes(SYNC_THRESHOLD, {'numeric'}, {'scalar', 'real', 'finite'});
REX_ANGLE_SIDE = validatestring(REX_ANGLE_SIDE, {'Left', 'Right'});

[rexTime, rexSyncIndex] = DataProcessor.alignSyncTime(rexData, ...
    REX_TIME_SCALE_TO_SECONDS, SYNC_THRESHOLD, 'Rex');
[mocapTime, mocapSyncIndex] = DataProcessor.alignSyncTime(mocapData, ...
    MOCAP_TIME_SCALE_TO_SECONDS, SYNC_THRESHOLD, 'Mocap');

fprintf('Sync onset: Rex row %d; Mocap row %d (each aligned to 0 s).\n', ...
    rexSyncIndex, mocapSyncIndex);
fprintf('Aligned time (s): Rex [%.6f, %.6f], Mocap [%.6f, %.6f]\n', ...
    rexTime(1), rexTime(end), mocapTime(1), mocapTime(end));

%% Overlay both native sample grids in one DataPlotter subplot
% No interpolation is needed for this visual comparison.
if isempty(PLOT_TIME_RANGE)
    plotTimeRange = [min(rexTime(1), mocapTime(1)), ...
        max(rexTime(end), mocapTime(end))];
else
    plotTimeRange = PLOT_TIME_RANGE;
end

plotter = DataPlotter();
rexAngle = rexData.(REX_ANGLE_SIDE).Angle;

[plotFigure, plotAxes] = plotter.plotGroups(rexTime, {rexAngle}, ...
    plotTimeRange, 'vertical', ...
    'Titles', {sprintf('Hall sensor (%s) vs Mocap', REX_ANGLE_SIDE)}, ...
    'YLabels', {'Angle (deg)'}, 'XLabel', 'Time from sync onset (s)', ...
    'Colors', {plotter.Config.Colors.(REX_ANGLE_SIDE)});
hold(plotAxes(1), 'on');

plot(plotAxes(1), mocapTime, mocapData.mocap_angle, ...
    'Color', plotter.Config.Colors.GM, ...
    'LineWidth', plotter.Config.LineWidth);
hold(plotAxes(1), 'off');
legend(plotAxes(1), {sprintf('Rex %s', REX_ANGLE_SIDE), 'Mocap'}, ...
    'Interpreter', 'none', 'Box', 'off', 'Location', 'northeastoutside');


%% Overlay both native sample grids in one DataPlotter subplot

% 올라가는 방향은 작은 원 (노란색)
% 내려가는 방향은 큰 원 (주황색)
% Hysterisis 검증
% Accuracy 동시 검증 - 왔다갔다 하면서 측정된 에러 계산