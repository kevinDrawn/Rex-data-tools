function plot_angle_x_cycloid_all(exp_data, rat_list, cond_list, y_type)

n_rat  = numel(rat_list);
n_cond = numel(cond_list);

figure;
tiledlayout(n_rat, n_cond); 

for i = 1:n_rat
    for j = 1:n_cond

        fprintf('\n[Processing] Rat: %s | Cond: %s\n', rat_list{i}, cond_list{j});

        try
            nexttile;
            hold on;

            % ===============================
            % 1. int_data
            % ===============================
            fprintf('  → Loading int_data...\n');
            int_data = exp_data(i,j).int_data;

            if isempty(int_data)
                warning('  int_data is empty');
                continue;
            end

            fprintf('  → Extract serial data...\n');
            serial = extract_t_interval_data(int_data);

            % y 선택
            switch y_type
                case 'vel'
                    yL = serial.left.vel;
                    yR = serial.right.vel;
                    ylabel_str = 'Angular velocity (deg/s)';
                case 'torque'
                    yL = serial.left.torque;
                    yR = serial.right.torque;
                    ylabel_str = 'Torque (N·mm/kg)';
                case 'power'
                    yL = serial.left.power;
                    yR = serial.right.power;
                    ylabel_str = 'Power (W/kg)';
                otherwise
                    error('Invalid y_type');
            end

            fprintf('  → Plot raw cycloid...\n');
            plot(serial.left.angle,  yL, 'Color', [1 0 0 0.2], 'LineWidth', 0.5);
            plot(serial.right.angle, yR, 'Color', [0 0 1 0.2], 'LineWidth', 0.5);

            % ===============================
            % 2. phase_data
            % ===============================
            fprintf('  → Loading phase_data...\n');
            phase_data = exp_data(i,j).phase_data;

            if isempty(phase_data)
                warning('  phase_data is empty');
                continue;
            end

            fprintf('  → Compute mean cycloid...\n');

            % LEFT
            L_angle = phase_data.left.exo.angle;
            L_y     = phase_data.left.exo.(y_type);

            L_mu_x = mean(L_angle,1,'omitnan');
            L_mu_y = mean(L_y,1,'omitnan');

            plot(L_mu_x, L_mu_y, 'r', 'LineWidth', 2);

            % RIGHT
            R_angle = phase_data.right.exo.angle;
            R_y     = phase_data.right.exo.(y_type);

            R_mu_x = mean(R_angle,1,'omitnan');
            R_mu_y = mean(R_y,1,'omitnan');

            plot(R_mu_x, R_mu_y, 'b', 'LineWidth', 2);

            % ===============================
            % formatting
            % ===============================
            title(sprintf('%s | %s', rat_list{i}, cond_list{j}), ...
                'Interpreter','none', 'FontSize',8);

            % 맨 왼쪽 column만 y-label
            if j == 1
                ylabel({rat_list{i}; ylabel_str});
            end

            % 맨 아래 row만 x-label
            if i == n_rat
                xlabel('Ankle angle (deg)');
            end

            % 맨 위 row에만 condition 표시
            if i == 1
                title(cond_list{j}, 'Interpreter','none');
            end

            grid on;
            axis tight;

            fprintf('  → DONE\n');

        catch ME
            fprintf('  ❌ ERROR at [%s | %s]\n', rat_list{i}, cond_list{j});
            fprintf('     %s\n', ME.message);

            % 에러 위치까지 출력 (핵심)
            for k = 1:length(ME.stack)
                fprintf('     → %s (line %d)\n', ...
                    ME.stack(k).name, ME.stack(k).line);
            end
        end

    end
end

fprintf('\n[Finished] Cycloid plotting\n');

end