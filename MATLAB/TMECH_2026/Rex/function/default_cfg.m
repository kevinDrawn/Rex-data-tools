function cfg = default_cfg(root_dir)

% ===============================
% 🔹 Font
% ===============================
cfg.font.name   = 'Times New Roman';
cfg.font.size   = 8;
cfg.font.size_col_1   = 25;
cfg.font.size_col_2   = 12;

cfg.font.label  = 9;
cfg.font.title  = 10;

% ===============================
% 🔹 Plot style
% ===============================
cfg.plot.lw_main = 2.5;
cfg.plot.lw_axis = 0.8;
cfg.plot.lw_zero = 0.8;
cfg.plot.alpha   = 0.6;
cfg.plot.alpha_shade = 0.2;
cfg.plot.scatter.size = 10;
cfg.plot.scatter_line_width = 3;
cfg.plot.jitter = 0.15;

% ===============================
% 🔹 Colors
% ===============================
cfg.color.left  = [0 0 1];
cfg.color.right = [1 0 0];

% ===============================
% 🔹 Axis limits
% ===============================
cfg.axis.angle   = [30 140];
cfg.axis.torque  = [-1.5 1.5];
cfg.axis.power   = [-0.08 0.08];

cfg.axis.torque_support = [-8 8];
cfg.axis.power_support  = [-0.18 0.18];

cfg.axis.cycloid_x = [30 140];
cfg.axis.stance_ratio = [0 1];

cfg.axis.x_margin_ratio = 0.1;
cfg.axis.y_margin_ratio = 0.1;

% ===============================
% 🔹 Data processing
% ===============================
cfg.data.densify_factor = 3;
cfg.data.cycloid_scale  = 60;

% ===============================
% 🔹 General
% ===============================
cfg.side = 'both';
cfg.root_dir = root_dir;

s = dbstack;
fprintf('[%s] loading config clear \r\n', s(1).name);
 
end