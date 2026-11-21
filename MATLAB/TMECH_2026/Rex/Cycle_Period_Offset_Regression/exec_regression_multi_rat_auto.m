clc; clear; close all;
addpath(fullfile(pwd, 'function'));

%% ===============================
% [0] 설정
% ===============================
base_path = 'C:\ncs\C_Logger\Rex-data-tools\exec\TMECH_2026\logging';
rat_id = 26;

% 분석할 조건
condition_name = 'Exo_shoe';

% CSV에서 사용할 column
ix = 8;     % Cycle period
iy = 15;    % Offset time

%% ===============================
% [1] Regression 데이터 로드
% ===============================
[raw, x_all, y_all, trial_num] = load_regression_trials( ...
    base_path, rat_id, condition_name, ix, iy);

n = numel(raw);
%% ===============================
% [2] Trial별 Regression
% ===============================

[slopes, intercepts, r2_each] = ...
    individual_regression( ...
        raw, ...
        trial_num);

%% ===============================
% [3] Combined Regression
% ===============================
outlier_threshold = 2;
result = combined_regression( ...
    x_all, ...
    y_all, ...
    outlier_threshold);
%% ===============================
% [4] Combined Regression Plot
% ===============================
plot_combined_regression( ...
    raw, ...
    trial_num, ...
    result);

%% ===============================
% [5] Phase Offset
% ========================36=======
phase_result = plot_phase_offset( ...
    result.x_clean, ...
    result.y_clean, ...
    'Degree'); % Gait phase (%) / Degree (위상각)