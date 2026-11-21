clc; clear; close all;

%% =========================================================
%% [1] 기본 설정
%% =========================================================
%% [1.1] Path 지정
script_dir = pwd;
addpath(script_dir);
addpath(fullfile(script_dir, 'function'));
root_dir = 'F:\Rodex\Experiment\2026_TMECH\Result\n=6';

%% [1.2] Config 가져오기
cfg = default_cfg(root_dir);
camera_fs = 120;

%% [1.3] 기본 실험 정보
% 분석대상 쥐 라벨
rat_list = {'#5', '#6', '#7', '#8', '#11', '#12'};

% 분석대상 실험 조건`
cond_list = {
    'intact_Exo shoe'
    'intact_Rex'
    'lido_Exo shoe'
    'lido_Rex'
};

%% =========================================================
%% [2] DATA PREPROCESSING (처음 한번만 하면 된다.)
%% =========================================================
%% Baseline 데이터 (Spatiotemporal)

cfg.plot_on = true;
baseline_rat_list = {'#5', '#6', '#7', '#8', '#11', '#12'};
mocap_index = cell(length(baseline_rat_list),1);

%% Load Data (Spatiotemporal)
for rat_idx = 1:length(baseline_rat_list)
    spatio_dir = fullfile( ...
        'F:\Rodex\Experiment\2026_TMECH\Result\n=6', ...
        baseline_rat_list{rat_idx}, ...
        'baseline');

    [cfg, params] = load_config(spatio_dir, cfg);

    mocap_index{rat_idx} = load_mocap_index( ...
        spatio_dir, ...
        camera_fs, ...
        params.left_right_video_flip);
end

%% [Spatiotemporal] Baseline Stance ratio
baseline_rat_list = {'#5', '#6', '#7', '#8', '#11', '#12'};
stance_ratio_baseline = analyze_stance_ratio_symmetry_baseline(baseline_rat_list, root_dir);
total_cycles = 0;
n_rat = numel(baseline_rat_list);

for i = 1:n_rat
    n_left  = length(stance_ratio_baseline(i).left.all);
    n_right = length(stance_ratio_baseline(i).right.all);
    total_cycles = total_cycles + n_left + n_right;
end

fprintf('Total gait cycles: %d\n', total_cycles);

%% [Spatiotemporal] Swing/stance ratio - related-work comparison
% Run after Baseline Stance ratio. Uses saved exp_data.mat, without rerunning
% preprocessing. All five conditions are exported; plot Baseline/IE/IR here.
% Ratio is dimensionless: swing duration / stance duration, NOT swing percent.
if ~exist('stance_ratio_baseline','var')
    baseline_rat_list = {'#5', '#6', '#7', '#8', '#11', '#12'};
    stance_ratio_baseline = analyze_stance_ratio_symmetry_baseline(baseline_rat_list, root_dir);
end
swing_stance_rat_list = {stance_ratio_baseline.rat};
swing_stance_input = fullfile(root_dir, 'exp_data.mat');
assert(isfile(swing_stance_input), 'Missing exp_data.mat: %s', swing_stance_input);
swing_stance_loaded = load(swing_stance_input, 'exp_data');
swing_stance_plot_conditions = {'Baseline','IE','IR'};
% To plot assistance or all conditions, change the list above, e.g.:
% swing_stance_plot_conditions = {'IE','LE','LR'};
% swing_stance_plot_conditions = {'Baseline','IE','IR','LE','LR'};
swing_stance_save_dir = fullfile(root_dir, 'TMECH_fig_summary', 'swing_stance_ratio');
swing_stance_results = analyze_swing_stance_ratio( ...
    stance_ratio_baseline, swing_stance_loaded.exp_data, ...
    swing_stance_rat_list, swing_stance_save_dir, swing_stance_plot_conditions);

%% [2.1] n마리 쥐 통합 데이터 분석 결과 계산 및 개별 프로젝트 폴더에 저장
root_dir = 'F:\Rodex\Experiment\2026_TMECH\Result\n=6';
assert(isfolder(root_dir), 'root_dir가 존재하지 않습니다.');

% % 분석대상 쥐 라벨
% rat_list = {'#5', '#6', '#7', '#8', '#11', '#12'};
% 
% % 분석대상 실험 조건`
% cond_list = {
%     'intact_Exo shoe'
%     'intact_Rex'
%     'lido_Exo shoe'
%     'lido_Rex'
% };

