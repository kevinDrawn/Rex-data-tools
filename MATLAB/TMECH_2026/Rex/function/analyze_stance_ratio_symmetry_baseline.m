function results = analyze_stance_ratio_symmetry_baseline( ...
    baseline_rat_list, root_dir)


% =========================================================
% Analyze Left/Right Stance Ratio and Symmetry Index
%
% OUTPUT FORMAT
%
% results(rat_idx).rat
%
% results(rat_idx).left.all
% results(rat_idx).left.mean
% results(rat_idx).left.std
%
% results(rat_idx).right.all
% results(rat_idx).right.mean
% results(rat_idx).right.std
%
% results(rat_idx).SI
%
% =========================================================


%% Initialization
camera_fs = 120;

cfg.plot_on = true;

mocap_index = cell(length(baseline_rat_list),1);


%% Load Data
for rat_idx = 1:length(baseline_rat_list)

    spatio_dir = fullfile( ...
        root_dir, ...
        baseline_rat_list{rat_idx}, ...
        'baseline');

    [cfg, params] = load_config(spatio_dir, cfg);

    mocap_index{rat_idx} = load_mocap_index( ...
        spatio_dir, ...
        camera_fs, ...
        params.left_right_video_flip);
end


%% Analysis
for rat_idx = 1:length(baseline_rat_list)

    %% LEFT
    TO_L = mocap_index{rat_idx}.left.hind.TO;
    IC_L = mocap_index{rat_idx}.left.hind.IC;

    n_cycle_L = length(TO_L) - 1;

    stance_ratio_L = nan(n_cycle_L,1);

    for k = 1:n_cycle_L

        t0 = TO_L(k);
        t1 = TO_L(k+1);

        idx_ic = find(IC_L > t0 & IC_L < t1, 1, 'first');

        if ~isempty(idx_ic)

            tic_event = IC_L(idx_ic);

            gait_period = t1 - t0;

            stance_tmp = (t1 - tic_event) ...
                / gait_period * 100;

            % Physiological validation
            if stance_tmp > 40 && stance_tmp < 80

                stance_ratio_L(k) = stance_tmp;

            end
        end
    end


    %% RIGHT
    TO_R = mocap_index{rat_idx}.right.hind.TO;
    IC_R = mocap_index{rat_idx}.right.hind.IC;

    n_cycle_R = length(TO_R) - 1;

    stance_ratio_R = nan(n_cycle_R,1);

    for k = 1:n_cycle_R

        t0 = TO_R(k);
        t1 = TO_R(k+1);

        idx_ic = find(IC_R > t0 & IC_R < t1, 1, 'first');

        if ~isempty(idx_ic)

            tic_event = IC_R(idx_ic);

            gait_period = t1 - t0;

            stance_tmp = (t1 - tic_event) ...
                / gait_period * 100;

            % Physiological validation
            if stance_tmp > 40 && stance_tmp < 80

                stance_ratio_R(k) = stance_tmp;

            end
        end
    end


    %% Remove NaN
    ratio_L = stance_ratio_L(~isnan(stance_ratio_L));
    ratio_R = stance_ratio_R(~isnan(stance_ratio_R));


    %% Outlier Removal
    ratio_L = ratio_L(~isoutlier(ratio_L,'quartiles'));
    ratio_R = ratio_R(~isoutlier(ratio_R,'quartiles'));


    %% Mean / STD
    L_mean = mean(ratio_L,'omitnan');
    R_mean = mean(ratio_R,'omitnan');

    L_std = std(ratio_L,'omitnan');
    R_std = std(ratio_R,'omitnan');


    %% Symmetry Index
    SI = abs(L_mean - R_mean) ...
        / (0.5 * (L_mean + R_mean)) * 100;


    %% Save Results
    results(rat_idx).rat = baseline_rat_list{rat_idx};

    results(rat_idx).left.all  = ratio_L;
    results(rat_idx).left.mean = L_mean;
    results(rat_idx).left.std  = L_std;

    results(rat_idx).right.all  = ratio_R;
    results(rat_idx).right.mean = R_mean;
    results(rat_idx).right.std  = R_std;

    results(rat_idx).SI = SI;

end


%% Plot
figure('Color','w');

subplot(1,2,1);
hold on;

x = 1:length(baseline_rat_list);

for rat_idx = 1:length(baseline_rat_list)

    % Mean bars
    bar(x(rat_idx)-0.15, ...
        results(rat_idx).left.mean, ...
        0.3);

    bar(x(rat_idx)+0.15, ...
        results(rat_idx).right.mean, ...
        0.3);

    % LEFT scatter
    scatter( ...
        (x(rat_idx)-0.15) ...
        + 0.03*randn(size(results(rat_idx).left.all)), ...
        results(rat_idx).left.all, ...
        25, ...
        'filled', ...
        'MarkerFaceAlpha',0.5);

    % RIGHT scatter
    scatter( ...
        (x(rat_idx)+0.15) ...
        + 0.03*randn(size(results(rat_idx).right.all)), ...
        results(rat_idx).right.all, ...
        25, ...
        'filled', ...
        'MarkerFaceAlpha',0.5);

end

set(gca,'XTick',x);
set(gca,'XTickLabel',baseline_rat_list);

xlabel('Rat');
ylabel('Stance Ratio (%)');

legend('Left Mean','Right Mean');

title('Left vs Right Stance Ratio');

grid on;
box off;


%% SI Plot
subplot(1,2,2);

SI_plot = arrayfun(@(s) s.SI, results);

bar(x, SI_plot, 0.5);

set(gca,'XTick',x);
set(gca,'XTickLabel',baseline_rat_list);

xlabel('Rat');
ylabel('Symmetry Index (%)');

title('Stance Ratio Symmetry Index');

grid on;
box off;

end