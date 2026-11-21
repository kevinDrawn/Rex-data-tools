function func_run_single_analysis_ver_2(root_dir, cond_name, plot_on)

% Motion Capture 데이터 통합 여부
camera_fs = 30;

% CSV 로깅 파일 인덱스
cfg.col_t     = 1;     % CSV의 time 열 (없으면 비워두면 자동생성)
cfg.col_left  = 2;     % 왼발 각도 열
cfg.col_right = 3;
cfg.col_mirror = 4;

cfg.col_left_tor = 6;
cfg.col_right_tor = 7;
cfg.fs        = [];    % 샘플링 주파수(비우면 time으로 추정)

% 그래프 plot 여부
cfg.plot_on = plot_on;   % default

% Filter 
cfg.lpf_angle_on    = true;  % 저역통과 필터 사용
cfg.lpf_torque_on    = true;  % 저역통과 필터 사용
cfg.fc        = 15;    % Hz
cfg.order     = 1;

%% 센서 데이터 검출 

% Config
[cfg, params] = load_config(root_dir, cfg);

% Motion Capture
mocap_index = load_mocap_index(root_dir, camera_fs, params.left_right_video_flip);

% Exoskeleton data
[log_file, t_interval] = select_logging_files(root_dir);

% Rat weight
rat_weight = load_rat_weight(root_dir);

[TBL, raw, cfg] = parse_log_data(log_file, cfg);

%% [Time] 통합 센서 데이터 

% Filtering
[filtered, fs] = filter_signals(raw, cfg);

% 시간 축에 대한 Integrated sensor data (ankle angle, velocity, torque, power)
int_data = build_int_data(filtered, t_interval, rat_weight, root_dir);

%% Mocap과 Exo 시간 도메인 매칭
    % main_left/right에 시간 바이어스가 조정된 mocap 이벤트 타임이 포함되었다.
    [main_left, main_right, time_bias] = align_exo_mocap_events( ...
        int_data, mocap_index, cfg, params);
    
    if cfg.plot_on
        plot_exo_mocap_events(main_left, main_right, int_data, root_dir);
    end
   
%% 0~100% Phase normalize
% 0~100% phase로 정규화된 angle, vel, torque, power 데이터 (L/R - Exo와 mocap 기준 개별 데이터)
fprintf('Test 1 \n');
phase_data = build_phase_dataset(main_left, main_right, int_data, root_dir, cond_name, time_bias);
fprintf('Test 2 \n');

%% [Phase] Phase data 저장 (0~100%) - angle, vel, torque, power
data_types = ["angle","vel","torque","power"];
sources    = ["exo","mocap"];

for d = data_types
    for s = sources
        phase_data = process_phase_data(phase_data, cfg, d, s);
    end
end

save_path = fullfile(root_dir, 'phase_data.mat');
save(save_path, 'phase_data');
fprintf('[i] phase_data saved: %s\n', save_path);

%% [Phase] Phase data plot (0~100%) - angle, vel, torque, power
if plot_on == true
    plot_phase_summary(phase_data, 'exo');
    plot_phase_summary(phase_data, 'mocap');
end

end