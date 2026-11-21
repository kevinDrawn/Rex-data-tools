function int_data = build_int_data(filtered, t_interval, rat_weight, root_dir)

s = dbstack;

t = filtered.t;

left_f  = filtered.left;
right_f = filtered.right;

left_torque_f  = filtered.left_torque;
right_torque_f = filtered.right_torque;

% ===============================
% velocity (deg/s)
% ===============================
vel_left  = gradient(left_f, t);
vel_right = gradient(right_f, t);

% ===============================
% angular velocity (rad/s)
% ===============================
omega_left  = vel_left  * pi/180;
omega_right = vel_right * pi/180;

% ===============================
% torque normalization (Nmm/kg)
% ===============================
torque_left_Nmm_kg  = left_torque_f * 1000 / rat_weight;
torque_right_Nmm_kg = right_torque_f * 1000 / rat_weight;

% ===============================
% power (W/kg)
% ===============================
power_weight_left  = -torque_left_Nmm_kg  .* omega_left / 1000; 
power_weight_right = -torque_right_Nmm_kg .* omega_right / 1000;

% ===============================
% struct 구성
% ===============================
int_data.t = t;
int_data.t_interval = t_interval;

int_data.left.angle  = left_f;
int_data.left.vel    = vel_left;
int_data.left.torque = torque_left_Nmm_kg;
int_data.left.torque_N_mm =  left_torque_f * 1000;
int_data.left.power  = power_weight_left;


int_data.right.angle  = right_f;
int_data.right.vel    = vel_right;
int_data.right.torque = torque_right_Nmm_kg;
int_data.right.torque_N_mm =  right_torque_f * 1000;
int_data.right.power  = power_weight_right;
int_data.meta.weight = rat_weight;

% ===============================
% 저장
% ===============================
save_path = fullfile(root_dir, 'int_data.mat');
save(save_path, 'int_data');
fprintf('[%s] int_data saved: %s\n', s(1).name, save_path);

end