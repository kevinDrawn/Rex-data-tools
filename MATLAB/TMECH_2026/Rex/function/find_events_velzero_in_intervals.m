function ev = find_events_velzero_in_intervals(t, x, t_interval, varargin)
% 속도 0-크로싱으로 보행 이벤트 검출 (구간별)
% ev(k).idx_max / t_max / x_max  : 최대(피크)
% ev(k).idx_min / t_min / x_min  : 최소(골)
%
% 옵션:
%   'SmoothWinSec' (기본 0.03): sgolay 스무딩 창(초)
%   'Type'         (기본 'both'): 'max'|'min'|'both'
%   'VelEps'       (기본 0): 0-크로싱 판정 최소 속도(잡음 억제용)

opt.SmoothWinSec = 0.03;
opt.Type         = 'both';
opt.VelEps       = 0;

for i=1:2:numel(varargin)
    opt.(char(varargin{i})) = varargin{i+1};
end

assert(isvector(t)&&isvector(x)&&numel(t)==numel(x), 't/x 길이 확인');
assert(all(diff(t)>0), 't는 단조 증가해야 함');
assert(size(t_interval,2)==2, 't_interval은 [N x 2]');

Ts = median(diff(t));

% ----- 부드럽게: Savitzky-Golay
win = max(3, 2*floor(opt.SmoothWinSec/Ts)+1); % 홀수
x_s = sgolayfilt(x, 3, win);

% 1차/2차 미분
v = gradient(x_s, Ts);
a = gradient(v, Ts);

N = size(t_interval,1);
ev = repmat(struct('idx_max',[],'t_max',[],'x_max',[], ...
                   'idx_min',[],'t_min',[],'x_min',[]), N,1);

for k=1:N
    t0=t_interval(k,1); t1=t_interval(k,2);
    mask = (t>=t0) & (t<=t1);
    if ~any(mask), continue; end
    idx_all = find(mask);

    v_seg = v(mask); a_seg = a(mask); t_seg = t(mask); x_seg = x(mask);

    % 최대: v가 +에서 0/−로 하강 (다운크로싱), 그리고 a<0 (오목)
    down = find(v_seg(1:end-1) > 0 & v_seg(2:end) <= 0);
    if opt.VelEps>0
        keep = abs(v_seg(down))>opt.VelEps | abs(v_seg(down+1))>opt.VelEps;
        down = down(keep);
    end
    cand_max = down + 1;
    cand_max = cand_max(a_seg(cand_max) < 0);

    % 최소: v가 −에서 0/+로 상승 (업크로싱), 그리고 a>0 (볼록)
    up = find(v_seg(1:end-1) < 0 & v_seg(2:end) >= 0);
    if opt.VelEps>0
        keep = abs(v_seg(up))>opt.VelEps | abs(v_seg(up+1))>opt.VelEps;
        up = up(keep);
    end
    cand_min = up + 1;
    cand_min = cand_min(a_seg(cand_min) > 0);

    if any(strcmp(opt.Type, {'both','max'}))
        ev(k).idx_max = idx_all(cand_max);
        ev(k).t_max   = t_seg(cand_max);
        ev(k).x_max   = x_seg(cand_max);
    end
    if any(strcmp(opt.Type, {'both','min'}))
        ev(k).idx_min = idx_all(cand_min);
        ev(k).t_min   = t_seg(cand_min);
        ev(k).x_min   = x_seg(cand_min);
    end
end
end
