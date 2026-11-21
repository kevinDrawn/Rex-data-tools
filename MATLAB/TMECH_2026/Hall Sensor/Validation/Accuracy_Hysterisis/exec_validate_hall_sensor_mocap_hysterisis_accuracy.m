%EXEC_VALIDATE_HALL_SENSOR_MOCAP Load Rex and Mocap CSVs for Hall validation.
% Set both CSV paths and column mappings, then run the entire script.
% Each MAT file contains a variable named data beside its source CSV.

%% Input settings
REX_LOGGING_PATH = "D:\park\01. STEAM\[STEAM] Bench Test\261111_Hall_sensor_validate\Mocap\261112_hall_dynamic\rex_live_20261112_092240_199.csv";
MOCAP_LOGGING_PATH = "D:\park\01. STEAM\[STEAM] Bench Test\261111_Hall_sensor_validate\Mocap\261112_hall_dynamic\views\left\joint_data\2026-11-12 09-22-41_jointpixeldata_tracker_AK_angle_trigger.csv";

% Options passed to readtable. For CSVs without headers, use:
% {'ReadVariableNames', false}. Set NumHeaderLines as needed for Mocap.
REX_CSV_READ_OPTIONS = {};
MOCAP_CSV_READ_OPTIONS = {};

% Convert each source time unit to seconds (Rex timestamps are milliseconds).
REX_TIME_SCALE_TO_SECONDS = 0.001;
MOCAP_TIME_SCALE_TO_SECONDS = 0.001; % Mocap CSV: time_ms.

REX_ANGLE_SIDE = 'Left'; % 'Left' or 'Right'

PLOT_TIME_RANGE = [4.4 5.7]; % Seconds relative to sync onset; [] shows both full traces.
BIAS_TIME_RANGE = [4.4 5.7]; % [start end] seconds from sync onset.
HYSTERESIS_TIME_RANGE = [4.4 5.7]; % [start end] in seconds from sync onset; [] uses all motion.
ACCURACY_TIME_RANGE = [4.4 5.7]; % Optional [start end] in sync-relative seconds; [] searches the full recording.

SYNC_THRESHOLD = 0.5; % sync_state > threshold means on (0/1 input).
MOCAP_LPF_CUTOFF_HZ = 10; % Causal first-order RC LPF (same form as calibration).

% [] fits over the full shared time span, independently of PLOT_TIME_RANGE.
HYSTERESIS_SPEED_WINDOW_S = 1; % Centered window for estimating Mocap angular speed.
HYSTERESIS_MIN_SPEED_DEG_S = 2; % Minimum absolute speed to classify motion.

HYSTERESIS_ANGLE_BIN_DEG = 1; % Reference-angle bin width for quantitative widths.
HYSTERESIS_MIN_SAMPLES_PER_BIN = 3; % Required samples in EACH direction.
% Metrics use their time ranges, independently of the displayed axis limits.
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
% Initial sync_state = 1 is ignored; a later 1 -> 0 -> 1 uses the new rising edge.
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

%% Filter Mocap on its full native time grid before selecting the fit interval
rexAngle = rexData.(REX_ANGLE_SIDE).Angle;
% Keep missing samples missing; filter each finite run independently so a
% tracking dropout cannot contaminate the remaining trace or create fit pairs.
mocapAngle = double(mocapData.mocap_angle(:));
finiteMocap = isfinite(mocapAngle);
if nnz(finiteMocap) < 2
    error('HallValidation:InsufficientMocapSamples', ...
        'Mocap must contain at least two finite angle samples.');
end
mocapAngleFiltered = NaN(size(mocapAngle));
finiteEdges = diff([false; finiteMocap; false]);
finiteStarts = find(finiteEdges == 1);
finiteEnds = find(finiteEdges == -1) - 1;
for runIndex = 1:numel(finiteStarts)
    runIndices = finiteStarts(runIndex):finiteEnds(runIndex);
    if numel(runIndices) == 1
        % A single sample has no time interval to filter.
        mocapAngleFiltered(runIndices) = mocapAngle(runIndices);
    else
        mocapAngleFiltered(runIndices) = DataProcessor.filterFirstOrderLowpass( ...
            mocapTime(runIndices), mocapAngle(runIndices), MOCAP_LPF_CUTOFF_HZ);
    end
