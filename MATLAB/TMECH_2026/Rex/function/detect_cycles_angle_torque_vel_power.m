function [angle_mat, varargout] = build_norm_mats_multi(intervals, t_u, angle_u, signals_u, phase_grid)
% signals_u: cell array {vel, torque, power, ...}

    nI = size(intervals,1);
    nSig = numel(signals_u);

    angle_mat = nan(nI, numel(phase_grid));

    % 각 signal별 output 준비
    out_mats = cell(1, nSig);
    for k = 1:nSig
        out_mats{k} = nan(nI, numel(phase_grid));
    end

    for i = 1:nI
        t0 = intervals(i,1);
        t1 = intervals(i,2);

        if ~(isfinite(t0) && isfinite(t1) && t1>t0)
            continue;
        end

        m = (t_u >= t0) & (t_u <= t1);
        if nnz(m) < 2
            continue;
        end

        seg_t = t_u(m);
        seg_a = angle_u(m);

        ph = (seg_t - seg_t(1)) / (seg_t(end)-seg_t(1)) * 100;

        % angle
        angle_mat(i,:) = interp1(ph, seg_a, phase_grid, 'linear', 'extrap');

        % 나머지 signal들
        for k = 1:nSig
            seg_s = signals_u{k}(m);
            out_mats{k}(i,:) = interp1(ph, seg_s, phase_grid, 'linear', 'extrap');
        end
    end

    % NaN row 제거
    bad = all(~isfinite(angle_mat),2);
    angle_mat(bad,:) = [];

    for k = 1:nSig
        out_mats{k}(bad,:) = [];
    end

    % 출력
    for k = 1:nSig
        varargout{k} = out_mats{k};
    end
end