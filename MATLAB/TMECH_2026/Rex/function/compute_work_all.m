function exp_data = compute_work_all(exp_data)

[n_rat, n_cond] = size(exp_data);

for i = 1:n_rat
    for j = 1:n_cond
        try
            int_data   = exp_data(i,j).int_data;
            phase_data = exp_data(i,j).phase_data;

            if isempty(int_data) || isempty(phase_data)
                continue;
            end

            % ===============================
            % time & power
            % ===============================
            t = int_data.t;

            P_L = int_data.left.power;
            P_R = int_data.right.power;

            % ===============================
            % cycle boundaries (mocap 기준)
            % ===============================
            t_TO_L = phase_data.events.left.mocap.t_TO;
            t_TO_R = phase_data.events.right.mocap.t_TO;

            % ===============================
            % LEFT
            % ===============================
            work_L = compute_work_per_side(t, P_L, t_TO_L);

            % ===============================
            % RIGHT
            % ===============================
            work_R = compute_work_per_side(t, P_R, t_TO_R);

            % ===============================
            % 저장
            % ===============================
            exp_data(i,j).work.left  = work_L;
            exp_data(i,j).work.right = work_R;

        catch ME
            fprintf('❌ Work ERROR [%d,%d]: %s\n', i, j, ME.message);
        end

    end
end

fprintf('\n[Finished] Work computation\n');

end

function work = compute_work_per_side(t, P, t_TO)

n_cycle = length(t_TO) - 1;

W_pos = nan(n_cycle,1);
W_neg = nan(n_cycle,1);
W_net = nan(n_cycle,1);

for k = 1:n_cycle

    idx = (t >= t_TO(k)) & (t < t_TO(k+1));

    t_seg = t(idx);
    P_seg = P(idx);

    if numel(t_seg) < 5
        continue;
    end

    % Positive / Negative 분리
    P_pos = max(P_seg, 0);
    P_neg = min(P_seg, 0);

    % Integration
    W_pos(k) = trapz(t_seg, P_pos);
    W_neg(k) = trapz(t_seg, P_neg);
    W_net(k) = trapz(t_seg, P_seg);

end

% ===============================
% 결과 struct
% ===============================
work.pos.cycle = W_pos;
work.neg.cycle = W_neg;
work.net.cycle = W_net;

work.pos.mean = mean(W_pos, 'omitnan');
work.pos.std  = std(W_pos,  'omitnan');

work.neg.mean = mean(W_neg, 'omitnan');
work.neg.std  = std(W_neg,  'omitnan');

work.net.mean = mean(W_net, 'omitnan');
work.net.std  = std(W_net,  'omitnan');

end
