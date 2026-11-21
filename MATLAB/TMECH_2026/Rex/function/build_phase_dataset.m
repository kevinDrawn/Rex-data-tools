function phase_data = build_phase_dataset( ...
    main_left, main_right, int_data, root_dir, cond_name, time_bias)
% ===============================
% Phase 정의
% ===============================
N = 100;
phase = linspace(0, N, 101);

% ===============================
% Interval 생성
% ===============================
L_Exo_intervals   = peaks_to_intervals(main_left);
R_Exo_intervals   = peaks_to_intervals(main_right);

L_Mocap_intervals = peaks_to_intervals_mocap(main_left);
R_Mocap_intervals = peaks_to_intervals_mocap(main_right);

% ===============================
% 예외 처리
% ===============================
st = dbstack;
assert(~isempty(L_Exo_intervals), ...
    'L Exo intervals empty [func: %s | cond: %s]', st(1).name, cond_name);

assert(~isempty(R_Exo_intervals), ...
    'R Exo intervals empty [func: %s | cond: %s]', st(1).name, cond_name);

assert(~isempty(L_Mocap_intervals), ...
    'L Mocap intervals empty [func: %s | cond: %s]', st(1).name, cond_name);

assert(~isempty(R_Mocap_intervals), ...
    'R Mocap intervals empty [func: %s | cond: %s]', st(1).name, cond_name);

% ===============================
% Phase matrix 생성
% ===============================
[exo_L, exo_R] = build_phase_data_mats( ...
    phase, L_Exo_intervals, R_Exo_intervals, int_data, 'exo');

[mocap_L, mocap_R] = build_phase_data_mats( ...
    phase, L_Mocap_intervals, R_Mocap_intervals, int_data, 'mocap');

% ===============================
% 구조체 저장
% ===============================
phase_data.phase = phase;

phase_data.left.exo   = exo_L;
phase_data.right.exo  = exo_R;

phase_data.left.mocap  = mocap_L;
phase_data.right.mocap = mocap_R;

% TO 이벤트 저장
phase_data.events.left.exo.t_TO = collect_TO_events(main_left, 't_TO');
phase_data.events.left.mocap.t_TO = collect_TO_events(main_left, 't_TO_mocap');
phase_data.events.left.mocap.t_IC = collect_TO_events(main_left, 't_IC_mocap');

phase_data.events.right.exo.t_TO = collect_TO_events(main_right, 't_TO');
phase_data.events.right.mocap.t_TO = collect_TO_events(main_right, 't_TO_mocap');
phase_data.events.right.mocap.t_IC = collect_TO_events(main_right, 't_IC_mocap');
phase_data.events.t_bias = time_bias;

phase_data.meta.cond_name = cond_name;

% ===============================
% 저장
% ===============================
filepath = fullfile(root_dir, 'phase_data.mat');
save(filepath, 'phase_data');

fprintf('[Saved] Phase data: %s\n', filepath);

% ===============================
% Cycle count 출력
% ===============================
fprintf('\n[Cycle count]\n');
fprintf('Left  - Exo  : %d\n', size(phase_data.left.exo.angle,1));
fprintf('Right - Exo  : %d\n', size(phase_data.right.exo.angle,1));
fprintf('Left  - Mocap: %d\n', size(phase_data.left.mocap.angle,1));
fprintf('Right - Mocap: %d\n', size(phase_data.right.mocap.angle,1));

end