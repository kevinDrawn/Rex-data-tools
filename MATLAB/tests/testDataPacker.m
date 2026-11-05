function testDataPacker()
%TESTDATAPACKER Check mapping independence, MAT round-trip, and bad inputs.
matlabDirectory = fileparts(fileparts(mfilename('fullpath')));
originalPath = path;
restorePath = onCleanup(@() path(originalPath)); %#ok<NASGU>
addpath(fullfile(matlabDirectory, 'Class'));
folder = tempname;
mkdir(folder);
cleanup = onCleanup(@() rmdir(folder, 's')); %#ok<NASGU>

packer = DataPacker('Rex');
fields = packer.Config.Fields;
assert(numel(fields) == 10);
template = packer.getColumnMap();
assert(isnan(template.Time));
assert(isnan(template.Left.Angle));
assert(isnan(template.Right.GM));
source = reshape(1:50, 5, 10);
csvA = fullfile(folder, 'a.csv');
csvB = fullfile(folder, 'b.csv');
writematrix(source, csvA);
permutation = [4 7 1 10 3 9 2 6 8 5];
writematrix(source(:, permutation), csvB);
mappingA = struct();
mappingB = struct();
for index = 1:numel(fields)
    parts = strsplit(fields{index}, '.');
    mappingA = setfield(mappingA, parts{:}, index); %#ok<SFLD>
    mappingB = setfield(mappingB, parts{:}, find(permutation == index)); %#ok<SFLD>
end
dataA = packer.pack(csvA, mappingA, 'ReadVariableNames', false);
dataB = packer.pack(csvB, mappingB, 'ReadVariableNames', false);
assert(isequal(dataA, dataB), 'Column permutations changed the packed result.');
for index = 1:numel(fields)
    parts = strsplit(fields{index}, '.');
    assert(isequal(getfield(dataA, parts{:}), source(:, index))); %#ok<GFLD>
end
output = fullfile(folder, 'packed.mat');
packer.saveMat(dataA, output);
loaded = load(output);
assert(isequal(fieldnames(loaded), {'data'}));
assert(isequal(loaded.data, dataA));

missing = rmfield(mappingA, 'Time');
assertError(@() packer.pack(csvA, missing), 'DataPacker:MappingMismatch');
extra = mappingA;
extra.Unknown = 1;
assertError(@() packer.pack(csvA, extra), 'DataPacker:MappingMismatch');
outside = mappingA;
outside.Time = 11;
assertFails(@() packer.pack(csvA, outside));
unequal = dataA;
unequal.Time = unequal.Time(1:end-1);
assertError(@() packer.saveMat(unequal, output), 'DataPacker:RowCountMismatch');
assertError(@() DataPacker('Unknown'), 'DataPacker:UnknownProject');
disp('DataPacker checks passed.');
end

function assertError(action, identifier)
try
    action();
catch exception
    assert(strcmp(exception.identifier, identifier), '%s', exception.message);
    return;
end
error('testDataPacker:ExpectedError', 'Expected error %s.', identifier);
end

function assertFails(action)
try
    action();
catch
    return;
end
error('testDataPacker:ExpectedError', 'Invalid column number was accepted.');
end
