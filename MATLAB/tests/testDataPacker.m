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

% Rex supports old mappings and unassigned optional template entries.
assert(isnan(template.sync_state));
optional = mappingA;
optional.sync_state = NaN;
assert(isequal(packer.pack(csvA, optional, 'ReadVariableNames', false), dataA));
optional.sync_state = [];
assert(isequal(packer.pack(csvA, optional, 'ReadVariableNames', false), dataA));
optional.sync_state = 2;
withSync = packer.pack(csvA, optional, 'ReadVariableNames', false);
assert(isequal(withSync.sync_state, source(:, 2)));
packer.saveMat(withSync, output);
loaded = load(output);
assert(isequal(loaded.data, withSync));
optional.sync_state = 11;
assertFails(@() packer.pack(csvA, optional, 'ReadVariableNames', false));
badSync = withSync;
badSync.sync_state = badSync.sync_state(1:end-1);
assertError(@() packer.saveMat(badSync, output), 'DataPacker:RowCountMismatch');

mocap = DataPacker('Mocap_Hall');
assert(strcmp(mocap.ProjectType, 'Mocap_Hall'));
mocapMap = mocap.getColumnMap();
assert(isequal(fieldnames(mocapMap), {'Time'; 'mocap_angle'; 'sync_state'}));
mocapMap.Time = 3;
mocapMap.mocap_angle = 1;
mocapMap.sync_state = 2;
mocapData = mocap.pack(csvA, mocapMap, 'ReadVariableNames', false);
assert(isequal(mocapData.Time, source(:, 3)));
assert(isequal(mocapData.mocap_angle, source(:, 1)));
assert(isequal(mocapData.sync_state, source(:, 2)));
mocap.saveMat(mocapData, output);
loaded = load(output);
assert(isequal(loaded.data, mocapData));
assertError(@() mocap.pack(csvA, rmfield(mocapMap, 'sync_state')), ...
    'DataPacker:MappingMismatch');
mocapMap.sync_state = NaN;
assertFails(@() mocap.pack(csvA, mocapMap));

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
