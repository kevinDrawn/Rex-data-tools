function testDataProcessor()
%TESTDATAPROCESSOR Check envelope scale, rejection, and MAT preservation.
matlabDirectory = fileparts(fileparts(mfilename('fullpath')));
originalPath = path;
restorePath = onCleanup(@() path(originalPath)); %#ok<NASGU>
addpath(fullfile(matlabDirectory, 'Class'));
processor = DataProcessor();
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
