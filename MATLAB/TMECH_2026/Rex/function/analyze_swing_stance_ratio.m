function result = analyze_swing_stance_ratio( ...
    baseline_data, exp_data, rat_list, save_dir, plot_conditions)
% SWING/STANCE = swing duration / stance duration (dimensionless).
% Convert EACH retained cycle, then average within rat, then across rats.
% Never use the legacy stance_swing_ratio field: it stores swing fraction.
% Baseline retains the existing 40<stance%<80 + quartile outlier filter.
% Other conditions retain the valid cycles in stance_phase.all as supplied.
% Pooled-cycle summaries are descriptive only; rats remain the analysis unit.

if nargin < 5
    plot_conditions = {'Baseline','IE','IR'};
end
labels = {'Baseline','IE','IR','LE','LR'};
source_conditions = {'baseline','intact_Exo shoe','intact_Rex', ...
    'lido_Exo shoe','lido_Rex'};
sides = {'left','right'};
assert(all(ismember(plot_conditions, labels)), 'Unknown plot condition.');
assert(~isempty(plot_conditions), 'Select at least one plot condition.');
rat_rows = cell(0,8);
cycle_rows = cell(0,6);

for r = 1:numel(rat_list)
    for c = 1:numel(labels)
        for s = 1:numel(sides)
            side = sides{s};
            if c == 1
                idx = find(strcmp({baseline_data.rat}, rat_list{r}));
                assert(numel(idx)==1, 'Missing/duplicate baseline for %s.',rat_list{r});
                stance = baseline_data(idx).(side).all;
            else
                idx = find(strcmp({exp_data.rat},rat_list{r}) & ...
                    strcmp({exp_data.cond},source_conditions{c}));
                assert(numel(idx)==1, 'Missing/duplicate data for %s / %s.', ...
                    rat_list{r}, labels{c});
                data = exp_data(idx).phase_data;
                assert(isstruct(data) && isfield(data,'results'), ...
                    'Missing phase results: %s / %s.',rat_list{r},labels{c});
                % Require cycle-level percentages; no fallback to group mean.
                stance = data.results.mocap.spatio.(side).stance_phase.all;
            end
            stance = stance(:);
            valid = isfinite(stance) & stance > 0 & stance < 100;
            if any(~valid)
                warning('SwingStance:InvalidCycle', ...
                    '%s / %s / %s: excluded %d invalid stance percentages.', ...
                    rat_list{r}, labels{c}, side, sum(~valid));
            end
            retained_idx = find(valid);
            stance = stance(valid);
            ratios = (100-stance)./stance;
            rat_rows(end+1,:) = {rat_list{r}, labels{c}, side, ...
                numel(ratios), mean(stance,'omitnan'), ...
                mean(ratios,'omitnan'), std(ratios,0,'omitnan'), ...
                source_conditions{c}}; %#ok<AGROW>
            for k = 1:numel(ratios)
                cycle_rows(end+1,:) = {rat_list{r}, labels{c}, side, ...
                    retained_idx(k), stance(k), ratios(k)}; %#ok<AGROW>
            end
        end
    end
end
rat_table = cell2table(rat_rows, 'VariableNames', ...
    {'Rat','Condition','Side','N_Cycles','MeanStancePercent', ...
    'MeanSwingStanceRatio','SDSwingStanceRatio','SourceCondition'});
cycle_table = cell2table(cycle_rows,'VariableNames', ...
    {'Rat','Condition','Side','SourceCycleIndex','StancePercent','SwingStanceRatio'});

group_rows = cell(0,10);
for s = 1:numel(sides)
    for c = 1:numel(labels)
        take_rat = strcmp(rat_table.Condition,labels{c}) & ...
            strcmp(rat_table.Side,sides{s});
        vals = rat_table.MeanSwingStanceRatio(take_rat);
        take_cycle = strcmp(cycle_table.Condition,labels{c}) & ...
            strcmp(cycle_table.Side,sides{s});
        cycles = cycle_table.SwingStanceRatio(take_cycle);
        base = rat_table.MeanSwingStanceRatio( ...
            strcmp(rat_table.Condition,'Baseline') & strcmp(rat_table.Side,sides{s}));
        base_mean = mean(base,'omitnan');
        group_mean = mean(vals,'omitnan');
        group_rows(end+1,:) = {labels{c}, sides{s}, sum(isfinite(vals)), ...
            numel(cycles), group_mean, std(vals,0,'omitnan'), ...
            mean(cycles,'omitnan'), std(cycles,0,'omitnan'), ...
            group_mean-base_mean, 100*(group_mean/base_mean-1)}; %#ok<AGROW>
    end
end
group_table = cell2table(group_rows,'VariableNames', ...
    {'Condition','Side','N_Rats','N_Cycles','MeanAcrossRats','SDAcrossRats', ...
    'PooledCycleMean','PooledCycleSD','DifferenceFromBaseline', ...
    'PercentChangeOfGroupMeanFromBaseline'});

% Paired changes retain rat identity and do not invert an averaged ratio.
change_rows = cell(0,6);
for r = 1:numel(rat_list)
    for s = 1:numel(sides)
        match = strcmp(rat_table.Rat,rat_list{r}) & strcmp(rat_table.Side,sides{s});
        b = rat_table.MeanSwingStanceRatio(match & strcmp(rat_table.Condition,'Baseline'));
        for c = 2:numel(labels)
            v = rat_table.MeanSwingStanceRatio(match & strcmp(rat_table.Condition,labels{c}));
            change_rows(end+1,:) = {rat_list{r},labels{c},sides{s},b,v-b,100*(v/b-1)}; %#ok<AGROW>
        end
    end
