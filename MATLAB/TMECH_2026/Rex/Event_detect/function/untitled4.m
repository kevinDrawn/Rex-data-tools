
function fig = plot_exoskeleton_torque(data, time_range)
% PLOT_EXOSKELETON_TORQUE
% Visualize bilateral ankle interaction torques
%
% Input:
%   data              : Exoskeleton data
%   data.t            : Time [s]
%   data.left_torque  : Left interaction torque
%   data.right_torque : Right interaction torque
%   time_range        : [start_time, end_time] (s)
%                       [] = Entire time range
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
    all(isfinite(time_range)) && ...
    time_range(1) < time_range(2), ...
    'time_range must be [start_time, end_time].');

%% ===============================
% Figure
% ===============================

fig = figure('Color', 'w');

plot(data.t, data.left_torque, ...
    'b', 'LineWidth', 1.5);
hold on;

plot(data.t, data.right_torque, ...
    'r', 'LineWidth', 1.5);

%% ===============================
% Axis & Legend
% ===============================

grid on;
xlim(time_range);

xlabel('Time (s)');
ylabel('Interaction torque (N mm)');

lgd = legend('Left torque', 'Right torque', ...
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
