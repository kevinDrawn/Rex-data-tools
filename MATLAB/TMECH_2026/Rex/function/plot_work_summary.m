function exp_data_summary = plot_work_summary(varargin)
% Accept both standalone plots and an existing target axes.
narginchk(5, 6);
if nargin == 6
    ax = varargin{1};
    assert(isscalar(ax) && isgraphics(ax, 'axes'), 'First input must be a valid axes.');
    args = varargin(2:end);
else
    fig = figure;
    ax = axes('Parent', fig);
    args = varargin;
end
[exp_data, exp_data_summary, rat_list, cond_list_plot, cfg] = args{:};
hold(ax,'on');

n_rat  = numel(rat_list);
n_cond = numel(cond_list_plot);

%% ===============================
% 1. 데이터 저장
%% ===============================
pos_mat = nan(n_rat, n_cond);
neg_mat = nan(n_rat, n_cond);

for i = 1:n_rat
    for j = 1:n_cond
        try
            work_L = exp_data(i,j).work.left;

            pos_mat(i,j) = work_L.pos.mean;
            neg_mat(i,j) = work_L.neg.mean;

        catch
            warning('Data missing [%d, %d]', i, j);
        end
    end
end

%% ===============================
% 2. 평균 & 표준편차
%% ===============================
pos_mean = mean(pos_mat, 1, 'omitnan');
pos_std  = std(pos_mat,  0, 1, 'omitnan');

neg_mean = mean(neg_mat, 1, 'omitnan');
neg_std  = std(neg_mat,  0, 1, 'omitnan');

%% ===============================
% 🔥 3. Summary 저장
%% ===============================
for j = 1:n_cond

    exp_data_summary(j).work.pos_work.mean = pos_mean(j);
    exp_data_summary(j).work.pos_work.std  = pos_std(j);

    exp_data_summary(j).work.neg_work.mean = neg_mean(j);
    exp_data_summary(j).work.neg_work.std  = neg_std(j);

    ratio_vals = pos_mat(:,j) ./ abs(neg_mat(:,j));
    ratio_vals(~isfinite(ratio_vals)) = NaN;  % 🔥 안정화

    exp_data_summary(j).work.pos_neg_ratio.mean = mean(ratio_vals, 'omitnan');
    exp_data_summary(j).work.pos_neg_ratio.std  = std(ratio_vals, 0, 'omitnan');
end

%% ===============================
% 4. Plot (ax에 그리기)
%% ===============================
x = 1:n_cond;
offset = 0.18;

pos_color = [0.2 0.5 0.9];
neg_color = [0.9 0.3 0.3];

b1 = bar(ax, x - offset, pos_mean, 0.35, ...
    'FaceColor', pos_color, ...
    'EdgeColor', 'none');

b2 = bar(ax, x + offset, neg_mean, 0.35, ...
    'FaceColor', neg_color, ...
    'EdgeColor', 'none');

b1.FaceAlpha = 0.4;
b2.FaceAlpha = 0.4;

% Error bars
errorbar(ax, x - offset, pos_mean, pos_std, ...
    'ko', 'LineStyle','none', 'LineWidth', cfg.plot.lw_main + 0.5);

errorbar(ax, x + offset, neg_mean, neg_std, ...
    'ko', 'LineStyle','none', 'LineWidth', cfg.plot.lw_main + 0.5);

% Scatter (개별 쥐 데이터)
markers = {'o','^','s','d','v','>'}; % 쥐별 marker

jitter_scale = cfg.plot.jitter;
jit = linspace(-jitter_scale, jitter_scale, n_rat);

for j = 1:n_cond
    for i = 1:n_rat
        if isnan(pos_mat(i,j)) || isnan(neg_mat(i,j))
            continue;
        end

        mk = markers{mod(i-1,numel(markers))+1};

        % Positive
        x_pos = (x(j) - offset) + jit(i);

        scatter(ax, x_pos, pos_mat(i,j), 35, ...
            pos_color, mk, ...
            'filled', ...
            'MarkerEdgeColor',pos_color, ...
            'MarkerFaceAlpha',0, ...
            'MarkerEdgeAlpha',0.7);

        % Negative
        x_neg = (x(j) + offset) + jitter_scale*(rand-0.5);

        scatter(ax, x_neg, neg_mat(i,j), 35, ...
            neg_color, mk, ...
            'filled', ...
            'MarkerEdgeColor',neg_color, ...
            'MarkerFaceAlpha',0, ...
            'MarkerEdgeAlpha',0.7);
    end
