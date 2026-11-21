function phase_result = plot_phase_offset( ...
    x_clean, y_clean, phase_unit)

% =========================================================
% plot_phase_offset
%
% Stride별 Right-Left phase offset 계산 및 plotting
%
% Input
%   x_clean   : Right gait cycle period T_R [s]
%   y_clean   : Right -> Left delay Δt [s]
%
%   phase_unit
%       'percent' : Gait phase [%]
%       'degree'  : Phase angle [deg.]
%
% Output
%   phase_result.phase
%   phase_result.mean
%   phase_result.std
%   phase_result.stride_number
% =========================================================


%% ---------------------------------------------------------
% [1] Phase 계산
% ---------------------------------------------------------

phase_ratio = y_clean ./ x_clean;

stride_number = (1:numel(phase_ratio))';


%% ---------------------------------------------------------
% [2] Phase Unit
% ---------------------------------------------------------

switch lower(phase_unit)

    case 'percent'
    
        phase = phase_ratio * 100;
    
        ylabel_text = 'Contralateral Phase Offset (%)';
    
        y_lim = [0 100];
    
        reference_phase = 50;
    
        y_ticks = [0 25 50 75 100];


    case 'degree'

            phase = phase_ratio * 360;
        
            ylabel_text = 'Contralateral Phase Offset (deg)';
        
            y_lim = [100 260];
        
            reference_phase = 180;
        
            y_ticks = [100 140 180 220 260];

    otherwise

        error( ...
            ['Unknown phase unit: %s\n' ...
             'Use ''percent'' or ''degree''.'], ...
            phase_unit);

end


%% ---------------------------------------------------------
% [3] Statistics
% ---------------------------------------------------------

mean_phase = mean(phase, 'omitnan');
std_phase  = std(phase, 'omitnan');

upper_sd = mean_phase + std_phase;
lower_sd = mean_phase - std_phase;


%% ---------------------------------------------------------
% [4] Figure
% ---------------------------------------------------------

fontsize = 25;

figure( ...
    'Color', 'w', ...
    'Units', 'pixels', ...
    'Position', [100 100 1200 550]);

ax = axes;
hold(ax, 'on');


%% ---------------------------------------------------------
% [5] Mean ± SD region
% ---------------------------------------------------------

x_patch = [ ...
    0.5, ...
    numel(phase) + 0.5, ...
    numel(phase) + 0.5, ...
    0.5];

y_patch = [ ...
    lower_sd, ...
    lower_sd, ...
    upper_sd, ...
    upper_sd];

h_sd = patch( ...
    ax, ...
    x_patch, ...
    y_patch, ...
    [0.2 0.45 0.8], ...
    'FaceAlpha', 0.15, ...
    'EdgeColor', 'none');


%% ---------------------------------------------------------
% [6] Individual strides
% ---------------------------------------------------------

h_phase = scatter( ...
    ax, ...
    stride_number, ...
    phase, ...
    38, ...
    'filled', ...
    'MarkerFaceColor', [0.45 0.45 0.45], ...
    'MarkerFaceAlpha', 0.60, ...
    'MarkerEdgeColor', 'none');


%% ---------------------------------------------------------
% [7] Mean phase
% ---------------------------------------------------------

h_mean = yline( ...
    ax, ...
    mean_phase, ...
    '-', ...
    'Color', [0 0.25 0.8], ...
    'LineWidth', 2.5);


%% ---------------------------------------------------------
% [8] Half-cycle reference
% ---------------------------------------------------------

h_reference = yline( ...
    ax, ...
    reference_phase, ...
    '--', ...
    'Color', 'k', ...
    'LineWidth', 1.8);


%% ---------------------------------------------------------
% [9] Axis
% ---------------------------------------------------------

xlabel(ax, 'Stride Number');
ylabel(ax, ylabel_text);

ylim(ax, y_lim);
yticks(ax, y_ticks);

if ~isempty(stride_number)
    xlim(ax, [0.5 numel(stride_number)+0.5]);
end

ax.FontName = 'Times New Roman';
ax.FontSize = fontsize;

ax.XColor = 'k';
ax.YColor = 'k';

ax.LineWidth = 1.2;

grid(ax, 'off');
box(ax, 'off');


%% ---------------------------------------------------------
% [10] Legend
% ---------------------------------------------------------

lgd = legend( ...
    ax, ...
    [h_phase h_mean h_sd h_reference], ...
    { ...
    'Individual Strides', ...
    'Mean', ...
    'Mean \pm SD', ...
    'Half-Cycle Reference' ...
    }, ...
    'Location', 'best', ...
    'Box', 'off');

lgd.FontName = 'Times New Roman';
lgd.FontSize = fontsize - 3;


%% ---------------------------------------------------------
% [11] Result
% ---------------------------------------------------------

fprintf('\n');
fprintf('========================================\n');
fprintf('Contralateral Phase Offset\n');
fprintf('========================================\n');

fprintf('N strides : %d\n', numel(phase));

if strcmpi(phase_unit, 'percent')

    fprintf('Mean       : %.2f %%\n', mean_phase);
    fprintf('SD         : %.2f %%\n', std_phase);
    fprintf('Mean ± SD  : %.2f ± %.2f %%\n', ...
        mean_phase, std_phase);

else

    fprintf('Mean       : %.2f deg.\n', mean_phase);
    fprintf('SD         : %.2f deg.\n', std_phase);
    fprintf('Mean ± SD  : %.2f ± %.2f deg.\n', ...
        mean_phase, std_phase);

end

fprintf('========================================\n\n');


%% ---------------------------------------------------------
% [12] Output
% ---------------------------------------------------------

phase_result.phase = phase;
phase_result.phase_ratio = phase_ratio;

phase_result.stride_number = stride_number;

phase_result.mean = mean_phase;
phase_result.std = std_phase;

phase_result.reference = reference_phase;
phase_result.unit = phase_unit;

end