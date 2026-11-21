function plot_peak_Dorsi_Plantar(ax, exp_data_summary, type, cond_list_plot, cfg)

axes(ax); hold(ax,'on');

n_cond = size(exp_data_summary, 1);
x = 1:n_cond;

%% ===============================
% Reference 값
%% ===============================
if strcmp(type,'torque')
    flex_mean = -0.007 * 1000;
    flex_std  = -0.005 * 1000;
    ext_mean  = 0.093 * 1000;
    ext_std   = 0.023 * 1000;

    color_pos = [0.85 0.33 0.10];
    color_neg = [0.49 0.18 0.56];

elseif strcmp(type,'power')
    flex_mean = -0.1;
    flex_std  = -0.0061;
    ext_mean  = 0.374;
    ext_std   = 0.221;

    color_pos = [0.0 0.6 0.6];
    color_neg = [0.8 0.2 0.2];
else
    flex_mean = 0; flex_std = 0;
    ext_mean  = 0; ext_std  = 0;
end

%% ===============================
% 데이터 모으기
%% ===============================
pos_mean = zeros(1,n_cond);
pos_std  = zeros(1,n_cond);

neg_mean = zeros(1,n_cond);
neg_std  = zeros(1,n_cond);

for i = 1:n_cond
    pos_mean(i) = exp_data_summary(i).peak.(type).left.pos.mean;
    pos_std(i)  = exp_data_summary(i).peak.(type).left.pos.std;

    neg_mean(i) = exp_data_summary(i).peak.(type).left.neg.mean;
    neg_std(i)  = exp_data_summary(i).peak.(type).left.neg.std;
end

%% ===============================
% Spaghetti (개별 쥐)
%% ===============================
rng(0,'twister');

% for i = 1:n_cond
% 
%     % Positive
%     pos_all = exp_data_summary(i).peak.(type).left.pos.all(:);
%     jitter = (rand(length(pos_all),1)-0.5)*cfg.plot.jitter;
% 
%     scatter(ax, x(i)+jitter, pos_all, 25, ...
%         'MarkerFaceColor',color_pos, ...
%         'MarkerEdgeColor','none', ...
%         'MarkerFaceAlpha',cfg.plot.alpha);
% 
%     % Negative
%     neg_all = exp_data_summary(i).peak.(type).left.neg.all(:);
%     jitter = (rand(length(neg_all),1)-0.5)*cfg.plot.jitter;
% 
%     scatter(ax, x(i)+jitter, neg_all, 25, ...
%         'MarkerFaceColor',color_neg, ...
%         'MarkerEdgeColor','none', ...
%         'MarkerFaceAlpha',cfg.plot.alpha);
% end

%% ===============================
% Mean ± STD
%% ===============================
% errorbar(ax, x, pos_mean, pos_std, ...
%     '-o', ...
%     'LineWidth',3, ...
%     'Color',color_pos, ...
%     'MarkerFaceColor',color_pos);
% 
% errorbar(ax, x, neg_mean, neg_std, ...
%     '-o', ...
%     'LineWidth',3, ...
%     'Color',color_neg, ...
%     'MarkerFaceColor',color_neg);

h_pos = errorbar(ax, x, pos_mean, pos_std, ...
    '-o', ...
    'LineStyle','-', ...
    'LineWidth',cfg.plot.lw_main, ...
    'Color',color_pos, ...
    'MarkerSize', cfg.plot.scatter.size);

h_pos.MarkerFaceColor = 'none';

h_neg = errorbar(ax, x, neg_mean, neg_std, ...
    '-o', ...
    'LineStyle','-', ...
    'LineWidth',cfg.plot.lw_main, ...
    'Color',color_neg, ...
    'MarkerSize', cfg.plot.scatter.size);

h_neg.MarkerFaceColor = 'none';

%% ===============================
% 🔵 Reference Moment
%% ===============================
xlim(ax, [0.5, n_cond + 0.5]);
xl = xlim(ax);

fake_ext_mean = [];
break_y_low = [];
break_y_high = [];
num_points = 20;

