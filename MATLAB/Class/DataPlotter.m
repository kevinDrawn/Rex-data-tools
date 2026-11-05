classdef DataPlotter
    %DATAPLOTTER Plot each cell of N-by-M signals in a separate subplot.
    properties (SetAccess = private)
        Config
    end

    methods
        function obj = DataPlotter()
            configDirectory = fullfile(fileparts(mfilename('fullpath')), 'config');
            originalPath = path;
            restorePath = onCleanup(@() path(originalPath)); %#ok<NASGU>
            addpath(configDirectory);
            obj.Config = PlotConfig();
        end

        function [fig, axesHandles] = plotGroups(obj, time, groups, timeRange, direction, varargin)
            %PLOTGROUPS One group = one subplot; matrix columns = curves.
            % timeRange: [start end] in the same units as time; [] = all.
            % direction: 'vertical' (N-by-1) or 'horizontal' (1-by-N).
            % Options: Titles, YLabels, Legends, Colors (one cell per group),
            % XLabel (text), Visible ('on'/'off'). Returns figure and axes.
            if nargin < 4
                timeRange = [];
            end
            if nargin < 5
                direction = 'vertical';
            end
            validateattributes(time, {'numeric'}, {'vector', 'real', 'finite', 'nonempty'});
            time = time(:);
            if any(diff(time) < 0) || time(end) <= time(1)
                error('DataPlotter:InvalidTime', 'Time must be nondecreasing and span a nonzero interval.');
            end
            direction = validatestring(direction, {'vertical', 'horizontal'});
            if ~iscell(groups) || isempty(groups) || ~isvector(groups)
                error('DataPlotter:InvalidGroups', 'groups must be a nonempty cell vector of signal matrices.');
            end
            count = numel(groups);
            if isempty(timeRange)
                timeRange = [time(1) time(end)];
            end
            validateattributes(timeRange, {'numeric'}, {'vector', 'numel', 2, 'real', 'finite'});
            if timeRange(1) >= timeRange(2)
                error('DataPlotter:InvalidRange', 'Time range must satisfy start < end.');
            end
            selected = time >= timeRange(1) & time <= timeRange(2);
            if ~any(selected)
                error('DataPlotter:EmptyRange', 'No samples fall within the requested time range.');
            end
            parser = inputParser;
            addParameter(parser, 'Titles', repmat({''}, 1, count));
            addParameter(parser, 'YLabels', repmat({''}, 1, count));
            addParameter(parser, 'Legends', repmat({{}}, 1, count));
            addParameter(parser, 'Colors', repmat({[]}, 1, count));
            addParameter(parser, 'XLabel', 'Time', @(x) ischar(x) || (isstring(x) && isscalar(x)));
            addParameter(parser, 'Visible', 'on', @(x) any(strcmp(x, {'on', 'off'})));
            parse(parser, varargin{:});
            options = parser.Results;
            for name = {'Titles', 'YLabels', 'Legends', 'Colors'}
                value = options.(name{1});
                if ~iscell(value) || numel(value) ~= count
                    error('DataPlotter:InvalidOptions', '%s must have one cell per group.', name{1});
                end
            end
            % Validate all groups before opening a figure.
            for index = 1:count
                signals = groups{index};
                validateattributes(signals, {'numeric'}, {'2d', 'real', 'nonempty'});
                if size(signals, 1) ~= numel(time)
                    error('DataPlotter:RowCountMismatch', 'Group %d must have one row per time sample.', index);
                end
                for name = {'Titles', 'YLabels'}
                    label = options.(name{1}){index};
                    if ~(ischar(label) && (isrow(label) || isempty(label))) && ...
                            ~(isstring(label) && isscalar(label))
                        error('DataPlotter:InvalidOptions', '%s must contain text scalars.', name{1});
                    end
                end
                labels = options.Legends{index};
                if ~isempty(labels) && (~iscellstr(labels) && ~isstring(labels)) %#ok<ISCLSTR>
                    error('DataPlotter:InvalidLegend', 'Legend labels must be a cell array of text or string array.');
                end
                if ~isempty(labels) && numel(labels) ~= size(signals, 2)
                    error('DataPlotter:InvalidLegend', 'Group %d requires one legend label per curve.', index);
                end
                colors = options.Colors{index};
                if ~isempty(colors)
                    validateattributes(colors, {'numeric'}, ...
                        {'real', 'finite', 'size', [size(signals, 2) 3], '>=', 0, '<=', 1});
                end
            end

            fig = figure('Color', obj.Config.FigureColor, ...
                'Position', obj.Config.FigurePosition, 'Visible', options.Visible);
            if strcmp(direction, 'vertical')
                layout = tiledlayout(fig, count, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
            else
                layout = tiledlayout(fig, 1, count, 'TileSpacing', 'compact', 'Padding', 'compact');
            end
            axesHandles = gobjects(count, 1);
            for index = 1:count
                ax = nexttile(layout);
                axesHandles(index) = ax;
                colors = options.Colors{index};
                if isempty(colors)
                    colors = obj.Config.ColorOrder;
                end
                colororder(ax, colors);
                lines = plot(ax, time(selected), groups{index}(selected, :), 'LineWidth', obj.Config.LineWidth);
                % Assign actual line colors explicitly, independent of axes resets.
                for curve = 1:numel(lines)
                    colorIndex = mod(curve - 1, size(colors, 1)) + 1;
                    lines(curve).Color = colors(colorIndex, :);
                end
                set(ax, 'Box', obj.Config.Box, 'XGrid', obj.Config.Grid, ...
                    'YGrid', obj.Config.Grid, 'XMinorGrid', obj.Config.Grid, ...
                    'YMinorGrid', obj.Config.Grid, 'FontSize', obj.Config.FontSize, ...
                    'FontName', obj.Config.FontName, 'TickLabelInterpreter', 'none', ...
                    'TitleFontSizeMultiplier', 1, 'LabelFontSizeMultiplier', 1);
                title(ax, options.Titles{index}, 'Interpreter', 'none');
                ylabel(ax, options.YLabels{index}, 'Interpreter', 'none');
                xlabel(ax, options.XLabel, 'Interpreter', 'none');
                xlim(ax, timeRange);
                if ~isempty(options.Legends{index})
                    legend(ax, options.Legends{index}, 'Interpreter', 'none', ...
                        'Box', 'off', 'FontSize', obj.Config.FontSize, ...
                        'FontName', obj.Config.FontName, 'Location', 'northeastoutside');
                end
            end
            linkaxes(axesHandles, 'x');
        end
    end
end
