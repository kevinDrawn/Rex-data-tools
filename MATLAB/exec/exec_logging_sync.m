%% Input settings
LOGGING_PATH = "C:\ncs\C_Logger\Rex-data-tools\MATLAB\experiment\261105_4ch_logging_sync_validate\rex_live_20261105_213634_977.csv";
PROJECT_TYPE = "Rex";

% Empty: save beside the CSV with the same base name.
% Alternatively, set the absolute destination .mat path.
MAT_PATH = "C:\ncs\C_Logger\Rex-data-tools\MATLAB\experiment\261105_4ch_logging_sync_validate\rex_live_20261105_213634_977.mat";

% Options passed to readtable. For a CSV without a header, use:
% CSV_READ_OPTIONS = {'ReadVariableNames', false};
CSV_READ_OPTIONS = {};

% Process all four raw EMG channels before plotting their filtered envelopes.
EMG_FIELDS = {'Left.TA', 'Left.GM', 'Right.TA', 'Right.GM'};
EMG_SAMPLE_RATE_HZ = 2000; % Rex: 0.5 ms/sample; Time units set in EMGConfig.

% Plot range uses the same units as data.Time. [] plots the full recording.
PLOT_TIME_RANGE = [0 245000]; % Example: [1000 5000] if Time is in milliseconds.
% PLOT_DIRECTION = "vertical"; % 'vertical': 4-by-1; 'horizontal': 1-by-4.

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
% MAT_PATH가 비어 있으면 CSV와 같은 폴더·이름으로 저장
if strlength(MAT_PATH) == 0
    [loggingDirectory, loggingName] = fileparts(LOGGING_PATH);
    MAT_PATH = fullfile(loggingDirectory, loggingName + ".mat");
end

data = packer.pack(LOGGING_PATH, columnMap, CSV_READ_OPTIONS{:});
packer.saveMat(data, MAT_PATH);
fprintf('Saved %d samples to %s\n', numel(data.Time), char(MAT_PATH));

%% Remove Outliar
processor = DataProcessor();
targetFields = EMG_FIELDS;

[data, report] = processor.processOutliersMat( ...
    MAT_PATH, targetFields, ...
    'WindowSamples', 401, ...
    'Threshold', 6, ...
    'VarianceWindowSamples', 21, ...
    'VarianceRatio', 9);

%% Plot the saved MAT file: Left/Right filtered EMG
loaded = load(MAT_PATH, 'data');
plotData = loaded.data;
plotter = DataPlotter();
colors = plotter.Config.Colors;

% One cell = one subplot. Each matrix column is a separate curve.
groups = { ...
    [plotData.Left.TA_cleaned, plotData.Left.GM_cleaned], ...
    [plotData.Right.TA_cleaned, plotData.Right.GM_cleaned]};

[plotFigure, plotAxes] = plotter.plotGroups( ...
    plotData.Time, groups, PLOT_TIME_RANGE, PLOT_DIRECTION, ...
    'Titles', {'Left TA / GM', 'Right TA / GM'}, ...
    'YLabels', {'EMG (ADC Counts)', 'EMG (ADC Counts)'}, ...
    'Legends', {{'Left TA', 'Left GM'}, {'Right TA', 'Right GM'}}, ...
    'Colors', {[colors.TA; colors.GM], [colors.TA; colors.GM]}, ...
    'XLabel', 'Time');

%% Timing Sync 
analyzer = SignalAnalyzer();

reports = analyzer.analyzeSquareWaveMat( ...
    MAT_PATH, EMG_FIELDS);

r = reports.Left.TA;

fprintf('측정: %.6f Hz\n기대: %.6f Hz\n오차: %+.3f %%\n', ...
    r.FrequencyHz, r.ExpectedFrequencyHz, r.FrequencyErrorPercent);
fprintf('주기 표준편차: %.4f ms\n', r.PeriodStdSeconds * 1000);
fprintf('주기 변동계수: %.4f %%\n', r.PeriodCVPercent);
fprintf('흔들림 기준 초과: %d 주기\n', r.CycleJitterExceededCount);

fprintf('시간축 간격 이상: %d 건\n', r.Timing.IrregularIntervalCount);
fprintf('시간축 공백: %d 건\n', r.Timing.GapCount);
fprintf('추정 누락 샘플: %d 개\n', r.Timing.EstimatedMissingSampleCount);


%% 이상치 조사
r = reports.Left.TA;
bad = r.CycleJitterExceeded;

table( ...
    r.CycleStartTimesSeconds(bad), ...
    r.CyclePeriodsSeconds(bad) * 1000, ...
    r.CycleJitterPercent(bad), ...
    'VariableNames', {'Time_s', 'Period_ms', 'Deviation_percent'})

fprintf('전체: %d주기, 기준 초과: %d주기\n', ...
    r.CompleteCycleCount, nnz(bad));

fprintf('기준 이내 주기 표준편차: %.4f ms\n', ...
    std(r.CyclePeriodsSeconds(~bad)) * 1000);

analyzer.plotTimingDiagnostics(r);