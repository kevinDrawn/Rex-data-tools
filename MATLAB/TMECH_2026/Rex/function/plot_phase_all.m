function plot_phase_all(exp_data, rat_list, cond_list, y_type, use_mocap_event)

n_rat  = numel(rat_list);
n_cond = numel(cond_list);

figure;
tiledlayout(n_rat, n_cond);

for i = 1:n_rat
    for j = 1:n_cond

        nexttile; hold on;

        try
            phase_data = exp_data(i,j).phase_data;

            if isempty(phase_data)
                warning('Empty phase_data [%s | %s]', rat_list{i}, cond_list{j});
                continue;
            end

            % ===============================
            % x축 (phase)
            % ===============================
            phase = phase_data.phase;   % 0~100

            % ===============================
            % source 선택 (핵심)
            % ===============================
            cond_name = cond_list{j};

            src_L = 'exo';
            src_R = 'exo';

            if use_mocap_event
                if contains(cond_name, 'intact_Rex') || ...
                   contains(cond_name, 'lido_Exo')  || ...
                   contains(cond_name, 'lido_Rex')

                    src_L = 'mocap';
                    src_R = 'mocap';
                end
            end

            % ===============================
            % y 데이터 선택
            % ===============================
            switch y_type
                case 'angle'
                    yL_mean = phase_data.results.(src_L).angle.left.mean;
                    yL_std  = phase_data.results.(src_L).angle.left.std;

                    yR_mean = phase_data.results.(src_R).angle.right.mean;
                    yR_std  = phase_data.results.(src_R).angle.right.std;

                    ylabel_str = 'Angle (deg)';

                case 'vel'
                    % fallback (mocap에 없을 경우 대비)
                    if ~isfield(phase_data.results.(src_L), 'vel')
                        warning('No vel in %s → fallback to exo', src_L);
                        src_L = 'exo';
                    end

                    yL_mean = phase_data.results.(src_L).vel.left.mean;
                    yL_std  = phase_data.results.(src_L).vel.left.std;

                    yR_mean = phase_data.results.(src_R).vel.right.mean;
                    yR_std  = phase_data.results.(src_R).vel.right.std;

                    ylabel_str = 'Angular velocity (deg/s)';

                case 'torque'
                    if ~isfield(phase_data.results.(src_L), 'torque')
                        warning('No torque in %s → fallback to exo', src_L);
                        src_L = 'exo';
                    end

                    yL_mean = phase_data.results.(src_L).torque.left.mean;
                    yL_std  = phase_data.results.(src_L).torque.left.std;

                    yR_mean = phase_data.results.(src_R).torque.right.mean;
                    yR_std  = phase_data.results.(src_R).torque.right.std;

                    ylabel_str = 'Torque (N·mm/kg)';

                case 'power'
                    if ~isfield(phase_data.results.(src_L), 'power')
                        warning('No power in %s → fallback to exo', src_L);
                        src_L = 'exo';
                    end

                    yL_mean = phase_data.results.(src_L).power.left.mean;
                    yL_std  = phase_data.results.(src_L).power.left.std;

                    yR_mean = phase_data.results.(src_R).power.right.mean;
                    yR_std  = phase_data.results.(src_R).power.right.std;

                    ylabel_str = 'Power (W/kg)';

                otherwise
                    error('Invalid y_type');
            end

            % LEFT raw cycles (transparent)
            try
                raw_angle_L = phase_data.left.(src_L).angle;   % n x 101
                raw_y_L     = phase_data.left.(src_L).(y_type);
            
                for k = 1:size(raw_angle_L,1)
                    plot(phase, raw_y_L(k,:), ...
                        'Color', [1 0 0 0.8], 'LineWidth', 0.5);
                end
            catch
                warning('No raw LEFT data [%s]', src_L);
            end

            % RIGHT raw cycles (transparent)
            try
                raw_angle_R = phase_data.right.(src_R).angle;
                raw_y_R     = phase_data.right.(src_R).(y_type);
            
                for k = 1:size(raw_angle_R,1)
                    plot(phase, raw_y_R(k,:), ...
                        'Color', [0 0 1 0.8], 'LineWidth', 0.5);
                end
            catch
                warning('No raw RIGHT data');
            end

            % ===============================
            % LEFT (red)
            % ===============================
            fill([phase, fliplr(phase)], ...
                 [yL_mean + yL_std, fliplr(yL_mean - yL_std)], ...
                 [1 0 0], 'FaceAlpha',0.2, 'EdgeColor','none');

            plot(phase, yL_mean, 'r', 'LineWidth', 2);

            % ===============================
            % RIGHT (blue)
            % ===============================
            fill([phase, fliplr(phase)], ...
                 [yR_mean + yR_std, fliplr(yR_mean - yR_std)], ...
                 [0 0 1], 'FaceAlpha',0.2, 'EdgeColor','none');

            plot(phase, yR_mean, 'b', 'LineWidth', 2);

            % ===============================
            % formatting
            % ===============================
            if j == 1
                ylabel({rat_list{i}; ylabel_str});
            end

            if i == n_rat
                xlabel('Gait phase (%)');
            end

            if i == 1
                title(cond_list{j}, 'Interpreter','none');
            end

            grid on;
            xlim([0 100]);

        catch ME
            fprintf('❌ ERROR [%s | %s]: %s\n', ...
                rat_list{i}, cond_list{j}, ME.message);
        end

    end
end

fprintf('\n[Finished] Phase plotting\n');

end