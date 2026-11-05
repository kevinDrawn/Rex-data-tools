# ADS1294 square-wave analysis

`SignalAnalyzer` measures rising-to-rising periods using the recorded `data.Time`
and hysteretic edge detection. It interpolates midpoint crossing times, reports
cycle periods and duty cycle, and does not modify signals or MAT files.
Use the raw test signal (or compare raw and cleaned signals), not an EMG envelope.

```matlab
analyzer = SignalAnalyzer();
reports = analyzer.analyzeSquareWaveMat(MAT_PATH, EMG_FIELDS);
reports.Left.TA

% Single vector; timestamps are milliseconds by default:
result = analyzer.analyzeSquareWave(data.Time, data.Left.TA);
fprintf('Measured %.6f Hz, expected %.6f Hz, error %+.3f %%\n', ...
    result.FrequencyHz, result.ExpectedFrequencyHz, result.FrequencyErrorPercent);
```

Edit `Class/config/SignalAnalyzerConfig.m` for project defaults. A custom config
struct can also be passed to the constructor. Per-call name/value overrides are
`TimeScaleToSeconds`, `TestFrequencyBits`, `ClockFrequencyHz`,
`HysteresisFraction`, and `FrequencyTolerancePercent`.

The firmware names 1HZ and 2HZ are approximate labels. According to the
[TI ADS129x datasheet, CONFIG2 section 9.6.1.3](https://www.ti.com/lit/pdf/sbas459),
TEST_FREQ=0 means CLK/2^21, 1 means CLK/2^20, 2 is reserved, and 3 is DC.
With the nominal 2.048 MHz ADC clock these are 0.9765625 and 1.953125 Hz.
DC has no period and this square-wave method rejects it explicitly.
The config takes the two TEST_FREQ bits, not the entire CONFIG2 byte.

`ClockFrequencyHz` is the ADC clock, not SPI SCLK. Configure the actual external
clock if used. The default 2% acceptance tolerance is an analysis setting, not a
guarantee of ADC accuracy. A measured 2.048 Hz is not explained by the mode name
alone: check the ADC clock, timestamp units, sample rate and recording continuity.
A 2.048 Hz source under this divider would imply an ADC clock of 2147483.648 Hz.
If time is reconstructed from sample indices and an assumed sampling rate, the
reported frequency depends on that assumption and is not an independent clock
measurement. Missing cycles remain visible as long periods; periods are not
silently discarded. At least two rising edges are required. The 10th/90th
percentiles estimate low/high levels, suitable for approximately 50% test pulses;
very narrow duty cycles or dense glitches require a different level estimator.

Run `addpath('MATLAB/tests'); testSignalAnalyzer` from the repository root.

## Cycle stability and possible sample loss

Existing analysis calls now also return cycle jitter and `Timing` diagnostics:

```matlab
r = reports.Left.TA;
fprintf('Period SD: %.4f ms; CV: %.4f %%\n', ...
    r.PeriodStdSeconds*1000, r.PeriodCVPercent);
fprintf('Irregular cycles: %d; timestamp gaps: %d; estimated missing: %d\n', ...
    r.CycleJitterExceededCount, r.Timing.GapCount, ...
    r.Timing.EstimatedMissingSampleCount);
analyzer.plotTimingDiagnostics(r);

% Timestamp-only inspection is also available:
timing = analyzer.analyzeSampleTiming(data.Time, 'ExpectedSampleRateHz', 2000);
```

Jitter is each period minus the measured median period, separating cycle
variation from the frequency offset relative to the expected source. The config
sets a 1% median-relative cycle threshold and 10% nominal sample-interval
threshold. Override these using `CycleJitterTolerancePercent` and
`SampleIntervalToleranceFraction` in square-wave analysis calls.
`ExpectedSampleRateHz` defaults to 2000; use the acquisition's intended rate.

Intervals at least 1.5 nominal sample intervals are flagged as gaps, with
`round(interval/nominal)-1` estimated missing samples. The estimate is not proof:
timestamp scheduling jitter can imitate gaps, while timestamps rebuilt from row
indices hide losses entirely. Confirm loss using a source sample counter.
Repeated/backward timestamps are rejected explicitly. `CyclesCrossingGaps`
marks periods whose time span overlaps a timestamp gap; no periods are silently
excluded from the statistics. Plots use seconds for the horizontal axis.
