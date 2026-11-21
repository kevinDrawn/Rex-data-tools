function plot_combined_regression(raw, trial_num, result)

% =========================================================
% plot_combined_regression
%
% Combined regression 결과 plotting
%
% Input
%   raw        : Trial별 raw data
%   trial_num  : Trial number
%   result     : combined_regression() 결과
% =========================================================

n = numel(raw);

fontsize = 23;

figure('Color','w');
hold on;

C_data = lines(n);

markerStyles = ...
    {'o','s','^','d','v','>','<','p','h','x','+'};

scatter_handles = gobjects(n,1);


%% ---------------------------------------------------------
% Original Scatter
% ---------------------------------------------------------

for k = 1:n

    if isempty(raw(k).x)
        continue;
    end

    scatter_handles(k) = scatter( ...
        raw(k).x, ...
        raw(k).y, ...
        40, ...
        'filled', ...
        'MarkerFaceColor', C_data(k,:), ...
        'MarkerFaceAlpha', 0.6, ...
        'MarkerEdgeColor','k', ...
        'MarkerEdgeAlpha',0.15, ...
        'Marker', ...
        markerStyles{mod(k-1,numel(markerStyles))+1});

end


%% ---------------------------------------------------------
% Outlier
% ---------------------------------------------------------

if any(result.is_outlier)

    h_outlier = scatter( ...
        result.x_out, ...
        result.y_out, ...
        120, ...
        'x', ...
        'MarkerEdgeColor',[0 0 0], ...
        'LineWidth',2.0);

end


%% ---------------------------------------------------------
% Original Regression
% ---------------------------------------------------------

h_original = plot( ...
    result.xq, ...
    result.yhat_original, ...
    '--', ...
    'LineWidth',2.0, ...
    'Color',[0.3 0.3 0.3]);


%% ---------------------------------------------------------
% Outlier-Removed Regression
% ---------------------------------------------------------

h_clean = plot( ...
    result.xq, ...
    result.yhat_clean, ...
    '-', ...
    'LineWidth',2.5, ...
    'Color',[1 0 0]);


%% ---------------------------------------------------------
% 95% Prediction Band
% ---------------------------------------------------------

has_CI = all(isfinite(result.yCI_clean(:)));

if has_CI

    h_CI = plot( ...
        result.xq, ...
        result.yCI_clean(:,1), ...
        '--', ...
        'Color',[1 0 0], ...
        'LineWidth',1.2);

    plot( ...
        result.xq, ...
        result.yCI_clean(:,2), ...
        '--', ...
        'Color',[1 0 0], ...
        'LineWidth',1.2, ...
        'HandleVisibility','off');

end


%% ---------------------------------------------------------
% Axis
% ---------------------------------------------------------

xlabel('$T_{r}$ (s)', ...
    'Interpreter','latex');

ylabel('$\Delta t$ (s)', ...
    'Interpreter','latex');

set(gca, ...
    'FontSize',fontsize, ...
    'FontName','Times New Roman');

grid off;
box on;


%% ---------------------------------------------------------
% Legend
% ---------------------------------------------------------

valid_trial = ...
    ~arrayfun(@(r) isempty(r.x), raw);

h_data = ...
    scatter_handles(valid_trial);

data_labels = arrayfun( ...
    @(x) sprintf('Data %d',x), ...
    trial_num(valid_trial), ...
    'UniformOutput',false);


legend_handles = h_data;
legend_labels  = data_labels(:);


% Outlier
if any(result.is_outlier)

    legend_handles(end+1,1) = h_outlier;
    legend_labels{end+1,1} = ...
        'Excluded outlier';

end


% Original regression
legend_handles(end+1,1) = h_original;

legend_labels{end+1,1} = ...
    'Original regression';


% Clean regression
legend_handles(end+1,1) = h_clean;

legend_labels{end+1,1} = ...
    'Outlier-removed regression';


% Prediction band
if has_CI

    legend_handles(end+1,1) = h_CI;

    legend_labels{end+1,1} = ...
        '95% prediction band';

end


legend( ...
    legend_handles, ...
    legend_labels, ...
    'Location','best', ...
    'Box','off');

end