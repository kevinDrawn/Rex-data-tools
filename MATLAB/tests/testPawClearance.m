function testPawClearance()
%TESTPAWCLEARANCE Frame conversion, schema round-trip, and shared-axis overlay.
matlabDirectory = fileparts(fileparts(mfilename('fullpath')));
originalPath = path;
restorePath = onCleanup(@() path(originalPath)); %#ok<NASGU>
addpath(fullfile(matlabDirectory, 'Class'));
folder = tempname;
mkdir(folder);
cleanupFolder = onCleanup(@() rmdir(folder, 's')); %#ok<NASGU>

% Source frame IDs, including gaps, determine elapsed video time.
frames = [0; 1; 3; 4];
time = DataProcessor.framesToTime(frames, 120);
assert(max(abs(time - [0; 1/120; 3/120; 4/120])) < 1e-12);
assert(isequal(time, DataProcessor.framesToTime(frames+1, 120, 1)));
assert(DataProcessor.framesToTime(120, 120) == 1);
assertFails(@() DataProcessor.framesToTime(frames, 0));
assertFails(@() DataProcessor.framesToTime([0; 1; 1], 120));
assertFails(@() DataProcessor.framesToTime([0; NaN], 120));
assertFails(@() DataProcessor.framesToTime([0; 0.5], 120));

source = [frames, zeros(4,2), [1;0;0;0], [0;0;1;0], zeros(4,1), [1;1;0;0]];
csvPath = fullfile(folder, 'stance.csv');
writematrix(source, csvPath);
packer = DataPacker('Stance');
map = packer.getColumnMap();
map.Time = 1; map.frame = 1; map.IC = 4; map.TO = 5; map.stance = 7;
stance = packer.pack(csvPath, map, 'ReadVariableNames', false);
stance.Time = DataProcessor.framesToTime(stance.frame, 120);
assert(isequal(stance.Time, time));
assert(isequal(stance.frame, frames));
assert(isequal(stance.stance, [1;1;0;0]));
output = fullfile(folder, 'stance.mat');
packer.saveMat(stance, output);
loaded = load(output);
assert(isequal(loaded.data, stance));

mocapPacker = DataPacker('Mocap_JW');
map = mocapPacker.getColumnMap(); map.Time = 1; map.TO_x = 2; map.TO_y = 3; map.IL_x = 4; map.IL_y = 5;
csvPath = fullfile(folder, 'mocap.csv');
writematrix([frames/60, [10;12;15;17], [5;7;NaN;6], [100;101;102;103], [50;51;52;53]], csvPath);
mocap = mocapPacker.pack(csvPath, map, 'ReadVariableNames', false);
mocap.TimeCSV = mocap.Time;
mocap.Time = stance.Time;
assert(isequal(mocap.TO_x,[10;12;15;17]));
mocap.TO_x_filtered = DataProcessor.filterFirstOrderLowpass(mocap.Time,mocap.TO_x,15);
assert(isequal(mocap.IL_x,[100;101;102;103]));
assert(isequal(mocap.IL_y,[50;51;52;53]));
mocap.IL_x_filtered=DataProcessor.filterFirstOrderLowpass(mocap.Time,mocap.IL_x,15);
mocap.IL_y_filtered=DataProcessor.filterFirstOrderLowpass(mocap.Time,mocap.IL_y,15);
mocapPacker.saveMat(mocap, fullfile(folder, 'mocap.mat'));
loaded = load(fullfile(folder, 'mocap.mat'));
assert(isequaln(loaded.data, mocap));
assert(max(abs(mocap.TimeCSV - frames/60)) < 1e-12);

plotter = DataPlotter();
[fig, ax, traces] = plotter.plotStanceOverlay(mocap.Time, mocap.TO_y, ...
    stance.Time, stance.stance, [], 'Visible', 'off');
cleanupFigure = onCleanup(@() close(fig)); %#ok<NASGU>
assert(numel(ax.YAxis) == 2);
assert(isequal(traces.ToeHeight.XData(:), time));
assert(isequaln(traces.ToeHeight.YData(:), mocap.TO_y));
assert(isequal(traces.Stance.XData(:), time));
assert(isequal(traces.Stance.YData(:), stance.stance));
assert(isequal(ax.XLim, [0 4/120]));
assert(strcmp(ax.YAxis(1).Label.String, 'Toe marker height (mm)'));
assert(strcmp(ax.YAxis(2).Label.String, 'Gait state'));
assertFails(@() plotter.plotStanceOverlay(time, [1;2], time, stance.stance, []));
assertFails(@() plotter.plotStanceOverlay(time, mocap.TO_y, time, [1;2;0;0], []));
disp('Paw clearance packing, frame-time, and overlay checks passed.');
end

function assertFails(action)
try
    action();
catch
    return;
end
error('testPawClearance:ExpectedError', 'Expected invalid input to fail.');
end
