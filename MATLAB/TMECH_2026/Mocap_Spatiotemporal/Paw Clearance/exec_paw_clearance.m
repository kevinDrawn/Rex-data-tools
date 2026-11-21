%% Input settings
STANCE_LOGGING_PATH ="F:\Rodex\Experiment\2026_TMECH\Result\n=6\#7\baseline\7#_baseline_2026-02-11 02-30-19_00-00-51\views\left\joint_data\HH_Base_2026-02-11 02-30-19_00-00-51_right_undistort_stance.csv";
MOCAP_JW_LOGGING_PATH ="F:\Rodex\Experiment\2026_TMECH\Result\n=6\#7\baseline\7#_baseline_2026-02-11 02-30-19_00-00-51\views\left\joint_data\HH_Base_2026-02-11 02-30-19_00-00-51_right_undistort_jointpixeldata_manual_checked_261116_015337_keyframes_intp.csv";

% MAT Save Path
MAT_PATH = "D:\park\01. STEAM\[Paper] Paperwork\2026_TMECH\TMECH Review\Spatiotemporal_Index\Paw_clearance\#7\Baseline";

% Options passed to readtable. For CSVs without headers, use:
% {'ReadVariableNames', false}. Set NumHeaderLines as needed for Mocap.
Stance_CSV_READ_OPTIONS = {};
MOCAP_JW_CSV_READ_OPTIONS = {};

% Both CSVs contain the same video frames, recorded at this FPS.
FPS_Logging = 120; % fps; authoritative for BOTH datasets.
MOCAP_LPF_CUTOFF_HZ = 15; % Causal first-order RC low-pass filter.
FRAME_INDEX_ORIGIN = 0; % CSV frame 0 is video time 0; use 1 for one-based IDs.
PLOT_TIME_RANGE = []; % [start end] in seconds; [] uses the full recording.

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

%% Stance: assign 1-based CSV column numbers
% ColumnMap stores CSV column indices, not converted data values.
StancePacker = DataPacker('Stance');
StanceColumnMap = StancePacker.getColumnMap();
StanceColumnMap.Time = 1; % Frame column; converted to seconds after packing.
StanceColumnMap.frame = 1; % Preserve original frame IDs.
StanceColumnMap.IC = 4; % IC_H: left hind paw initial-contact flags.
StanceColumnMap.TO = 5; % TO_H: left hind paw toe-off flags.
StanceColumnMap.stance = 7; % stance_H: 1 = stance, 0 = swing.

%% Mocap: assign 1-based CSV column numbers
Mocap_JW_Packer = DataPacker('Mocap_JW');
MocapColumnMap = Mocap_JW_Packer.getColumnMap();
MocapColumnMap.Time = 1; % CSV time is preserved as TimeCSV below.
MocapColumnMap.IL_x = 2; % IL_x_mm: left ilium-marker horizontal coordinate.
MocapColumnMap.IL_y = 3; % IL_y_mm: left ilium-marker vertical coordinate.
MocapColumnMap.TO_x = 10; % TO_x_mm: left toe-marker horizontal coordinate.
MocapColumnMap.TO_y = 11; % TO_y_mm: left toe-marker height.

%% Validate both source paths before loading or saving
if ~isfile(STANCE_LOGGING_PATH)
    error('PawClearance:MissingStanceCSV', 'Stance CSV not found: %s', STANCE_LOGGING_PATH);
end
if ~isfile(MOCAP_JW_LOGGING_PATH)
    error('PawClearance:MissingMocapCSV', 'Mocap CSV not found: %s', MOCAP_JW_LOGGING_PATH);
end

%% Pack both datasets
StanceData = StancePacker.pack(STANCE_LOGGING_PATH, StanceColumnMap, ...
    Stance_CSV_READ_OPTIONS{:});
mocapData = Mocap_JW_Packer.pack(MOCAP_JW_LOGGING_PATH, MocapColumnMap, ...
    MOCAP_JW_CSV_READ_OPTIONS{:});

%% Shared video-frame timeline (seconds)
% Both rows must refer to the SAME source frame, in the same order.
% Row-count agreement alone does not establish this correspondence for other files.
if numel(mocapData.IL_x) ~= numel(mocapData.TO_y) || ...
        numel(mocapData.IL_y) ~= numel(mocapData.TO_y)
    error('PawClearance:CoordinateCountMismatch', 'IL and TO coordinates must have the same number of rows.');
