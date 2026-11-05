classdef DataProcessor
    %DATAPROCESSOR Process selected raw EMG channels and extend a MAT file.
    properties (SetAccess = private)
        Config
    end

    methods
        function obj = DataProcessor()
            configDirectory = fullfile(fileparts(mfilename('fullpath')), 'config');
            originalPath = path;
            restorePath = onCleanup(@() path(originalPath)); %#ok<NASGU>
            addpath(configDirectory);
            obj.Config = EMGConfig();
        end

        function filtered = filterEMG(obj, raw, sampleRateHz)
            %FILTEREMG Return an N-by-1 voltage envelope from signed ADC counts.
            % Optional sampleRateHz overrides config.SampleRateHz.
            if nargin < 3
                sampleRateHz = obj.Config.SampleRateHz;
            end
            config = obj.Config;
            validateattributes(sampleRateHz, {'numeric'}, {'scalar', 'real', 'finite', 'positive'});
            validateattributes(config.ADCBits, {'numeric'}, {'scalar', 'integer', '>=', 2, '<=', 32});
            validateattributes(config.VRef, {'numeric'}, {'scalar', 'real', 'finite', 'positive'});
            validateattributes(config.ADCGain, {'numeric'}, {'scalar', 'real', 'finite', 'positive'});
            validateattributes(config.BandpassHz, {'numeric'}, {'vector', 'numel', 2, 'real', 'finite', 'positive'});
            validateattributes(config.LowpassHz, {'numeric'}, {'scalar', 'real', 'finite', 'positive'});
            validateattributes(config.BandpassOrder, {'numeric'}, {'scalar', 'integer', 'positive', 'even'});
            validateattributes(config.LowpassOrder, {'numeric'}, {'scalar', 'integer', 'positive'});
            if config.BandpassHz(1) >= config.BandpassHz(2) || ...
                    config.BandpassHz(2) >= sampleRateHz / 2 || config.LowpassHz >= sampleRateHz / 2
                error('DataProcessor:InvalidCutoff', 'Cutoffs must be ordered and strictly below Nyquist (Fs/2).');
            end
            validateattributes(raw, {'numeric'}, {'vector', 'nonempty', 'real', 'finite', 'integer'});
            raw = double(raw(:));
            fullScale = 2^(config.ADCBits - 1);
            if any(raw < -fullScale | raw > fullScale - 1)
                error('DataProcessor:ADCOutOfRange', 'Raw samples must be signed %d-bit ADC counts.', config.ADCBits);
            end
            if config.ZeroPhase && numel(raw) <= 3 * max(config.BandpassOrder, config.LowpassOrder)
                error('DataProcessor:SignalTooShort', 'Not enough samples for forward-backward filtering.');
            end
            if exist('butter', 'file') == 0 || exist('filtfilt', 'file') == 0 || exist('zp2sos', 'file') == 0
                error('DataProcessor:MissingToolbox', 'Signal Processing Toolbox is required.');
            end
            % Signed two's-complement bipolar scaling: -2^(bits-1) -> -VRef/Gain.
            volts = raw * (config.VRef / (config.ADCGain * fullScale));
            [z, p, k] = butter(config.BandpassOrder / 2, config.BandpassHz / (sampleRateHz / 2), 'bandpass');
            [bandSOS, bandGain] = zp2sos(z, p, k);
            bandpassed = obj.applyFilter(bandSOS, bandGain, volts);
            if config.Rectify
                bandpassed = abs(bandpassed);
            end
            [z, p, k] = butter(config.LowpassOrder, config.LowpassHz / (sampleRateHz / 2), 'low');
            [lowSOS, lowGain] = zp2sos(z, p, k);
            filtered = obj.applyFilter(lowSOS, lowGain, bandpassed);
        end

        function data = processEMGMat(obj, matPath, signalFields, sampleRateHz)
            %PROCESSEMGMat Add e.g. data.Left.TA_filtered to an existing MAT.
            % signalFields: {'Left.TA','Left.GM'} or a string vector.
            % Raw fields and unrelated MAT variables are preserved.
            if nargin < 4
                sampleRateHz = obj.Config.SampleRateHz;
            end
            if ~isfile(matPath)
                error('DataProcessor:MissingMAT', 'MAT file does not exist: %s.', matPath);
            end
            if ischar(signalFields)
                signalFields = {signalFields};
            elseif isstring(signalFields)
                signalFields = cellstr(signalFields);
            end
            if ~iscellstr(signalFields) || isempty(signalFields) || ~isvector(signalFields) %#ok<ISCLSTR>
                error('DataProcessor:InvalidFields', 'Specify a nonempty list of raw signal field paths.');
            end
            if numel(unique(signalFields)) ~= numel(signalFields)
                error('DataProcessor:DuplicateFields', 'Signal field paths must be unique.');
            end
            loaded = load(matPath, 'data');
            variables = whos('-file', matPath);
            if any(strcmp({variables.name}, 'EMGProcessing'))
                savedMetadata = load(matPath, 'EMGProcessing');
                loaded.EMGProcessing = savedMetadata.EMGProcessing;
            end
            if ~isfield(loaded, 'data') || ~isstruct(loaded.data) || ~isscalar(loaded.data)
                error('DataProcessor:InvalidMAT', 'MAT file must contain a scalar data struct.');
            end
            data = loaded.data;
            if ~isfield(data, 'Time')
                error('DataProcessor:MissingTime', 'data.Time is required to verify the sample rate.');
            end
            validateattributes(sampleRateHz, {'numeric'}, {'scalar', 'real', 'finite', 'positive'});
            validateattributes(data.Time, {'numeric'}, {'column', 'real', 'finite', 'nonempty'});
            intervals = diff(double(data.Time)) * obj.Config.TimeScaleToSeconds;
            expected = 1 / sampleRateHz;
            if isempty(intervals) || any(abs(intervals - expected) > expected * obj.Config.SampleIntervalTolerance)
                error('DataProcessor:InvalidSampleRate', ...
                    'data.Time must be uniformly sampled at Fs. Check Fs and config.TimeScaleToSeconds.');
            end
            if isfield(loaded, 'EMGProcessing')
                EMGProcessing = loaded.EMGProcessing;
                if ~isstruct(EMGProcessing) || ~isscalar(EMGProcessing)
                    error('DataProcessor:InvalidMetadata', 'EMGProcessing must be a scalar struct.');
                end
            else
                EMGProcessing = struct();
            end
            for index = 1:numel(signalFields)
                parts = strsplit(signalFields{index}, '.');
                if ~all(cellfun(@isvarname, parts)) || endsWith(parts{end}, obj.Config.OutputSuffix)
                    error('DataProcessor:InvalidFields', 'Specify raw field paths without the filtered suffix.');
                end
                try
                    raw = getfield(data, parts{:}); %#ok<GFLD>
                catch
                    error('DataProcessor:MissingSignal', 'Raw field not found: %s.', signalFields{index});
                end
                if numel(raw) ~= numel(data.Time)
                    error('DataProcessor:RowCountMismatch', 'Signal %s must match data.Time length.', signalFields{index});
                end
                filtered = obj.filterEMG(raw, sampleRateHz);
                parts{end} = [parts{end} obj.Config.OutputSuffix];
                data = setfield(data, parts{:}, filtered); %#ok<SFLD>
                metadata = obj.Config;
                metadata.SampleRateHz = sampleRateHz;
                metadata.SourceField = signalFields{index};
                metadata.ADCEncoding = 'signed twos complement';
                EMGProcessing = setfield(EMGProcessing, parts{:}, metadata); %#ok<SFLD>
            end
            % Only write after every selected signal has passed processing.
            save(matPath, 'data', 'EMGProcessing', '-append');
        end
    end

    methods (Access = private)
        function output = applyFilter(obj, sos, gain, input)
            if obj.Config.ZeroPhase
                output = filtfilt(sos, gain, input);
            else
                output = sosfilt(sos, gain * input);
            end
        end
    end
end
