function phase_data = process_phase_data(phase_data, cfg, data_type, source)

cfg.y_axis = data_type;

% ===============================
% 데이터 선택
% ===============================
L_mat = phase_data.left.(source).(data_type);
R_mat = phase_data.right.(source).(data_type);

% ===============================
% Mean / Std (phase-wise)
% ===============================
muL = mean(L_mat,1,'omitnan');
sdL = std(L_mat,0,1,'omitnan');

muR = mean(R_mat,1,'omitnan');
sdR = std(R_mat,0,1,'omitnan');

% n개 Cycle에 대한 개별적인 Range of motion
ROM_L = max(L_mat,[],2) - min(L_mat,[],2);
ROM_R = max(R_mat,[],2) - min(R_mat,[],2);

ROM_L_mean = mean(ROM_L,'omitnan');
ROM_L_std  = std(ROM_L,'omitnan');

ROM_R_mean = mean(ROM_R,'omitnan');
ROM_R_std  = std(ROM_R,'omitnan');

% n개 Cycle에 대한 개별적인 Maximum, Minumum Value (+, -)
Max_L = max(L_mat,[],2);
Max_R = max(R_mat,[],2);

Min_L = min(L_mat,[],2);
Min_R = min(R_mat,[],2);

% ===============================
% 저장
% ===============================

% ---- Left phase graph ----
% Mean + std Phase
phase_data.results.(source).(data_type).left.mean   = muL;
phase_data.results.(source).(data_type).left.std    = sdL;

% ---- Right phase graph ----
phase_data.results.(source).(data_type).right.mean  = muR;
phase_data.results.(source).(data_type).right.std   = sdR;

% Range of motion
phase_data.results.(source).(data_type).left.ROM_each = ROM_L;
phase_data.results.(source).(data_type).left.ROM_mean = ROM_L_mean;
phase_data.results.(source).(data_type).left.ROM_std  = ROM_L_std;

phase_data.results.(source).(data_type).right.ROM_each = ROM_R;
phase_data.results.(source).(data_type).right.ROM_mean = ROM_R_mean;
phase_data.results.(source).(data_type).right.ROM_std  = ROM_R_std;

% Positive Peak + Negative Peak
phase_data.results.(source).(data_type).left.peak_pos = Max_L;
phase_data.results.(source).(data_type).left.peak_pos_mean = mean(Max_L, 'omitnan');
phase_data.results.(source).(data_type).left.peak_pos_std = std(Max_L, 'omitnan');


phase_data.results.(source).(data_type).left.peak_neg = Min_L;
phase_data.results.(source).(data_type).left.peak_neg_mean = mean(Min_L, 'omitnan');
phase_data.results.(source).(data_type).left.peak_neg_std = std(Min_L, 'omitnan');


phase_data.results.(source).(data_type).right.peak_pos = Max_R;
phase_data.results.(source).(data_type).right.peak_pos_mean = mean(Max_R, 'omitnan');
phase_data.results.(source).(data_type).right.peak_pos_std = std(Max_R, 'omitnan');


phase_data.results.(source).(data_type).right.peak_neg = Min_R;
phase_data.results.(source).(data_type).right.peak_neg_mean = mean(Min_R, 'omitnan');
phase_data.results.(source).(data_type).right.peak_neg_std = std(Min_R, 'omitnan');

s = dbstack;
fprintf('[%s] Process clear [%s]\n', s(1).name, data_type);

end