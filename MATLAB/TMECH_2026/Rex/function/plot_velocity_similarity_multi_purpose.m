function plot_velocity_similarity_multi_purpose( ...
    ax, ...
    exp_data_summary, ...
    rat_list, ...
    cfg)

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

m = arrayfun( ...
    @(s) s.similarity.vel.mean, ...
    exp_data_summary(idx_plot));

s = arrayfun( ...
    @(s) s.similarity.vel.std, ...
    exp_data_summary(idx_plot));

%% ========================================================
% Plot
%% ========================================================

axes(ax);
hold(ax,'on');

b = bar( ...
    ax, ...
    x, ...
    m, ...
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
        ax, ...
        x(j), ...
        m(j), ...
        s(j), ...
        'Color', colors_scatter(j,:), ...
        'LineStyle','none', ...xline(3, '--k', 'LineWidth',1.2);
        'LineWidth', cfg.plot.lw_main, ...
        'CapSize', 10);

end

%% ========================================================
% Scatter
%% ========================================================

n_rat = numel(rat_list);

for j = 1:n_cond

    vals = ...
        exp_data_summary(idx_plot(j)).similarity.vel.all;

    vals = vals(:);

    jitter_value = 0.5;

    jitter = ...
        (rand(n_rat,1)-0.5) * jitter_value;

    scatter( ...
        ax, ...
        x(j)+jitter, ...
        vals, ...
        42, ...
        '^', ...
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
% Axis
%% ========================================================

xticks(ax, x);

xticklabels(ax, label_plot);

ylabel(ax, 'Cycloid Similarity (%)');

ylim(ax, [0 100]);

xlim(ax, [0.3 6.7]);

%% ========================================================
% Formatting
%% ========================================================

style_axis_col_1(ax, cfg);

box(ax, 'off');

grid(ax, 'off');

set(ax, ...
    'FontName', cfg.font.name, ...
    'FontSize', cfg.font.size_col_1, ...
    'LineWidth', cfg.plot.lw_axis, ...
    'TickDir','out');

%% ========================================================
% Summary print
%% ========================================================

fprintf('\n=== Velocity Similarity Summary ===\n');

for j = 1:n_cond

    fprintf( ...
        '%-5s : %6.2f ± %5.2f %%\n', ...
        label_plot{j}, ...
        m(j), ...
        s(j));

end

fprintf('===================================\n');

end