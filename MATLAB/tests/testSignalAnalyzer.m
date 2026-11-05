function testSignalAnalyzer()
%TESTSIGNALANALYZER Clock mapping, square-wave metrics and MAT field selection.
originalPath = path;
restorePath = onCleanup(@() path(originalPath)); %#ok<NASGU>
addpath(fullfile(fileparts(fileparts(mfilename('fullpath'))), 'Class'));
analyzer = SignalAnalyzer();
assert(analyzer.expectedTestFrequencyHz(0) == 0.9765625);
assert(analyzer.expectedTestFrequencyHz(1) == 1.953125);
assert(analyzer.expectedTestFrequencyHz(3) == 0);
assert(analyzer.expectedTestFrequencyHz(1, 2^21) == 2);
assertError(@() analyzer.expectedTestFrequencyHz(2), 'SignalAnalyzer:ReservedTestFrequency');
t = (0:0.0005:10)';
frequency = analyzer.expectedTestFrequencyHz();
x = -5000 + 9000 * double(mod(t * frequency, 1) < 0.5);
x = x + 5 * sin(2*pi*71*t);
result = analyzer.analyzeSquareWave(t * 1000, x);
assert(abs(result.FrequencyHz - frequency) < 0.001);
assert(abs(result.PeriodSeconds - 0.512) < 0.0005);
assert(abs(result.DutyCyclePercent - 50) < 0.2);
assert(result.WithinTolerance && result.CompleteCycleCount > 10);
assert(result.PeriodCVPercent < 0.2 && result.Timing.EstimatedMissingSampleCount == 0);
assert(result.Timing.IrregularIntervalCount == 0);
% Three removed acquisition samples leave one four-interval timestamp gap.
keep = true(size(t)); keep(1500:1502) = false;
timing = analyzer.analyzeSampleTiming(t(keep), 'TimeScaleToSeconds', 1);
assert(timing.GapCount == 1 && timing.EstimatedMissingSampleCount == 3);
assert(timing.GapIntervalIndices == 1499 && ~timing.MissingSamplesConfirmed);
gapped = analyzer.analyzeSquareWave(t(keep)*1000, x(keep));
assert(any(gapped.CyclesCrossingGaps));
% A long signal level hides one pulse: retain the anomalous full-cycle period.
lostPulse = x;
lostPulse(t >= 2.5 & t < 3.1) = -5000;
unstable = analyzer.analyzeSquareWave(t*1000, lostPulse);
assert(unstable.CycleJitterExceededCount > 0);
assert(unstable.PeriodMaxSeconds > 1.5 * unstable.MedianPeriodSeconds);
assert(unstable.Timing.GapCount == 0);
seconds = analyzer.analyzeSquareWave(t, x, 'TimeScaleToSeconds', 1);
assert(abs(seconds.FrequencyHz - result.FrequencyHz) < 1e-10);
wrongClock = analyzer.analyzeSquareWave(t*1000, x, 'ClockFrequencyHz', 2^21);
assert(~wrongClock.WithinTolerance);
assertError(@() analyzer.analyzeSquareWave(t, x, 'TestFrequencyBits', 3), 'SignalAnalyzer:DCMode');
assertError(@() analyzer.analyzeSquareWave(t, zeros(size(t))), 'SignalAnalyzer:NoAmplitude');
assertError(@() analyzer.analyzeSquareWave([0 1 1], [0 1 0]), 'SignalAnalyzer:InvalidTime');
assertError(@() analyzer.analyzeSquareWave((1:100)', [zeros(50, 1); ones(50, 1)]), 'SignalAnalyzer:InsufficientCycles');
% Small midpoint chatter never reaches the upper threshold.
chatter = x;
chatter(700:704) = [-600 -400 -600 -400 -600];
chatterResult = analyzer.analyzeSquareWave(t*1000, chatter);
assert(chatterResult.CompleteCycleCount == result.CompleteCycleCount);
folder = tempname;
mkdir(folder);
cleanup = onCleanup(@() rmdir(folder, 's')); %#ok<NASGU>
matPath = fullfile(folder, 'test.mat');
data.Time = t * 1000;
data.Left.TA = x;
unrelated = 42;
save(matPath, 'data', 'unrelated');
reports = analyzer.analyzeSquareWaveMat(matPath, {'Left.TA'});
assert(isequal(reports.Left.TA.FrequencyHz, result.FrequencyHz));
saved = load(matPath);
assert(isequal(saved.data, data) && saved.unrelated == unrelated);
assertError(@() analyzer.analyzeSquareWaveMat(matPath, {'Left.Missing'}), 'SignalAnalyzer:MissingSignal');
disp('SignalAnalyzer checks passed.');
end

function assertError(action, identifier)
try
    action();
catch exception
    assert(strcmp(exception.identifier, identifier), '%s', exception.message);
    return;
end
error('testSignalAnalyzer:ExpectedError', 'Expected error %s.', identifier);
end
