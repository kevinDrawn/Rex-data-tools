function main = find_main_peaks_by_minima_IC_TO(t, x, t_interval, varargin)

% --- cfg 분리
cfg = varargin{end};
varargin = varargin(1:end-1);

% --- 옵션 기본값
opt.SmoothWinSec     = 0.05;
opt.VelEps           = 0;
opt.MinProm          = [];
opt.MinPeakDistSec   = [];
opt.MinPeakDistPolicy= 'keepMax';
opt.BoundaryMarginSec = 0;

% --- 옵션 파싱
for i = 1:2:numel(varargin)
    opt.(char(varargin{i})) = varargin{i+1};
end

% --- IC 옵션
opt.IC_AngleDiff     = cfg.IC_AngleDiff;
opt.IC_SearchWinSec  = cfg.SearchWinSec;

assert(isvector(t)&&isvector(x)&&numel(t)==numel(x), 't/x 길이 불일치');
assert(all(diff(t)>0), 't는 단조 증가해야 함');
assert(size(t_interval,2)==2, 't_interval은 [N×2]');

%% 1) 이벤트 후보
evMin = find_events_velzero_in_intervals( ...
    t, x, t_interval, ...
    'SmoothWinSec', opt.SmoothWinSec, ...
    'Type','min', 'VelEps', opt.VelEps);

evMax = find_events_velzero_in_intervals( ...
    t, x, t_interval, ...
    'SmoothWinSec', opt.SmoothWinSec, ...
    'Type','max', 'VelEps', opt.VelEps);

N = size(t_interval,1);

% --- 구조 확장 ---
main = repmat(struct( ...
    'idx',[],'to',[],'x',[], ...      % TO
    'idx_ic',[],'t_ic',[],'x_ic',[] ... % IC
    ), N,1);

%% ===============================
% Main Loop
%% ===============================
for k = 1:N

    t0 = t_interval(k,1);  
    t1 = t_interval(k,2);

    margin = max(0, opt.BoundaryMarginSec);
    t0m = t0 + margin;  
    t1m = t1 - margin;

    if t1m <= t0m, continue; end

    mask = (t > t0m) & (t < t1m);
    if ~any(mask), continue; end

    idxStart = find(mask,1,'first');
    idxEnd   = find(mask,1,'last');

    %% --- minima ---
    idxMin = evMin(k).idx_min(:)';
    if ~isempty(idxMin)
        tMin   = t(idxMin);
        idxMin = idxMin((tMin > t0m) & (tMin < t1m));
        idxMin = sort(idxMin);
    end

    bounds = [idxStart, idxMin, idxEnd];
    if numel(bounds) < 2, continue; end

    keep_idx = [];
    keep_t   = [];
    keep_x   = [];

    %% --- TO 검출 ---
    for j = 1:numel(bounds)-1

        seg = bounds(j):bounds(j+1);

        cand = evMax(k).idx_max;
        cand = cand(cand>=seg(1) & cand<=seg(end));

        if ~isempty(cand)
            [~,mi] = max(x(cand)); 
            idxPick = cand(mi);
        else
            [~,mi] = max(x(seg));  
            idxPick = seg(mi);
        end

        if ~isempty(opt.MinProm)
            prom = x(idxPick) - min(x(seg));
            if prom < opt.MinProm, continue; end
        end

        keep_idx(end+1) = idxPick;
        keep_t(end+1)   = t(idxPick);
        keep_x(end+1)   = x(idxPick);
    end

    %% --- TO 저장 ---
    main(k).idx_TO = keep_idx;
    main(k).t_TO   = keep_t;
    main(k).x_TO   = keep_x;

    %% --- Peak 간 거리 필터 ---
    if ~isempty(opt.MinPeakDistSec) && numel(main(k).t_TO) > 1
        [main(k).idx_TO, main(k).t_TO, main(k).x_TO] = prune_peaks_by_distance( ...
            main(k).idx_TO, main(k).t_TO, main(k).x_TO, ...
            opt.MinPeakDistSec, opt.MinPeakDistPolicy);
    end

    %% ============================
    % 🔥 IC 검출 (TO 이후)
    %% ============================
    [idx_ic, t_ic, x_ic] = find_ic_after_to(t, x, main(k).idx_TO, opt);

    main(k).idx_IC = idx_ic;
    main(k).t_IC   = t_ic;
    main(k).x_IC   = x_ic;

end
end

function [idx2,t2,x2] = prune_peaks_by_distance(idx,t,x,minDistSec,policy)

if isempty(idx)
    idx2=idx; t2=t; x2=x; return;
end

[t, order] = sort(t(:));
idx = idx(order);
x   = x(order);

switch lower(policy)
    case 'keepfirst'
        keep   = true(size(t));
        last_t = -inf;
        for i = 1:numel(t)
            if t(i) - last_t < minDistSec
                keep(i) = false;
            else
                last_t = t(i);
            end
        end
        idx2 = idx(keep); t2 = t(keep); x2 = x(keep);

    otherwise % keepmax
        while true
            dt = diff(t);
            k  = find(dt < minDistSec, 1);
            if isempty(k), break; end

            if x(k) >= x(k+1)
                t(k+1)=[]; x(k+1)=[]; idx(k+1)=[];
            else
                t(k)=[]; x(k)=[]; idx(k)=[];
            end
        end
        idx2 = idx; t2 = t; x2 = x;
end
end
