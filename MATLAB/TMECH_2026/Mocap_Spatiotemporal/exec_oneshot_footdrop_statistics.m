%% Statistics for the exact rat-level values saved by the one-shot analysis
project_dir = pwd;
if ~isfile(fullfile(project_dir, 'function', 'footdrop_config.m'))
    project_dir = fileparts(mfilename('fullpath'));
end
assert(isfile(fullfile(project_dir, 'function', 'footdrop_config.m')), ...
    'Set Current Folder to TMECH_2026/Mocap_Spatiotemporal.');
addpath(fullfile(project_dir, 'function'));
cfg = footdrop_config(project_dir);
if exist('FOOTDROP_CONFIG', 'var'), cfg = FOOTDROP_CONFIG; end
addpath(cfg.ClassDirectory);
input_path = fullfile(cfg.OutputDirectory, 'spatiotemporal_indices.mat');
assert(isfile(input_path), 'Run exec_oneshot_footdrop_function first: %s', input_path);
payload = load(input_path, 'data');
combined = payload.data;
% Configuration changes must not relabel an existing figure's endpoint.
assert(strcmp(string(combined.PawSourceMetric), string(cfg.PawMetric)), ...
    'PawMetric differs from the saved analysis. Rerun exec_oneshot_footdrop_function.');
assert(exist('ttest', 'file') ~= 0 && exist('friedman', 'file') ~= 0, ...
    'Statistics and Machine Learning Toolbox is required.');

%% Paw: existing repeated-condition statistics, using the plotted paw endpoint
% Preserve the earlier IE/LE/LR comparison set and tests. Use rat values from
% this figure, not the legacy open-swing per-cycle collector's different metric.
paw = combined.Metrics.PawClearance;
conditions = string(cfg.PawStatisticsConditions(:));
assert(numel(unique(conditions)) == numel(conditions), 'Repeated paw statistical conditions.');
[found, columns] = ismember(conditions, string(paw.ConditionNames));
assert(all(found), 'A requested paw statistical condition is absent.');
collection.RatIDs = paw.RatIDs;
collection.ConditionNames = conditions;
for c = 1:numel(conditions)
    collection.Conditions.(conditions(c)).RatMeans_mm = paw.RatMeans(:, columns(c));
end
collector = PawClearanceCollector();
pawStatistics = collector.analyzeStatistics(collection);
pawStatistics.SourceMetric = combined.PawSourceMetric;
pawStatistics.Definition = paw.Definition;
pawStatistics.InputCombinedMAT = string(input_path);

%% Dorsiflexion and dragging: preserve existing LE/LR paired analysis
assistanceStatistics = SpatiotemporalIndexAssembler.analyzeAssistance(combined);
footdropStatistics.SchemaVersion = 1;
footdropStatistics.InputCombinedMAT = string(input_path);
footdropStatistics.InputFiles = combined.InputFiles;
footdropStatistics.Configuration = cfg;
footdropStatistics.Paw = pawStatistics;
footdropStatistics.Assistance = assistanceStatistics;
footdropStatistics.Multiplicity = ...
    "Separate existing families: paw condition pairs; two LE/LR assistance endpoints. No correction across both families.";

%% One statistics bundle plus tables for review
statistics_dir = fullfile(cfg.OutputDirectory, 'statistics');
GaitMetricCollector.saveMetric(footdropStatistics, fullfile(statistics_dir, 'footdrop_statistics.mat'));
GaitMetricCollector.saveMetric(pawStatistics, fullfile(statistics_dir, 'paw_clearance_statistics.mat'));
GaitMetricCollector.saveMetric(assistanceStatistics, fullfile(statistics_dir, 'assistance_statistics.mat'));
writetable(pawStatistics.Pairwise, fullfile(statistics_dir, 'paw_clearance_pairwise.csv'));
pawOmnibus = table(numel(pawStatistics.RatIDs), ...
    pawStatistics.FriedmanAsymptoticP, pawStatistics.FriedmanExactP, ...
    pawStatistics.FriedmanPermutationCount, 'VariableNames', ...
    {'CompleteRats','FriedmanAsymptoticP','FriedmanExactP','PermutationCount'});
writetable(pawOmnibus, fullfile(statistics_dir, 'paw_clearance_omnibus.csv'));
writetable(assistanceStatistics.Summary, fullfile(statistics_dir, 'assistance_statistics.csv'));
writetable(assistanceStatistics.IndividualDifferences, fullfile(statistics_dir, 'assistance_paired_differences.csv'));
writetable(combined.IndividualValues, fullfile(statistics_dir, 'analyzed_rat_values.csv'));
disp(assistanceStatistics.Summary);
fprintf('\nStatistics saved to %s\n', statistics_dir);
fprintf('Rat is the experimental unit. Missing values are not replaced with zero.\n');
fprintf('Paw uses complete rats across the requested conditions; LE/LR uses endpoint-specific paired rats.\n');