end
change_table = cell2table(change_rows,'VariableNames', ...
    {'Rat','Condition','Side','BaselineSwingStanceRatio', ...
    'DifferenceFromBaseline','PercentChangeFromBaseline'});

if ~isfolder(save_dir), mkdir(save_dir); end
result = struct('rat_table',rat_table,'cycle_table',cycle_table, ...
    'group_table',group_table,'change_table',change_table);
result.definition = 'Swing duration / stance duration = (100-stance%)/stance%, per cycle';
result.aggregation = 'Within-rat cycle mean, then equal-weight mean and sample SD across rats';
result.baseline_filter = 'Inherited: 40<stance%<80, then quartile outlier removal in stance%';
result.other_filter = 'Inherited stance_phase.all; retain finite percentages strictly between 0 and 100';
result.pooled_note = 'PooledCycleMean/SD are descriptive, not independent animal replicates';
result.change_definition = 'Group percent change = 100*(condition group mean/baseline group mean-1)';
result.source_cycle_note = 'SourceCycleIndex indexes supplied all array; baseline array is already filtered';
result.plot_conditions = plot_conditions;
writetable(rat_table,fullfile(save_dir,'swing_stance_by_rat.csv'));
writetable(cycle_table,fullfile(save_dir,'swing_stance_by_cycle.csv'));
writetable(group_table,fullfile(save_dir,'swing_stance_group_summary.csv'));
writetable(change_table,fullfile(save_dir,'swing_stance_baseline_changes.csv'));
save(fullfile(save_dir,'swing_stance_ratio.mat'),'result');

fprintf('\nSwing/stance ratio [-]: mean +/- SD across rats\n');
for k = 1:height(group_table)
    fprintf('%-8s %-5s %.4f +/- %.4f (n=%d rats, %d cycles); baseline change %+.4f (%+.1f%%)\n', ...
        group_table.Condition{k}, group_table.Side{k}, ...
        group_table.MeanAcrossRats(k),group_table.SDAcrossRats(k), ...
        group_table.N_Rats(k),group_table.N_Cycles(k), ...
        group_table.DifferenceFromBaseline(k), ...
        group_table.PercentChangeOfGroupMeanFromBaseline(k));
end
fprintf('Baseline and other conditions retain their existing, different filtering rules.\n');
fprintf('Pooled-cycle summaries are descriptive only. Saved: %s\n',save_dir);

% One figure per anatomical side; same metric and horizontal bar orientation
% as Ref. [9], with each dot representing one rat (not a gait cycle).
bar_colors = [0.7 0.7 0.7;0.6078 0.7882 0.8824;0.2980 0.6000 0.8000; ...
    0.8706 0.7608 0.1490;0.8863 0.5255 0.2353];
dot_colors = [0.3 0.3 0.3;0.2510 0.5255 0.6706;0.0863 0.3804 0.5412; ...
    0.7412 0.5294 0.0235;0.6118 0.3804 0.0667];
for s = 1:numel(sides)
    fig = figure('Color','w','Name',['Swing/stance ratio - ' sides{s}], ...
        'Position',[100 100 900 650]);
    ax = axes(fig,'Position',[0.20 0.17 0.75 0.77]);
    hold(ax,'on');
    plotted_values = [];
    for c = 1:numel(plot_conditions)
        ci = find(strcmp(labels,plot_conditions{c}));
        take = strcmp(rat_table.Condition,plot_conditions{c}) & strcmp(rat_table.Side,sides{s});
        vals = rat_table.MeanSwingStanceRatio(take);
        vals = vals(isfinite(vals));
        if isempty(vals), continue; end
        m = mean(vals); sd = std(vals);
        b = barh(ax,c,m,0.7,'FaceColor',bar_colors(ci,:),'EdgeColor','none');
        b.FaceAlpha = 0.85;
        errorbar(ax,m,c,sd,sd,'horizontal','LineStyle','none', ...
            'Color',dot_colors(ci,:),'LineWidth',2.5,'CapSize',10);
        jitter = linspace(-0.15,0.15,numel(vals))';
        scatter(ax,vals,c+jitter,50,'filled','MarkerFaceColor',dot_colors(ci,:), ...
            'MarkerEdgeColor','none','MarkerFaceAlpha',0.7);
        plotted_values = [plotted_values; vals; m+sd]; %#ok<AGROW>
    end
    set(ax,'YTick',1:numel(plot_conditions),'YTickLabel',plot_conditions, ...
        'YDir','reverse','FontName','Times New Roman','FontSize',25, ...
        'LineWidth',0.8,'TickDir','out');
    xlabel(ax,'Swing/stance ratio (-)','FontName','Times New Roman','FontSize',25);
    ylim(ax,[0.4 numel(plot_conditions)+0.6]);
    if ~isempty(plotted_values), xlim(ax,[0 max(plotted_values)*1.12+eps]); end
    grid(ax,'off'); box(ax,'off');
    tag = strjoin(plot_conditions,'_');
    stem = fullfile(save_dir,['swing_stance_' sides{s} '_' tag]);
    exportgraphics(fig,[stem '.png'],'Resolution',300);
    exportgraphics(fig,[stem '.pdf'],'ContentType','vector');
    savefig(fig,[stem '.fig']);
end
end
