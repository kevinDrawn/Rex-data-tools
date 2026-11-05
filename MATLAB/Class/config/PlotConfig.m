function config = PlotConfig()
%PLOTCONFIG Shared graph appearance and Rex signal colors.
config.Box = 'off';
config.Grid = 'off';
config.FontSize = 20;
config.FontName = 'Times New Roman';
config.LineWidth = 1.5;
config.FigureColor = 'white';
config.FigurePosition = [80 40 1500 1100];
config.Colors.Left = [0.00 0.25 0.85];
config.Colors.Right = [0.85 0.05 0.10];
config.Colors.TA = [0.00 0.60 0.20]; % Green, shared by left/right TA.
config.Colors.GM = [0.55 0.15 0.75]; % Purple, shared by left/right GM.
config.Colors.LeftTA = config.Colors.TA;
config.Colors.LeftGM = config.Colors.GM;
config.Colors.RightTA = config.Colors.TA;
config.Colors.RightGM = config.Colors.GM;
config.ColorOrder = [config.Colors.Left; config.Colors.Right; ...
    config.Colors.TA; config.Colors.GM];
end