end
if numel(mocapData.TO_x) ~= numel(mocapData.TO_y)
    error('PawClearance:CoordinateCountMismatch', 'Mocap X and Y must have the same number of rows.');
end
if numel(StanceData.frame) ~= numel(mocapData.TO_y)
    error('PawClearance:FrameCountMismatch', ...
        ['Stance has %d frames and Mocap has %d rows. Select CSVs covering ' ...
         'the same video frames; rows are not truncated or interpolated.'], ...
        numel(StanceData.frame), numel(mocapData.TO_y));
end
StanceData.Time = DataProcessor.framesToTime( ...
    StanceData.frame, FPS_Logging, FRAME_INDEX_ORIGIN);
mocapData.TimeCSV = mocapData.Time;
mocapData.Time = StanceData.Time;
fprintf('Shared video FPS: %.6g; %d paired frames.\n', ...
    FPS_Logging, numel(StanceData.Time));
fprintf('Shared time range: [%.6f, %.6f] s.\n', ...
    StanceData.Time(1), StanceData.Time(end));
fprintf('Mocap CSV timestamps preserved in mocapData.TimeCSV; Time uses video frames.\n');

%% Filter toe and ilium coordinates on the shared native timeline
% Preserve raw TO_x / TO_y / IL_x / IL_y; all use the same cutoff and filter method.
mocapData.TO_y_filtered = DataProcessor.filterFirstOrderLowpass( ...
    mocapData.Time, mocapData.TO_y, MOCAP_LPF_CUTOFF_HZ);
fprintf('Mocap toe-height LPF: first-order RC, %.3f Hz.\n', MOCAP_LPF_CUTOFF_HZ);

mocapData.TO_x_filtered = DataProcessor.filterFirstOrderLowpass( ...
    mocapData.Time, mocapData.TO_x, MOCAP_LPF_CUTOFF_HZ);
fprintf('Mocap toe-X LPF: first-order RC, %.3f Hz.\n', MOCAP_LPF_CUTOFF_HZ);

mocapData.IL_x_filtered = DataProcessor.filterFirstOrderLowpass( ...
    mocapData.Time, mocapData.IL_x, MOCAP_LPF_CUTOFF_HZ);
mocapData.IL_y_filtered = DataProcessor.filterFirstOrderLowpass( ...
    mocapData.Time, mocapData.IL_y, MOCAP_LPF_CUTOFF_HZ);
fprintf('Mocap ilium X/Y LPF: first-order RC, %.3f Hz.\n', MOCAP_LPF_CUTOFF_HZ);

%% Per-cycle peak paw height: stance minimum -> following swing maximum
% Use the filtered trace for BOTH extrema. Calculations cover the full data,
% independently of PLOT_TIME_RANGE. Height must increase upward.
% Skip a leading partial stance unless row 1 explicitly carries an IC flag;
% include a trailing swing, marked SwingEndObserved = 0 if its end is unobserved.
PawClearanceData = DataProcessor.extractPawClearance( ...
    mocapData.Time, mocapData.TO_y_filtered, StanceData.stance, ...
    'InitialStanceIsComplete', logical(StanceData.IC(1) == 1));
nPawCycles = numel(PawClearanceData.Cycle);
PawClearanceData.GroundFrame = StanceData.frame(PawClearanceData.GroundIndex);
PawClearanceData.PeakFrame = StanceData.frame(PawClearanceData.PeakIndex);
PawClearanceData.FPS_Hz = repmat(FPS_Logging, nPawCycles, 1);
PawClearanceData.LPFCutoff_Hz = repmat(MOCAP_LPF_CUTOFF_HZ, nPawCycles, 1);
PawClearancePacker = DataPacker('PawClearance');
if nPawCycles == 0
    warning('PawClearance:NoPhasePairs', ...
        'No eligible stance-to-swing pairs; no cycle-result MAT file will be saved.');
