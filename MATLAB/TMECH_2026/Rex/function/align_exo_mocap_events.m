function [main_left, main_right, time_bias] = align_exo_mocap_events( ...
    int_data, mocap_index, cfg, params)

t       = int_data.t;
left_f  = int_data.left.angle;
right_f = int_data.right.angle;
t_interval = int_data.t_interval;

% ===============================
% Exo 이벤트 검출
% ===============================
main_left = find_main_peaks_by_minima_IC_TO( ...
    t, left_f, t_interval, ...
    'SmoothWinSec', 0.01, ...
    'VelEps', 0, ...
    'MinPeakDistSec', params.refractory_time, ...
    'MinPeakDistPolicy', 'keepMax', cfg);

main_right = find_main_peaks_by_minima_IC_TO( ...
    t, right_f, t_interval, ...
    'SmoothWinSec', 0.01, ...
    'VelEps', 0, ...
    'MinPeakDistSec', params.refractory_time, ...
    'MinPeakDistPolicy', 'keepMax', cfg);

% ===============================
% Time bias 계산
% ===============================
time_bias = compute_time_bias(t_interval, mocap_index, main_right);
time_bias = zeros(size(time_bias)); % Preserve zero bias for every interval.

% ===============================
% Mocap 이벤트 정렬
% ===============================
for k = 1:numel(main_left)

    t_start = t_interval(k,1);
    t_end   = t_interval(k,2);

    if k > numel(mocap_index)
        continue;
    end

    % LEFT
    [main_left(k).t_TO_mocap, main_left(k).t_IC_mocap] = ...
        extract_mocap_events(mocap_index(k), 'left', t_start, t_end, time_bias(k));

    % RIGHT
    [main_right(k).t_TO_mocap, main_right(k).t_IC_mocap] = ...
        extract_mocap_events(mocap_index(k), 'right', t_start, t_end, time_bias(k));
end

end

function [t_TO, t_IC] = extract_mocap_events(mocap_k, side, t_start, t_end, bias)

t_TO = [];
t_IC = [];

if ~isfield(mocap_k, side)
    return;
end

% ===============================
% TO
% ===============================
if isfield(mocap_k.(side),'hind') && ...
   isfield(mocap_k.(side).hind,'TO') && ...
   ~isempty(mocap_k.(side).hind.TO)

    t_global = t_start + mocap_k.(side).hind.TO(:) + bias;
    idx = t_global >= t_start & t_global <= t_end;
    t_TO = t_global(idx);
end

% ===============================
% IC
% ===============================
if isfield(mocap_k.(side),'hind') && ...
   isfield(mocap_k.(side).hind,'IC') && ...
   ~isempty(mocap_k.(side).hind.IC)

    t_global = t_start + mocap_k.(side).hind.IC(:) + bias;
    idx = t_global >= t_start & t_global <= t_end;
    t_IC = t_global(idx);
end

s = dbstack;
fprintf('[%s] Mocap and Exo synchronize clear \r\n', s(1).name);

end