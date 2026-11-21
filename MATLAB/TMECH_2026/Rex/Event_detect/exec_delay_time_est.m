clc; clear; close all;

%% Add local functions
addpath(fullfile(pwd, 'function'));

% 프로젝트 Root Directory
root_dir = 'D:\park\01. STEAM\[Paper] 논문작성\2027_ICRA\Data\#26\Exo_shoe_1';

%% ---------------- 사용자 설정 ----------------
cfg.col_t     = 1;     % CSV의 time 열 (없으면 비워두면 자동생성)
cfg.col_left  = 4;     % 왼발 각도 열
cfg.col_right = 5;
cfg.col_mirror = 6;

cfg.col_torque_left = 8;
cfg.col_torque_right = 9;
cfg.col_TA = 10;
cfg.col_GM = 11;

cfg.fs        = [];    % 샘플링 주파수(비우면 time으로 추정)
cfg.lpf_on    = Off;  % 저역통과 필터 사용
cfg.fc        = 15;    % Hz
cfg.order     = 1;

%% ===============================
% UART Data Load & Preprocessing
% ===============================
[data, cfg] = load_exoskeleton_uart(root_dir, cfg);

t              = data.t;
left_f         = data.left;
right_f        = data.right;
left_torque_f  = data.left_torque;
right_torque_f = data.right_torque;

fs = data.fs;
Ts = data.Ts;

%% ===============================
% Full-Graph
% ===============================

figure(1);
plot(t, left_f, t, right_f);
grid on;
axis auto;
ekfms 
xlabel('Time (s)');
ylabel('Ankle angle (deg)');
legend('Left angle', 'Right angle', 'Orientation', 'horizontal');

set(gca, 'FontName', 'Times New Roman', 'FontSize', 25);

%% ===============================
% Gait Peak Detection
% ===============================
interval_mode = 'auto';

t_interval = make_time_intervals( ...
    interval_mode, ...
    'Start', 6, ...
    'End',   153, ...
    'Step',  4);

interval_mode = 'manual';

manual_interval = [ ...
    62.246    64.8365;
];

t_interval = make_time_intervals( ...
    interval_mode, ...
    'Intervals', manual_interval);

[main_left, main_right] = ...
    detect_gait_peaks( ...
    t, left_f, right_f, t_interval);

plot_gait_peaks( ...
    t, left_f, right_f, ...
    t_interval, main_left, main_right);

%% ===============================
% Cycle Period + Offset Extraction
% ===============================

% Time interval 저장
save_time_intervals(root_dir, t_interval);

% T_R + Δt 계산
right_cycles_tbl = extract_cycle_offset( ...
    main_left, ...
    main_right, ...
    t);

% CSV 저장
save_cycle_offset( ...
    root_dir, ...
    data.file_name, ...
    right_cycles_tbl);