function plot_regression_validate_corr(reg_data, rat_list, reg_colors)

rat_n = numel(rat_list);

% x 위치 (쥐 Index)
x = 1:rat_n;

R_mean = zeros(rat_n, 1);
R_std = zeros(rat_n, 1);

figure; hold on;
for i = 1:rat_n

    R = reg_data(i).result.R_phase(:);
    % % Scatter (cycle 별)
    % scatter(x, R, 50, 'k', 'filled', ...
    %     'MarkerFaceAlpha', 0.6);
    
    R_mean(i) = mean(R);
    R_std(i) = std(R);

    bar(x(i), R_mean(i), 0.6, 'Facecolor',reg_colors(i,:), ...
    'EdgeColor','none');

    % Error bar
    errorbar(x(i), R_mean(i), R_std(i), ...
        'k', 'linewidth', 2, ...
        'MarkerSize', 8, ...
        'MarkerFacecolor','none', ...
        'linestyle','none');
end

xlim([0.5 rat_n+0.5]);
xticks(x);
xticklabels({'rat1', 'rat2', 'rat3'});
ylabel('Pearson correlation (R)');
ylim([0.0 1]);
set(gca, 'FontName', 'Times new roman', 'FontSize', 20);
box off;