end
if any(~finiteMocap)
    warning('HallValidation:MissingMocapAngles', ...
        '%d nonfinite Mocap angles kept as NaN and excluded from comparisons.', ...
        nnz(~finiteMocap));
end

%% Fit a constant Mocap bias on synchronized timestamps
% RMSE uses one pair per native Mocap sample, with Rex linearly interpolated.
% Positive bias means Mocap reads higher: corrected Mocap = filtered - bias.
% The fit range is clipped to shared data; no extrapolated samples are used.
biasResult = DataProcessor.fitMocapBias(rexTime, rexAngle, ...
    mocapTime, mocapAngleFiltered, BIAS_TIME_RANGE);
% Use this optimized bias unchanged for all subsequent calculations and plots.
mocapBiasDegrees = biasResult.BiasDegrees;
mocapAngleCorrected = mocapAngleFiltered - mocapBiasDegrees;
fprintf('Mocap LPF: first-order RC, %.3f Hz (causal).\n', MOCAP_LPF_CUTOFF_HZ);
fprintf('Bias fit interval: [%.6f, %.6f] s; %d finite pairs.\n', ...
    biasResult.EffectiveTimeRange, biasResult.SampleCount);
fprintf('Mocap bias: %+.6f deg (subtract from filtered Mocap).\n', mocapBiasDegrees);
fprintf('Fit-interval RMSE: %.6f -> %.6f deg after bias correction.\n', ...
    biasResult.RMSEBeforeDegrees, biasResult.RMSEAfterDegrees);

%% Overlay both native sample grids in one DataPlotter subplot
% Each trace uses its own native timestamps in this overlay.
if isempty(PLOT_TIME_RANGE)
    plotTimeRange = [min(rexTime(1), mocapTime(1)), ...
        max(rexTime(end), mocapTime(end))];
else
    plotTimeRange = PLOT_TIME_RANGE;
end

plotter = DataPlotter();

[plotFigure, plotAxes] = plotter.plotGroups(rexTime, {rexAngle}, ...
    plotTimeRange, 'vertical', ...
    'Titles', {sprintf('Hall sensor (%s) vs Mocap', REX_ANGLE_SIDE)}, ...
    'YLabels', {'Angle (deg)'}, 'XLabel', 'Time from sync onset (s)', ...
    'Colors', {plotter.Config.Colors.(REX_ANGLE_SIDE)});
hold(plotAxes(1), 'on');

plot(plotAxes(1), mocapTime, mocapAngleFiltered, ...
    'Color', plotter.Config.Colors.GM, ...
    'LineWidth', plotter.Config.LineWidth);
hold(plotAxes(1), 'off');
legend(plotAxes(1), {sprintf('Rex %s', REX_ANGLE_SIDE), ...
    sprintf('Mocap (1st-order LPF, %g Hz)', MOCAP_LPF_CUTOFF_HZ)}, ...
    'Interpreter', 'none', 'Box', 'off', 'Location', 'northeastoutside');

%% Overlay after applying the optimal constant Mocap bias
displayStart = plotTimeRange(1);
displayTimeRange = plotTimeRange - displayStart;

[biasFigure, biasAxes] = plotter.plotGroups( ...
    rexTime - displayStart, {rexAngle}, ...
    displayTimeRange, 'vertical', ...
    'Titles', {sprintf('Mocap bias = %+.4f deg; fit RMSE %.4f -> %.4f deg', ...
        mocapBiasDegrees, biasResult.RMSEBeforeDegrees, biasResult.RMSEAfterDegrees)}, ...
    'YLabels', {'Angle (deg)'}, 'XLabel', 'Time (s)', ...
    'Colors', {plotter.Config.Colors.(REX_ANGLE_SIDE)});

set(findobj(biasAxes(1), 'Type', 'line'), 'Visible', 'off');
hold(biasAxes(1), 'on');

mocapPoints = scatter(biasAxes(1), ...
    mocapTime - displayStart, mocapAngleCorrected, ...
    100, plotter.Config.Colors.GM, 'filled', ...
    'MarkerEdgeColor', 'none');

rexPoints = scatter(biasAxes(1), ...
    rexTime - displayStart, rexAngle, ...
    12, plotter.Config.Colors.(REX_ANGLE_SIDE), 'filled', ...
    'MarkerEdgeColor', 'none');

xlim(biasAxes(1), displayTimeRange);
hold(biasAxes(1), 'off');