plot_on = true;

% One shot 분석 함수
exec_rats_oneshot_analysis(rat_list, root_dir, cond_list, plot_on);

%% [1.3] n마리 쥐 개별 프로젝트에서 분석 결과 추출 후 전체 구조체로 통합 / 저장
rat_list = {'#5', '#6', '#7', '#8', '#11', '#12'};
cond_list = {
    'intact_Exo shoe'
    'intact_Rex'
    'lido_Exo shoe'
    'lido_Rex'
};

[exp_data, exp_data_summary] = load_mat_data(root_dir, rat_list, cond_list, cfg);

save_path = fullfile(root_dir, 'exp_data.mat');
save(save_path, 'exp_data');

fprintf('[Saved] exp_data: %s\n', save_path);

save_path = fullfile(root_dir, 'exp_data_summary.mat');
save(save_path, 'exp_data_summary');

fprintf('[Saved] exp_data_summary: %s\n', save_path);

%% =========================================================
%% [2] DATA loading
%% =========================================================
%% [2.1] 통합 Mat 데이터 load
root_dir = 'F:\Rodex\Experiment\2026_TMECH\Result\n=6';

save_path = fullfile(root_dir, 'exp_data.mat');
S = load(save_path, 'exp_data');
exp_data = S.exp_data;
fprintf('[Load] exp_data: %s\n', save_path);

save_path = fullfile(root_dir, 'exp_data_summary.mat');
S = load(save_path, 'exp_data_summary');
exp_data_summary = S.exp_data_summary;
fprintf('[Load] exp_data_summary: %s\n', save_path);

%% =========================================================
%% [2.2] 전체 Cycle 개수 확인
%% =========================================================
n_rat  = numel(rat_list);
n_cond = numel(cond_list);

cycle_left  = zeros(n_rat, n_cond);
cycle_right = zeros(n_rat, n_cond);

total_cycle = 0;

for i = 1:n_rat
    for j = 1:n_cond
        
        try
            % LEFT
            L_angle = exp_data(i,j).phase_data.left.exo.angle;
            nL = size(L_angle, 1);

            % RIGHT
            R_angle = exp_data(i,j).phase_data.right.exo.angle;
            nR = size(R_angle, 1);

            cycle_left(i,j)  = nL;
            cycle_right(i,j) = nR;

            total_cycle = total_cycle + nL + nR;
        
            fprintf('  %-20s : L %2d | R %2d | Total %2d\n', ...
                cond_list{j}, ...
                cycle_left(i,j), ...
                cycle_right(i,j), ...
                cycle_left(i,j) + cycle_right(i,j));

        catch
            cycle_left(i,j)  = NaN;
            cycle_right(i,j) = NaN;
        end
    end
end

fprintf('Total gait cycle: %d \n', total_cycle);

%% =========================================================
%% [3] Contralateral gait controller 검증
%% =========================================================
%% [3-1] Intact + Exo shoe 조건에서 보행 예측 검증
% 1. Step time
% 2. Pearson corr 
% 3. Maximum Flexion delay time

root_dir = 'F:\Rodex\Experiment\2026_TMECH\Result\n=6';
rat_list_reg = {'#7', '#8', '#11'};

cond_name_reg = 'intact_Exo shoe_Regression';
reg_data = extract_reg_validation_data(root_dir, rat_list_reg, cond_name_reg);

reg_colors = [
    0.2  0.7  0.3   % Green (sb1)
    0.6  0.4  0.8   % Purple (sb2)
    0.9  0.6  0.2   % Orange (sb3)
];

plot_step_time_per_rat(reg_data, rat_list_reg, reg_colors);
plot_peak_flexion_time_error(reg_data, rat_list_reg, reg_colors);
plot_regression_validate_corr(reg_data, rat_list_reg, reg_colors);

%% [3-2] Intact, Lido + Rex shoe 조건에서 보행 Sync 검증 (Exo Toe-off event vs Mocap Toe-off event)

controller_val_colors = [
    0.2  0.7  0.3   % green
    0.9  0.6  0.2   % orange
    0.6  0.4  0.8   % purple
    0.0  0.6  0.6   % teal
    0.8  0.2  0.6   % magenta
    0.6  0.5  0.2   % olive/brown
];

