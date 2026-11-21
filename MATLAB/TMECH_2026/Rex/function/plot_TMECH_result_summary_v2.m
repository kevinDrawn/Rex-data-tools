function plot_TMECH_result_summary_v2(target_rat, rat_list, cond_list, cond_list_plot, exp_data, exp_data_summary, cfg)

% 🔹 기본 설정
n_row  = 4; % Angle - Velocity Cycloid - Torque Cycloid - Power Cycloid
n_col  = numel(cond_list); % 4 condition + 정량적 지표 그래프
target_rdx = find(strcmp(rat_list, target_rat{1}));
rat_name = rat_list{target_rdx};

% Figure
fig = figure('Color','w', ...
    'Units','centimeters', ...
    'Position',[2 2 18 20], ...
    'Name', rat_name, ...        
    'NumberTitle','off');        

sgtitle(rat_list{target_rdx}, ...
    'FontSize', cfg.font.size, ...
    'FontWeight','normal', ...
    'Interpreter','none');

tiledlayout(n_row, n_col, ...
    'TileSpacing','compact', ...
    'Padding','compact');

for i = 1:n_col
    % (1) Row - Ankle angle pattern + ROM SI Index        
    ax = nexttile(i); hold on;

    phase = exp_data(1,1).phase_data.phase;
    if ~isempty(phase)    
        phase_data = exp_data(target_rdx,i).phase_data;
    
        % Left
        muL = phase_data.results.mocap.angle.left.mean;
        sdL = phase_data.results.mocap.angle.left.std;
    
        % Right
        muR = phase_data.results.exo.angle.right.mean;
        sdR = phase_data.results.exo.angle.right.std;
        
        % Angle graph - average pattern
        plot_mean_std_shaded(ax, phase, muL, sdL, muR, sdR, cfg);

        % IC Phase 
        x_IC_left  = exp_data(target_rdx, i).phase_data.results.mocap.spatio.left.IC_phase.mean;
        x_IC_right = exp_data(target_rdx, i).phase_data.results.mocap.spatio.right.IC_phase.mean;
        
        % 🔥 세로 점선 (LEFT)
        xline(ax, x_IC_left, '--', ...
            'Color', cfg.color.left, ...
            'LineWidth', 1.5, ...
            'HandleVisibility','off');
        
        % 🔥 세로 점선 (RIGHT)
        xline(ax, x_IC_right, '--', ...
            'Color', cfg.color.right, ...
            'LineWidth', 1.5, ...
            'HandleVisibility','off');

        xlabel(ax, 'Gait phase (%)');
        style_axis_col_2(ax, cfg);
    end

    % (2) Row - Ankle angle velocity cycloid        
    ax = nexttile(n_col + i); hold on;
    plot_angle_type_cycloid(ax, exp_data, i, target_rdx, 'vel', cfg);        
    xlabel(ax, 'Ankle angle (deg.)');
    style_axis_col_2(ax, cfg);

    % (3) Row - Ankle angle torque cycloid        
    ax = nexttile(2 * n_col + i); hold on;
    plot_angle_type_cycloid(ax, exp_data, i, target_rdx, 'torque', cfg);        
    xlabel(ax, 'Ankle angle (deg.)');
    style_axis_col_2(ax, cfg);
    
    % (4) Row - Power angle cycloid        
    ax = nexttile(3 * n_col + i); hold on;
    plot_angle_type_cycloid(ax, exp_data, i, target_rdx, 'power', cfg);        
    xlabel(ax, 'Ankle angle (deg.)');
    style_axis_col_2(ax, cfg);
end

% 저장 경로 생성
save_dir = fullfile(cfg.root_dir, 'TMECH_fig_summary');

if ~isfolder(save_dir)
    mkdir(save_dir);
end

%% ===============================
% Save Figure
%% ===============================

set(fig, 'Renderer', 'painters');

% base name
base_name = sprintf('%s_summary', rat_name);

% full path
fig_path = fullfile(save_dir, [base_name '.fig']);
pdf_path = fullfile(save_dir, [base_name '.pdf']);
png_path = fullfile(save_dir, [base_name '.png']);

% 1. MATLAB figure
savefig(fig, fig_path);

% 2. Vector PDF (논문용 최고 추천)
exportgraphics(fig, pdf_path, ...
    'ContentType','vector');

% 3. High-resolution PNG
exportgraphics(fig, png_path, ...
    'Resolution',600);

fprintf('[Saved]\n');
fprintf('  FIG : %s\n', fig_path);
fprintf('  PDF : %s\n', pdf_path);
fprintf('  PNG : %s\n', png_path);
end

function add_inner_margin(ax, ratio)

pos = ax.Position;

dx = pos(3) * ratio;
dy = pos(4) * ratio;

ax.Position = [
    pos(1)+dx ...
    pos(2)+dy ...
    pos(3)-2*dx ...
    pos(4)-2*dy ...
];
end