legend(biasAxes(1), [rexPoints, mocapPoints], ...
    {sprintf('Rex %s', REX_ANGLE_SIDE), 'Mocap (LPF + bias corrected)'}, ...
    'Interpreter', 'none', 'Box', 'off', ...
    'Location', 'northeastoutside');
%% Pair Hall and Mocap angles and estimate motion direction
% Use the filtered, bias-corrected reference from the overlay above.
% Interpolate Hall onto the native Mocap grid without extrapolating.
hallOnMocap = interp1(rexTime, double(rexAngle(:)), mocapTime, 'linear', NaN);
validPairs = isfinite(hallOnMocap) & isfinite(mocapAngleCorrected);

% Estimate direction using a centered angular change over a window in seconds.
% This reduces frame-to-frame tracking jitter when the joint is stationary.
validateattributes(HYSTERESIS_SPEED_WINDOW_S, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'positive'});
validateattributes(HYSTERESIS_MIN_SPEED_DEG_S, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'positive'});
halfWindow = HYSTERESIS_SPEED_WINDOW_S / 2;
windowStart = max(mocapTime - halfWindow, mocapTime(1));
windowEnd = min(mocapTime + halfWindow, mocapTime(end));
angleStart = interp1(mocapTime, mocapAngleCorrected, windowStart, 'linear');
angleEnd = interp1(mocapTime, mocapAngleCorrected, windowEnd, 'linear');
mocapSpeed = (angleEnd - angleStart) ./ (windowEnd - windowStart);
increasing = validPairs & mocapSpeed >= HYSTERESIS_MIN_SPEED_DEG_S;
decreasing = validPairs & mocapSpeed <= -HYSTERESIS_MIN_SPEED_DEG_S;

%% Accuracy over one continuous increasing sweep
% Use the sweep with the largest reference-angle increase by default.
accuracyIncreasing = increasing;
if ~isempty(ACCURACY_TIME_RANGE)
    validateattributes(ACCURACY_TIME_RANGE, {'numeric'}, ...
        {'vector', 'numel', 2, 'real', 'finite', 'increasing'});
    accuracyIncreasing = accuracyIncreasing & mocapTime >= ACCURACY_TIME_RANGE(1) & ...
        mocapTime <= ACCURACY_TIME_RANGE(2);
end
sweepEdges = diff([false; accuracyIncreasing; false]);
sweepStarts = find(sweepEdges == 1);
sweepEnds = find(sweepEdges == -1) - 1;
hasMultipleSamples = sweepEnds > sweepStarts;
sweepStarts = sweepStarts(hasMultipleSamples);
sweepEnds = sweepEnds(hasMultipleSamples);

accuracyResult = struct();
if isempty(sweepStarts)
    warning('HallValidation:NoIncreasingSweep', ...
        'No continuous increasing sweep with at least two pairs was found.');
