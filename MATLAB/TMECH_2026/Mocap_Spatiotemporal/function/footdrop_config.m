function cfg = footdrop_config(projectDirectory)
%FOOTDROP_CONFIG Shared inputs for the foot-drop figure and its statistics.
% Edit paths here once. Both exec_oneshot entry points use this configuration.
if nargin == 0
    projectDirectory = fileparts(fileparts(mfilename('fullpath')));
end
cfg.ProjectDirectory = string(projectDirectory);
candidate = char(projectDirectory);
while ~isfolder(fullfile(candidate, 'Class'))
    parent = fileparts(candidate);
    if strcmp(parent, candidate) || isempty(parent)
        error('Footdrop:MissingClass', 'Cannot find MATLAB/Class above %s.', projectDirectory);
    end
    candidate = parent;
end
cfg.ClassDirectory = string(fullfile(candidate, 'Class'));

cfg.RootDirectory = "D:\park\01. STEAM\[Paper] Paperwork\2026_TMECH\TMECH Review\Spatiotemporal_Index";
cfg.MetaLoggingPath = "D:\park\01. STEAM\[Paper] Paperwork\2026_TMECH\TMECH Review\Data\TMECH_meta_data\exp_data.mat";
cfg.BaselineMetaPath = ""; % Optional exp_data MAT containing Baseline Hall records.
cfg.PawRootDirectory = fullfile(cfg.RootDirectory, 'Paw_clearance');
cfg.DraggingWorkbook = fullfile(cfg.RootDirectory, 'Dragging_incidence', '261116_toe dragging incidence.xlsx');
% Keep new results separate from the earlier metric-specific exports.
cfg.OutputDirectory = fullfile(cfg.RootDirectory, '_combined', 'footdrop_function');
cfg.Conditions = ["Baseline", "IE", "IR", "LE", "LR"];
cfg.AngleSide = 'left';
cfg.PhaseSamples = 201;
cfg.PawMetric = 'MeanTrajectoryPeakHeight'; % Alternative: MeanPeakPawHeight.
cfg.PawStatisticsConditions = ["IE", "LE", "LR"];
cfg.MakeFigures = true;
end
