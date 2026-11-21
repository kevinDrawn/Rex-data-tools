function plot_SI_bar(ax, exp_data, exp_data_summary, cond_list_plot, cfg)

%% ===============================
% 1. 기본 설정
%% ===============================
n_cond = numel(exp_data_summary);
x = 1:n_cond;

% summary 값 추출
SI_mean = arrayfun(@(s) s.ROM.SI.mean, exp_data_summary);
SI_std  = arrayfun(@(s) s.ROM.SI.std,  exp_data_summary);

%% ===============================
% 2. Bar plot
%% ===============================
axes(ax);      % 또는 생략 가능
hold(ax, 'on');   % ✔ 중요

b = bar(x, SI_mean, 'FaceColor','flat');

% 색상 (green theme)
colors = [
    0.6 0.85 0.6;
    0.2 0.7 0.3;
    0.7 0.8 0.7;
    0.3 0.6 0.3;
];

b.CData = colors(1:n_cond,:);
b.FaceAlpha = 0.8;

%% ===============================
% 3. Errorbar
%% ===============================
errorbar(x, SI_mean, SI_std, ...
    'ko', 'LineStyle','none', 'LineWidth',cfg.plot.lw_main, ...
    'MarkerSize',cfg.plot.scatter.size);

%% ===============================
% 4. Scatter (개별 쥐)
%% ===============================
n_rat = size(exp_data,1);

markers = {'o','^','s','d','v','>'}; % 쥐별 marker

%% ===============================
% Scatter
%% ===============================

% for j = 1:n_cond
% 
%     SI_vals = exp_data_summary(j).ROM.SI.all;
%     SI_vals = SI_vals(:);
% 
%     for r = 1:n_rat
% 
%         x_scatter = x(j) + ...
%             (rand-0.5)*cfg.plot.jitter;
% 
%         scatter(x_scatter, SI_vals(r), ...
%             75, ...
%             'k', ...
%             markers{r}, ...
%             'filled', ...
%             'MarkerFaceAlpha',cfg.plot.alpha);
%     end
% end

%% ===============================
% 5. Formatting
%% ===============================
xticks(x);

xticklabels(cond_list_plot);
ylabel('Symmetry Index (%)');

grid off;
box off;

set(gca, ...
    'FontSize', cfg.font.size_col_1, ...
    'FontName', cfg.font.name, ...
    'LineWidth',1);

%% ===============================
% 6. Auto ylim + margin
%% ===============================

% 1. bar + error 포함
y_top = SI_mean + SI_std;
y_bot = SI_mean - SI_std;

% 2. scatter까지 포함 (더 robust)
all_scatter = [];
for j = 1:n_cond
    vals = exp_data_summary(j).ROM.SI.all;
    all_scatter = [all_scatter; vals(:)];
end

% 3. 전체 데이터
all_y = [y_top(:); y_bot(:); all_scatter(:)];

y_min = min(all_y, [], 'omitnan');
y_max = max(all_y, [], 'omitnan');

% 4. margin 적용
y_range = y_max - y_min;
margin = y_range * cfg.axis.y_margin_ratio;

% 예외 처리
if y_range == 0
    margin = 1;
end

ylim(ax, [y_min - margin, y_max + margin]);
% xticklabels(ax, []);
style_axis_col_1(ax, cfg);  


%% ===============================
% 7. Summary print (fprintf)
%% ===============================
fprintf('\n=== Symmetry Index (SI) Summary ===\n');

for j = 1:n_cond
    fprintf('%-20s : %6.2f ± %5.2f %%\n', ...
        cond_list_plot{j}, SI_mean(j), SI_std(j));
end

fprintf('===================================\n');

end