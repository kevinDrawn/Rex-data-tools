%PACKLOGGINGDATA Save a TMECH logger CSV to MAT and plot the measured channels.

%% Input settings
LOGGING_PATH = "C:\ncs\C_Logger\Rex-data-tools\exec\TMECH_2026\logging\rex_tmech_live_20261121_201958_670.csv";
PROJECT_TYPE = "Rex_TMECH";

% Empty: save beside the CSV with the same base name.
% Alternatively, set the absolute destination .mat path.
MAT_PATH = "";

% Options passed to readtable. The default mapping uses TMECH CSV headers.
CSV_READ_OPTIONS = {};

% Time is in milliseconds. [] plots the full recording.
PLOT_TIME_RANGE = [];
PLOT_DIRECTION = "vertical"; % "vertical" stacks the four subplots.

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

%% Load the TMECH header mapping
packer = DataPacker(PROJECT_TYPE);
columnMap = packer.getColumnMap();

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

%% Plot angles, measured torques, compensation and sync
plotter = DataPlotter();
groups = { ...
    [data.Left.Angle, data.Right.Angle, data.Assisted.Angle, data.Nominal.Angle], ...
    [data.Left.Torque, data.Right.Torque, data.Axial.Torque], ...
    data.Compensation.Torque, ...
    data.sync_state};

[plotFigure, plotAxes] = plotter.plotGroups( ...
    data.Time, groups, PLOT_TIME_RANGE, PLOT_DIRECTION, ...
    'Titles', {'Joint angles', 'Measured torques', 'Admittance torque', 'Sync input'}, ...
    'YLabels', {'Angle (deg)', 'Logger-scaled units', 'Logger-scaled units', 'State'}, ...
    'Legends', {{'Left', 'Right', 'Assisted', 'Nominal'}, {'Left CAN', 'Right CAN', 'Axial'}, {}, {}}, ...
    'XLabel', 'Logger time (ms)');
yticks(plotAxes(4), [0 1]);
ylim(plotAxes(4), [-0.1 1.1]);
