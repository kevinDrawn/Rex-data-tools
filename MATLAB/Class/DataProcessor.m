classdef DataProcessor
    %DATAPROCESSOR Preprocess signals, align time axes, and extend MAT files.
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

        function [cleaned, mask, details] = removeOutliers(~, signal, varargin)
            %REMOVEOUTLIERS Repair local amplitude/variance artifacts by interpolation.
            % Window sizes are samples. Variance detection is opt-in because
            % physiological EMG bursts can also increase local variance.
            parser = inputParser;
            windowCheck = @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x >= 3 && mod(x, 2) == 1;
            positiveCheck = @(x) isnumeric(x) && isscalar(x) && isreal(x) && isfinite(x) && x > 0;
            addParameter(parser, 'WindowSamples', 201, windowCheck);
            addParameter(parser, 'Threshold', 6, positiveCheck);
            addParameter(parser, 'VarianceWindowSamples', 21, windowCheck);
            addParameter(parser, 'VarianceRatio', Inf, @(x) positiveCheck(x) || isequal(x, Inf));
            parse(parser, varargin{:});
            options = parser.Results;
            validateattributes(signal, {'numeric'}, {'vector', 'nonempty', 'real', 'finite'});
            x = double(signal(:));
            baseline = movmedian(x, options.WindowSamples);
            deviation = abs(x - baseline);
            localScale = 1.4826 * movmedian(deviation, options.WindowSamples);
            % Avoid a zero threshold in constant or quantized recordings.
            scaleFloor = eps(max(1, max(abs(x))));
            amplitudeMask = deviation > options.Threshold * max(localScale, scaleFloor);
            varianceMask = false(size(x));
            if isfinite(options.VarianceRatio)
                if options.VarianceWindowSamples >= options.WindowSamples
                    error('DataProcessor:InvalidWindows', 'VarianceWindowSamples must be smaller than WindowSamples.');
                end
                % Remove amplitude spikes before assessing sustained variance.
                residual = x - baseline;
                residual(amplitudeMask) = 0;
                localVariance = movvar(residual, options.VarianceWindowSamples);
                referenceVariance = movmedian(localVariance, options.WindowSamples);
                varianceMask = localVariance > options.VarianceRatio * max(referenceVariance, scaleFloor^2);
            end
            mask = amplitudeMask | varianceMask;
            cleaned = x;
            if any(mask)
                good = find(~mask);
                if numel(good) < 2
                    error('DataProcessor:InsufficientCleanSamples', 'At least two unflagged samples are required for interpolation.');
                end
                interior = mask & (1:numel(x))' >= good(1) & (1:numel(x))' <= good(end);
                cleaned(interior) = interp1(good, x(good), find(interior), 'linear');
                % Edge artifacts use the nearest retained value, not extrapolation.
                cleaned(1:good(1)-1) = x(good(1));
                cleaned(good(end)+1:end) = x(good(end));
            end
            cleaned = reshape(cleaned, size(signal));
            mask = reshape(mask, size(signal));
            details = options;
            details.AmplitudeMask = reshape(amplitudeMask, size(signal));
            details.VarianceMask = reshape(varianceMask, size(signal));
            details.Mask = mask;
            details.ReplacedCount = nnz(mask);
        end

        function [data, OutlierProcessing] = processOutliersMat(obj, matPath, signalFields, varargin)
            %PROCESSOUTLIERSMAT Append selected fields as *_cleaned, preserving sources.
            % Example: processOutliersMat(path, {'Left.TA_filtered'}, ...
            %     'WindowSamples', 201, 'Threshold', 6, 'VarianceRatio', 9)
            if ischar(signalFields) || isstring(signalFields)
                signalFields = cellstr(signalFields);
            end
            if ~iscellstr(signalFields) || isempty(signalFields) || ~isvector(signalFields) %#ok<ISCLSTR>
                error('DataProcessor:InvalidFields', 'Specify a nonempty list of signal field paths.');
            end
            if numel(unique(signalFields)) ~= numel(signalFields)
                error('DataProcessor:DuplicateFields', 'Signal field paths must be unique.');
            end
            loaded = load(matPath);
            if ~isfield(loaded, 'data') || ~isstruct(loaded.data) || ~isscalar(loaded.data)
                error('DataProcessor:InvalidMAT', 'MAT file must contain a scalar data struct.');
            end
            data = loaded.data;
            OutlierProcessing = struct();
            if isfield(loaded, 'OutlierProcessing')
                OutlierProcessing = loaded.OutlierProcessing;
            end
            for index = 1:numel(signalFields)
                parts = strsplit(signalFields{index}, '.');
                if ~all(cellfun(@isvarname, parts)) || endsWith(parts{end}, '_cleaned')
                    error('DataProcessor:InvalidFields', 'Specify source field paths without the cleaned suffix.');
                end
                try
                    signal = getfield(data, parts{:}); %#ok<GFLD>
                catch
                    error('DataProcessor:MissingSignal', 'Signal field not found: %s.', signalFields{index});
                end
                if isfield(data, 'Time') && numel(signal) ~= numel(data.Time)
                    error('DataProcessor:RowCountMismatch', 'Signal %s must match data.Time length.', signalFields{index});
                end
                [cleaned, ~, metadata] = obj.removeOutliers(signal, varargin{:});
                metadata.SourceField = signalFields{index};
                parts{end} = [parts{end} '_cleaned'];
                data = setfield(data, parts{:}, cleaned); %#ok<SFLD>
                OutlierProcessing = setfield(OutlierProcessing, parts{:}, metadata); %#ok<SFLD>
            end
            % Commit only after all selected fields have been processed.
            save(matPath, 'data', 'OutlierProcessing', '-append');
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

    methods (Static)
        function result = extractPawClearance(time, toeHeight, stanceState, varargin)
            %EXTRACTPAWCLEARANCE Pair each eligible stance with the next observed swing.
            % Ground = minimum height in stance (1); peak = maximum height in
            % the immediately following swing (0). Clearance = peak - ground.
            % Heights must increase upward. Both phases use the SAME input trace.
            % Time is the peak time. Sample indices are 1-based input-row indices.
            % A recording starting in stance is treated as partial unless the
            % caller confirms its start (for example, an IC flag at row 1).
            validateattributes(time, {'numeric'}, ...
                {'column', 'real', 'finite', 'nonempty', 'increasing'});
            validateattributes(toeHeight, {'numeric'}, ...
                {'column', 'real', 'finite', 'numel', numel(time)});
            validateattributes(stanceState, {'numeric', 'logical'}, ...
                {'column', 'real', 'finite', 'numel', numel(time)});
            if any(stanceState ~= 0 & stanceState ~= 1)
                error('DataProcessor:InvalidStance', 'Stance labels must be 0 or 1.');
            end
            parser = inputParser;
            addParameter(parser, 'InitialStanceIsComplete', false, ...
                @(value) islogical(value) && isscalar(value));
            parse(parser, varargin{:});
            state = logical(stanceState);
            starts = [1; find(diff(state) ~= 0) + 1];
            ends = [starts(2:end)-1; numel(state)];
            pairs = find(state(starts(1:end-1)) & ~state(starts(2:end)));
            % Retain a trailing swing using its available samples. Its peak is
            % the observed maximum; a later stance need not be in the recording.
            % SwingEndObserved = 0 distinguishes this boundary case in saved data.
            if ~parser.Results.InitialStanceIsComplete
                pairs = pairs(starts(pairs) > 1);
            end
            count = numel(pairs);
            names = {'Cycle', 'Time', 'StanceStartIndex', 'StanceEndIndex', ...
                'SwingStartIndex', 'SwingEndIndex', 'StanceStartTime_s', ...
                'StanceEndTime_s', 'SwingStartTime_s', 'SwingEndTime_s', ...
                'GroundIndex', 'GroundTime_s', 'GroundHeight_mm', ...
                'PeakIndex', 'PeakTime_s', 'PeakToeHeight_mm', 'PeakPawHeight_mm', ...
                'SwingEndObserved'};
            result = struct();
            for field = 1:numel(names)
                result.(names{field}) = zeros(count, 1);
            end
            for cycle = 1:count
                run = pairs(cycle);
                stanceRows = starts(run):ends(run);
                swingRows = starts(run+1):ends(run+1);
                [ground, groundOffset] = min(toeHeight(stanceRows));
                [peak, peakOffset] = max(toeHeight(swingRows));
                groundRow = stanceRows(groundOffset);
                peakRow = swingRows(peakOffset);
                result.Cycle(cycle) = cycle;
                result.Time(cycle) = time(peakRow);
                result.StanceStartIndex(cycle) = stanceRows(1);
                result.StanceEndIndex(cycle) = stanceRows(end);
                result.SwingStartIndex(cycle) = swingRows(1);
                result.SwingEndIndex(cycle) = swingRows(end);
                result.StanceStartTime_s(cycle) = time(stanceRows(1));
                result.StanceEndTime_s(cycle) = time(stanceRows(end));
                result.SwingStartTime_s(cycle) = time(swingRows(1));
                result.SwingEndTime_s(cycle) = time(swingRows(end));
                result.GroundIndex(cycle) = groundRow;
                result.GroundTime_s(cycle) = time(groundRow);
                result.GroundHeight_mm(cycle) = ground;
                result.PeakIndex(cycle) = peakRow;
                result.PeakTime_s(cycle) = time(peakRow);
                result.PeakToeHeight_mm(cycle) = peak;
                result.PeakPawHeight_mm(cycle) = peak - ground;
                result.SwingEndObserved(cycle) = double(run+1 < numel(starts));
            end
        end

        function time = framesToTime(frame, fps, frameOrigin)
            %FRAMESTOTIME Convert source frame IDs to seconds without closing gaps.
            % Zero-based video frame IDs use frameOrigin = 0 (the default).
            % For one-based frame IDs use frameOrigin = 1. Cropped recordings
            % retain their position on the original video timeline.
            if nargin < 3
                frameOrigin = 0;
            end
            validateattributes(frame, {'numeric'}, ...
                {'vector', 'real', 'finite', 'integer', 'nonempty'});
            validateattributes(fps, {'numeric'}, ...
                {'scalar', 'real', 'finite', 'positive'});
            validateattributes(frameOrigin, {'numeric'}, ...
                {'scalar', 'real', 'finite', 'integer'});
            frame = double(frame(:));
            if any(frame < frameOrigin) || any(diff(frame) <= 0)
                error('DataProcessor:InvalidFrame', ...
                    'Frame IDs must be strictly increasing and >= frameOrigin.');
            end
            time = (frame - double(frameOrigin)) / double(fps);
        end

        function filtered = filterFirstOrderLowpass(time, signal, cutoffHz)
            %FILTERFIRSTORDERLOWPASS Causal RC LPF using each interval in seconds.
            % Backward Euler: alpha = dt/(RC + dt), RC = 1/(2*pi*cutoffHz).
            % Initialize at the first value to avoid a zero-state startup jump.
            validateattributes(time, {'numeric'}, {'vector', 'real', 'finite', 'nonempty'});
            validateattributes(signal, {'numeric'}, ...
                {'vector', 'real', 'finite', 'numel', numel(time)});
            validateattributes(cutoffHz, {'numeric'}, {'scalar', 'real', 'finite', 'positive'});
            time = double(time(:));
            intervals = diff(time);
            if isempty(intervals) || any(intervals <= 0)
                error('DataProcessor:InvalidTime', 'LPF time must be strictly increasing with at least two samples.');
            end
            if cutoffHz >= 0.5 / median(intervals)
                error('DataProcessor:InvalidCutoff', 'LPF cutoff must be below the nominal Nyquist frequency.');
            end
            values = double(signal(:));
            filtered = values;
            rc = 1 / (2*pi*cutoffHz);
            for index = 2:numel(values)
                alpha = intervals(index-1) / (rc + intervals(index-1));
                filtered(index) = filtered(index-1) + alpha * (values(index) - filtered(index-1));
            end
            filtered = reshape(filtered, size(signal));
        end

        function result = fitMocapBias(rexTime, rexAngle, mocapTime, mocapAngle, timeRange)
            %FITMOCAPBIAS Fit mocap_corrected = mocap - BiasDegrees.
            % Minimize RMSE on native Mocap timestamps in the synced interval.
            % Interpolate Rex linearly without extrapolation; ignore nonfinite pairs.
            validateattributes(rexTime, {'numeric'}, {'vector', 'real', 'finite', 'nonempty'});
            validateattributes(mocapTime, {'numeric'}, {'vector', 'real', 'finite', 'nonempty'});
            validateattributes(rexAngle, {'numeric'}, {'vector', 'real', 'numel', numel(rexTime)});
            validateattributes(mocapAngle, {'numeric'}, {'vector', 'real', 'numel', numel(mocapTime)});
            rexTime = double(rexTime(:));
            mocapTime = double(mocapTime(:));
            if numel(rexTime) < 2 || any(diff(rexTime) <= 0) || ...
                    numel(mocapTime) < 2 || any(diff(mocapTime) <= 0)
                error('DataProcessor:InvalidTime', 'Bias fitting requires strictly increasing time vectors.');
            end
            overlap = [max(rexTime(1), mocapTime(1)), min(rexTime(end), mocapTime(end))];
            if nargin < 5 || isempty(timeRange)
                timeRange = overlap;
            end
            validateattributes(timeRange, {'numeric'}, {'vector', 'numel', 2, 'real', 'finite'});
            if timeRange(1) >= timeRange(2)
                error('DataProcessor:InvalidBiasRange', 'Bias time range must satisfy start < end.');
            end
            effectiveRange = [max(timeRange(1), overlap(1)), min(timeRange(2), overlap(2))];
            selected = mocapTime >= effectiveRange(1) & mocapTime <= effectiveRange(2);
            comparisonTime = mocapTime(selected);
            rexOnMocap = interp1(rexTime, double(rexAngle(:)), comparisonTime, 'linear', NaN);
            mocapValues = double(mocapAngle(:));
            mocapValues = mocapValues(selected);
            valid = isfinite(rexOnMocap) & isfinite(mocapValues);
            if nnz(valid) < 2
                error('DataProcessor:InsufficientBiasSamples', ...
                    'Bias range must contain at least two finite overlapping Mocap/Rex pairs.');
            end
            residual = mocapValues(valid) - rexOnMocap(valid);
            result.BiasDegrees = mean(residual);
            result.RMSEBeforeDegrees = sqrt(mean(residual.^2));
            result.RMSEAfterDegrees = sqrt(mean((residual - result.BiasDegrees).^2));
            result.RequestedTimeRange = timeRange(:)';
            result.EffectiveTimeRange = effectiveRange;
            result.SampleCount = nnz(valid);
            result.Time = comparisonTime(valid);
            result.RexAngle = rexOnMocap(valid);
            result.MocapAngle = mocapValues(valid);
            result.ResidualBeforeDegrees = residual;
            result.ResidualAfterDegrees = residual - result.BiasDegrees;
        end

        function [time, syncIndex] = alignSyncTime(data, scale, threshold, source)
            %ALIGNSYNCTIME Return seconds relative to the first observed rising edge.
            % Preserve the source data and its original time axis.
            validateattributes(scale, {'numeric'}, {'scalar', 'real', 'finite', 'positive'});
            validateattributes(threshold, {'numeric'}, {'scalar', 'real', 'finite'});
            if ~isfield(data, 'sync_state')
                error('DataProcessor:MissingSync', ...
                    '%s requires a sync_state column mapping for synchronization.', source);
            end
            validateattributes(data.Time, {'numeric'}, ...
                {'column', 'real', 'finite', 'nonempty'});
            if numel(data.Time) < 2 || any(diff(data.Time) <= 0)
                error('DataProcessor:InvalidTime', ...
                    '%s Time must contain at least two strictly increasing samples.', source);
            end
            validateattributes(data.sync_state, {'numeric'}, ...
                {'column', 'real', 'finite', 'numel', numel(data.Time)});
            on = data.sync_state > threshold;
            % Ignore an initial high plateau; only an observed off-to-on edge counts.

            syncIndex = find(~on(1:end-1) & on(2:end), 1, 'first') + 1;
            if isempty(syncIndex)
                error('DataProcessor:MissingSyncOnset', ...
                    '%s has no observed off-to-on sync transition. Record a low state followed by a high state.', source);
            end
            time = (double(data.Time) - double(data.Time(syncIndex))) * scale;
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
