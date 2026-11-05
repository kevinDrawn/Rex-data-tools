function testDataPlotter()
%TESTDATAPLOTTER Verify grouping, range, layout, styles, and curve colors.
matlabDirectory = fileparts(fileparts(mfilename('fullpath')));
originalPath = path;
restorePath = onCleanup(@() path(originalPath)); %#ok<NASGU>
addpath(fullfile(matlabDirectory, 'Class'));
plotter = DataPlotter();
time = (0:0.1:2)';
signals = [sin(time), cos(time)];
colors = [plotter.Config.Colors.TA; plotter.Config.Colors.GM];
assert(isequal(plotter.Config.Colors.LeftTA, colors(1, :)));
assert(isequal(plotter.Config.Colors.RightTA, colors(1, :)));
assert(isequal(plotter.Config.Colors.LeftGM, colors(2, :)));
assert(isequal(plotter.Config.Colors.RightGM, colors(2, :)));
[fig, axesHandles] = plotter.plotGroups(time, {signals, signals * 2}, ...
    [0.5 1.5], 'vertical', 'Colors', {colors, colors}, 'Visible', 'off');
cleanup = onCleanup(@() close(fig)); %#ok<NASGU>
assert(numel(axesHandles) == 2);
assert(isequal(fig.Children.GridSize, [2 1]));
selected = time >= 0.5 & time <= 1.5;
for index = 1:2
    ax = axesHandles(index);
    assert(strcmp(ax.Box, 'off') && strcmp(ax.XGrid, 'off') && strcmp(ax.YGrid, 'off'));
    assert(ax.FontSize == plotter.Config.FontSize && strcmp(ax.FontName, 'Times New Roman'));
    assert(isequal(ax.XLim, [0.5 1.5]));
    lines = findobj(ax, 'Type', 'line');
    assert(numel(lines) == 2);
    for curve = 1:2
        line = lines(arrayfun(@(item) isequal(item.Color, colors(curve, :)), lines));
        assert(isscalar(line));
        assert(isequal(line.XData(:), time(selected)));
        assert(isequal(line.YData(:), signals(selected, curve) * index));
    end
end
[horizontal, ~] = plotter.plotGroups(time, {signals, signals}, [], ...
    'horizontal', 'Visible', 'off');
cleanupHorizontal = onCleanup(@() close(horizontal)); %#ok<NASGU>
assert(isequal(horizontal.Children.GridSize, [1 2]));
assertError(@() plotter.plotGroups(time, {signals}, [3 4]), 'DataPlotter:EmptyRange');
assertError(@() plotter.plotGroups(time, {signals}, [1 0]), 'DataPlotter:InvalidRange');
assertError(@() plotter.plotGroups(time, {signals(1:end-1, :)}), 'DataPlotter:RowCountMismatch');
disp('DataPlotter checks passed.');
end

function assertError(action, identifier)
try
    action();
catch exception
    assert(strcmp(exception.identifier, identifier), '%s', exception.message);
    return;
end
error('testDataPlotter:ExpectedError', 'Expected error %s.', identifier);
end