else
    angleGains = mocapAngleCorrected(sweepEnds) - mocapAngleCorrected(sweepStarts);
    [~, sweepIndex] = max(angleGains);
    accuracyIndices = sweepStarts(sweepIndex):sweepEnds(sweepIndex);
    accuracyTime = mocapTime(accuracyIndices);
    accuracyHall = hallOnMocap(accuracyIndices);
    accuracyMocap = mocapAngleCorrected(accuracyIndices);
    accuracyError = accuracyHall - accuracyMocap;
    errorBeforeBias = accuracyHall - mocapAngleFiltered(accuracyIndices);

    accuracyResult.TimeRange = [accuracyTime(1), accuracyTime(end)];
    accuracyResult.ReferenceAngleEndpoints = [accuracyMocap(1), accuracyMocap(end)];
    accuracyResult.SampleCount = numel(accuracyIndices);
    accuracyResult.MeanErrorDegrees = mean(accuracyError);
    accuracyResult.MAEDegrees = mean(abs(accuracyError));
    accuracyResult.RMSEDegrees = sqrt(mean(accuracyError.^2));
    accuracyResult.MaxAbsErrorDegrees = max(abs(accuracyError));
    accuracyResult.RMSEBeforeBiasDegrees = sqrt(mean(errorBeforeBias.^2));

    fprintf('Increasing sweep: %.3f to %.3f s, Mocap %.3f to %.3f deg (%d pairs).\n', ...
        accuracyResult.TimeRange, accuracyResult.ReferenceAngleEndpoints, ...
        accuracyResult.SampleCount);
    fprintf('Sweep RMSE before -> after Mocap bias correction: %.4f -> %.4f deg.\n', ...
        accuracyResult.RMSEBeforeBiasDegrees, accuracyResult.RMSEDegrees);
    fprintf('Sweep error (Hall - Mocap): mean %+.4f, MAE %.4f, max absolute %.4f deg.\n', ...
        accuracyResult.MeanErrorDegrees, accuracyResult.MAEDegrees, ...
        accuracyResult.MaxAbsErrorDegrees);

    accuracyFigure = figure('Name', 'Hall sensor accuracy during one increasing sweep', ...
        'Color', 'w', 'Position', [100 100 1100 700]);
    accuracyAxes = axes('Parent', accuracyFigure, ...
        'FontName', 'Times New Roman', 'FontSize', 25, ...
        'LabelFontSizeMultiplier', 1);
    referenceColor = [0.00 0.35 0.70];
    hallColor = [0.60 0.60 0.60];
    errorColor = [0.89 0.36 0.09];

    yyaxis(accuracyAxes, 'left');
    hold(accuracyAxes, 'on');
    hallScatter = scatter(accuracyAxes, accuracyTime, accuracyHall, 22, hallColor, ...
        'filled', 'DisplayName', sprintf('Hall sensor (%s)', REX_ANGLE_SIDE));
    referenceScatter = scatter(accuracyAxes, accuracyTime, accuracyMocap, 14, ...
        referenceColor, 'filled', 'DisplayName', 'MoCap reference');
    ylabel(accuracyAxes, 'Angle (deg)');

    yyaxis(accuracyAxes, 'right');
    errorScatter = scatter(accuracyAxes, accuracyTime, accuracyError, 18, errorColor, ...
        'filled', 'DisplayName', 'Hall - MoCap');
    ylabel(accuracyAxes, 'Angle error (deg)');
    errorLimit = max(1, 1.05 * accuracyResult.MaxAbsErrorDegrees);
    % ylim(accuracyAxes, [-errorLimit, errorLimit]);
    ylim(accuracyAxes, [-5, 5]);

    accuracyAxes.YAxis(1).Color = [0.15 0.15 0.15];
    accuracyAxes.YAxis(2).Color = errorColor;
    xlim(accuracyAxes, accuracyResult.TimeRange);
    xlabel(accuracyAxes, 'Time (s)');
    grid(accuracyAxes, 'off');
    box(accuracyAxes, 'off');
    % legend(accuracyAxes, [referenceScatter, hallScatter, errorScatter], ...
    %     'Location', 'northoutside', 'Orientation', 'horizontal', 'Box', 'off', ...
    %     'FontName', 'Times New Roman', 'FontSize', 25);
    title(accuracyAxes, sprintf('Bias %+.4f deg | RMSE %.4f deg | MAE %.4f deg', ...
        mocapBiasDegrees, accuracyResult.RMSEDegrees, accuracyResult.MAEDegrees), 'FontSize', 14);
    hold(accuracyAxes, 'off');
end

%% Hysteresis plot for moving samples
motionTimeMask = true(size(mocapTime));
if ~isempty(HYSTERESIS_TIME_RANGE)
    validateattributes(HYSTERESIS_TIME_RANGE, {'numeric'}, ...
        {'vector', 'numel', 2, 'real', 'finite', 'increasing'});
    motionTimeMask = mocapTime >= HYSTERESIS_TIME_RANGE(1) & ...
        mocapTime <= HYSTERESIS_TIME_RANGE(2);
end
movingUp = increasing & motionTimeMask;
movingDown = decreasing & motionTimeMask;
moving = movingUp | movingDown;
fprintf('Hysteresis: %d synchronized pairs; %d increasing and %d decreasing in motion plot.\n', ...
    nnz(validPairs), nnz(movingUp), nnz(movingDown));
if ~any(moving)
    warning('HallValidation:NoHysteresisMotion', ...
        'No moving samples in the selected range. Check the time range and speed threshold.');
else
motionTime = mocapTime(moving);
fprintf('Motion plot: first to last selected sample %.3f to %.3f s.\n', ...
    motionTime(1), motionTime(end));

hysteresisFigure = figure('Name', 'Hall sensor hysteresis', 'Color', 'w', ...
    'Position', [100 100 900 800]);
