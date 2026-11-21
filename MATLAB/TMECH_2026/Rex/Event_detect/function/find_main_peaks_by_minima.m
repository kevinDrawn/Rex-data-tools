function main = find_main_peaks_by_minima(t, x, t_interval, varargin)
% 보행 신호 x에서, 각 [t0 t1] 구간을 '골(min)'로 분할하고
% 분할된 각 구간(= 한 주기의 절반~한 주기)에서 가장 큰 최대 1개만 반환.
%
% main(k) 필드:
%   idx : 원본 인덱스(1×M_k)
%   t   : 시간(초, 1×M_k)
%   x   : 값(1×M_k)
%
% 옵션 (Name-Value):
%   'SmoothWinSec' (기본 0.05) : sgolay 스무딩 창(초)
%   'VelEps'       (기본 0)    : 속도 0-크로싱 최소 속도(잡음 억제)
%   'MinProm'      (기본 [])   : 선택. 각 세그먼트 내 (피크 - 세그먼트 최소) 최소값
%
opt.SmoothWinSec     = 0.01;
opt.VelEps           = 0;
opt.MinProm          = [];
opt.MinPeakDistSec   = [];        % ★ 추가: 피크 간 최소 간격(초)
opt.MinPeakDistPolicy= 'keepMax'; % ★ 추가: 'keepMax' or 'keepFirst'
opt.BoundaryMarginSec = 0.04;   % 기본 0초

for i = 1:2:numel(varargin)
    opt.(char(varargin{i})) = varargin{i+1};
end

assert(isvector(t)&&isvector(x)&&numel(t)==numel(x), 't/x 길이 불일치');
assert(all(diff(t)>0), 't는 단조 증가해야 함');
assert(size(t_interval,2)==2, 't_interval은 [N×2]');

% 1) 골/피크 후보 찾기
evMin = find_events_velzero_in_intervals( ...
    t, x, t_interval, ...
    'SmoothWinSec', opt.SmoothWinSec, ...
    'Type','min', 'VelEps', opt.VelEps);

evMax = find_events_velzero_in_intervals( ...
    t, x, t_interval, ...
    'SmoothWinSec', opt.SmoothWinSec, ...
    'Type','max', 'VelEps', opt.VelEps);

N = size(t_interval,1);
main = repmat(struct('idx',[],'t',[],'x',[]), N,1);

for k = 1:N

    t0 = t_interval(k,1);
    t1 = t_interval(k,2);

    % 전체 t_interval에서 기존 방식 그대로 검출
    mask = (t > t0) & (t < t1);

    if ~any(mask)
        main(k).idx = [];
        main(k).t   = [];
        main(k).x   = [];
        continue;
    end

    idxStart = find(mask,1,'first');
    idxEnd   = find(mask,1,'last');

    % 구간 내부 minima
    idxMin = evMin(k).idx_min(:)';

    if ~isempty(idxMin)
        tMin   = t(idxMin);
        idxMin = idxMin((tMin > t0) & (tMin < t1));
        idxMin = sort(idxMin);
    end

    bounds = [idxStart, idxMin, idxEnd];

    if numel(bounds) < 2
        continue;
    end

    keep_idx = [];
    keep_t   = [];
    keep_x   = [];

    for j = 1:numel(bounds)-1

        seg = bounds(j):bounds(j+1);

        cand = evMax(k).idx_max;
        cand = cand(cand >= seg(1) & cand <= seg(end));

        if ~isempty(cand)
            [~,mi] = max(x(cand));
            idxPick = cand(mi);
        else
            [~,mi] = max(x(seg));
            idxPick = seg(mi);
        end

        % prominence
        if ~isempty(opt.MinProm)
            prom = x(idxPick) - min(x(seg));
            if prom < opt.MinProm
                continue;
            end
        end

        %% ★ Boundary exclusion
        % 검출은 했지만 원래 t_interval 경계 근처면 저장하지 않음
        tPick = t(idxPick);

        if (tPick - t0 < opt.BoundaryMarginSec) || ...
           (t1 - tPick < opt.BoundaryMarginSec)
            continue;
        end

        %% 저장
        keep_idx(end+1) = idxPick;
        keep_t(end+1)   = tPick;
        keep_x(end+1)   = x(idxPick);
    end

    main(k).idx = keep_idx;
    main(k).t   = keep_t;
    main(k).x   = keep_x;

    % 최소 간격 필터
    if ~isempty(opt.MinPeakDistSec) && numel(main(k).t) > 1
        [main(k).idx, main(k).t, main(k).x] = ...
            prune_peaks_by_distance( ...
                main(k).idx, main(k).t, main(k).x, ...
                opt.MinPeakDistSec, opt.MinPeakDistPolicy);
    end
end


end

function [idx2,t2,x2] = prune_peaks_by_distance(idx,t,x,minDistSec,policy)
% 인접 선택 피크 간격이 minDistSec 미만이면 제거
% policy:
%   'keepMax'   : 붙은 군집에서 가장 큰 피크만 남김 (권장)
%   'keepFirst' : 먼저 나온 피크만 남김

if isempty(idx)
    idx2=idx; t2=t; x2=x; return;
end
% 시간순 정렬
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

    otherwise % 'keepmax' (반복적으로 가까운 쌍을 줄이며 큰 것 유지)
        while true
            dt = diff(t);
            k  = find(dt < minDistSec, 1, 'first');
            if isempty(k), break; end
            if x(k) >= x(k+1)
                % 뒤의 것을 버림
                t(k+1) = []; x(k+1) = []; idx(k+1) = [];
            else
                % 앞의 것을 버림
                t(k)   = []; x(k)   = []; idx(k)   = [];
            end
        end
        idx2 = idx; t2 = t; x2 = x;
end
end