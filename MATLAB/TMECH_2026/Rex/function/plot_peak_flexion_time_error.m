function plot_peak_flexion_time_error(reg_data, rat_list, reg_colors)

rat_n = numel(rat_list);

% x 위치 (쥐 Index)
x = 1:rat_n;

t_err_mean = zeros(rat_n, 1);
t_err_std = zeros(rat_n, 1);


% jitter 크기 설정
jitter_amount = 0.08;

figure; hold on;
for i = 1:rat_n

    t_err = reg_data(i).result.dt_list(:);

    % 현재 t_delay = t_est - t_meas로 되어있다.
    % TMECH 논문에서는 t_delay = t_meas - t_est로 통일하기 때문에 부호 반대로 설정한다.
    t_err = - t_err;


    % x축 jitter 추가
    x_jittered = x(i) + (rand(size(t_err)) - 0.5) * 2 * jitter_amount;
    
    % Scatter (cycle 별)
    scatter(x_jittered, t_err, 30, reg_colors(i,:), 'filled', ...
        'MarkerFaceAlpha', 0.5);
 
    t_err_mean(i) = mean(t_err);
    t_err_std(i) = std(t_err);
    t_err_rmse(i) = sqrt(mean(t_err.^2));

    fprintf('Rat %s: %.3f ± %.3f s (RMSE: %.3f s)\n', ...
        rat_list{i}, t_err_mean(i), t_err_std(i), t_err_rmse(i));

    % Error bar
    errorbar(x(i), t_err_mean(i), t_err_std(i), ...
        'o', 'linewidth', 2, ...
        'Color', reg_colors(i,:), ...
        'MarkerSize', 10, ...
        'MarkerFacecolor','w', ...
        'linestyle','none');

end


xlim([0.5 rat_n+0.5]);
xticks(x);
xticklabels({'rat1', 'rat2', 'rat3'});
ylabel('Maximum Flexion Delay (s)');
ylim([-0.06 0.1]);
set(gca, 'FontName', 'Times new roman', 'FontSize', 20);
box off;

