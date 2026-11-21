function plot_SI_bar_multi_purpose(ax, exp_data, exp_data_summary, cfg)

%% ========================================================
% Plot order
%% ========================================================

% Original condition order
% 1 = IE
% 2 = IR
% 3 = LE
% 4 = LR

idx_plot = [1 2 1 3 4];

label_plot = {'IE','IR','IE','LE','LR'};

% x positions
x = [1 2 4 5 6];

n_cond = numel(idx_plot);

%% ========================================================
% Data extraction
%% ========================================================

SI_mean = arrayfun( ...
    @(s) s.ROM.SI.mean, ...
    exp_data_summary(idx_plot));

SI_std = arrayfun( ...
    @(s) s.ROM.SI.std, ...
    exp_data_summary(idx_plot));

%% ========================================================
% Plot
%% ========================================================

axes(ax);
hold(ax,'on');

b = bar(x, SI_mean, ...
    0.7, ...
    'FaceColor','flat', ...
    'EdgeColor','none');

%% ========================================================
% Colors
%% ========================================================

colors_bar = [

    % Transparency
    0.6078 0.7882 0.8824;   % IE  (#9BC9E1)
    0.2980 0.6000 0.8000;   % IR  (#4C99CC)

    % Rehabilitation
    0.6078 0.7882 0.8824;   % IE  (#9BC9E1)
    0.8706 0.7608 0.1490;   % LE  (#DEC226)
    0.8863 0.5255 0.2353;   % LR  (#E2843C)
];

colors_scatter = [

    % Transparency
    0.2510 0.5255 0.6706;   % IE  (#4086AB)
    0.0863 0.3804 0.5412;   % IR  (#16516A)

    % Rehabilitation
    0.2510 0.5255 0.6706;   % IE  (#4086AB)
    0.7412 0.5294 0.0235;   % LE  (#BD8706)
    0.6118 0.3804 0.0667;   % LR  (#9C6111)
];

b.CData = colors_bar;
b.FaceAlpha = 0.85;

%% ========================================================
% Errorbar
%% ========================================================

for j = 1:n_cond

    errorbar( ...
        x(j), ...
        SI_mean(j), ...
        SI_std(j), ...
        'Color', colors_scatter(j,:), ...
        'LineStyle','none', ...
        'LineWidth', cfg.plot.lw_main, ...
        'CapSize', 10);

end

%% ========================================================
% Scatter
%% ========================================================

n_rat = size(exp_data,1);

for j = 1:n_cond

    vals = exp_data_summary(idx_plot(j)).ROM.SI.all;
    vals = vals(:);

    jitter_value = 0.5;

    jitter = ...
        (rand(n_rat,1)-0.5) * jitter_value;

    scatter( ...
        x(j)+jitter, ...
        vals, ...
        32, ...
        'o', ...
        'MarkerFaceColor', colors_scatter(j,:), ...
        'MarkerEdgeColor', 'none', ...
        'MarkerFaceAlpha', cfg.plot.alpha);

end

%% ========================================================
% Separator line
%% ========================================================

xline( ...
    ax, ...
    3, ...
    '--', ...
    'Color',[0.5 0.5 0.5], ...
    'LineWidth',1.2);

%% ========================================================
% Axis labels
%% ========================================================

xticks(x);
xticklabels(label_plot);
xlim(ax, [0.3 6.7]);

ylabel('ROM Symmetry Index (%)');

%% ========================================================
% Auto ylim
%% ========================================================

y_top = SI_mean + SI_std;
y_bot = SI_mean - SI_std;

all_scatter = [];

for j = 1:n_cond

    vals = ...
        exp_data_summary(idx_plot(j)).ROM.SI.all;

    all_scatter = [all_scatter; vals(:)];

end

all_y = [ ...
    y_top(:); ...
    y_bot(:); ...
    all_scatter(:)];

y_min = min(all_y,[],'omitnan');
y_max = max(all_y,[],'omitnan');

y_range = y_max - y_min;

margin = ...
    y_range * cfg.axis.y_margin_ratio;

if y_range == 0
    margin = 1;
end

ylim([ ...
    y_min-margin ...
    y_max+margin]);

%% ========================================================
% Group titles
%% ========================================================

yl = ylim;

y_text = yl(2) - 0.05*(yl(2)-yl(1));

%% ========================================================
% Formatting
%% ========================================================

grid off;
box off;

set(gca, ...
    'FontSize', cfg.font.size_col_1, ...
    'FontName', cfg.font.name, ...
    'LineWidth',1, ...
    'TickDir','out');

style_axis_col_1(ax, cfg);

%% ========================================================
% Summary print
%% ========================================================

fprintf('\n=== Symmetry Index (SI) Summary ===\n');

for j = 1:n_cond

    fprintf( ...
        '%-5s : %6.2f ± %5.2f %%\n', ...
        label_plot{j}, ...
        SI_mean(j), ...
        SI_std(j));

end

fprintf('===================================\n');

end