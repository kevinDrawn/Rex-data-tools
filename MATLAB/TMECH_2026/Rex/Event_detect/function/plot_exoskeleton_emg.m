
function fig = plot_exoskeleton_emg(data, time_range)
% PLOT_EXOSKELETON_EMG
% Visualize TA and GM EMG signals
%
% Input:
%   data.t
%   data.TA_bp, data.GM_bp
%   data.TA_env, data.GM_env
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
    all(isfinite(time_range)) && ...
    time_range(1) < time_range(2), ...
    'time_range must be [start_time, end_time].');

%% ===============================
% Figure
% ===============================

fig = figure('Color', 'w');

tiledlayout(2,1, 'TileSpacing', 'compact');

%% ===============================
% TA EMG
% ===============================

nexttile;

plot(data.t, data.TA_bp, ...
    'Color', [0.7 0.7 0.7]); hold on;

plot(data.t, data.TA_env, ...
    'r', 'LineWidth', 1.5);

grid on;
xlim(time_range);

ylabel('TA EMG (\muV)');
legend('Filtered EMG', 'Envelope', ...
    'Orientation', 'horizontal');

%% ===============================
% GM EMG
% ===============================

nexttile;

plot(data.t, data.GM_bp, ...
    'Color', [0.7 0.7 0.7]); hold on;

plot(data.t, data.GM_env, ...
    'b', 'LineWidth', 1.5);

grid on;
xlim(time_range);

xlabel('Time (s)');
ylabel('GM EMG (\muV)');
legend('Filtered EMG', 'Envelope', ...
    'Orientation', 'horizontal');

%% ===============================
% Figure Formatting
% ===============================

set(findall(fig, 'Type', 'axes'), ...
    'FontName', 'Times New Roman', ...
    'FontSize', 18);

end
