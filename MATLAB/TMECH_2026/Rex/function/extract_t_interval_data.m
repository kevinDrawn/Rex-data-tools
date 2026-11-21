function data_struct = extract_t_interval_data(int_data)

n_interval = size(int_data.t_interval,1);

t_all = [];
left_all = [];
right_all = [];

velL_all = [];
velR_all = [];

torqueL_all = [];
torqueR_all = [];

powerL_all = [];
powerR_all = [];

for k = 1:n_interval

    t_start = int_data.t_interval(k,1);
    t_end   = int_data.t_interval(k,2);

    if k < n_interval
        idx = (int_data.t >= t_start) & (int_data.t < t_end);
    else
        idx = (int_data.t >= t_start) & (int_data.t <= t_end);
    end

    % ===== DEBUG =====
    fprintf('k=%d | idx sum=%d\n', k, sum(idx));

    % ===== skip invalid =====
    if sum(idx) < 2
        continue;
    end

    % ===== append =====
    t_all = [t_all; int_data.t(idx)];
    left_all = [left_all; int_data.left.angle(idx)];
    right_all = [right_all; int_data.right.angle(idx)];

    velL_all = [velL_all; int_data.left.vel(idx)];
    velR_all = [velR_all; int_data.right.vel(idx)];

    torqueL_all = [torqueL_all; int_data.left.torque(idx)];
    torqueR_all = [torqueR_all; int_data.right.torque(idx)];

    powerL_all = [powerL_all; int_data.left.power(idx)];
    powerR_all = [powerR_all; int_data.right.power(idx)];

end

% ===== output =====
data_struct = struct();

data_struct.t = t_all;
data_struct.t_interval = int_data.t_interval;

data_struct.left.angle  = left_all;
data_struct.right.angle = right_all;

data_struct.left.vel  = velL_all;
data_struct.right.vel = velR_all;

data_struct.left.torque  = torqueL_all;
data_struct.right.torque = torqueR_all;

data_struct.left.power  = powerL_all;
data_struct.right.power = powerR_all;

end