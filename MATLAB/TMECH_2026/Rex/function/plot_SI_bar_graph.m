function plot_SI_bar_graph(SI_all, n_cond, n_rat, cond_list, plot_cond_list)

figure;
hold on;

%% Color setting

colors_bar = [

    0.7 0.7 0.7;            % Baseline
    0.6078 0.7882 0.8824;   % IE
    0.2980 0.6000 0.8000;   % IR
    0.8706 0.7608 0.1490;   % LE
    0.8863 0.5255 0.2353;   % LR
];

colors_scatter = [

    0.3 0.3 0.3;            % Baseline
    0.2510 0.5255 0.6706;   % IE
    0.0863 0.3804 0.5412;   % IR
    0.7412 0.5294 0.0235;   % LE
    0.6118 0.3804 0.0667;   % LR
];

%% Reorder conditions
% baseline -> first column
baseline_idx = find(strcmp(cond_list, 'baseline'));

other_idx = find(~strcmp(cond_list, 'baseline'));

plot_order = [baseline_idx(:).' other_idx(:).'];

% Reordered
SI_plot    = SI_all(:, plot_order);
cond_plot  = cond_list(plot_order);

x = 1:length(plot_order);

%% Mean / STD
mean_SI = mean(SI_plot, 1, 'omitnan');
std_SI  = std(SI_plot, 0, 1, 'omitnan');

%% Bar graph

b = bar(x, mean_SI);

for c = 1:length(plot_order)

    b.FaceColor = 'flat';

    % 막대 색상
    b.CData(c,:) = colors_bar(c,:);

end

% 막대 테두리 제거
b.EdgeColor = 'none';


%% Error bar
errorbar(x, mean_SI, std_SI, ...
    'k', ...
    'LineStyle','none', ...
    'LineWidth',2);

%% Scatter

jitter_scale = 0.5;

for r = 1:n_rat

    for c = 1:length(plot_order)

        if ~isnan(SI_plot(r,c))

            x_jitter = x(c) ...
                + (rand-0.5)*jitter_scale;

            scatter(x_jitter, SI_plot(r,c), ...
                70, ...
                colors_scatter(c,:), ...
                'filled', ...
                'MarkerEdgeColor','none', ...
                'MarkerFaceAlpha',0.7);

        end
    end
end

%% Axis
set(gca, 'XTick', x);
set(gca, 'XTickLabel', plot_cond_list);

ylabel('Symmetry Index (%)');
% title('Stance phase symmetry index');

box off;
ylim([0, 20]);
set(gca, 'FontName', 'Times new roman', 'FontSize', 25);
end