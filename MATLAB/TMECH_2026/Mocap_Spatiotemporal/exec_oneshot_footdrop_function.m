%% One-shot foot-drop metrics: existing processed MATs -> rat values and figure
% Set MATLAB Current Folder to this Mocap_Spatiotemporal directory.
% Shared settings: function/footdrop_config.m. Original CSVs are not processed.
project_dir = pwd;
if ~isfile(fullfile(project_dir, 'function', 'footdrop_config.m'))
    project_dir = fileparts(mfilename('fullpath'));
end
assert(isfile(fullfile(project_dir, 'function', 'footdrop_config.m')), ...
    'Set Current Folder to TMECH_2026/Mocap_Spatiotemporal.');
addpath(fullfile(project_dir, 'function'));

cfg = footdrop_config(project_dir);
% Explicit optional override for batch execution; never uses leftover cfg values.
if exist('FOOTDROP_CONFIG', 'var'), cfg = FOOTDROP_CONFIG; end
addpath(cfg.ClassDirectory);

%% Validate shared sources before producing any outputs
assert(isfolder(cfg.PawRootDirectory), 'Missing paw directory: %s', cfg.PawRootDirectory);
assert(isfile(cfg.MetaLoggingPath), 'Missing exp_data MAT: %s', cfg.MetaLoggingPath);
assert(isfile(cfg.DraggingWorkbook), 'Missing dragging workbook: %s', cfg.DraggingWorkbook);
if strlength(cfg.BaselineMetaPath) > 0
    assert(isfile(cfg.BaselineMetaPath), 'Missing baseline MAT: %s', cfg.BaselineMetaPath);
end
assert(all(ismember(["Baseline","IE","IR","LE","LR"], string(cfg.Conditions))), ...
    'The combined figure requires Baseline/IE/IR/LE/LR.');
assert(ismember(string(cfg.PawMetric), ["MeanTrajectoryPeakHeight","MeanPeakPawHeight"]), ...
    'Unsupported PawMetric.');
output_dir = cfg.OutputDirectory;
paw_path = fullfile(output_dir, 'metrics', 'paw_clearance_plot_data.mat');
df_path = fullfile(output_dir, 'metrics', 'peak_swing_dorsiflexion_plot_data.mat');
drag_path = fullfile(output_dir, 'metrics', 'dragging_incidence.mat');

%% 1. Paw clearance: complete cycles, original time_range.txt selections
pawClearanceMetrics = GaitMetricCollector.collectPaw( ...
    cfg.PawRootDirectory, cfg.Conditions, cfg.PhaseSamples);
pawClearanceMetrics.PrimaryPlotMetric = string(cfg.PawMetric);
GaitMetricCollector.saveMetric(pawClearanceMetrics, paw_path);
writetable(pawClearanceMetrics.(cfg.PawMetric).RatMeanTable, ...
    fullfile(output_dir, 'paw_clearance_by_rat.csv'));
writetable(pawClearanceMetrics.(cfg.PawMetric).GroupSummary, ...
    fullfile(output_dir, 'paw_clearance_group.csv'));
writetable(pawClearanceMetrics.PerCycle, fullfile(output_dir, 'paw_clearance_all_cycles.csv'));

%% 2. Swing dorsiflexion: original Hall angles and stored aligned IC/TO events
swingDorsiflexionMetrics = GaitMetricCollector.collectDorsiflexion( ...
    cfg.MetaLoggingPath, cfg.BaselineMetaPath, cfg.AngleSide, ...
    pawClearanceMetrics.RatIDs, cfg.Conditions);
GaitMetricCollector.saveMetric(swingDorsiflexionMetrics, df_path);
writetable(swingDorsiflexionMetrics.RatMeanTable, fullfile(output_dir, 'dorsiflexion_by_rat.csv'));
writetable(swingDorsiflexionMetrics.PerSwing, fullfile(output_dir, 'dorsiflexion_all_swings.csv'));

%% 3. Dragging: scored workbook counts / original full-video detected swings
% Includes observed trailing swings; does NOT inherit paw time_range filtering.
draggingIncidence = GaitMetricCollector.collectDraggingWorkbook( ...
    cfg.DraggingWorkbook, paw_path, ["LE", "LR"]);
GaitMetricCollector.saveMetric(draggingIncidence, drag_path);
writetable(draggingIncidence.PerAnimalSummary, fullfile(output_dir, 'dragging_by_rat.csv'));
writetable(draggingIncidence.FileSummary, fullfile(output_dir, 'dragging_source_counts.csv'));

%% Align identities, save exact source paths, and generate three separate figures
spatiotemporalData = SpatiotemporalIndexAssembler.collect(cfg.RootDirectory, ...
    'PawMetric', cfg.PawMetric, 'PawFile', paw_path, ...
    'DorsiflexionFile', df_path, 'DraggingFile', drag_path);
spatiotemporalData.Configuration = cfg;
GaitMetricCollector.saveMetric(spatiotemporalData, fullfile(output_dir, 'spatiotemporal_indices.mat'));
writetable(spatiotemporalData.GroupSummary, fullfile(output_dir, 'spatiotemporal_group_summary.csv'));
writetable(spatiotemporalData.IndividualValues, fullfile(output_dir, 'spatiotemporal_individual_values.csv'));
writetable(spatiotemporalData.InputFiles, fullfile(output_dir, 'spatiotemporal_source_files.csv'));
disp(spatiotemporalData.GroupSummary);

if cfg.MakeFigures
    metrics = {spatiotemporalData.Metrics.PawClearance, ...
        spatiotemporalData.Metrics.PeakSwingDorsiflexion, ...
        spatiotemporalData.Metrics.DraggingIncidence};
    if strcmp(cfg.PawMetric, 'MeanTrajectoryPeakHeight')
        paw_label = 'Peak height of mean toe trajectory (mm)';
    else
        paw_label = 'Mean peak paw clearance (mm)';
    end
    labels = {paw_label, 'Peak swing dorsiflexion angle (deg)', 'Dragging incidence (%)'};
    figure_names = {'paw_clearance', 'swing_dorsiflexion', 'dragging_incidence'};
    metricFigures = gobjects(numel(metrics), 1);
    metricAxes = gobjects(numel(metrics), 1);
    for metric_index = 1:numel(metrics)
        [metricFigures(metric_index), metricAxes(metric_index)] = ...
            plot_footdrop_metric(metrics{metric_index}, labels{metric_index});
        savefig(metricFigures(metric_index), ...
            fullfile(output_dir, [figure_names{metric_index} '.fig']));
        exportgraphics(metricFigures(metric_index), ...
            fullfile(output_dir, [figure_names{metric_index} '.png']), 'Resolution', 300);
    end
end
fprintf('\nFoot-drop metrics saved to %s\n', output_dir);
fprintf('Run exec_oneshot_footdrop_statistics for statistics on these saved rat values.\n');