end


%% ===============================
% 5. Formatting
%% ===============================
xticks(ax, x);
xticklabels(ax, cond_list_plot);

ylabel(ax, 'Work (J/kg)');

legend(ax, {'Positive work', 'Negative work'}, ...
    'Location','northwest', 'box', 'off');

grid(ax, 'off');
box(ax, 'off');

% y축 symmetric
all_vals = [pos_mat(:); neg_mat(:)];
all_vals = all_vals(~isnan(all_vals));

p = prctile(abs(all_vals), 99);  % 99% 기준
ymax = max(p, max(abs(pos_mean + pos_std)));

ylim(ax, [-1.1*ymax, 1.1*ymax]);

% 스타일 함수
style_axis_col_1(ax, cfg);

%% ===============================
% 6. Summary print (fprintf)
%% ===============================
fprintf('\n=== Interaction Work Summary ===\n');

for j = 1:n_cond

    % mJ/kg 변환
    pos_mJ = pos_mean(j) * 1000;
    pos_std_mJ = pos_std(j) * 1000;

    neg_mJ = neg_mean(j) * 1000;
    neg_std_mJ = neg_std(j) * 1000;

    ratio_mean = exp_data_summary(j).work.pos_neg_ratio.mean;
    ratio_std  = exp_data_summary(j).work.pos_neg_ratio.std;

    fprintf('%-20s : +Work %6.2f ± %5.2f mJ/kg | -Work %6.2f ± %5.2f mJ/kg | Ratio %5.2f ± %4.2f\n', ...
        cond_list_plot{j}, ...
        pos_mJ, pos_std_mJ, ...
        neg_mJ, neg_std_mJ, ...
        ratio_mean, ratio_std);
end

fprintf('=================================\n');


%% 통계분석
fprintf('\n=== Statistical Test (vs IE) ===\n');

% IE_idx = find(strcmp(cond_list_plot,'IE'));
% 
% for j = 1:n_cond
% 
%     if j == IE_idx
%         continue;
%     end
% 
%     % 데이터
%     IE_pos = pos_mat(:,IE_idx);
%     CUR_pos = pos_mat(:,j);
% 
%     IE_neg = neg_mat(:,IE_idx);
%     CUR_neg = neg_mat(:,j);
% 
%     % p-value
%     [~, p_pos] = ttest(IE_pos, CUR_pos);
%     [~, p_neg] = ttest(IE_neg, CUR_neg);
% 
%     % 별표
%     star_pos = p_to_star(p_pos);
%     star_neg = p_to_star(p_neg);
% 
%     fprintf('%-20s vs IE : +Work p = %.4f (%s) | -Work p = %.4f (%s)\n', ...
%         cond_list_plot{j}, ...
%         p_pos, star_pos, ...
%         p_neg, star_neg);
% end
% 
% fprintf('=================================\n');
% 
% fprintf('\n=== Statistical Test (LE vs LR) ===\n');
% 
% LE_idx = find(strcmp(cond_list_plot,'LE'));
% LR_idx = find(strcmp(cond_list_plot,'LR'));
% 
% if ~isempty(LE_idx) && ~isempty(LR_idx)
% 
%     LE_pos = pos_mat(:,LE_idx);
%     LR_pos = pos_mat(:,LR_idx);
% 
%     LE_neg = neg_mat(:,LE_idx);
%     LR_neg = neg_mat(:,LR_idx);
% 
%     [~, p_pos] = ttest(LE_pos, LR_pos);
%     [~, p_neg] = ttest(LE_neg, LR_neg);
% 
%     star_pos = p_to_star(p_pos);
%     star_neg = p_to_star(p_neg);
% 
%     fprintf('LE vs LR           : +Work p = %.4f (%s) | -Work p = %.4f (%s)\n', ...
%         p_pos, star_pos, ...
%         p_neg, star_neg);
% 
% end

fprintf('=================================\n');

end

function s = p_to_star(p)
    if p < 0.001
        s = '***';
    elseif p < 0.01
        s = '**';
    elseif p < 0.05
        s = '*';
    else
        s = 'ns'; % 또는 '' 로 해도 됨
    end
end