motionAxes = axes('Parent', hysteresisFigure, ...
    'FontName', 'Times New Roman', 'FontSize', 25, ...
    'LabelFontSizeMultiplier', 1, 'TitleFontSizeMultiplier', 1);

movingAngles = [mocapAngleCorrected(moving); hallOnMocap(moving)];
limits = [min(movingAngles), max(movingAngles)];
margin = max(1, 0.02 * diff(limits));
limits = limits + [-margin margin];

hold(motionAxes, 'on');
identityLine = plot(motionAxes, limits, limits, '--', 'Color', [0.5 0.5 0.5], ...
    'DisplayName', 'Hall = Mocap');
[motionUp, motionDown] = plotHysteresisDirections(motionAxes, mocapAngleCorrected, hallOnMocap, ...
    movingUp, movingDown);
axis(motionAxes, 'equal');
xlim(motionAxes, [50 123]);
ylim(motionAxes, [50 123]);

grid(motionAxes, 'off');
box(motionAxes, 'off');
title(motionAxes, sprintf('Moving samples only | Mocap bias %+.4f deg', mocapBiasDegrees));
xlabel(motionAxes, 'Reference sensor angle (deg)');
ylabel(motionAxes, sprintf('Hall sensor angle (deg)'));
legend(motionAxes, 'Location', 'northwest', 'Box', 'off', ...
    'FontName', 'Times New Roman', 'FontSize', 25);
hold(motionAxes, 'off');

end % Motion plot is optional; summary tables are always produced.

%% Final quantitative summary (same optimized bias for every row)
[accuracySummary, hysteresisSummary, hysteresisBinSummary] = summarizeHallValidation( ...
    mocapTime, hallOnMocap, mocapAngleCorrected, validPairs, ...
    increasing, decreasing, movingUp, movingDown, ACCURACY_TIME_RANGE, ...
    HYSTERESIS_ANGLE_BIN_DEG, HYSTERESIS_MIN_SAMPLES_PER_BIN);
fprintf('\n========== Quantitative summary (bias = %+.6f deg) ==========\n', mocapBiasDegrees);
fprintf('Accuracy: error = Hall - corrected Mocap; all values in degrees.\n');
fprintf('Overall includes stationary samples; Increasing/Decreasing pool ALL selected sweeps.\n');
fprintf('TimeStart_s/TimeEnd_s are first/last included timestamps, not continuous durations.\n');
disp(accuracySummary);
fprintf('Hysteresis: absolute difference of mean Hall-minus-Mocap error between directions\n');
fprintf('within the same %.3f-deg reference-angle bin, with >= %d samples per direction.\n', ...
    HYSTERESIS_ANGLE_BIN_DEG, HYSTERESIS_MIN_SAMPLES_PER_BIN);
fprintf('Only bins supported by BOTH directions are used; bins have equal weight.\n');
fprintf('Hysteresis uses HYSTERESIS_TIME_RANGE; plot axis limits do not restrict either table.\n');
disp(hysteresisSummary);
function [up, down] = plotHysteresisDirections( ...
    ax, mocapAngle, hallAngle, increasing, decreasing)

% 큰 파란색 점을 위에 그림
up = scatter(ax, mocapAngle(increasing), hallAngle(increasing), ...
    100, [0.35 0.62 0.82], 'o', 'filled', ...
    'MarkerEdgeColor', 'none', ...
    'DisplayName', 'Mocap increasing');

% 작은 주황색 점을 먼저 그림
down = scatter(ax, mocapAngle(decreasing), hallAngle(decreasing), ...
    30, [0.95 0.48 0.15], 'o', 'filled', ...
    'MarkerEdgeColor', 'none', ...
    'DisplayName', 'Mocap decreasing');

end

function [accuracyTable, hysteresisTable, binTable] = summarizeHallValidation( ...
    time, hall, reference, validPairs, increasing, decreasing, movingUp, movingDown, ...
    accuracyTimeRange, binWidth, minSamples)
% Widths are binned directional mean-error differences, not raw point extremes.
validateattributes(binWidth, {'numeric'}, {'scalar','real','finite','positive'});
validateattributes(minSamples, {'numeric'}, {'scalar','real','finite','integer','positive'});
time = time(:); hall = hall(:); reference = reference(:);
validPairs = validPairs(:) & isfinite(hall) & isfinite(reference);
increasing = increasing(:); decreasing = decreasing(:);
selected = validPairs;
if ~isempty(accuracyTimeRange)
    selected = selected & time >= accuracyTimeRange(1) & time <= accuracyTimeRange(2);