if strcmp(type, 'torque')

    fake_ext_mean = 16.5;
    yticks(ax, [-15 -10 -5 0 5 10 16.5]);
    yticklabels(ax, { ...
    '-15', '-10', '-5', '0', '5', '10', num2str(ext_mean, '%.0f') ...
});
    ylim(ax, [-10 17]);
    break_y_low  = 14.5;
    break_y_high = 15.5;
elseif strcmp(type, 'power')

    fake_ext_mean = 0.12;
    yticks(ax, [-0.1 -0.05 0 0.05 0.12]);
    yticklabels(ax, { ...
    '-0.1', '-0.05', '0', '0.05', num2str(ext_mean, '%.2f') ...
});
    ylim(ax, [-0.125 0.125]);

    break_bias = 0.005;
    break_pos_bias = 0.03;

    break_y_low  = fake_ext_mean - break_bias - break_pos_bias;
    break_y_high = fake_ext_mean + break_bias - break_pos_bias;
end

%% ===============================
% Reference line
%% ===============================
if ~isempty(fake_ext_mean)

    yline(ax, fake_ext_mean, '--', ...
        'Color',color_pos, ...
        'LineWidth',1.5);

    yline(ax, flex_mean, '--', ...
        'Color',color_neg, ...
        'LineWidth',1.5);
end

%% ===============================
% Zig-zag patch
%% ===============================
if strcmp(type, 'torque') || strcmp(type, 'power')
    
    xx = linspace(xl(1), xl(2), num_points);

    zig = (mod(1:num_points, 2)*2 - 1);

    if strcmp(type, 'torque')
        amp = 0.5;   % 기존 유지 (크게)
    elseif strcmp(type, 'power')
        amp = 0.005;  % 🔥 작게 (비율 기반)
    end

    yy_top    = break_y_high + zig * amp;
    yy_bottom = break_y_low  + zig * amp;

    % patch(ax, [xx, fliplr(xx)], [yy_top, fliplr(yy_bottom)], ...
    %     [1 1 1], ...
    %     'EdgeColor','k', ...
    %     'LineWidth',1, ...
    %     'HandleVisibility','off');
end

%% ===============================
% 🔴 Statistical test (LE vs LR)
%% ===============================
fprintf('\n=== Statistical Test (LE vs LR) ===\n');

LE_idx = find(strcmp(cond_list_plot, 'LE'));
LR_idx = find(strcmp(cond_list_plot, 'LR'));

if isempty(LE_idx) || isempty(LR_idx)
    error('LE 또는 LR 조건을 찾을 수 없습니다.');
end

% 데이터
LE_pos = exp_data_summary(LE_idx).peak.(type).left.pos.all(:);
LR_pos = exp_data_summary(LR_idx).peak.(type).left.pos.all(:);

LE_neg = exp_data_summary(LE_idx).peak.(type).left.neg.all(:);
LR_neg = exp_data_summary(LR_idx).peak.(type).left.neg.all(:);

% paired test
[~, p_pos] = ttest(LE_pos, LR_pos);
[~, p_neg] = ttest(LE_neg, LR_neg);

fprintf('LE vs LR : Plantar p = %.4f | Dorsi p = %.4f\n', p_pos, p_neg);
fprintf('===================================\n');


