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

fontsize = 28;

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
box off;

%% ---------------------------------------------------------
% Legend
% ---------------------------------------------------------

valid_trial = ...
    ~arrayfun(@(r) isempty(r.x), raw);

h_data = ...
    scatter_handles(valid_trial);

data_labels = arrayfun( ...
    @(x) sprintf('Rat %d',x), ...
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

%% =========================================================
% Clean Figure
% Outliers removed
% ==========================================================

figure('Color','w');
hold on;

scatter_handles_clean = gobjects(n,1);

%% ---------------------------------------------------------
% Scatter data WITHOUT outliers
% ---------------------------------------------------------

for k = 1:n

    if isempty(raw(k).x)
        continue;
    end

    % 현재 trial의 데이터가 combined data에서 어디에 해당하는지
    % result에 trial index 정보가 있다고 가정하지 않고,
    % x-y pair를 이용하여 outlier 여부 확인

    x_k = raw(k).x(:);
    y_k = raw(k).y(:);

    keep = true(size(x_k));

    % result에서 검출된 outlier 제거
    for j = 1:length(result.x_out)

        is_same = ...
            abs(x_k - result.x_out(j)) < 1e-10 & ...
            abs(y_k - result.y_out(j)) < 1e-10;

        keep(is_same) = false;

    end

    x_clean = x_k(keep);
    y_clean = y_k(keep);

    if isempty(x_clean)
        continue;
    end

    scatter_handles_clean(k) = scatter( ...
        x_clean, ...
        y_clean, ...
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
% Outlier-Removed Regression ONLY
% ---------------------------------------------------------

h_clean2 = plot( ...
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

    h_CI2 = plot( ...
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

ylabel('Offset time $\Delta t$ (s)', ...
    'Interpreter','latex');

set(gca, ...
    'FontSize',fontsize, ...
    'FontName','Times New Roman');

grid off;
box off;


%% ---------------------------------------------------------
% Legend
% ---------------------------------------------------------

valid_clean = isgraphics(scatter_handles_clean);

h_data_clean = ...
    scatter_handles_clean(valid_clean);

data_labels_clean = arrayfun( ...
    @(x) sprintf('Rat %d',x), ...
    trial_num(valid_clean), ...
    'UniformOutput',false);

legend_handles_clean = h_data_clean;
legend_labels_clean  = data_labels_clean(:);


% Clean regression
legend_handles_clean(end+1,1) = h_clean2;

legend_labels_clean{end+1,1} = ...
    'Regression';


% Prediction band
if has_CI

    legend_handles_clean(end+1,1) = h_CI2;

    legend_labels_clean{end+1,1} = ...
        '95% prediction band';

end


legend( ...
    legend_handles_clean, ...
    legend_labels_clean, ...
    'Location','best', ...
    'Box','off');

end