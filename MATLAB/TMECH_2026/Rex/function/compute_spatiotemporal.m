function exp_data = compute_spatiotemporal(exp_data, rat_idx, cond_idx)

sides = {'left','right'};

for s = 1:2

    side = sides{s};

    % ===============================
    % 데이터 가져오기
    % ===============================
    TO = exp_data(rat_idx,cond_idx).phase_data.events.(side).mocap.t_TO;
    IC = exp_data(rat_idx,cond_idx).phase_data.events.(side).mocap.t_IC;

    TO = TO(:);
    IC = IC(:);

    % ===============================
    % cycle 개수
    % ===============================
    n_cycle = length(TO) - 1;

    IC_phase_all = nan(n_cycle,1);
    stance_ratio_all = nan(n_cycle,1);
    stance_phase_all = nan(n_cycle,1);
    
    % ===============================
    % 계산 (🔥 수정된 robust 방식)
    % ===============================
    for i = 1:n_cycle

        t0 = TO(i);
        t1 = TO(i+1);

        % 🔥 TO 구간 내 IC 찾기
        idx = find(IC > t0 & IC < t1);

        if isempty(idx)
            continue;
        end

        % 가장 가까운 IC 선택
        [~, k] = min(abs(IC(idx) - t0));
        tic = IC(idx(k));

        cycle_dur = t1 - t0;

        if cycle_dur <= 0
            continue;
        end

        ic_phase = (tic - t0) / cycle_dur * 100;


        IC_phase_all(i) = ic_phase;
        stance_phase_all(i) = 100-ic_phase;

        stance_ratio_all(i) = ic_phase / 100;

    end

    % ===============================
    % 저장
    % ===============================
    exp_data(rat_idx,cond_idx).phase_data.results.mocap.spatio.(side).IC_phase.all  = IC_phase_all;
    exp_data(rat_idx,cond_idx).phase_data.results.mocap.spatio.(side).IC_phase.mean = mean(IC_phase_all,'omitnan');
    exp_data(rat_idx,cond_idx).phase_data.results.mocap.spatio.(side).IC_phase.std  = std(IC_phase_all,'omitnan');

    exp_data(rat_idx,cond_idx).phase_data.results.mocap.spatio.(side).stance_phase.all  = stance_phase_all;
    exp_data(rat_idx,cond_idx).phase_data.results.mocap.spatio.(side).stance_phase.mean = mean(stance_phase_all,'omitnan');
    exp_data(rat_idx,cond_idx).phase_data.results.mocap.spatio.(side).stance_phase.std  = std(stance_phase_all,'omitnan');

    exp_data(rat_idx,cond_idx).phase_data.results.mocap.spatio.(side).stance_swing_ratio.all  = stance_ratio_all;
    exp_data(rat_idx,cond_idx).phase_data.results.mocap.spatio.(side).stance_swing_ratio.mean = mean(stance_ratio_all,'omitnan');
    exp_data(rat_idx,cond_idx).phase_data.results.mocap.spatio.(side).stance_swing_ratio.std  = std(stance_ratio_all,'omitnan');

end
end