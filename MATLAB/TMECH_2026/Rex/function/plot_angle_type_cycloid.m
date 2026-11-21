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
% plot(serial.left.angle,  serial.left.(type), ...
%     'Color',[1 0 0 0.15], 'LineWidth',0.5);   % LEFT
% 
% plot(serial.right.angle, serial.right.(type), ...
%     'Color',[0 0 1 0.15], 'LineWidth',0.5);   % RIGHT

%% ===============================
% 3. Mean cycloid (LEFT / RIGHT 공통 함수)
%% ===============================

plot_one_side(ax, ...
    angle_data.left.mean, angle_data.left.std, ...
    y_data.left.mean,     y_data.left.std, ...
    cfg.color.left, cfg);   

plot_one_side(ax, ...
    angle_data.right.mean, angle_data.right.std, ...
    y_data.right.mean,     y_data.right.std, ...
    cfg.color.right, cfg);   

% 방향 확인용

% scatter(ax, angle_data.left.mean(1), y_data.left.mean(1));
% plot(ax, ...
%     angle_data.left.mean(1:50), y_data.left.mean(1:50));   
% 
% scatter(ax, angle_data.right.mean(1), y_data.right.mean(1));
% plot(ax, ...
%     angle_data.right.mean(1:50), y_data.right.mean(1:50));   
%% ===============================
% 4. Axis
%% ===============================
% xlabel(ax, 'Ankle angle (deg)');

% switch type
%     case 'vel'
%         ylabel(ax, 'Angular velocity (deg/s)');
%     case 'torque'
%         ylabel(ax, 'Torque (N·mm/kg)');
%     case 'power'
%         ylabel(ax, 'Power (W/kg)');
%     otherwise
%         ylabel(ax, type);
% end

% ===============================
% X/Y 범위 자동 설정 + margin
% ===============================

% X 데이터 (angle)
all_x = [ ...
    angle_data.left.mean(:); ...
    angle_data.right.mean(:) ...
];

% Y 데이터
all_y = [ ...
    y_data.left.mean(:); ...
    y_data.right.mean(:) ...
];

% --- X ---
x_min = min(all_x, [], 'omitnan');
x_max = max(all_x, [], 'omitnan');
x_range = x_max - x_min;

x_margin = x_range * cfg.axis.x_margin_ratio;

% --- Y ---
y_min = min(all_y, [], 'omitnan');
y_max = max(all_y, [], 'omitnan');
y_range = y_max - y_min;

y_margin = y_range * cfg.axis.y_margin_ratio;

% 적용
xlim(ax, [x_min - x_margin, x_max + x_margin]);
ylim(ax, [y_min - y_margin, y_max + y_margin]);
box(ax,'off');

end

function plot_one_side(ax, theta, theta_std, y_mean, y_std, color, cfg)

% ===============================
% 0. 입력 체크
% ===============================
if isempty(theta) || isempty(y_mean)
    return;
end

% row vector 강제
theta     = theta(:)';
theta_std = theta_std(:)';
y_mean    = y_mean(:)';
y_std     = y_std(:)';

% 길이 맞추기 (안정성)
N = min([numel(theta), numel(y_mean), numel(theta_std), numel(y_std)]);
theta     = theta(1:N);
theta_std = theta_std(1:N);
y_mean    = y_mean(1:N);
y_std     = y_std(1:N);

% ===============================
% 1. std 계산
% ===============================
std_base = sqrt(theta_std.^2 + y_std.^2);

% ===============================
% 2. 🔥 padding 방식 (부드러운 연결)
% ===============================
pad_ratio = 0.01;   % 10% padding
pad_n = max(1, round(N * pad_ratio));  % 최소 3개 확보

theta_ext = [theta(end-pad_n+1:end), theta, theta(1:pad_n)];
y_ext     = [y_mean(end-pad_n+1:end), y_mean, y_mean(1:pad_n)];
std_ext   = [std_base(end-pad_n+1:end), std_base, std_base(1:pad_n)];

% ===============================
% 3. t 축 생성 (🔥 핵심 수정)
% ===============================
L = numel(theta_ext);

t_ext   = linspace(0,1,L);
N_dense = min(N * cfg.data.densify_factor, 2000);
t_dense = linspace(0,1,N_dense);

% ===============================
% 4. interpolation
% ===============================
x = interp1(t_ext, theta_ext, t_dense, 'pchip');
y = interp1(t_ext, y_ext,     t_dense, 'pchip');
std_dense = interp1(t_ext, std_ext, t_dense, 'linear');

% ===============================
% 5. linewidth 생성
% ===============================
lw = make_linewidth(std_dense, cfg);
% lw = min(lw, cfg.plot.lw_main);

% ===============================
% 6. plot
% ===============================
hold(ax, 'on');

for k = 1:length(x)-1
    plot(ax, x(k:k+1), y(k:k+1), ...
        'Color',[color 0.8], ...
        'LineWidth', lw(k), ...
        'HandleVisibility','off');
end

end
