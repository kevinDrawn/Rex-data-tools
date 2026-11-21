function plot_mean_std_shaded(ax, phase, muL, sdL, muR, sdR, cfg)

axes(ax); hold on;

% column vector 강제 (중요)
phase = phase(:);
muL   = muL(:);
sdL   = sdL(:);
muR   = muR(:);
sdR   = sdR(:);

%% ================= LEFT =================
upper = muL + sdL;
lower = muL - sdL;

x = [phase; flipud(phase)];
y = [upper; flipud(lower)];

patch(ax, ...
    'XData', x, ...
    'YData', y, ...
    'FaceColor', cfg.color.left, ...
    'FaceAlpha', cfg.plot.alpha_shade, ...
    'EdgeColor', 'none');

plot(ax, phase, muL, ...
    'Color', cfg.color.left, ...
    'LineWidth', cfg.plot.lw_main);

%% ================= RIGHT =================
upper = muR + sdR;
lower = muR - sdR;

x = [phase; flipud(phase)];
y = [upper; flipud(lower)];

patch(ax, ...
    'XData', x, ...
    'YData', y, ...
    'FaceColor', cfg.color.right, ...
    'FaceAlpha', cfg.plot.alpha_shade, ...
    'EdgeColor', 'none');

plot(ax, phase, muR, ...
    'Color', cfg.color.right, ...
    'LineWidth', cfg.plot.lw_main);

%% ================= AXIS =================
% xlabel(ax, 'Gait cycle (%)', 'Interpreter','none');
% ylabel(ax, 'Ankle angle (deg)');

xlim(ax, [0 100]);
% ylim(ax, cfg.axis.angle);

end