end
masks = [selected, selected & increasing, selected & decreasing];
Scope = ["Overall"; "Increasing"; "Decreasing"];
Samples = sum(masks,1)';
TimeStart_s = NaN(3,1); TimeEnd_s = NaN(3,1);
MeanError_deg = NaN(3,1); MAE_deg = NaN(3,1);
RMSE_deg = NaN(3,1); MaxAbsError_deg = NaN(3,1);
errorDegrees = hall - reference;
for row = 1:3
    mask = masks(:,row);
    if ~any(mask), continue; end
    t = time(mask); e = errorDegrees(mask);
    TimeStart_s(row) = t(1); TimeEnd_s(row) = t(end);
    MeanError_deg(row) = mean(e);
    MAE_deg(row) = mean(abs(e));
    RMSE_deg(row) = sqrt(mean(e.^2));
    MaxAbsError_deg(row) = max(abs(e));
end
accuracyTable = table(Scope, Samples, TimeStart_s, TimeEnd_s, ...
    MeanError_deg, MAE_deg, RMSE_deg, MaxAbsError_deg);

% Retain per-bin counts and means to make the summary reproducible.
binTable = table('Size',[0 8], ...
    'VariableTypes', repmat({'double'},1,8), ...
    'VariableNames', {'AngleLower_deg','AngleUpper_deg','AngleCenter_deg', ...
    'IncreasingSamples','DecreasingSamples','IncreasingMeanError_deg', ...
    'DecreasingMeanError_deg','Width_deg'});
up = movingUp(:) & validPairs; down = movingDown(:) & validPairs;
if any(up) && any(down)
    lower = max(min(reference(up)), min(reference(down)));
    upper = min(max(reference(up)), max(reference(down)));
    if upper > lower
        % Use only complete bins inside the measured common angular support.
        binCount = floor((upper-lower)/binWidth);
        if binCount > 0
            edges = lower + (0:binCount)*binWidth;
            bin = discretize(reference, edges);
            upSelected = up & ~isnan(bin);
            downSelected = down & ~isnan(bin);
            countsUp = accumarray(bin(upSelected), 1, [binCount 1], @sum, 0);
            countsDown = accumarray(bin(downSelected), 1, [binCount 1], @sum, 0);
            meanUp = accumarray(bin(upSelected), errorDegrees(upSelected), ...
                [binCount 1], @mean, NaN);
            meanDown = accumarray(bin(downSelected), errorDegrees(downSelected), ...
                [binCount 1], @mean, NaN);
            keep = countsUp >= minSamples & countsDown >= minSamples;
            lo = edges(1:end-1)'; hi = edges(2:end)'; center = (lo+hi)/2;
            widths = abs(meanUp-meanDown);
            binTable = table(lo(keep), hi(keep), center(keep), ...
                countsUp(keep), countsDown(keep), meanUp(keep), meanDown(keep), ...
                widths(keep), 'VariableNames', binTable.Properties.VariableNames);
        end
    end
end
MaxWidth_deg = NaN; MeanAbsWidth_deg = NaN; RMSWidth_deg = NaN;
AngleAtMax_deg = NaN; AngleLower_deg = NaN; AngleUpper_deg = NaN;
ValidBins = height(binTable);
if ValidBins > 0
    [MaxWidth_deg, index] = max(binTable.Width_deg);
    MeanAbsWidth_deg = mean(binTable.Width_deg);
    RMSWidth_deg = sqrt(mean(binTable.Width_deg.^2));
    AngleAtMax_deg = binTable.AngleCenter_deg(index);
    AngleLower_deg = min(binTable.AngleLower_deg);
    AngleUpper_deg = max(binTable.AngleUpper_deg);
else
    warning('HallValidation:InsufficientHysteresisBins', ...
        'No common angle bins meet the per-direction sample minimum; hysteresis metrics are NaN.');
end
BinWidth_deg = binWidth;
MinSamplesPerDirection = minSamples;
hysteresisTable = table(MaxWidth_deg, MeanAbsWidth_deg, RMSWidth_deg, ...
    AngleAtMax_deg, ValidBins, AngleLower_deg, AngleUpper_deg, ...
    BinWidth_deg, MinSamplesPerDirection);
end