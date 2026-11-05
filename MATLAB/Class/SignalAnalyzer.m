classdef SignalAnalyzer
    %SIGNALANALYZER Measure test waveforms without modifying source data.
    properties (SetAccess = private)
        Config
    end

    methods
        function obj = SignalAnalyzer(config)
            % Optional config struct allows external clock and time-unit settings.
            if nargin == 0
                configDirectory = fullfile(fileparts(mfilename('fullpath')), 'config');
                originalPath = path;
                restorePath = onCleanup(@() path(originalPath)); %#ok<NASGU>
                addpath(configDirectory);
                config = SignalAnalyzerConfig();
            end
            obj.Config = config;
        end

        function frequencyHz = expectedTestFrequencyHz(obj, bits, clockHz)
            % Input is TEST_FREQ[1:0] only, not the entire CONFIG2 register.
            if nargin < 2, bits = obj.Config.TestFrequencyBits; end
            if nargin < 3, clockHz = obj.Config.ClockFrequencyHz; end
            validateattributes(bits, {'numeric'}, {'scalar', 'integer', '>=', 0, '<=', 3});
            validateattributes(clockHz, {'numeric'}, {'scalar', 'real', 'finite', 'positive'});
            switch double(bits)
                case 0
                    frequencyHz = clockHz / 2^21;
                case 1
                    frequencyHz = clockHz / 2^20;
                case 3
                    frequencyHz = 0;
                otherwise
                    error('SignalAnalyzer:ReservedTestFrequency', 'TEST_FREQ=0x02 is reserved.');
            end
        end

        function result = analyzeSquareWave(obj, time, signal, varargin)
            %ANALYZESQUAREWAVE Hysteretic edges, interpolated midpoint crossings.
            % Edge times are seconds in the input timestamp reference frame.
            % Only full rising-to-rising cycles contribute to period/duty metrics.
            parser = inputParser;
            addParameter(parser, 'TimeScaleToSeconds', obj.Config.TimeScaleToSeconds);
            addParameter(parser, 'TestFrequencyBits', obj.Config.TestFrequencyBits);
            addParameter(parser, 'ClockFrequencyHz', obj.Config.ClockFrequencyHz);
            addParameter(parser, 'HysteresisFraction', obj.Config.HysteresisFraction);
            addParameter(parser, 'FrequencyTolerancePercent', obj.Config.FrequencyTolerancePercent);
            addParameter(parser, 'ExpectedSampleRateHz', obj.Config.ExpectedSampleRateHz);
            addParameter(parser, 'SampleIntervalToleranceFraction', obj.Config.SampleIntervalToleranceFraction);
            addParameter(parser, 'CycleJitterTolerancePercent', obj.Config.CycleJitterTolerancePercent);
            parse(parser, varargin{:});
            settings = parser.Results;
            validateattributes(time, {'numeric'}, {'vector', 'real', 'finite', 'nonempty'});
            validateattributes(signal, {'numeric'}, {'vector', 'real', 'finite', 'nonempty'});
            validateattributes(settings.TimeScaleToSeconds, {'numeric'}, {'scalar', 'real', 'finite', 'positive'});
            validateattributes(settings.HysteresisFraction, {'numeric'}, {'scalar', 'real', 'finite', '>', 0, '<', 0.5});
            validateattributes(settings.FrequencyTolerancePercent, {'numeric'}, {'scalar', 'real', 'finite', 'nonnegative'});
            validateattributes(settings.CycleJitterTolerancePercent, {'numeric'}, {'scalar', 'real', 'finite', 'nonnegative'});
            t = double(time(:)) * settings.TimeScaleToSeconds;
            x = double(signal(:));
            if numel(t) ~= numel(x) || numel(t) < 3 || any(diff(t) <= 0)
                error('SignalAnalyzer:InvalidTime', 'Signal and time must have equal length >=3 with strictly increasing timestamps.');
            end
            expected = obj.expectedTestFrequencyHz(settings.TestFrequencyBits, settings.ClockFrequencyHz);
            if expected == 0
                error('SignalAnalyzer:DCMode', 'DC test mode has no square-wave period to analyze.');
            end
            % Quantiles reject sparse amplitude outliers without extra toolboxes.
            ordered = sort(x);
            low = ordered(max(1, round(0.1 * numel(x))));
            high = ordered(min(numel(x), round(0.9 * numel(x))));
            if high <= low
                error('SignalAnalyzer:NoAmplitude', 'Cannot identify distinct low and high levels.');
            end
            midpoint = (low + high) / 2;
            lower = midpoint - settings.HysteresisFraction * (high - low);
            upper = midpoint + settings.HysteresisFraction * (high - low);
            rising = zeros(numel(x), 1);
            falling = zeros(numel(x), 1);
            nr = 0; nf = 0; state = 0; candidate = NaN;
            for k = 1:numel(x)
                if state == 0
                    if x(k) <= lower, state = -1;
                    elseif x(k) >= upper, state = 1;
                    end
                    continue;
                end
                if k > 1
                    if state == -1 && x(k-1) < midpoint && x(k) >= midpoint
                        candidate = t(k-1) + (midpoint-x(k-1)) / (x(k)-x(k-1)) * (t(k)-t(k-1));
                    elseif state == 1 && x(k-1) > midpoint && x(k) <= midpoint
                        candidate = t(k-1) + (midpoint-x(k-1)) / (x(k)-x(k-1)) * (t(k)-t(k-1));
                    end
                end
                if state == -1 && x(k) >= upper
                    if isfinite(candidate), nr = nr + 1; rising(nr) = candidate; end
                    state = 1; candidate = NaN;
                elseif state == 1 && x(k) <= lower
                    if isfinite(candidate), nf = nf + 1; falling(nf) = candidate; end
                    state = -1; candidate = NaN;
                end
            end
            rising = rising(1:nr); falling = falling(1:nf);
            if nr < 2
                error('SignalAnalyzer:InsufficientCycles', 'At least two rising edges are required. Analyze a longer interval.');
            end
            periods = diff(rising);
            duty = NaN(size(periods));
            for k = 1:numel(periods)
                edge = falling(falling > rising(k) & falling < rising(k+1));
                if numel(edge) == 1
                    duty(k) = 100 * (edge-rising(k)) / periods(k);
                end
            end
            result.ExpectedFrequencyHz = expected;
            result.ExpectedPeriodSeconds = 1 / expected;
            result.PeriodSeconds = mean(periods);
            result.FrequencyHz = 1 / result.PeriodSeconds;
            result.FrequencyErrorPercent = 100 * (result.FrequencyHz / expected - 1);
            result.WithinTolerance = abs(result.FrequencyErrorPercent) <= settings.FrequencyTolerancePercent;
            result.CyclePeriodsSeconds = periods;
            result.PeriodStdSeconds = std(periods);
            result.MedianPeriodSeconds = median(periods);
            result.CycleStartTimesSeconds = rising(1:end-1);
            result.CycleJitterSeconds = periods - median(periods);
            result.CycleJitterPercent = 100 * result.CycleJitterSeconds / median(periods);
            result.PeriodCVPercent = 100 * std(periods) / mean(periods);
            result.PeriodMinSeconds = min(periods);
            result.PeriodMaxSeconds = max(periods);
            result.PeriodPeakToPeakSeconds = max(periods) - min(periods);
            result.CycleJitterExceeded = abs(result.CycleJitterPercent) > settings.CycleJitterTolerancePercent;
            result.CycleJitterExceededCount = nnz(result.CycleJitterExceeded);
            result.Timing = obj.analyzeSampleTiming(time, ...
                'TimeScaleToSeconds', settings.TimeScaleToSeconds, ...
                'ExpectedSampleRateHz', settings.ExpectedSampleRateHz, ...
                'SampleIntervalToleranceFraction', settings.SampleIntervalToleranceFraction);
            % Cycles crossing timestamp gaps have uncertain edge/period estimates.
            gap = result.Timing.GapIntervalIndices;
            result.CyclesCrossingGaps = false(size(periods));
            for k = 1:numel(periods)
                result.CyclesCrossingGaps(k) = any(t(gap) < rising(k+1) & t(gap+1) > rising(k));
            end
            result.CycleDutyCyclePercent = duty;
            result.DutyCyclePercent = mean(duty, 'omitnan');
            result.RisingEdgeTimes = rising;
            result.FallingEdgeTimes = falling;
            result.CompleteCycleCount = numel(periods);
            result.LowLevel = low;
            result.HighLevel = high;
            result.Thresholds = [lower upper];
            result.Settings = settings;
        end

        function timing = analyzeSampleTiming(obj, time, varargin)
            % Timestamp gaps imply possible losses; acquisition counters are
            % required to distinguish lost samples from delayed timestamps.
            parser = inputParser;
            addParameter(parser, 'TimeScaleToSeconds', obj.Config.TimeScaleToSeconds);
            addParameter(parser, 'ExpectedSampleRateHz', obj.Config.ExpectedSampleRateHz);
            addParameter(parser, 'SampleIntervalToleranceFraction', obj.Config.SampleIntervalToleranceFraction);
            parse(parser, varargin{:});
            settings = parser.Results;
            validateattributes(time, {'numeric'}, {'vector', 'real', 'finite', 'nonempty'});
            validateattributes(settings.TimeScaleToSeconds, {'numeric'}, {'scalar', 'real', 'finite', 'positive'});
            validateattributes(settings.ExpectedSampleRateHz, {'numeric'}, {'scalar', 'real', 'finite', 'positive'});
            validateattributes(settings.SampleIntervalToleranceFraction, {'numeric'}, {'scalar', 'real', 'finite', '>=', 0, '<', 0.5});
            t = double(time(:)) * settings.TimeScaleToSeconds;
            if numel(t) < 2 || any(diff(t) <= 0)
                error('SignalAnalyzer:InvalidTime', 'At least two strictly increasing timestamps are required.');
            end
            dt = diff(t);
            nominal = 1 / settings.ExpectedSampleRateHz;
            ratios = dt / nominal;
            gaps = ratios >= 1.5;
            missing = zeros(size(dt));
            missing(gaps) = max(0, round(ratios(gaps)) - 1);
            timing.ExpectedSampleRateHz = settings.ExpectedSampleRateHz;
            timing.NominalIntervalSeconds = nominal;
            timing.DurationSeconds = t(end) - t(1);
            timing.SampleCount = numel(t);
            timing.EffectiveSampleRateHz = (numel(t)-1) / timing.DurationSeconds;
            timing.IntervalStartTimesSeconds = t(1:end-1);
            timing.IntervalsSeconds = dt;
            timing.IntervalErrorSeconds = dt - nominal;
            timing.MedianIntervalSeconds = median(dt);
            timing.IntervalStdSeconds = std(dt);
            timing.MaxIntervalSeconds = max(dt);
            timing.IrregularIntervalMask = abs(ratios-1) > settings.SampleIntervalToleranceFraction;
            timing.IrregularIntervalCount = nnz(timing.IrregularIntervalMask);
            timing.GapIntervalIndices = find(gaps);
            timing.GapCount = nnz(gaps);
            timing.EstimatedMissingSamplesPerGap = missing(gaps);
            timing.EstimatedMissingSampleCount = sum(missing);
            timing.EstimatedMissingPercent = 100 * sum(missing) / (numel(t) + sum(missing));
            timing.MissingSamplesConfirmed = false;
            timing.Limitation = ['Timestamp-based estimate only. Delayed timestamps can mimic loss; ' ...
                'reconstructed timestamps can hide loss. Confirm with acquisition sample counters.'];
            timing.Settings = settings;
        end

        function [fig, axesHandles] = plotTimingDiagnostics(~, result)
            % Plot cycle periods, median-relative jitter, and timestamp intervals.
            fig = figure('Name', 'Signal timing diagnostics');
            layout = tiledlayout(fig, 3, 1);
            axesHandles = gobjects(3, 1);
            axesHandles(1) = nexttile(layout);
            plot(result.CycleStartTimesSeconds, result.CyclePeriodsSeconds * 1000, '.-');
            yline(result.ExpectedPeriodSeconds * 1000, '--', 'Expected');
            ylabel('Period (ms)'); grid on;
            axesHandles(2) = nexttile(layout);
            plot(result.CycleStartTimesSeconds, result.CycleJitterSeconds * 1000, '.-');
            ylabel('Jitter (ms)'); grid on;
            axesHandles(3) = nexttile(layout);
            plot(result.Timing.IntervalStartTimesSeconds, result.Timing.IntervalsSeconds * 1000, '.');
            yline(result.Timing.NominalIntervalSeconds * 1000, '--', 'Nominal');
            ylabel('Sample interval (ms)'); xlabel('Time (s)'); grid on;
            linkaxes(axesHandles, 'x');
        end

        function reports = analyzeSquareWaveMat(obj, matPath, signalFields, varargin)
            % Read selected data fields; leave MAT and signals unchanged.
            if ischar(signalFields) || isstring(signalFields), signalFields = cellstr(signalFields); end
            if ~iscellstr(signalFields) || isempty(signalFields) || ~isvector(signalFields) %#ok<ISCLSTR>
                error('SignalAnalyzer:InvalidFields', 'Specify a nonempty list of signal field paths.');
            end
            loaded = load(matPath, 'data');
            if ~isfield(loaded, 'data') || ~isstruct(loaded.data) || ~isscalar(loaded.data) || ~isfield(loaded.data, 'Time')
                error('SignalAnalyzer:InvalidMAT', 'MAT file must contain a scalar data struct with Time.');
            end
            reports = struct();
            for k = 1:numel(signalFields)
                parts = strsplit(signalFields{k}, '.');
                if ~all(cellfun(@isvarname, parts))
                    error('SignalAnalyzer:InvalidFields', 'Invalid signal field path.');
                end
                try
                    signal = getfield(loaded.data, parts{:}); %#ok<GFLD>
                catch
                    error('SignalAnalyzer:MissingSignal', 'Signal field not found: %s.', signalFields{k});
                end
                result = obj.analyzeSquareWave(loaded.data.Time, signal, varargin{:});
                result.SourceField = signalFields{k};
                reports = setfield(reports, parts{:}, result); %#ok<SFLD>
            end
        end
    end
end
