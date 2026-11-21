function ax = plot_intervals(t, left_f, right_f, t_interval, varargin)
% plot_intervals  각 시간 구간(t_interval)을 정사각형(n×n) 그리드로 플롯
%
% ax = plot_intervals(t, left_f, right_f, t_interval, Name,Value,...)
%
% 입력:
%   t           : 시간 벡터 (등간격 권장)
%   left_f      : 왼발 각도 벡터
%   right_f     : 오른발 각도 벡터
%   t_interval  : [N x 2] 행렬, 각 행은 [t_start t_end]
%
% Name-Value 옵션:
%   'LineWidth' : 선 두께 (기본 1.5)
%   'LinkY'     : 모든 서브플롯 y축 연결 (기본 true)
%   'YLim'      : [ymin ymax] 지정 (기본 [])
%   'XLabel'    : x축 라벨 (기본 'time (s)')
%   'YLabel'    : y축 라벨 (기본 'Ankle angle (deg)')
%   'Legend'    : 범례 셀 {'left','right'} (기본 표시)
%   'UseTiled'  : tiledlayout 사용 (기본 true, false면 subplot 사용)
%
% 출력:
%   ax          : axes 핸들 배열 (길이 N)

% ── 기본 옵션
opt.LineWidth = 1.5;
opt.LinkY     = true;
opt.YLim      = [];
opt.XLabel    = 'time (s)';
opt.YLabel    = 'Ankle angle (deg)';
opt.Legend    = {'',''};
opt.UseTiled  = true;

% ── Name-Value 파싱
if mod(numel(varargin),2)~=0
    error('Name-Value 인자가 짝이 맞지 않습니다.');
end
for i = 1:2:numel(varargin)
    name = varargin{i}; value = varargin{i+1};
    if ~ischar(name) && ~isstring(name)
        error('옵션 이름은 문자형이어야 합니다.');
    end
    name = char(name);
    if isfield(opt, name)
        opt.(name) = value;
    else
        error('알 수 없는 옵션: %s', name);
    end
end

% ── 입력 검증
assert(isvector(t) && isvector(left_f) && isvector(right_f), ...
    't/left_f/right_f는 벡터여야 합니다.');
assert(numel(t)==numel(left_f) && numel(t)==numel(right_f), ...
    't, left_f, right_f의 길이가 다릅니다.');
assert(size(t_interval,2)==2, 't_interval은 N×2 행렬이어야 합니다.');
assert(all(t_interval(:,2) > t_interval(:,1)), ...
    '각 구간의 [끝]은 [시작]보다 커야 합니다.');
assert(all(diff(t) > 0), 't는 단조 증가(엄격히 증가)해야 합니다.');

% 샘플 간격 및 여유폭
Ts    = median(diff(t));
eps_t = Ts/2;

N = size(t_interval,1);
segT = cell(N,1); segL = cell(N,1); segR = cell(N,1);

% ── 구간별 데이터 추출
for k = 1:N
    t0 = t_interval(k,1);  t1 = t_interval(k,2);
    mask = (t >= t0 - eps_t) & (t <= t1 + eps_t);
    if ~any(mask)
        error('구간 %d (%.3f–%.3f s)에 해당하는 샘플이 없습니다.', ...
              k, t0, t1);
    end
    segT{k} = t(mask);
    segL{k} = left_f(mask);
    segR{k} = right_f(mask);
end

% ── 그리드 크기 계산: 정사각형에 가깝게 (예: 8개 → 3x3)
nRows = ceil(sqrt(N));
nCols = ceil(N / nRows);  % 거의 nRows==nCols가 됨

% ── 그림 및 서브플롯 구성
figure('Color','w');

ax = gobjects(N,1);
if opt.UseTiled
    tl = tiledlayout(nRows, nCols, 'Padding','compact', 'TileSpacing','compact'); %#ok<NASGU>
    for k = 1:N
        ax(k) = nexttile;  % 빈 타일은 자동으로 남음
        plot(segT{k}, segL{k}, 'LineWidth', opt.LineWidth, 'color', 'b'); hold on;
        plot(segT{k}, segR{k}, 'LineWidth', opt.LineWidth, 'color', 'r');
        grid off; box off;
        xlim(t_interval(k,:));
        if ~isempty(opt.YLim), ylim(opt.YLim); end
        if k==1 && ~isempty(opt.Legend), legend(opt.Legend, 'Location','best'); end
        if k > N-nCols, xlabel(opt.XLabel); end   % 마지막 행에만 x라벨
        if mod(k-1,nCols)==0, ylabel(opt.YLabel); end  % 첫 열에만 y라벨
        title(sprintf('%.3f–%.3f s', t_interval(k,1), t_interval(k,2)));
    end
else
    for k = 1:N
        ax(k) = subplot(nRows, nCols, k); %#ok<LAXES>
        plot(segT{k}, segL{k}, 'LineWidth', opt.LineWidth); hold on;
        plot(segT{k}, segR{k}, 'LineWidth', opt.LineWidth);
        grid off; box off;
        xlim(t_interval(k,:));
        if ~isempty(opt.YLim), ylim(opt.YLim); end
        if k==1 && ~isempty(opt.Legend), legend(opt.Legend, 'Location','best'); end
        if k > N-nCols, xlabel(opt.XLabel); end
        if mod(k-1,nCols)==0, ylabel(opt.YLabel); end
        title(sprintf('%.3f–%.3f s', t_interval(k,1), t_interval(k,2)));
    end
end

% ── y축 링크 (옵션)
if opt.LinkY && isempty(opt.YLim)
    linkaxes(ax, 'y');
end
end