function fig = plot_exoskeleton_emg(data)
% PLOT_EXOSKELETON_EMG
% Visualize TA and GM EMG signals
%
% Input:
%   data.t
%   data.TA_bp, data.GM_bp
%   data.TA_env, data.GM_env
%
% Output:
%   fig : Figure handle

fig = figure('Color', 'w');

tiledlayout(2,1, 'TileSpacing', 'compact');

%% TA EMG
nexttile;

plot(data.t, data.TA_bp, ...
    'Color', [0.7 0.7 0.7]); hold on;

plot(data.t, data.TA_env, ...
    'r', 'LineWidth', 1.5);

grid on;
ylabel('TA EMG (\muV)');
legend('Filtered EMG', 'Envelope', ...
    'Orientation', 'horizontal');

%% GM EMG
nexttile;

plot(data.t, data.GM_bp, ...
    'Color', [0.7 0.7 0.7]); hold on;

plot(data.t, data.GM_env, ...
    'b', 'LineWidth', 1.5);

grid on;
xlabel('Time (s)');
ylabel('GM EMG (\muV)');
legend('Filtered EMG', 'Envelope', ...
    'Orientation', 'horizontal');

%% Figure formatting
set(findall(fig, 'Type', 'axes'), ...
    'FontName', 'Times New Roman', ...
    'FontSize', 18);

end
