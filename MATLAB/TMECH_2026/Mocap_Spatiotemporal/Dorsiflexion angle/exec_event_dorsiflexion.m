%% Input settings
META_LOGGING_PATH = "D:\park\01. STEAM\[Paper] Paperwork\2026_TMECH\TMECH Review\Data\TMECH_meta_data\exp_data.mat";
RAT_ID = "#5";
CONDITION = "LR"; % IE / IR / LE / LR, or the full condition name
ANGLE_SIDE = 'left';
EVENT_TIME_OFFSET_SECONDS = 0; % Stored events are already aligned. Do not add t_bias again.
ZERO_TIME_AT_INTERVAL_START = true; % Plot only; stored times remain absolute.
SAVE_RESULTS = false;
SAVE_DORSIFLEXION_TABLE = true; % Export individual-rat supplementary tables.
OUTPUT_DIRECTORY = fullfile(fileparts(META_LOGGING_PATH),'event_dorsiflexion');

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

%% Load 6-by-4 record array and list available rats / conditions
metaData = load(META_LOGGING_PATH,'exp_data');
expData = metaData.exp_data;
conditionCodes = ["IE","IR","LE","LR"];
conditionNames = ["intact_Exo shoe","intact_Rex","lido_Exo shoe","lido_Rex"];
match = find(conditionCodes==string(CONDITION),1);
selectedConditionName = string(CONDITION);
if ~isempty(match), selectedConditionName = conditionNames(match); end

%% Extract each record on the Hall time grid, keeping disjoint intervals separate
% The actual event path contains the side: events.left.mocap / events.right.mocap.
% t_bias can be a vector for two-video records; it is preserved as metadata.
% No filtering, angle offset, or dorsiflexion sign conversion is applied here.
eventAngleData = repmat(struct(),size(expData));
Rat = strings(numel(expData),1); Condition = Rat;
IntervalCount = zeros(numel(expData),1); SampleCount = IntervalCount;
CompleteSwingCount = IntervalCount; UnknownStateSamples = IntervalCount;
selectedIndex = [];
for index = 1:numel(expData)
    result = GaitEventAnalyzer.extract(expData(index),'Side',ANGLE_SIDE, ...
        'EventTimeOffsetSeconds',EVENT_TIME_OFFSET_SECONDS);
    if index==1, eventAngleData = repmat(result,size(expData)); end
    eventAngleData(index) = result;
    Rat(index) = result.Rat; Condition(index) = result.Condition;
    IntervalCount(index) = numel(result.Segments);
    SampleCount(index) = numel(result.Time_s);
    CompleteSwingCount(index) = height(result.SwingIntervals);
    UnknownStateSamples(index) = nnz(isnan(result.StanceState));
    if result.Rat==RAT_ID && result.Condition==selectedConditionName
        selectedIndex(end+1) = index; %#ok<SAGROW>
    end
end
eventSummary = table(Rat,Condition,IntervalCount,SampleCount,CompleteSwingCount,UnknownStateSamples);
disp(eventSummary);
if numel(selectedIndex)~=1
    error('GaitEvents:Selection','Expected one record matching %s / %s; found %d.', ...
        RAT_ID,selectedConditionName,numel(selectedIndex));
end

%% Plot selected rat / condition: angle + exact IC/TO transitions and binary state
selectedResult = eventAngleData(selectedIndex);
plotter = DataPlotter();
[eventFigure,eventAxes] = plotter.plotEventAngle(selectedResult, ...
    'ZeroTimeAtIntervalStart',ZERO_TIME_AT_INTERVAL_START);
fprintf('%s / %s / %s: %d intervals, %d complete swings.\n', ...
    selectedResult.Rat,selectedResult.Condition,selectedResult.Side, ...
    numel(selectedResult.Segments),height(selectedResult.SwingIntervals));
disp(selectedResult.SwingIntervals);

%% Optional save: extraction for all records plus selected figure
if SAVE_RESULTS
    if ~isfolder(OUTPUT_DIRECTORY), mkdir(OUTPUT_DIRECTORY); end
    save(fullfile(OUTPUT_DIRECTORY,'event_ankle_angle_data.mat'), ...
        'eventAngleData','eventSummary','META_LOGGING_PATH','ANGLE_SIDE','EVENT_TIME_OFFSET_SECONDS');
    figureStem = regexprep(RAT_ID+"_"+string(CONDITION)+"_"+string(ANGLE_SIDE),'[^a-zA-Z0-9_-]','_');
    savefig(eventFigure,fullfile(OUTPUT_DIRECTORY,figureStem+"_event_angle.fig"));
    exportgraphics(eventFigure,fullfile(OUTPUT_DIRECTORY,figureStem+"_event_angle.png"),'Resolution',300);
end

%% Supplementary table: each rat x four conditions (no across-rat pooling)
dorsiflexionResults = GaitEventAnalyzer.dorsiflexionTable( ...
    eventAngleData,conditionNames,conditionCodes);
swingDorsiflexionTable = dorsiflexionResults.DisplayTable;
fprintf('\n===== Hall angle at peak swing dorsiflexion (deg) =====\n');
fprintf('Each cell: mean +/- SD across complete swings of that rat and condition.\n');
fprintf('Lower angle = greater dorsiflexion. No ROM normalization or across-rat average.\n');
disp(swingDorsiflexionTable);
fprintf('Valid complete swing counts for the corresponding cells:\n');
disp(dorsiflexionResults.CycleCountTable);
if SAVE_DORSIFLEXION_TABLE
    if ~isfolder(OUTPUT_DIRECTORY), mkdir(OUTPUT_DIRECTORY); end
    save(fullfile(OUTPUT_DIRECTORY,'peak_swing_dorsiflexion_by_rat.mat'), ...
        'dorsiflexionResults','META_LOGGING_PATH','ANGLE_SIDE','EVENT_TIME_OFFSET_SECONDS');
    writetable(swingDorsiflexionTable,fullfile(OUTPUT_DIRECTORY,'peak_swing_dorsiflexion_by_rat.csv'));
    writetable(dorsiflexionResults.CycleCountTable, ...
        fullfile(OUTPUT_DIRECTORY,'peak_swing_dorsiflexion_cycle_counts.csv'));
    writetable(dorsiflexionResults.PerSwing, ...
        fullfile(OUTPUT_DIRECTORY,'peak_swing_dorsiflexion_all_swings.csv'));
    fprintf('Individual-rat supplementary tables saved to %s\n',OUTPUT_DIRECTORY);
end
