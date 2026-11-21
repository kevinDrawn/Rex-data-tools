function plot_angle_type_cycloid(ax, exp_data, condition_idx, target_rat_dx, type, cfg)

axes(ax); hold(ax,'on');

%% ===============================
% 1. 데이터 가져오기
%% ===============================
angle_data = exp_data(target_rat_dx, condition_idx).phase_data.results.exo.angle;
y_data     = exp_data(target_rat_dx, condition_idx).phase_data.results.exo.(type);

int_data = exp_data(target_rat_dx,condition_idx).int_data;

if isempty(int_data)
    warning('int_data is empty');
    return;
end

serial = extract_t_interval_data(int_data);

%% ===============================
% 2. Raw cycloid (투명)
%% ===============================
plot(serial.left.angle,  serial.left.(type), ...
    'Color',[1 0 0 0.15], 'LineWidth',0.5);   % LEFT

plot(serial.right.angle, serial.right.(type), ...
    'Color',[0 0 1 0.15], 'LineWidth',0.5);   % RIGHT

%% ===============================
% 3. Mean cycloid (LEFT / RIGHT 공통 함수)
%% ===============================
plot_one_side(ax, ...
    angle_data.left.mean, angle_data.left.std, ...
    y_data.left.mean,     y_data.left.std, ...
    [1 0 0], cfg);   % LEFT = red

plot_one_side(ax, ...
    angle_data.right.mean, angle_data.right.std, ...
    y_data.right.mean,     y_data.right.std, ...
    [0 0 1], cfg);   % RIGHT = blue

%% ===============================
% 4. Axis
%% ===============================
xlabel(ax, 'Ankle angle (deg)');

switch type
    case 'vel'
        ylabel(ax, 'Angular velocity (deg/s)');
    case 'torque'
        ylabel(ax, 'Torque (N·mm/kg)');
    case 'power'
        ylabel(ax, 'Power (W/kg)');
    otherwise
        ylabel(ax, type);
end

box(ax,'off');

end

function plot_one_side(ax, theta, theta_std, y_mean, y_std, color, cfg)

if isempty(theta)
    return;
end

% row vector
theta     = theta(:)';
theta_std = theta_std(:)';
y_mean    = y_mean(:)';
y_std     = y_std(:)';

% 폐루프
theta_ext = [theta, theta(1)];
y_ext     = [y_mean, y_mean(1)];

% std (안정적으로)
std_ext = sqrt(theta_std.^2 + y_std.^2);
std_ext = [std_ext, std_ext(1)];

% densify
N = numel(theta);
N_dense = min(N * cfg.data.densify_factor, 2000);

t_ext   = linspace(0,1,N+1);
t_dense = linspace(0,1,N_dense);

x = interp1(t_ext, theta_ext, t_dense, 'pchip');
y = interp1(t_ext, y_ext,     t_dense, 'pchip');

std_dense = interp1(t_ext, std_ext, t_dense, 'linear');

% linewidth
lw = make_linewidth(std_dense, cfg);

% clamp (안정성)
lw = max(min(lw, cfg.max_lw), cfg.min_lw);

% plot
for k = 1:length(x)-1
    plot(ax, x(k:k+1), y(k:k+1), ...
        'Color',[color 0.8], ...
        'LineWidth', lw(k), ...
        'HandleVisibility','off');
end

end
