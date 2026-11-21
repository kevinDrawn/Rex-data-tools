function [fig, ax] = plot_footdrop_metric(metric, yLabel)
%PLOT_FOOTDROP_METRIC One standalone figure with the Rex SI condition colors.
% Exact IE/IR/LE/LR RGB values from plot_SI_bar_multi_purpose.m.
conditions = ["Baseline", "IE", "IR", "LE", "LR"];
barColors = [
    165/255 165/255 165/255; % Baseline: retain neutral gray.
    0.6078 0.7882 0.8824;   % IE
    0.2980 0.6000 0.8000;   % IR
    0.8706 0.7608 0.1490;   % LE
    0.8863 0.5255 0.2353];  % LR
detailColors = [
    0.4000 0.4000 0.4000;   % Baseline: dark neutral gray.
    0.2510 0.5255 0.6706;   % IE
    0.0863 0.3804 0.5412;   % IR
    0.7412 0.5294 0.0235;   % LE
    0.6118 0.3804 0.0667];  % LR
[found, colorIndices] = ismember(string(metric.ConditionNames), conditions);
assert(all(found), 'Footdrop:UnknownConditionColor', 'Unknown condition in foot-drop metric.');
fig = figure('Name', char(string(yLabel)), 'Color', 'w', 'Position', [100 100 900 650]);
ax = axes('Parent', fig, 'Position', [0.20 0.14 0.76 0.82]);
hold(ax, 'on');
nC = numel(metric.ConditionNames);
% Fit each figure to its own condition count.
x = 1:nC;
offsets = linspace(-0.18, 0.18, numel(metric.RatIDs));
for c = 1:nC
    barColor = barColors(colorIndices(c), :);
    detailColor = detailColors(colorIndices(c), :);
    values = metric.RatMeans(:, c);
    valid = find(isfinite(values));
    if isempty(valid)
        text(ax, x(c), 0, 'No data', 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
        continue;
    end
    mu = mean(values(valid));
    bar(ax, x(c), mu, 0.7, 'FaceColor', barColor, 'EdgeColor', 'none', 'FaceAlpha', 0.85);
    if numel(valid) > 1
        errorbar(ax, x(c), mu, std(values(valid), 0), 'Color', detailColor, ...
            'LineStyle', 'none', 'LineWidth', 2.5, 'CapSize', 10);
    end
    for r = valid(:)'
        scatter(ax, x(c) + offsets(r), values(r), 32, 'o', ...
            'MarkerFaceColor', detailColor, 'MarkerEdgeColor', 'none', ...
            'MarkerFaceAlpha', 0.6, 'DisplayName', char(metric.RatIDs(r)));
    end
end
set(ax, 'XTick', x, 'XTickLabel', cellstr(metric.ConditionNames), ...
    'XLim', [0.4 nC + 0.6], 'FontName', 'Times New Roman', 'FontSize', 25, ...
    'LabelFontSizeMultiplier', 1, 'TitleFontSizeMultiplier', 1, ...
    'LineWidth', 0.8, 'TickDir', 'out', 'XMinorGrid', 'off', 'YMinorGrid', 'off');
if ~any(isfinite(metric.RatMeans(:))) && string(metric.Units) == "%"
    ylim(ax, [0 100]);
end
xlabel(ax, '');
ylabel(ax, yLabel, 'FontSize', 25, 'FontName', 'Times New Roman');
grid(ax, 'off');
box(ax, 'off');
end
