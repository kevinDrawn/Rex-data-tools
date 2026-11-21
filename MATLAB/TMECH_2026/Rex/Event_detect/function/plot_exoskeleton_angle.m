
function fig = plot_exoskeleton_angle(data, time_range)
% PLOT_EXOSKELETON_ANGLE
% Visualize bilateral ankle joint angles
%
% Input:
%   data       : Exoskeleton data
%   time_range : [start_time, end_time] (s)
%                [] = Entire time range
%
% Output:
%   fig : Figure handle

%% ===============================
% Time Range
% ===============================

if nargin < 2 || isempty(time_range)
    time_range = [min(data.t), max(data.t)];
end

assert(numel(time_range) == 2 && ...
    time_range(1) < time_range(2), ...
    'time_range must be [start_time, end_time].');

%% ===============================
% Figure
% ===============================

fig = figure('Color', 'w');

plot(data.t, data.left, ...
    'b', 'LineWidth', 1.5);
hold on;

plot(data.t, data.right, ...
    'r', 'LineWidth', 1.5);

%% ===============================
% Axis & Legend
% ===============================

grid on;
xlim(time_range);

xlabel('Time (s)');
ylabel('Ankle angle (deg)');

lgd = legend('Left angle', 'Right angle', ...
    'Orientation', 'horizontal', ...
    'Location', 'best');

%% ===============================
% Figure Formatting
% ===============================

set(gca, ...
    'FontName', 'Times New Roman', ...
    'FontSize', 25, ...
    'LineWidth', 1.2);

set(lgd, ...
    'FontName', 'Times New Roman', ...
    'FontSize', 20);

end
