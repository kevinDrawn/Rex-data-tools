function plot_step_time_per_rat(reg_data, rat_list, reg_colors)

rat_n = numel(rat_list);

% x 위치 (쥐 Index)
x = 1:rat_n;

cycle_freq_mean = zeros(rat_n, 1);
cycle_freq_std = zeros(rat_n, 1);

% jitter 크기 설정
jitter_amount = 0.08;

figure; hold on;
for i = 1:rat_n

    T_cycle = reg_data(i).result.T_cycle(:);
    T_cycle_freq = 1./T_cycle;

    % x축 jitter 추가
    x_jittered = x(i) + (rand(size(T_cycle_freq)) - 0.5) * 2 * jitter_amount;
    
    % Scatter (cycle 별)
    scatter(x_jittered, T_cycle_freq, 30, reg_colors(i,:), 'filled', ...
        'MarkerFaceAlpha', 0.5);

    cycle_freq_mean(i) = mean(T_cycle_freq);
    cycle_freq_std(i) = std(T_cycle_freq);

    fprintf('[Cycle time] Rat %s: %.3f ± %.3f Hz \n', ...
        rat_list{i}, cycle_freq_mean(i), cycle_freq_std(i));

    % Error bar
    errorbar(x(i), cycle_freq_mean(i), cycle_freq_std(i), ...
        'o', 'linewidth', 2, ...
        'Color', reg_colors(i,:),...
        'MarkerSize', 10, ...
        'MarkerFacecolor','w', ...
        'linestyle','none');
end


xlim([0.5 rat_n+0.5]);
xticks(x);
xticklabels({'rat1', 'rat2', 'rat3'});
ylabel('Gait frequency (Hz)');
% ylim([-0.2 0.2]);
set(gca, 'FontName', 'Times new roman', 'FontSize', 20);
box off;