else
    pawClearanceTable = struct2table(PawClearanceData);
    disp(pawClearanceTable(:, {'Cycle', 'GroundTime_s', 'GroundHeight_mm', ...
        'PeakTime_s', 'PeakToeHeight_mm', 'PeakPawHeight_mm', 'SwingEndObserved'}));
    fprintf('Peak paw height: %.4f +/- %.4f mm (%d stance/swing pairs).\n', ...
        mean(PawClearanceData.PeakPawHeight_mm), ...
        std(PawClearanceData.PeakPawHeight_mm), nPawCycles);
    if any(PawClearanceData.SwingEndObserved == 0)
        fprintf('Trailing swing included using its observed maximum (SwingEndObserved = 0).\n');
    end
end

%% Plot on a single shared time axis
plotter = DataPlotter();
[pawFigure, pawAxes, pawTraces] = plotter.plotStanceOverlay( ...
    mocapData.Time, mocapData.TO_y_filtered, StanceData.Time, StanceData.stance, ...
    PLOT_TIME_RANGE, 'Title', sprintf( ...
        'Left hind paw: toe height (1st-order LPF, %g Hz) and stance', MOCAP_LPF_CUTOFF_HZ));
pawTraces.ToeHeight.DisplayName = sprintf('Toe height (LPF, %g Hz)', MOCAP_LPF_CUTOFF_HZ);
legend(pawAxes, [pawTraces.ToeHeight, pawTraces.Stance], ...
    {pawTraces.ToeHeight.DisplayName, 'Stance (left hind paw)'}, ...
    'Interpreter', 'none', 'Box', 'off', 'Location', 'northeastoutside');

if nPawCycles > 0
    pawMarkers = plotter.annotatePawClearance(pawAxes, PawClearanceData);
    legend(pawAxes, [pawTraces.ToeHeight, pawTraces.Stance, pawMarkers.Ground, pawMarkers.Peak], ...
        {pawTraces.ToeHeight.DisplayName, 'Stance (left hind paw)', ...
         'Stance minimum', 'Swing maximum'}, ...
        'Interpreter', 'none', 'Box', 'off', 'Location', 'northeastoutside');
end

%% Save per-frame datasets and per-cycle results in MAT_PATH
validateattributes(MAT_PATH, {'char', 'string'}, {'nonempty'});
if strlength(string(MAT_PATH)) == 0
    error('PawClearance:MissingMatPath', 'Set MAT_PATH to an output folder.');
end
if ~isfolder(MAT_PATH)
    [created, message] = mkdir(MAT_PATH);
    if ~created
        error('PawClearance:CreateMatDirectoryFailed', ...
            'Cannot create MAT output folder: %s', message);
    end
end
[~, stanceName] = fileparts(STANCE_LOGGING_PATH);
STANCE_MAT_PATH = fullfile(MAT_PATH, stanceName + ".mat");
[~, mocapName] = fileparts(MOCAP_JW_LOGGING_PATH);
MOCAP_MAT_PATH = fullfile(MAT_PATH, mocapName + ".mat");
StancePacker.saveMat(StanceData, STANCE_MAT_PATH);
Mocap_JW_Packer.saveMat(mocapData, MOCAP_MAT_PATH);
fprintf('Mocap MAT contains raw and filtered TO_x / TO_y / IL_x / IL_y (mm).\n');
PAW_CLEARANCE_MAT_PATH = fullfile(MAT_PATH, mocapName + "_paw_clearance.mat");
if nPawCycles > 0
    PawClearancePacker.saveMat(PawClearanceData, PAW_CLEARANCE_MAT_PATH);
    fprintf('Paw clearance: %d cycles saved to %s\n', ...
        nPawCycles, char(PAW_CLEARANCE_MAT_PATH));
end
fprintf('Stance: %d samples saved to %s\n', numel(StanceData.Time), char(STANCE_MAT_PATH));
fprintf('Mocap: %d samples saved to %s\n', numel(mocapData.Time), char(MOCAP_MAT_PATH));

%% Save the final overlay, including stance minima and swing maxima
PAW_FIG_PATH = fullfile(MAT_PATH, mocapName + "_paw_clearance.fig");
PAW_PNG_PATH = fullfile(MAT_PATH, mocapName + "_paw_clearance.png");
drawnow;
savefig(pawFigure, PAW_FIG_PATH);
exportgraphics(pawFigure, PAW_PNG_PATH, 'Resolution', 300);
fprintf('Paw clearance figure saved to %s\n', char(PAW_FIG_PATH));
fprintf('Paw clearance PNG saved to %s\n', char(PAW_PNG_PATH));