% %% ===============================
% % 🔴 LE vs LR 추가 (Recovery 비교)
% %% ===============================
% 
% % 🔥 global 값 다시 계산 (안전)
% all_pos_all = [];
% all_neg_all = [];
% 
% for k = 1:n_cond
%     all_pos_all = [all_pos_all; exp_data_summary(k).peak.(type).left.pos.all(:)];
%     all_neg_all = [all_neg_all; exp_data_summary(k).peak.(type).left.neg.all(:)];
% end
% 
% y_max_global = max(all_pos_all);
% y_min_global = min(all_neg_all);
% 
% LE_idx = find(strcmp(cond_list_plot,'LE'));
% LR_idx = find(strcmp(cond_list_plot,'LR'));
% 
% if isempty(LE_idx) || isempty(LR_idx)
%     warning('LE 또는 LR 조건을 찾을 수 없습니다.');
% else
% 
%     % ===== 데이터 =====
%     LE_pos = exp_data_summary(LE_idx).peak.(type).left.pos.all(:);
%     LR_pos = exp_data_summary(LR_idx).peak.(type).left.pos.all(:);
% 
%     LE_neg = exp_data_summary(LE_idx).peak.(type).left.neg.all(:);
%     LR_neg = exp_data_summary(LR_idx).peak.(type).left.neg.all(:);
% 
%     % ===== p-value =====
%     [~, p_pos] = ttest(LE_pos, LR_pos);
%     [~, p_neg] = ttest(LE_neg, LR_neg);
% 
%     % ===== x 위치 =====
%     x1 = LE_idx;
%     x2 = LR_idx;
% 
%     if strcmp(type,'torque')
%         offset = 0.1;
%     else
%         offset = 0.005;
%     end
% 
%     % ===============================
%     % 🔥 Plantar (위쪽)
%     % ===============================
%     y_pos = y_max_global + offset * (1 + n_cond*0.8);
% 
%     add_sig(ax, x1, x2, y_pos, p_pos, offset*1.1, "up");
% 
%     % ===============================
%     % 🔥 Dorsi (아래쪽)
%     % ===============================
%     y_neg = y_min_global - offset * (2 + n_cond*1.0);
% 
%     add_sig(ax, x1, x2, y_neg, p_neg, offset*1.3, "down");
% 
% end

%% ===============================
% Axis
%% ===============================
xticks(ax, x);

set(ax, ...
    'FontName', cfg.font.name, ...
    'FontSize', cfg.font.size, ...
    'LineWidth', cfg.plot.lw_axis, ...
    'TickDir','out', ...
    'Box','off');

% xline(ax, 0, '--', 'Color',[0.3 0.3 0.3]);
yline(ax, 0, '-k');

xticklabels(ax, cond_list_plot);

if strcmp(type, 'torque')
    ylabel(ax, 'Peak torque (N.mm/kg)');
elseif strcmp(type, 'power')
    ylabel(ax, 'Peak power (W/kg)');
end

box(ax,'off');

lgd = legend(ax, [h_pos, h_neg], ...
    {'Plantar. peak', 'Dorsi. peak'}, ...
    'Orientation','horizontal', ...
    'Location','southoutside', 'box', 'off');

% xticklabels(ax, []);
style_axis_col_1(ax, cfg); 

%% ===============================
% Summary print (fprintf)
%% ===============================
fprintf('\n=== Peak %s Summary ===\n', type);

for i = 1:n_cond
    
    pos_pct = (pos_mean(i) / ext_mean) * 100;
    neg_pct = (neg_mean(i) / abs(flex_mean)) * 100;

    fprintf('%-20s : Plantar %6.4f ± %5.4f (%.1f%%) | Dorsi %6.4f ± %5.4f (%.1f%%)\n', ...
        cond_list_plot{i}, ...
        pos_mean(i), pos_std(i), pos_pct, ...
        neg_mean(i), neg_std(i), neg_pct);
end

fprintf('===================================\n');


end

function s = p_to_star(p)
    if p < 0.001
        s = '***';
    elseif p < 0.01
        s = '**';
    elseif p < 0.05
        s = '*';
    else
        s = '';
    end
end

function add_sig(ax, x1, x2, y, p, offset, direction)

    star = p_to_star(p);

    if isempty(star)
        return;
    end

    if direction == "up"
        y_line = [y y+offset y+offset y];
        y_text = y + offset*1.3;
    else % down
        y_line = [y y-offset y-offset y];
        y_text = y - offset*1.3;
    end

    % bracket
    plot(ax, [x1 x1 x2 x2], y_line, 'k', 'LineWidth', 1.5);

    % 별표
    text(ax, (x1+x2)/2, y_text, star, ...
        'HorizontalAlignment','center', ...
        'FontSize', 14, ...
        'FontWeight','bold');
end