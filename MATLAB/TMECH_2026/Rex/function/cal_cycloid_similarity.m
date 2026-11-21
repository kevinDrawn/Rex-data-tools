function sim_mat = cal_cycloid_similarity(exp_data, y_type, cond_list, cfg)

n_rat = size(exp_data, 1);
n_cond = numel(cond_list);

% sim_mat = nan(n_cond, n_rat);
sim_mat = nan(n_rat, n_cond);

if ~isfield(cfg,'densify_factor')
    cfg.densify_factor = 10;
end

total_iter = n_rat * n_cond;
iter_count = 0;

t_total = tic;

for i = 1:n_rat
    for j = 1:n_cond

        iter_count = iter_count + 1;
        t_iter = tic;

        fprintf('\n[%d/%d] START → rat=%d, cond=%d\n', ...
            iter_count, total_iter, i, j);

        try
            phase_data = exp_data(i,j).phase_data;

            if isempty(phase_data)
                fprintf('  ⚠️ phase_data empty → skip\n');
                continue;
            end

            % ===============================
            % LEFT
            % ===============================
            cond_name = cond_list{j};
            
            % ===============================
            % LEFT source 선택
            % ===============================
            if contains(cond_name, 'lido_Exo shoe')
                src_L = phase_data.left.mocap;
            else
                src_L = phase_data.left.exo;
            end
            
            % ===============================
            % 데이터 추출
            % ===============================
            thetaL = src_L.angle;
            yL     = src_L.(y_type);

            thetaL_mu = mean(thetaL,1,'omitnan');
            yL_mu     = mean(yL,1,'omitnan');

            % ===============================
            % RIGHT
            % ===============================
            thetaR = phase_data.right.exo.angle;
            yR     = phase_data.right.exo.(y_type);

            thetaR_mu = mean(thetaR,1,'omitnan');
            yR_mu     = mean(yR,1,'omitnan');

            if isempty(thetaL_mu) || isempty(thetaR_mu)
                fprintf('  ⚠️ empty mean → skip\n');
                continue;
            end

            % ===============================
            % periodic + densify
            % ===============================
            fprintf('  → densify...\n');
            [xL, yL] = make_cycloid_dense(thetaL_mu, yL_mu, cfg);
            [xR, yR] = make_cycloid_dense(thetaR_mu, yR_mu, cfg);

            % ===============================
            % IoU
            % ===============================
            fprintf('  → compute IoU...\n');
            sim = compute_cycloid_iou(xL, yL, xR, yR);

            sim_mat(i,j) = sim;

            fprintf('  ✔ DONE | sim = %.2f | time = %.3f s\n', ...
                sim, toc(t_iter));

        catch ME
            fprintf('  ❌ ERROR: %s\n', ME.message);

            % stack trace 출력
            for k = 1:length(ME.stack)
                fprintf('     → %s (line %d)\n', ...
                    ME.stack(k).name, ME.stack(k).line);
            end
        end

        % ===============================
        % 전체 진행률
        % ===============================
        progress = 100 * iter_count / total_iter;

        fprintf('  → Progress: %.1f %% (%d / %d)\n', ...
            progress, iter_count, total_iter);

        % 예상 남은 시간
        elapsed = toc(t_total);
        est_total = elapsed / iter_count * total_iter;
        est_remain = est_total - elapsed;

        fprintf('  → Elapsed: %.1f s | Remaining: %.1f s\n', ...
            elapsed, est_remain);

    end
end

fprintf('\n[FINISHED] Total time: %.2f s\n', toc(t_total));

end
function [x_dense, y_dense] = make_cycloid_dense(theta, y, cfg)

theta = theta(:)';
y     = y(:)';

N = numel(theta);

% periodic extension
theta_ext = [theta, theta(1)];
y_ext     = [y,     y(1)];

t_ext = linspace(0,1,N+1);

t_dense = linspace(0,1,N*cfg.densify_factor);

x_dense = interp1(t_ext, theta_ext, t_dense, 'pchip');
y_dense = interp1(t_ext, y_ext,     t_dense, 'pchip');

end
