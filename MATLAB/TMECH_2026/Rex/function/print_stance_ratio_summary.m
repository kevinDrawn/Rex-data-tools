function print_stance_ratio_summary( ...
    spatio_cond_list, ...
    stance_ratio_baseline, ...
    exp_data, ...
    SI_all, plot_cond_list)

% =========================================================
% Print stance ratio / symmetry index summary table
%
% INPUT
%
% spatio_cond_list
%   : condition names
%
% stance_ratio_baseline
%   : baseline stance ratio structure
%
% exp_data
%   : experiment data structure
%
% SI_all
%   : symmetry index matrix
%
% =========================================================


%% Basic info
n_cond = numel(spatio_cond_list);
n_rat  = size(SI_all,1);

stance_L = nan(n_rat,n_cond);
stance_R = nan(n_rat,n_cond);

%% Header
fprintf('\n===============================================================\n');
fprintf('        Stance Ratio and Symmetry Index Summary\n');
fprintf('===============================================================\n');

fprintf('%-20s %-35s %-20s\n', ...
    'Condition', ...
    'Stance ratio (%)', ...
    'Symmetric Index (%)');

fprintf('---------------------------------------------------------------\n');

for c = 1:n_cond

    if strcmp(spatio_cond_list{c},'baseline')

        for r = 1:n_rat

            stance_L(r,c) = ...
                stance_ratio_baseline(r).left.mean;

            stance_R(r,c) = ...
                stance_ratio_baseline(r).right.mean;

        end

    else

        for r = 1:n_rat

            stance_L(r,c) = ...
                exp_data(r,c).phase_data.results.mocap.spatio.left.stance_phase.mean;

            stance_R(r,c) = ...
                exp_data(r,c).phase_data.results.mocap.spatio.right.stance_phase.mean;

        end
    end
end


%% Loop Conditions
for c = 1:n_cond

    %% Initialize
    L_mean_all = nan(n_rat,1);
    L_std_all  = nan(n_rat,1);

    R_mean_all = nan(n_rat,1);
    R_std_all  = nan(n_rat,1);


    %% BASELINE
    if strcmp(spatio_cond_list{c}, 'baseline')

        for r = 1:n_rat

            L_mean_all(r) = ...
                stance_ratio_baseline(r).left.mean;

            L_std_all(r) = ...
                stance_ratio_baseline(r).left.std;

            R_mean_all(r) = ...
                stance_ratio_baseline(r).right.mean;

            R_std_all(r) = ...
                stance_ratio_baseline(r).right.std;

        end


    %% OTHER CONDITIONS
    else

        for r = 1:n_rat

            L_mean_all(r) = ...
                exp_data(r,c).phase_data.results.mocap.spatio.left.stance_phase.mean;

            L_std_all(r) = ...
                exp_data(r,c).phase_data.results.mocap.spatio.left.stance_phase.std;

            R_mean_all(r) = ...
                exp_data(r,c).phase_data.results.mocap.spatio.right.stance_phase.mean;

            R_std_all(r) = ...
                exp_data(r,c).phase_data.results.mocap.spatio.right.stance_phase.std;

        end
    end


    %% Group Mean ± STD
    L_group_mean = mean(L_mean_all,'omitnan');
    L_group_std  = std(L_mean_all,'omitnan');

    R_group_mean = mean(R_mean_all,'omitnan');
    R_group_std  = std(R_mean_all,'omitnan');


    %% SI Mean ± STD
    SI_mean = mean(SI_all(:,c),'omitnan');
    SI_std  = std(SI_all(:,c),'omitnan');


    %% Print
    fprintf('%-20s ', spatio_cond_list{c});

    fprintf('(L) %.1f ± %.1f  (R) %.1f ± %.1f ', ...
        L_group_mean, L_group_std, ...
        R_group_mean, R_group_std);

    fprintf('%.1f ± %.1f\n', ...
        SI_mean, SI_std);

end

% 막대 그래프 plot
plot_stance_ratio_bar_graph( ...
    stance_L, ...
    stance_R, ...
    spatio_cond_list, ...
    plot_cond_list, n_rat);

%% Footer
fprintf('===============================================================\n');

end


function plot_stance_ratio_bar_graph( ...
    stance_L, ...
    stance_R, ...
    cond_list, ...
    plot_cond_list, n_rat)

colors_bar = [
    0.7 0.7 0.7;              % Baseline
    0.6078 0.7882 0.8824;     % IE
    0.2980 0.6000 0.8000;     % IR
    0.8706 0.7608 0.1490;     % LE
    0.8863 0.5255 0.2353;     % LR
];

colors_scatter = [
    0.3 0.3 0.3;              % Baseline
    0.2510 0.5255 0.6706;     % IE
    0.0863 0.3804 0.5412;     % IR
    0.7412 0.5294 0.0235;     % LE
    0.6118 0.3804 0.0667;     % LR
];

figure;
hold on;

%% baseline first

baseline_idx = find(strcmp(cond_list,'baseline'));
other_idx = find(~strcmp(cond_list,'baseline'));

plot_order = [baseline_idx(:).' other_idx(:).'];

stance_L = stance_L(:,plot_order);
stance_R = stance_R(:,plot_order);

%% mean/std

L_mean = mean(stance_L,1,'omitnan');
R_mean = mean(stance_R,1,'omitnan');

L_std = std(stance_L,0,1,'omitnan');
R_std = std(stance_R,0,1,'omitnan');

Y = [L_mean(:) R_mean(:)];
ngroups = size(Y,1);
nbars   = size(Y,2);

%% grouped bar

b = bar(Y,'grouped');

for i = 1:2

    b(i).FaceColor = 'flat';
    b(i).EdgeColor = 'none';

    for c = 1:ngroups
        b(i).CData(c,:) = colors_bar(c,:);
    end

end

b(1).EdgeColor = 'none';
b(2).EdgeColor = 'none';

%% error bar 위치
groupwidth = min(0.8, nbars/(nbars+1.5));

for i = 1:nbars

    x = (1:ngroups) ...
        - groupwidth/2 ...
        + (2*i-1) * groupwidth/(2*nbars);

    if i==1
        errorbar(x,L_mean,L_std,...
            'k','linestyle','none','linewidth',1.5);
    else
        errorbar(x,R_mean,R_std,...
            'k','linestyle','none','linewidth',1.5);
    end
end

%% Scatter

jitter_scale = 0.2;

for r = 1:n_rat

    for c = 1:ngroups

        if ~isnan(stance_L(r,c))

            xL = c - 0.15 ...
                + (rand-0.5)*jitter_scale;

            scatter( ...
                xL,...
                stance_L(r,c),...
                70,...
                colors_scatter(c,:),...
                'filled',...
                'MarkerEdgeColor','none',...
                'MarkerFaceAlpha',0.7);

        end

        if ~isnan(stance_R(r,c))

            xR = c + 0.15 ...
                + (rand-0.5)*jitter_scale;

        scatter( ...
            xR,...
            stance_R(r,c),...
            70,...
            colors_scatter(c,:),...
            'filled',...
            'Marker','^',...
            'MarkerEdgeColor','none',...
            'MarkerFaceAlpha',0.7);

        end

    end
end

%% Axis

xticks(1:ngroups);
xticklabels(plot_cond_list);

ylabel('Stance ratio (%)');

legend({'Left','Right'}, ...
    'Location','northoutside', ...
    'Orientation','horizontal');

box off;
set(gca,'FontName','Times New Roman');
set(gca,'FontSize',25);

end