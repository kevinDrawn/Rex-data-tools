function plot_work_all(exp_data, rat_list, cond_list)

n_rat  = numel(rat_list);
n_cond = numel(cond_list);

figure;
tiledlayout(n_rat, n_cond);

for i = 1:n_rat
    for j = 1:n_cond

        nexttile; hold on;

        try
            work_L = exp_data(i,j).work.left;

            if isempty(work_L)
                warning('Empty work [%s | %s]', rat_list{i}, cond_list{j});
                continue;
            end

            % ===============================
            % mean / std
            % ===============================
            y_mean = [ ...
                work_L.pos.mean, ...
                work_L.neg.mean, ...
                work_L.net.mean ...
            ];

            y_std = [ ...
                work_L.pos.std, ...
                work_L.neg.std, ...
                work_L.net.std ...
            ];

            x = 1:3;

            % ===============================
            % Bar plot
            % ===============================
            b = bar(x, y_mean, 0.6);
            b.FaceColor = 'flat';

            % 색상
            b.CData(1,:) = [1 0 0];   % Pos
            b.CData(2,:) = [0 0 1];   % Neg
            b.CData(3,:) = [0 0 0];   % Net

            % ===============================
            % Errorbar
            % ===============================
            errorbar(x, y_mean, y_std, ...
                'k', 'LineStyle','none', 'LineWidth',1);

            % ===============================
            % Ratio 계산
            % ===============================
            ratio = work_L.pos.mean / abs(work_L.neg.mean);

            if abs(work_L.neg.mean) < 1e-6
                ratio = NaN;
            end

            % ===============================
            % Ratio 표시 (오른쪽)
            % ===============================
            x_ratio = 3.5;

            yyaxis right
            hold on;

            plot(x_ratio, ratio, 'ko', ...
                'MarkerFaceColor','g', 'MarkerSize',5);

            text(x_ratio, ratio, sprintf('%.2f', ratio), ...
                'FontSize',7, ...
                'HorizontalAlignment','left');

            ylabel('Pos / |Neg|');

            % ratio y축 범위 자동 설정
            ylim([0 max(1.5, ratio*1.2)]);

            yyaxis left

            % ===============================
            % formatting
            % ===============================
            xticks(x);
            xticklabels({'Pos','Neg','Net'});

            xlim([0.5 4]);

            % symmetric y-axis (보기 좋게)
            ymax = max(abs(y_mean + y_std));
            if ymax > 0
                ylim([-ymax ymax]);
            end

            if j == 1
                ylabel({rat_list{i}; 'Work (J/kg)'});
            end

            if i == 1
                title(cond_list{j}, 'Interpreter','none');
            end

            grid on;

        catch ME
            fprintf('❌ ERROR [%s | %s]: %s\n', ...
                rat_list{i}, cond_list{j}, ME.message);
        end

    end
end

fprintf('\n[Finished] Work plotting\n');

end