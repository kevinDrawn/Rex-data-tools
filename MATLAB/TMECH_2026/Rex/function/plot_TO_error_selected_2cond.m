function plot_TO_error_selected_2cond(timing_error_data, cond_list_select, rat_list_plot, cfg)

per_rat   = timing_error_data.per_rat;
summary   = timing_error_data.summary;
rat_list  = timing_error_data.meta.rat_list;
cond_list = timing_error_data.meta.cond_list;

[n_rat, ~] = size(per_rat);

assert(numel(cond_list_select) == 2, '조건은 2개만 선택해야 합니다.');

% -------------------------------
% 조건 index 찾기
% -------------------------------
cond_idx = zeros(1,2);

for k = 1:2
    idx = find(strcmp(cond_list, cond_list_select{k}));
    assert(~isempty(idx), '조건 "%s"을 찾을 수 없습니다.', cond_list_select{k});
    cond_idx(k) = idx;
end

% -------------------------------
% Marker (조건 구분)
% -------------------------------
markers = {'o','^'};   % ○, △

% -------------------------------
% 🔥 쥐별 색상 (고정)
% -------------------------------
controller_val_colors = [
    0.2  0.7  0.3
    0.9  0.6  0.2
    0.6  0.4  0.8
    0.0  0.6  0.6
    0.8  0.2  0.6
    0.6  0.5  0.2
];

assert(n_rat <= size(controller_val_colors,1), ...
    '쥐 개수보다 색상이 부족합니다.');

figure;
ax = axes;
hold(ax, 'on');

%% ===============================
% 🔴 Scatter + Errorbar
%% ===============================
for a = 1:2
    i = cond_idx(a);

    for j = 1:n_rat

        if isempty(per_rat(j,i).left.err)
            continue;
        end

        err = per_rat(j,i).left.err;

        x = j;

        color_j = controller_val_colors(j,:);

        % scatter
        scatter(ax, x + (a-1)*0.18 - 0.09, err, 100, ...
            color_j, ...
            markers{a}, ...
            'filled', ...
            'MarkerFaceAlpha', 0.5);

        % errorbar
        errorbar(ax, x + (a-1)*0.18 - 0.09, ...
            per_rat(j,i).left.mean, ...
            per_rat(j,i).left.std, ...
            'ko','LineWidth',2,'MarkerFaceColor','w');
    end
end

%% ===============================
% 🔵 Overall RMSE (오른쪽)
%% ===============================
x_center = n_rat + 1.5;
offset = 0.15;

light_gray = [0.75 0.75 0.75];
dark_gray  = [0.35 0.35 0.35];

for a = 1:2
    i = cond_idx(a);

    % 좌우 위치
    if a == 1
        x_rmse = x_center - offset;
        bar_color = light_gray;
    else
        x_rmse = x_center + offset;
        bar_color = dark_gray;
    end

    % bar
    bar(ax, x_rmse, summary(i).left.rmse, 0.25, ...
        'FaceColor', bar_color, ...
        'EdgeColor','none');

    % errorbar
    errorbar(ax, x_rmse, ...
        summary(i).left.rmse, ...
        summary(i).left.std, ...
        'ko', ...
        'LineWidth',2, ...
        'LineStyle','none');
end
%% ===============================
% Axis 설정
%% ===============================
% 🔥 핵심: XTick은 중앙만
set(ax, 'XTick', [1:n_rat, x_center]);
set(ax, 'XTickLabel', [rat_list_plot, {'Ave'}]);

ylabel(ax, 'Synchronization delay (s)');
yline(ax, 0,'--k');

yticks([-0.1, -0.05, 0, 0.05, 0.1])
ylim(ax, [-0.15 0.15]);
box(ax, 'off');
grid(ax, 'off');

xlim(ax, [0.5 x_center+0.6]);

title(ax, 'TO Timing Error (Selected Conditions)');

%% ===============================
% Legend
%% ===============================
legend(ax, cond_list_select, 'Location','best');

%% ===============================
% Style 적용
%% ===============================
style_axis_col_1(ax, cfg);

%% ===============================
% 🔵 RMSE Summary print
%% ===============================
fprintf('\n=== RMSE Summary (Selected Conditions) ===\n');

for a = 1:2
    i = cond_idx(a);

    fprintf('%-20s : RMSE %6.4f ± %5.4f (s)\n', ...
        cond_list_select{a}, ...
        summary(i).left.rmse, ...
        summary(i).left.std);
end

fprintf('=========================================\n');


%% ===============================
% 🔴 Per-rat Mean ± Std print
%% ===============================
fprintf('\n=== Per-Rat Timing Error (Mean ± Std) ===\n');

for a = 1:2
    i = cond_idx(a);

    fprintf('\n[%s]\n', cond_list_select{a});

    for j = 1:n_rat

        if isempty(per_rat(j,i).left.err)
            fprintf('  %-10s : (no data)\n', rat_list_plot{j});
            continue;
        end

        mu  = per_rat(j,i).left.mean;
        sig = per_rat(j,i).left.std;

        fprintf('  %-10s : % .4f ± %.4f (s)\n', ...
            rat_list_plot{j}, mu, sig);
    end
end

fprintf('=========================================\n');

end