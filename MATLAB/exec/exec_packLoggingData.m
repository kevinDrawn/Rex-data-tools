%PACKLOGGINGDATA Configure the input and mapping, then run the entire script.

%% Input settings
LOGGING_PATH = "D:\park\01. STEAM\[STEAM] Animal Experiment\20261103_4ch_EMG\#39\IE\logging\rex_live_20261103_164747_195.csv";
PROJECT_TYPE = "Rex";

% Empty: save beside the CSV with the same base name.
% Alternatively, set the absolute destination .mat path.
MAT_PATH = "D:\park\01. STEAM\[STEAM] Animal Experiment\20261103_4ch_EMG\#39\IE\logging\rex_live_20261103_164747_195.mat";

% Options passed to readtable. For a CSV without a header, use:
% CSV_READ_OPTIONS = {'ReadVariableNames', false};
CSV_READ_OPTIONS = {};

% Process all four raw EMG channels before plotting their filtered envelopes.
EMG_FIELDS = {'Left.TA', 'Left.GM', 'Right.TA', 'Right.GM'};
EMG_SAMPLE_RATE_HZ = 2000; % Rex: 0.5 ms/sample; Time units set in EMGConfig.

% Plot range uses the same units as data.Time. [] plots the full recording.
PLOT_TIME_RANGE = [234678 260000]; % Example: [1000 5000] if Time is in milliseconds.
PLOT_DIRECTION = "vertical"; % 'vertical': 4-by-1; 'horizontal': 1-by-4.

%% Include classes relative to this script
filePath = matlab.desktop.editor.getActiveFilename;
execDirectory = fileparts(filePath);
classDirectory = fullfile(fileparts(execDirectory), 'Class');
addpath(classDirectory);
%% Load the project's mapping structure and enter CSV column numbers
packer = DataPacker(PROJECT_TYPE);
columnMap = packer.getColumnMap();

% REQUIRED: replace every NaN with the correct CSV column number (1-based).
columnMap.Time = 1;
columnMap.Left.Angle = 4;
columnMap.Right.Angle = 5;
columnMap.Assisted.Angle = 6;
columnMap.Left.Torque = 8;
columnMap.Right.Torque = 9;
columnMap.Left.TA = 10;
columnMap.Left.GM = 11;
columnMap.Right.TA = 12;
columnMap.Right.GM = 13;

%% Pack and export
if LOGGING_PATH == "[csv 파일 절대경로]" || strlength(LOGGING_PATH) == 0
    error('packLoggingData:MissingPath', 'Set LOGGING_PATH to the absolute CSV path.');
end
if isempty(regexp(char(LOGGING_PATH), '^(?:[A-Za-z]:[\\/]|[\\/]{2}|/)', 'once'))
    error('packLoggingData:RelativePath', 'LOGGING_PATH must be an absolute path.');
end
if strlength(MAT_PATH) == 0
    [loggingDirectory, loggingName] = fileparts(LOGGING_PATH);
    MAT_PATH = fullfile(loggingDirectory, loggingName + ".mat");
end

data = packer.pack(LOGGING_PATH, columnMap, CSV_READ_OPTIONS{:});
packer.saveMat(data, MAT_PATH);
fprintf('Saved %d samples to %s\n', numel(data.Time), char(MAT_PATH));

%% Process all EMG channels and append *_filtered fields to the MAT
processor = DataProcessor();
data = processor.processEMGMat(MAT_PATH, EMG_FIELDS, EMG_SAMPLE_RATE_HZ);
fprintf('Added filtered EMG fields for %d channels.\n', numel(EMG_FIELDS));

%% Plot the saved MAT file: angles, torques, left/right filtered EMG
loaded = load(MAT_PATH, 'data');
plotData = loaded.data;
plotter = DataPlotter();
colors = plotter.Config.Colors;

% One cell = one subplot. Each matrix column is a separate curve.
groups = { ...
    [plotData.Left.Angle, plotData.Right.Angle], ...
    [plotData.Left.Torque, plotData.Right.Torque], ...
    [plotData.Left.TA_filtered, plotData.Left.GM_filtered], ...
    [plotData.Right.TA_filtered, plotData.Right.GM_filtered]};

[plotFigure, plotAxes] = plotter.plotGroups( ...
    plotData.Time, groups, PLOT_TIME_RANGE, PLOT_DIRECTION, ...
    'Titles', {'Ankle joint angle (Left / Right)', ...
        'Ankle joint torque (Left / Right)', ...
        'Left TA / GM (filtered)', 'Right TA / GM (filtered)'}, ...
    'YLabels', {'Angle', 'Torque', 'EMG envelope (V)', 'EMG envelope (V)'}, ...
    'Legends', {{'Left', 'Right'}, {'Left', 'Right'}, ...
        {'Left TA', 'Left GM'}, {'Right TA', 'Right GM'}}, ...
    'Colors', {[colors.Left; colors.Right], [colors.Left; colors.Right], ...
        [colors.TA; colors.GM], [colors.TA; colors.GM]}, ...
    'XLabel', 'Time');