rat_list = {'#5', '#6', '#7', '#8', '#11', '#12'};
rat_list_plot = {'rat1', 'rat2', 'rat3', 'rat4', 'rat5', 'rat6'};

timing_error_data = compute_TO_error(exp_data, rat_list, cond_list);
save(fullfile(root_dir, 'timing_error_data.mat'), 'timing_error_data');

% Plot
cond_list_controller_timing_err = {'intact_Rex', 'lido_Rex'};
plot_TO_error_selected_2cond(timing_error_data, cond_list_controller_timing_err, rat_list_plot, cfg);

%% Print table about gait cycle

% cond_cycle_list = {
%     'intact_Exo shoe'
%     'intact_Rex'
%     'lido_Exo shoe'
%     'lido_Rex'
% };

cond_cycle_list = {
    'intact_Rex'
    'lido_Rex'
};

print_table_gait_cycle( ...
    exp_data, ...
    rat_list, ...
    cond_list, ...
    cond_cycle_list);


% 의지가 없어서 엑소 제어 이후에 쥐 밞 모션이 따라 움직이는 경향을 보였다.
%% =========================================================
%% [4] 그래프 그리기
%% =========================================================

%% [4-0] Spatiotemporal에 대한 데이터 그리기
fprintf('\n==============================\n');
fprintf('[Stance phase per Rat]\n');
fprintf('==============================\n');

rat_list = {'#5', '#6', '#7', '#8', '#11', '#12'};
spatio_cond_list = {
    'intact_Exo shoe'
    'intact_Rex'
    'lido_Exo shoe'
    'lido_Rex'
    'baseline'
};

plot_cond_list = {
    'Baseline'
    'IE'
    'IR'
    'LE'
    'LR'
};

n_rat  = numel(rat_list);
n_cond = numel(spatio_cond_list);
SI_all = nan(n_rat, n_cond);

for r = 1:n_rat
    fprintf('\n[%s]\n', rat_list{r});
    for c = 1:n_cond
        try
            % BASELINE CONDITION
            if strcmp(spatio_cond_list{c}, 'baseline')
                % LEFT
                L_mean = stance_ratio_baseline(r).left.mean;
                L_std  = stance_ratio_baseline(r).left.std;

                % RIGHT
                R_mean = stance_ratio_baseline(r).right.mean;
                R_std  = stance_ratio_baseline(r).right.std;
            else
                % OTHER CONDITIONS
                % LEFT
                L_mean = exp_data(r,c).phase_data.results.mocap.spatio.left.stance_phase.mean;
                L_std  = exp_data(r,c).phase_data.results.mocap.spatio.left.stance_phase.std;

                % RIGHT
                R_mean = exp_data(r,c).phase_data.results.mocap.spatio.right.stance_phase.mean;
                R_std  = exp_data(r,c).phase_data.results.mocap.spatio.right.stance_phase.std;
            end
            % Symmetry Index 계산
            SI_all(r,c) = abs(L_mean - R_mean) / (0.5*(L_mean + R_mean)) * 100;
            fprintf('  %-20s : L %.2f ± %.2f %% | R %.2f ± %.2f %% | SI %.2f %%\n', ...
                spatio_cond_list{c}, L_mean, L_std, R_mean, R_std, SI_all(r, c));
        catch
            SI_all(r,c) = NaN;
            fprintf('  %-20s : (no data)\n', spatio_cond_list{c});
        end
    end
end

plot_SI_bar_graph(SI_all, n_cond, n_rat, spatio_cond_list, plot_cond_list);
fprintf('\n==============================\n');

print_stance_ratio_summary( ...
    spatio_cond_list, ...
    stance_ratio_baseline, ...
    exp_data, ...
    SI_all, plot_cond_list);

%% [4-1] Phase에 대한 데이터 그리기

plot_phase_all(exp_data, rat_list, cond_list, 'angle', true);
plot_phase_all(exp_data, rat_list, cond_list, 'vel', true);
plot_phase_all(exp_data, rat_list, cond_list, 'torque', true);
plot_phase_all(exp_data, rat_list, cond_list, 'power', true);

%% [4-2] Ankle angle에 대한 Cycloid 그래프 그리기 

