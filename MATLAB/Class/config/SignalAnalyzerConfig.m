function config = SignalAnalyzerConfig()
    %SIGNALANALYZERCONFIG ADS1294 test source and square-wave analysis settings.
    % TI ADS129x datasheet SBAS459K, CONFIG2 TEST_FREQ[1:0]:
    % https://www.ti.com/lit/pdf/sbas459 (section 9.6.1.3)
    config.ADS129X_CONFIG2_TEST_FREQ_1HZ = hex2dec('00'); % fCLK / 2^21
    config.ADS129X_CONFIG2_TEST_FREQ_2HZ = hex2dec('01'); % fCLK / 2^20
    config.ADS129X_CONFIG2_TEST_FREQ_DC = hex2dec('03');
    config.TestFrequencyBits = config.ADS129X_CONFIG2_TEST_FREQ_2HZ;
    config.ClockFrequencyHz = 2048000; % ADC CLK, NOT SPI SCLK; adjust for external CLK.
    config.TimeScaleToSeconds = 0.001; % Input timestamps are milliseconds.
    config.HysteresisFraction = 0.2; % Thresholds at midpoint +/- fraction * amplitude.
    config.FrequencyTolerancePercent = 2; % User acceptance criterion, not a device spec.
    config.ExpectedSampleRateHz = 2000;
    config.SampleIntervalToleranceFraction = 0.1; % Flag intervals >10% from nominal.
    config.CycleJitterTolerancePercent = 1; % Deviation from measured median period.
end
