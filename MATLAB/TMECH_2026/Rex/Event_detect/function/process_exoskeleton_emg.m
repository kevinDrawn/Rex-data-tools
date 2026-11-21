
function data = process_exoskeleton_emg(data, cfg)
% PROCESS_EXOSKELETON_EMG
% ADS1294 EMG preprocessing
%
% Input:
%   data.t   : Time [s]
%   data.TA  : TA raw ADC counts
%   data.GM  : GM raw ADC counts
%   data.fs  : Sampling frequency [Hz]
%   cfg      : EMG configuration
%
% Output:
%   data.TA_uV,   data.GM_uV
%   data.TA_bp,   data.GM_bp
%   data.TA_rect, data.GM_rect
%   data.TA_env,  data.GM_env

%% ===============================
% Sampling frequency
% ===============================

fs = data.fs;

%% ===============================
% ADC counts -> microvolts
% ===============================

adc_scale = (cfg.emg.vref / cfg.emg.gain) ...
    / (2^(cfg.emg.bits-1) - 1) * 1e6;

data.TA_uV = double(data.TA) * adc_scale;
data.GM_uV = double(data.GM) * adc_scale;

%% ===============================
% EMG Filtering
% ===============================

if cfg.emg_filter_on

    % Band-pass filter
    bp_high = min(cfg.emg_bp_high, 0.95 * fs/2);

    if cfg.emg_bp_low >= bp_high
        error('Invalid EMG band-pass frequency range.');
    end

    [z_bp, p_bp, k_bp] = butter(cfg.emg_order, ...
        [cfg.emg_bp_low bp_high] / (fs/2), 'bandpass');

    [sos_bp, g_bp] = zp2sos(z_bp, p_bp, k_bp);
    sos_bp(1, 1:3) = sos_bp(1, 1:3) * g_bp;

    data.TA_bp = filtfilt(sos_bp, 1, data.TA_uV);
    data.GM_bp = filtfilt(sos_bp, 1, data.GM_uV);

    % Full-wave rectification
    data.TA_rect = abs(data.TA_bp);
    data.GM_rect = abs(data.GM_bp);

    % Envelope low-pass filter
    [b_env, a_env] = butter(cfg.emg_order, ...
        cfg.emg_env_fc / (fs/2), 'low');

    data.TA_env = filtfilt(b_env, a_env, data.TA_rect);
    data.GM_env = filtfilt(b_env, a_env, data.GM_rect);

else

    data.TA_bp = data.TA_uV;
    data.GM_bp = data.GM_uV;

    data.TA_rect = abs(data.TA_uV);
    data.GM_rect = abs(data.GM_uV);

    data.TA_env = data.TA_rect;
    data.GM_env = data.GM_rect;

end

end
