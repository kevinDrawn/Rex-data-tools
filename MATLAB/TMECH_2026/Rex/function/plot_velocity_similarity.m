function plot_velocity_similarity(ax, exp_data_summary, rat_list, cond_list_plot, cfg)

axes(ax); hold on;

% ===============================
% Data 정리
% ===============================
n_rat = numel(rat_list);
n_cond = size(exp_data_summary, 1);
x = 1:n_cond;
m = arrayfun(@(s) s.similarity.vel.mean, exp_data_summary(:));
s = arrayfun(@(s) s.similarity.vel.std, exp_data_summary(:));

% ===============================
% Bar plot
% ===============================
b = bar(ax, x, m, 'FaceColor','flat');

% 색상 (green theme)
colors = [
    0.6 0.75 0.9;   % light blue (기존 0.6 0.85 0.6 대응)
    0.2 0.45 0.8;   % strong blue
    0.7 0.8 0.9;    % pale blue
    0.3 0.5 0.7;    % muted blue
];

b.CData = colors(1:n_cond,:);
b.FaceAlpha = 0.8;

% ===============================
% Error bar
% ===============================
errorbar(ax, x, m, s, ...
    'ko', ...
    'LineStyle','none', ...
    'LineWidth',cfg.plot.lw_main, 'MarkerSize',cfg.plot.scatter.size);

% ===============================
% Scatter (개별 쥐)
% ===============================
% for k = 1:n_cond
% 
%     % jitter 추가 (겹침 방지)
%     jitter = (rand(n_rat,1)-0.5)*cfg.plot.jitter;
% 
%     m_individual = exp_data_summary(k).similarity.vel.all;
%     m_individual = m_individual(:);
% 
%     scatter(ax, ...
%         x(k)+jitter, ...
%         m_individual, ...
%         30, ...
%         'k', 'filled', ...
%         'MarkerFaceAlpha',cfg.plot.alpha);
% end

% ===============================
% Axis 설정
% ===============================
xticks(ax, x);
xticklabels(ax, cond_list_plot);
ylabel(ax, 'Similarity (%)');
ylim(ax, [0 100]);

style_axis_col_1(ax, cfg);   
% xticklabels(ax, []);
box(ax, 'off');


%% ===============================
% Summary print (fprintf)
%% ===============================
fprintf('\n=== Velocity Similarity Summary ===\n');

for k = 1:n_cond
    fprintf('%-20s : %6.2f ± %5.2f %%\n', ...
        cond_list_plot{k}, m(k), s(k));
end

fprintf('===================================\n');