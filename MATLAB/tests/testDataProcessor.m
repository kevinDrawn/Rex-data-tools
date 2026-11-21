function testDataProcessor()
%TESTDATAPROCESSOR Check tracking metrics, EMG filtering, and MAT preservation.
matlabDirectory = fileparts(fileparts(mfilename('fullpath')));
originalPath = path;
restorePath = onCleanup(@() path(originalPath)); %#ok<NASGU>
addpath(fullfile(matlabDirectory, 'Class'));
processor = DataProcessor();
assert(processor.calculateRMSE([1 2 3], [3; 4; 5]) == 2);

% Recover a fractional-sample delay despite different offsets and amplitudes.
phaseTime = (0:0.01:4)' + 0.001*sin((0:400)');
frequencyHz = 2;
knownDelay = 0.0325;
reference = 50 + 10*cos(2*pi*frequencyHz*phaseTime);
measured = 47 + 6*cos(2*pi*frequencyHz*(phaseTime-knownDelay));
[delay, phase] = processor.calculatePhaseDelay(phaseTime, reference, measured, frequencyHz);
assert(abs(delay - knownDelay) < 1e-10);
assert(abs(phase - 360*frequencyHz*knownDelay) < 1e-8);
[delay, phase] = processor.calculatePhaseDelay(phaseTime, measured, reference, frequencyHz);
assert(abs(delay + knownDelay) < 1e-10);
assert(abs(phase + 360*frequencyHz*knownDelay) < 1e-8);
assertError(@() processor.calculatePhaseDelay(phaseTime, reference, ones(size(measured)), frequencyHz), ...
    'DataProcessor:UndefinedPhase');
assertError(@() processor.calculatePhaseDelay([0 0.01 0.02 0.03], reference(1:4), measured(1:4), frequencyHz), ...
    'DataProcessor:SignalTooShort');

fs = processor.Config.SampleRateHz;
time = (0:1/fs:5-1/fs)';
amplitude = 100000;
raw = round(amplitude * sin(2*pi*100*time));
filtered = processor.filterEMG(raw);
middle = time > 1 & time < 4;
expected = (2/pi) * amplitude * processor.Config.VRef / ...
    (processor.Config.ADCGain * 2^(processor.Config.ADCBits-1));
assert(isequal(size(filtered), size(raw)) && all(isfinite(filtered)));
assert(abs(mean(filtered(middle)) - expected) < 0.1 * expected);
outOfBand = processor.filterEMG(round(amplitude * sin(2*pi*800*time)));
assert(mean(abs(outOfBand(middle))) < 0.15 * mean(filtered(middle)));
assert(all(processor.filterEMG(zeros(size(raw))) == 0));
assertError(@() processor.filterEMG(raw, 1000), 'DataProcessor:InvalidCutoff');
assertError(@() processor.filterEMG(2^23 * ones(100, 1)), 'DataProcessor:ADCOutOfRange');
assertError(@() processor.filterEMG(zeros(5, 1)), 'DataProcessor:SignalTooShort');

folder = tempname;
mkdir(folder);
cleanup = onCleanup(@() rmdir(folder, 's')); %#ok<NASGU>
matPath = fullfile(folder, 'emg.mat');
data.Time = time / processor.Config.TimeScaleToSeconds;
data.Left.TA = raw;
data.Left.GM = raw * 2;
data.Right.Angle = ones(size(time));
unrelated = 'keep this MAT variable';
save(matPath, 'data', 'unrelated');
result = processor.processEMGMat(matPath, {'Left.TA'});
assert(isequal(result.Left.TA, raw));
assert(isequal(result.Left.GM, raw * 2));
assert(~isfield(result.Left, 'GM_filtered'));
assert(isequal(result.Left.TA_filtered, filtered));
loaded = load(matPath);
assert(strcmp(loaded.unrelated, unrelated));
assert(isequal(loaded.data.Right.Angle, data.Right.Angle));
assert(strcmp(loaded.EMGProcessing.Left.TA_filtered.OutputUnit, 'V'));
assert(loaded.EMGProcessing.Left.TA_filtered.SampleRateHz == fs);
assertError(@() processor.processEMGMat(matPath, {'Left.GM', 'Left.Missing'}), ...
    'DataProcessor:MissingSignal');
afterFailure = load(matPath, 'data');
assert(isequal(afterFailure.data, loaded.data));
result = processor.processEMGMat(matPath, {'Left.GM'});
assert(isfield(result.Left, 'TA_filtered') && isfield(result.Left, 'GM_filtered'));
data.Time(10) = data.Time(10) + 0.1;
save(matPath, 'data', '-append');
assertError(@() processor.processEMGMat(matPath, {'Left.TA'}), 'DataProcessor:InvalidSampleRate');
% Synchronization uses a real rising edge, including after an initial high.
syncData.Time = (1000:100:1500)';
syncData.sync_state = [0; 0; 1; 1; 0; 1];
[aligned, syncIndex] = DataProcessor.alignSyncTime(syncData, 0.001, 0.5, 'Test');
assert(syncIndex == 3 && aligned(syncIndex) == 0);
assert(max(abs(aligned - (-0.2:0.1:0.3)')) < 1e-12);
syncData.sync_state = [1; 1; 0; 0; 1; 1];
originalSyncData = syncData;
[aligned, syncIndex] = DataProcessor.alignSyncTime(syncData, 0.001, 0.5, 'Test');
assert(syncIndex == 5 && aligned(syncIndex) == 0);
assert(max(abs(aligned - (-0.4:0.1:0.1)')) < 1e-12);
assert(isequal(syncData, originalSyncData));
% Multiple triggers still select the first observed low-to-high edge.
syncData.sync_state = [1; 0; 1; 0; 1; 1];
[~, syncIndex] = DataProcessor.alignSyncTime(syncData, 0.001, 0.5, 'Test');
assert(syncIndex == 3);
for states = {[1;1;1;1;1;1], [0;0;0;0;0;0], [1;1;1;0;0;0]}
    syncData.sync_state = states{1};
    assertError(@() DataProcessor.alignSyncTime(syncData, 0.001, 0.5, 'Test'), ...
        'DataProcessor:MissingSyncOnset');
end
disp('DataProcessor checks passed.');
end

function assertError(action, identifier)
try
    action();
catch exception
    assert(strcmp(exception.identifier, identifier), '%s', exception.message);
    return;
end
error('testDataProcessor:ExpectedError', 'Expected error %s.', identifier);
end
