function [proc, fs] = filter_signals(raw, cfg)

t = raw.t;
s = dbstack;

% ===============================
% Sampling frequency
% ===============================
if isempty(cfg.fs)
    dt = diff(t);
    assert(all(isfinite(dt)) && all(dt>0), '[%s] 시간 간격 dt에 이상이 있습니다.', s(1).name);
    fs = 1 / median(dt);
else
    fs = cfg.fs;
end

assert(isfinite(fs) && fs>0, '[%s] 샘플링 주파수 추정/설정 실패', s(1).name);

fprintf('[%s] Sampling frequency: %.2f Hz\n', s(1).name, fs);

% ===============================
% Filter design (공통)
% ===============================
use_lpf = cfg.lpf_angle_on || cfg.lpf_torque_on;

if use_lpf
    [b,a] = butter(cfg.order, cfg.fc/(fs/2), 'low');
end

% ===============================
% Angle filtering
% ===============================
if cfg.lpf_angle_on
    proc.left  = filtfilt(b,a,raw.left);
    proc.right = filtfilt(b,a,raw.right);
else
    proc.left  = raw.left;
    proc.right = raw.right;
end

% ===============================
% Torque filtering
% ===============================
if cfg.lpf_torque_on
    proc.left_torque  = filtfilt(b,a,raw.left_torque);
    proc.right_torque = filtfilt(b,a,raw.right_torque);
else
    proc.left_torque  = raw.left_torque;
    proc.right_torque = raw.right_torque;
end

% ===============================
% time 그대로 전달
% ===============================
proc.t = t;

fprintf('[%s] Data filter processing clear \r\n', s(1).name)

end