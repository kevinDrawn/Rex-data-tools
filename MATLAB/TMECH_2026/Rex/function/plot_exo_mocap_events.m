function plot_exo_mocap_events(main_left, main_right, int_data, root_dir)

st = dbstack;

left_f  = int_data.left.angle;
right_f = int_data.right.angle;
t       = int_data.t;
t_interval = int_data.t_interval;

n = numel(main_left);

fig = figure;
tiledlayout(n,1);

for k = 1:n

    ax = nexttile;
    hold(ax,'on');

    % ===============================
    % interval 구간만 선택
    % ===============================
    t0 = t_interval(k,1);
    t1 = t_interval(k,2);

    mask = (t >= t0) & (t <= t1);

    t_seg     = t(mask);
    left_seg  = left_f(mask);
    right_seg = right_f(mask);

    % ===============================
    % signal plot
    % ===============================
    plot(ax, t_seg, left_seg,  'b');
    plot(ax, t_seg, right_seg, 'r');

    % ===============================
    % EXO TO / IC
    % ===============================
    if ~isempty(main_left(k).idx_TO)
        plot(ax, main_left(k).t_TO, left_f(main_left(k).idx_TO), ...
            'ko','MarkerFaceColor','w');
    end

    if ~isempty(main_right(k).idx_TO)
        plot(ax, main_right(k).t_TO, right_f(main_right(k).idx_TO), ...
            'rs','MarkerFaceColor','w');
    end

    if ~isempty(main_left(k).idx_IC)
        plot(ax, main_left(k).t_IC, left_f(main_left(k).idx_IC), ...
            'ko','MarkerFaceColor','k');
    end

    if ~isempty(main_right(k).idx_IC)
        plot(ax, main_right(k).t_IC, right_f(main_right(k).idx_IC), ...
            'rs','MarkerFaceColor','r');
    end

    % ===============================
    % MOCAP (vertical lines)
    % ===============================
    % xline(ax, main_left(k).t_TO_mocap, '-b','LineWidth',2);
    % xline(ax, main_left(k).t_IC_mocap, 'b','LineWidth',2);
    % 
    % xline(ax, main_right(k).t_TO_mocap, '-r','LineWidth',1);
    % xline(ax, main_right(k).t_IC_mocap, 'r','LineWidth',2);

    % ===============================
    % x축 제한 (핵심)
    % ===============================
    xlim(ax, [t0 t1]);

    title(ax, sprintf('Interval %d', k));
end

% ===============================
% 저장
% ===============================
save_folder = fullfile(root_dir, 'L_R Serial angle with Peak');

if ~exist(save_folder, 'dir')
    mkdir(save_folder);
end

save_path = fullfile(save_folder, 'LR Serial angle with Peak.fig');
savefig(fig, save_path);

% ===============================
% 로그
% ===============================
if numel(st) >= 2
    fprintf('[%s <- %s] Figure saved:\n%s\n', ...
        st(1).name, st(2).name, save_path);
else
    fprintf('[%s] Figure saved:\n%s\n', ...
        st(1).name, save_path);
end

end