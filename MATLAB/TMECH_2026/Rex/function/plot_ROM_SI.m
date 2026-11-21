function [exp_data, exp_data_summary] = plot_ROM_SI(exp_data, exp_data_summary, rat_list, cond_list)

n_rat  = numel(rat_list);
n_cond = numel(cond_list);
SI_mat = nan(n_rat, n_cond); 

figure;

for j = 1:n_rat
    
    %% ===============================
    % 데이터 준비
    %% ===============================
    L_mean = nan(1,n_cond);
    R_mean = nan(1,n_cond);
    
    L_std = nan(1,n_cond);
    R_std = nan(1,n_cond);
    
    SI_all = nan(1,n_cond);

    for i = 1:n_cond
        
        cond_name = cond_list{i};
        
        % ===============================
        % LEFT source 선택
        % ===============================
        use_mocap_left = contains(cond_name, 'lido_Exo shoe');
        
        if use_mocap_left
            src_L = exp_data(j,i).phase_data.results.mocap;
        else
            src_L = exp_data(j,i).phase_data.results.exo;
        end
        
        % ===============================
        % RIGHT source
        % ===============================
        src_R = exp_data(j,i).phase_data.results.exo;
        
        % ===============================
        % 값 추출
        % ===============================
        L_mean(i) = src_L.angle.left.ROM_mean;
        L_std(i)  = src_L.angle.left.ROM_std;
        
        R_mean(i) = src_R.angle.right.ROM_mean;
        R_std(i)  = src_R.angle.right.ROM_std;

        % SI 계산
        SI_all(i) = compute_SI(L_mean(i), R_mean(i));
        SI_mat(j,i) = SI_all(i);
    end

    %% ===============================
    % 🔴 (열1) ROM plot
    %% ===============================
    subplot(n_rat,2,(j-1)*2 + 1); hold on;

    x = 1:n_cond;
    offset = 0.15;

    bar(x-offset, L_mean, 0.3, 'FaceColor',[0.8 0.2 0.2]);
    errorbar(x-offset, L_mean, L_std, 'k','LineStyle','none');

    bar(x+offset, R_mean, 0.3, 'FaceColor',[0.2 0.2 0.8]);
    errorbar(x+offset, R_mean, R_std, 'k','LineStyle','none');

    title(sprintf('%s - ROM', rat_list{j}));
    ylabel('Range of Motion (deg)');
    set(gca,'XTick',x,'XTickLabel',cond_list);

    legend({'Left','Right'},'Location','best');
    box off;

    %% ===============================
    % 🔵 (열2) SI plot
    %% ===============================
    subplot(n_rat,2,(j-1)*2 + 2); hold on;

    bar(x, SI_all, 0.5, 'FaceColor',[0.3 0.7 0.3]);
    yline(0,'--k');

    title(sprintf('%s - SI', rat_list{j}));
    ylabel('Symmetry Index (%)');
    set(gca,'XTick',x,'XTickLabel',cond_list);

    box off;

    %% ===============================
    % 출력
    %% ===============================
    fprintf('\n[%s] Symmetry Index\n', rat_list{j});
    for i = 1:n_cond
        fprintf('  %s : %.3f %%\n', cond_list{i}, SI_all(i));
    end
end

%% ===============================
% 전체 평균 출력
%% ===============================
fprintf('\n==============================\n');
fprintf('[Overall Symmetry Index]\n');

for i = 1:n_cond
    mean_SI = mean(SI_mat(:,i),'omitnan');
    std_SI  = std(SI_mat(:,i),'omitnan');

    fprintf('  %s : %.3f ± %.3f %%\n', ...
        cond_list{i}, mean_SI, std_SI);
end

fprintf('==============================\n');

for i = 1:n_cond
    
    % SI
    exp_data_summary(i).ROM.SI.mean = mean(SI_mat(:,i), 'omitnan');
    exp_data_summary(i).ROM.SI.std  = std(SI_mat(:,i), 0, 'omitnan');
    exp_data_summary(i).ROM.SI.all = SI_mat(:,i);

    % LEFT ROM
    L_vals = arrayfun(@(j) exp_data(j,i).phase_data.results.exo.angle.left.ROM_mean, 1:n_rat);
    exp_data_summary(i).ROM.left.mean = mean(L_vals, 'omitnan');
    exp_data_summary(i).ROM.left.std  = std(L_vals, 0, 'omitnan');
    exp_data_summary(i).ROM.left.all = L_vals;

    % RIGHT ROM
    R_vals = arrayfun(@(j) exp_data(j,i).phase_data.results.exo.angle.right.ROM_mean, 1:n_rat);
    exp_data_summary(i).ROM.right.mean = mean(R_vals, 'omitnan');
    exp_data_summary(i).ROM.right.std  = std(R_vals, 0, 'omitnan');
    exp_data_summary(i).ROM.right.all = R_vals;
end


end