function config = EMGConfig()
    %EMGCONFIG Raw signed ADC counts -> voltage -> bandpass -> abs -> lowpass.
    config.ADCBits = 24;
    config.VRef = 2.4;                % Volts; bipolar full scale assumed +/-VRef/Gain.
    config.ADCGain = 8;               % Hardware PGA gain.
    config.SampleRateHz = 2000;       % Rex logger: one sample every 0.5 ms.
    config.TimeScaleToSeconds = 0.001; % Rex data.Time is in milliseconds.
    config.SampleIntervalTolerance = 0.001; % Relative tolerance for a uniform time axis.
    config.BandpassHz = [15 500];
    config.BandpassOrder = 4;         % Total single-pass order; butter uses order/2.
    config.Rectify = true;           % Full-wave rectification.
    config.LowpassHz = 10;
    config.LowpassOrder = 4;
    config.ZeroPhase = true;         % filtfilt; effective order is twice single-pass.
    config.OutputSuffix = '_filtered';
    config.OutputUnit = 'V';
end
