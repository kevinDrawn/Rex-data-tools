function save_TMECH_figure(fig, save_dir, fig_name, cfg)

% ===============================
% 1. Figure size (1-column)
% ===============================
set(fig, 'Units','centimeters');
set(fig, 'Position',[0 0 8.8 6]);

% ===============================
% 2. Font 통일
% ===============================
set(findall(fig,'-property','FontName'), 'FontName', cfg.font.name);
set(findall(fig,'-property','FontSize'), 'FontSize', cfg.font.size_col_1);

% ===============================
% 3. 경로
% ===============================
fig_path = fullfile(save_dir, [fig_name '.fig']);
png_path = fullfile(save_dir, [fig_name '.png']);
pdf_path = fullfile(save_dir, [fig_name '.pdf']);

% ===============================
% 4. 저장
% ===============================
savefig(fig, fig_path);

exportgraphics(fig, png_path, 'Resolution',300);
exportgraphics(fig, pdf_path, 'ContentType','vector');

fprintf('[Saved] %s\n', fig_path);

end