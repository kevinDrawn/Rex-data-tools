function ax = plot_gait_peaks( ...
    t, left, right, ...
    t_interval, main_left, main_right)

% =========================================================
% plot_gait_peaks
%
% Interval별 Left / Right angle 및 검출 peak 표시
% 최대 4 × 4 subplot / figure
% =========================================================

max_per_fig = 16;

n_interval = size(t_interval,1);
n_fig = ceil(n_interval / max_per_fig);

ax = gobjects(n_interval,1);

% =========================================================
% Figure 단위 loop
% =========================================================

for f = 1:n_fig

    % 현재 figure에서 그릴 interval index
    idx_start = (f-1)*max_per_fig + 1;
    idx_end   = min(f*max_per_fig, n_interval);

    idx_now = idx_start:idx_end;

    % ===============================
    % Interval plot
    % ===============================

    ax_now = plot_intervals( ...
        t, ...
        left, ...
        right, ...
        t_interval(idx_now,:), ...
        'LineWidth',1.5, ...
        'LinkY',true, ...
        'XLabel','Time (s)', ...
        'YLabel','Ankle angle (deg.)', ...
        'Legend',[], ...
        'UseTiled',true);

    % 전체 ax에 저장
    ax(idx_now) = ax_now;

    % ===============================
    % Peak overlay
    % ===============================

    for j = 1:numel(idx_now)

        k = idx_now(j);

        hold(ax(k),'on');

        % ---------------------------
        % Left
        % ---------------------------

        if ~isempty(main_left(k).idx)

            plot( ...
                ax(k), ...
                main_left(k).t, ...
                left(main_left(k).idx), ...
                'ko', ...
                'MarkerFaceColor','w', ...
                'MarkerSize',10, ...
                'LineWidth',1.2);

        end

        % ---------------------------
        % Right
        % ---------------------------

        if ~isempty(main_right(k).idx)

            plot( ...
                ax(k), ...
                main_right(k).t, ...
                right(main_right(k).idx), ...
                'rs', ...
                'MarkerFaceColor','w', ...
                'MarkerSize',10, ...
                'LineWidth',1.2);

        end

    end

end

% =========================================================
% Figure style
% =========================================================

for k = 1:numel(ax)

    set(ax(k), ...
        'FontName','Times New Roman', ...
        'FontSize',25);

end

end