function testPawClearanceMetrics()
%TESTPAWCLEARANCEMETRICS Phase pairing, local baseline, boundaries, and saving.
originalPath = path;
restorePath = onCleanup(@() path(originalPath)); %#ok<NASGU>
addpath(fullfile(fileparts(fileparts(mfilename('fullpath'))), 'Class'));
time = (0:14)'/120;
state = [ones(3,1); zeros(3,1); ones(3,1); zeros(3,1); ones(3,1)];
height = [12;10;11;14;17;13; 8;6;7;9;12;8; 5;4;5];
result = DataProcessor.extractPawClearance(time,height,state, ...
    'InitialStanceIsComplete', true);
assert(isequal(result.GroundIndex,[2;8]));
assert(isequal(result.PeakIndex,[5;11]));
assert(isequal(result.GroundHeight_mm,[10;6]));
assert(isequal(result.PeakToeHeight_mm,[17;12]));
assert(isequal(result.PeakPawHeight_mm,[7;6]));
assert(isequal(result.Time,time([5;11])));
assert(isequal(result.SwingEndObserved,[1;1]));
assert(isequal(result.StanceEndIndex,[3;9]));
assert(isequal(result.SwingStartIndex,[4;10]));
% An overall coordinate offset must cancel independently in each cycle.
shifted = DataProcessor.extractPawClearance(time,height+100,state, ...
    'InitialStanceIsComplete', true);
assert(isequal(result.PeakPawHeight_mm,shifted.PeakPawHeight_mm));
% Leading stance is excluded if its onset was not observed/confirmed.
partial = DataProcessor.extractPawClearance(time,height,state);
assert(isequal(partial.PeakPawHeight_mm,6));
assert(partial.StanceStartIndex==7);
% Ending in swing retains the observed maximum and records its open boundary.
partial = DataProcessor.extractPawClearance(time(1:12),height(1:12),state(1:12), ...
    'InitialStanceIsComplete', true);
assert(isequal(partial.PeakPawHeight_mm,[7;6]));
assert(isequal(partial.SwingEndObserved,[1;0]));
assert(partial.PeakIndex(end)==11);
% A maximum at the recording edge is not silently treated as a closed swing.
edgeHeight=height(1:12); edgeHeight(12)=14;
edgePeak=DataProcessor.extractPawClearance(time(1:12),edgeHeight,state(1:12), ...
    'InitialStanceIsComplete', true);
assert(edgePeak.PeakIndex(end)==12 && edgePeak.SwingEndObserved(end)==0);
% Initial swing has no preceding stance and is not incorrectly paired.
partial = DataProcessor.extractPawClearance(time(4:end),height(4:end),state(4:end));
assert(isequal(partial.PeakPawHeight_mm,6));
empty = DataProcessor.extractPawClearance(time,height,ones(size(state)));
assert(isempty(empty.Cycle));
empty = DataProcessor.extractPawClearance(time,height,zeros(size(state)));
assert(isempty(empty.Cycle));
assertFails(@() DataProcessor.extractPawClearance(time,height,[2;state(2:end)]));
assertFails(@() DataProcessor.extractPawClearance(time,height(2:end),state));
assertFails(@() DataProcessor.extractPawClearance(time,[NaN;height(2:end)],state));
% A lower peak is retained as a negative difference rather than clipped to zero.
negative = DataProcessor.extractPawClearance((0:5)',[10;11;8;9;10;11], ...
    [1;1;0;0;1;1], 'InitialStanceIsComplete', true);
assert(negative.PeakPawHeight_mm == -1);

output = [tempname '.mat'];
cleanupMat = onCleanup(@() delete(output)); %#ok<NASGU>
packer = DataPacker('PawClearance');
packer.saveMat(result,output);
loaded = load(output);
assert(isequal(loaded.data,result));
plotter = DataPlotter();
[fig, ax] = plotter.plotStanceOverlay(time,height,time,state,[],'Visible','off');
cleanupFigure = onCleanup(@() close(fig)); %#ok<NASGU>
markers = plotter.annotatePawClearance(ax,result);
assert(isequal(markers.Ground.XData(:),result.GroundTime_s));
assert(isequal(markers.Ground.YData(:),[10;6]));
assert(isequal(markers.Peak.YData(:),[17;12]));
disp('Paw-clearance metrics: known heights, local baselines, boundaries, MAT and markers passed.');
end

function assertFails(action)
try
    action();
catch
    return;
end
error('testPawClearanceMetrics:ExpectedError','Expected invalid input to fail.');
end
