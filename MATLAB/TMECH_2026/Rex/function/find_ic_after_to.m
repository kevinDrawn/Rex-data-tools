function [idx_ic, t_ic, x_ic] = find_ic_after_to(t, x, idx_to, opt)

idx_ic = [];
t_ic   = [];
x_ic   = [];

if isempty(idx_to), return; end

for i = 1:numel(idx_to)

    i_to = idx_to(i);
    t_to = t(i_to);
    x_to = x(i_to);

    % 탐색 구간 설정
    t_end = t_to + opt.IC_SearchWinSec;
    idx_win = find(t > t_to & t < t_end);

    if numel(idx_win) < 5
        continue;
    end

    % local peak 찾기
    x_seg = x(idx_win);
    t_seg = t(idx_win);

    % peak 후보 (findpeaks 사용 추천)
    [pks, locs] = findpeaks(x_seg);

    if isempty(pks)
        continue;
    end

    % TO 대비 충분히 낮은 peak만 선택
    valid = pks < (x_to - opt.IC_AngleDiff);

    if any(valid)
        % 가장 큰 IC peak 선택
        [~, mi] = max(pks .* valid);
        idx_pick = idx_win(locs(mi));

        idx_ic(end+1) = idx_pick;
        t_ic(end+1)   = t(idx_pick);
        x_ic(end+1)   = x(idx_pick);
    end
end
end