function testOutlierProcessing()
%TESTOUTLIERPROCESSING Synthetic spikes, variance bursts, and MAT preservation.
addpath(fullfile(fileparts(fileparts(mfilename('fullpath'))), 'Class'));
processor = DataProcessor();
x = ones(1001, 1);
x([1 500 1001]) = 100;
[cleaned, mask] = processor.removeOutliers(x);
assert(nnz(mask) == 3 && all(cleaned == 1));
[row, rowMask] = processor.removeOutliers(x');
assert(isrow(row) && isequal(rowMask, mask'));
t = (1:2001)';
normal = (-1).^t;
burst = normal;
burst(950:1050) = 10 * burst(950:1050);
[cleaned, mask, details] = processor.removeOutliers(burst, ...
    'WindowSamples', 401, 'Threshold', 100, 'VarianceRatio', 9);
assert(all(mask(950:1050)) && ~any(mask(1:800)));
assert(any(details.VarianceMask) && all(isfinite(cleaned)));
[unchanged, mask] = processor.removeOutliers(normal);
assert(isequal(unchanged, normal) && ~any(mask));
folder = tempname;
mkdir(folder);
cleanup = onCleanup(@() rmdir(folder, 's')); %#ok<NASGU>
matPath = fullfile(folder, 'test.mat');
data.Time = (1:numel(x))';
data.Left.TA = x;
data.Left.GM = zeros(size(x));
unrelated = 42;
save(matPath, 'data', 'unrelated');
[result, metadata] = processor.processOutliersMat(matPath, {'Left.TA'});
assert(isequal(result.Left.TA, x) && all(result.Left.TA_cleaned == 1));
assert(isequal(result.Left.GM, data.Left.GM));
assert(metadata.Left.TA_cleaned.ReplacedCount == 3);
saved = load(matPath);
assert(saved.unrelated == unrelated);
try
    processor.processOutliersMat(matPath, {'Left.GM', 'Left.Missing'});
    error('testOutlierProcessing:ExpectedError', 'Expected missing field failure.');
catch exception
    assert(strcmp(exception.identifier, 'DataProcessor:MissingSignal'));
end
after = load(matPath);
assert(isequal(saved, after));
disp('Outlier processing checks passed.');
end