plot_angle_x_cycloid_all(exp_data, rat_list, cond_list, 'vel');
plot_angle_x_cycloid_all(exp_data, rat_list, cond_list, 'torque');
plot_angle_x_cycloid_all(exp_data, rat_list, cond_list, 'power');

%% [4-3] Work 데이터 그리기 (Positive + Negative + Ratio) 
plot_work_all(exp_data, rat_list, cond_list);

%% [4-4] TMECH - Two coloum result summary graph
target_rat = {'#7'};
cfg = default_cfg(root_dir);
cfg.plot.show_direction = true;

cond_list_plot = {'IE', 'IR', 'LE', 'LR'};
plot_TMECH_result_summary_v2(target_rat, rat_list, cond_list, cond_list_plot, exp_data, exp_data_summary, cfg);

%% [4-5] TMECH - Two column result summary graph
cond_list_plot = {'IE', 'IR', 'LE', 'LR'};

cfg = default_cfg(root_dir);
% ===============================
% 1. SI
% ===============================
save_dir = fullfile(root_dir, 'TMECH_fig_summary');

fig = figure('Color','w', ...
    'Units','centimeters', ...
    'Position',[2 2 8.8 6]);

ax = axes(fig);   
% plot_SI_bar(ax, exp_data, exp_data_summary, cond_list_plot, cfg); 
plot_SI_bar_multi_purpose(ax, exp_data, exp_data_summary, cfg)

% 저장
% save_TMECH_figure(fig, save_dir, 'SI', cfg);

%% ===============================
% 2. Similarity
% ===============================
fig = figure('Color','w', ...
    'Units','centimeters', ...
    'Position',[2 2 8.8 6]);

ax = axes(fig);   
% plot_velocity_similarity(ax, exp_data_summary, rat_list, cond_list_plot, cfg);
plot_velocity_similarity_multi_purpose(ax, exp_data_summary, rat_list, cfg);

% save_TMECH_figure(fig, save_dir, 'similarity', cfg);

%% ===============================
% 3. Torque Peak
% ===============================
cond_list_plot = {'IE', 'IR', 'LE', 'LR'};
save_dir = fullfile(root_dir, 'TMECH_fig_summary');

fig = figure('Color','w', ...
    'Units','centimeters', ...
    'Position',[2 2 8.8 6]);

ax = axes(fig);   
plot_peak_Dorsi_Plantar(ax, exp_data_summary, 'torque', cond_list_plot, cfg);

save_TMECH_figure(fig, save_dir, 'torque_peak', cfg);

% ===============================
% 4. Power Peak
% ===============================
fig = figure('Color','w', ...
    'Units','centimeters', ...
    'Position',[2 2 8.8 6]);

ax = axes(fig);   
plot_peak_Dorsi_Plantar(ax, exp_data_summary, 'power', cond_list_plot, cfg);

save_TMECH_figure(fig, save_dir, 'power_peak', cfg);

%%
% ===============================
% 5. Work
% ===============================
cond_list_plot = {'IE', 'IR', 'LE', 'LR'};
save_dir = fullfile(root_dir, 'TMECH_fig_summary');

fig = figure('Color','w', ...
    'Units','centimeters', ...
    'Position',[2 2 8.8 6]);

ax = axes(fig);   
exp_data_summary = plot_work_summary(ax, exp_data, exp_data_summary, rat_list, cond_list_plot, cfg);
save_TMECH_figure(fig, save_dir, 'ankle_work', cfg);

%% =========================================================
%% [5] 데이터 후처리
%% =========================================================
%% [5-1] Angular Velocity Cycloid Similarity 계산 [시간소요 1~2분]  

% Lido는 mocap 기반으로 event 추출
cond_list = {
    'intact_Exo shoe'
    'intact_Rex'
    'lido_Exo shoe'
    'lido_Rex'
};

cfg.densify_factor = 10;
sim_vel    = cal_cycloid_similarity(exp_data, 'vel', cond_list, cfg);

sim_struct = struct();
sim_struct.data = sim_vel;
sim_struct.density_factor = cfg.densify_factor;
sim_struct.type = 'vel';
sim_struct = sim_struct';

save_path = fullfile(root_dir, 'sim_vel.mat');
save(save_path, 'sim_struct', '-v7.3');
fprintf('[Saved] sim_vel: %s\n', save_path);