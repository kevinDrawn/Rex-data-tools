function ax_all = plot_intervals_grid(t, left_f, right_f, t_interval, varargin)
% 여러 구간을 r×c 그리드로 묶어 여러 Figure에 나눠 그림
% 옵션: 'Rows', 'Cols', 'PerFig', 'LineWidth', 'LinkY', 'XLabel', 'YLabel', 'Legend'
opt.Rows= []; opt.Cols= []; opt.PerFig=[]; opt.LineWidth=1.5;
opt.LinkY=true; opt.XLabel='time (s)'; opt.YLabel='Ankle angle (deg)';
opt.Legend={'left angle','right angle'};
for i=1:2:numel(varargin), opt.(char(varargin{i}))=varargin{i+1}; end

N = size(t_interval,1);
if isempty(opt.PerFig), opt.PerFig = 6; end          % 페이지당 서브플롯 수
if isempty(opt.Rows) || isempty(opt.Cols)
    r = floor(sqrt(opt.PerFig)); c = ceil(opt.PerFig/r);
else
    r = opt.Rows; c = opt.Cols; opt.PerFig = r*c;
end

pages   = ceil(N/opt.PerFig);
ax_all  = gobjects(0);

for p = 1:pages
    idx = (1:opt.PerFig) + (p-1)*opt.PerFig;
    idx = idx(idx<=N);
    figure('Color','w'); tiledlayout(r,c,'Padding','compact','TileSpacing','compact');
    ax = gobjects(numel(idx),1);

    for k = 1:numel(idx)
        ii = idx(k);
        ax(k) = nexttile;
        mask  = (t>=t_interval(ii,1)) & (t<=t_interval(ii,2));
        plot(t(mask), left_f(mask),  'LineWidth',opt.LineWidth); hold on;
        plot(t(mask), right_f(mask), 'LineWidth',opt.LineWidth);
        grid on; box on; xlim(t_interval(ii,:));
        title(sprintf('%.3f–%.3f s', t_interval(ii,1), t_interval(ii,2)));
        if k>numel(idx)-c, xlabel(opt.XLabel); end
        if mod(k-1,c)==0,  ylabel(opt.YLabel); end
    end
    % if ~isempty(opt.Legend), legend(ax(1), opt.Legend, 'Location','best'); end
    if opt.LinkY, linkaxes(ax,'y'); end
    ax_all = [ax_all; ax]; %#ok<AGROW>
end
end