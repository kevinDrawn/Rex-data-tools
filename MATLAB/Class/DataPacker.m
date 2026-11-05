classdef DataPacker
    %DATAPACKER Map CSV columns to a project's standard MATLAB structure.
    % pack returns a struct; saveMat writes it as variable "data".

    properties (SetAccess = private)
        ProjectType
        Config
    end

    methods
        function obj = DataPacker(projectType)
            validateattributes(projectType, {'char', 'string'}, ...
                {'nonempty'}, mfilename, 'projectType');
            if (isstring(projectType) && ~isscalar(projectType)) || ...
                    (ischar(projectType) && ~isrow(projectType))
                error('DataPacker:InvalidProject', 'Project type must be a text scalar.');
            end
            projectType = char(projectType);
            if ~isvarname(projectType)
                error('DataPacker:InvalidProject', 'Project type must be a valid MATLAB identifier.');
            end
            % Resolve config relative to this class; restore path afterwards.
            configDirectory = fullfile(fileparts(mfilename('fullpath')), 'config');
            configs = dir(fullfile(configDirectory, '*Config.m'));
            match = find(strcmpi({configs.name}, [projectType 'Config.m']));
            if numel(match) ~= 1
                error('DataPacker:UnknownProject', ...
                    'Unsupported project type: %s.', projectType);
            end
            [~, configFunction] = fileparts(configs(match).name);
            originalPath = path;
            restorePath = onCleanup(@() path(originalPath)); %#ok<NASGU>
            addpath(configDirectory);
            obj.Config = feval(configFunction);
            obj.ProjectType = obj.Config.ProjectType;
        end

        function columnMap = getColumnMap(obj)
            %GETCOLUMNMAP Get the project's mapping template.
            % Replace each NaN with the corresponding 1-based CSV column.
            columnMap = struct();
            for index = 1:numel(obj.Config.Fields)
                parts = strsplit(obj.Config.Fields{index}, '.');
                columnMap = setfield(columnMap, parts{:}, NaN); %#ok<SFLD>
            end
        end

        function data = pack(obj, csvPath, columnMap, varargin)
            %PACK Read a CSV and map each signal to an N-by-1 vector.
            % columnMap mirrors the output structure; its leaves are 1-based
            % CSV column numbers. Additional arguments go to readtable, e.g.
            % pack(..., 'NumHeaderLines', 2).
            if ~isfile(csvPath)
                error('DataPacker:MissingCSV', 'CSV file does not exist: %s.', csvPath);
            end
            if ~isstruct(columnMap) || ~isscalar(columnMap)
                error('DataPacker:InvalidMapping', 'columnMap must be a scalar struct.');
            end
            csv = readtable(csvPath, varargin{:});
            if height(csv) == 0
                error('DataPacker:EmptyCSV', 'CSV contains no data rows.');
            end
            obj.validateMapping(columnMap, obj.Config.Fields, width(csv));
            data = struct();
            for index = 1:numel(obj.Config.Fields)
                fieldPath = obj.Config.Fields{index};
                parts = strsplit(fieldPath, '.');
                column = getfield(columnMap, parts{:}); %#ok<GFLD>
                values = csv{:, column};
                if ~isnumeric(values) || ~isreal(values) || size(values, 2) ~= 1
                    error('DataPacker:NonNumericSignal', ...
                        'Signal %s (CSV column %d) must contain real numeric data.', ...
                        fieldPath, column);
                end
                data = setfield(data, parts{:}, values); %#ok<SFLD>
            end
        end

        function saveMat(obj, data, outputPath)
            %SAVEMAT Save the packed structure as a variable named data.
            obj.validateData(data);
            [~, ~, extension] = fileparts(outputPath);
            if ~strcmpi(extension, '.mat')
                error('DataPacker:InvalidOutputPath', 'Output path must end with .mat.');
            end
            save(outputPath, 'data');
        end
    end

    methods (Access = private)
        function validateMapping(obj, columnMap, expected, numberOfColumns)
            actual = obj.leafPaths(columnMap, '');
            missing = setdiff(expected, actual);
            extra = setdiff(actual, expected);
            if ~isempty(missing) || ~isempty(extra)
                error('DataPacker:MappingMismatch', ...
                    'Mapping fields differ from config. Missing: [%s]. Extra: [%s].', ...
                    strjoin(missing, ', '), strjoin(extra, ', '));
            end
            for index = 1:numel(expected)
                parts = strsplit(expected{index}, '.');
                column = getfield(columnMap, parts{:}); %#ok<GFLD>
                validateattributes(column, {'numeric'}, ...
                    {'scalar', 'real', 'finite', 'integer', 'positive', '<=', numberOfColumns}, ...
                    'DataPacker.pack', expected{index});
            end
        end

        function validateData(obj, data)
            if ~isstruct(data) || ~isscalar(data)
                error('DataPacker:InvalidData', 'data must be a scalar struct.');
            end
            actual = obj.leafPaths(data, '');
            if ~isempty(setxor(obj.Config.Fields, actual))
                error('DataPacker:InvalidData', 'Data fields must match the project config.');
            end
            numberOfRows = [];
            for index = 1:numel(obj.Config.Fields)
                parts = strsplit(obj.Config.Fields{index}, '.');
                values = getfield(data, parts{:}); %#ok<GFLD>
                validateattributes(values, {'numeric'}, {'real', 'column', 'nonempty'});
                if isempty(numberOfRows)
                    numberOfRows = size(values, 1);
                elseif size(values, 1) ~= numberOfRows
                    error('DataPacker:RowCountMismatch', 'All signals must have the same number of rows.');
                end
            end
        end
    end

    methods (Static, Access = private)
        function paths = leafPaths(value, prefix)
            paths = cell(0, 1);
            names = fieldnames(value);
            for index = 1:numel(names)
                name = names{index};
                if isempty(prefix)
                    fieldPath = name;
                else
                    fieldPath = [prefix '.' name];
                end
                child = value.(name);
                if isstruct(child) && isscalar(child) && ~isempty(fieldnames(child))
                    paths = [paths; DataPacker.leafPaths(child, fieldPath)]; %#ok<AGROW>
                else
                    paths{end + 1, 1} = fieldPath; %#ok<AGROW>
                end
            end
        end
    end
end
