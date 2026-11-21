function print_table_gait_cycle(exp_data, rat_list, cond_list, cond_cycle_list)

% =========================================================================
% Extract condition indices
% =========================================================================
[is_exist, cond_idx_list] = ismember(cond_cycle_list, cond_list);

if any(~is_exist)
    error('The following conditions were not found in cond_list:\n%s', ...
        strjoin(cond_cycle_list(~is_exist), ', '));
end

% =========================================================================
% Print header
% =========================================================================
fprintf('\n====================================================================================================\n');
fprintf('                                  Gait Cycle Summary\n');
fprintf('====================================================================================================\n');

fprintf('%-8s %-20s %12s %12s %12s %12s %8s %8s\n', ...
    'Rat', ...
    'Condition', ...
    'Tmean(s)', ...
    'Tsd(s)', ...
    'Fmean(Hz)', ...
    'Fsd(Hz)', ...
    'N', ...
    'Rm');

nRat  = length(rat_list);
nCond = length(cond_idx_list);

mean_freq_all = nan(nRat,nCond);
sd_freq_all   = nan(nRat,nCond);


% =========================================================================
% Loop over rats and conditions
% =========================================================================
for rat_idx = 1:length(rat_list)

    rat_name = rat_list{rat_idx};

    for k = 1:length(cond_idx_list)

        cond_idx = cond_idx_list(k);
        cond_name = cond_list{cond_idx};

        try

            % -------------------------------------------------------------
            % TO timing vector [sec]
            % -------------------------------------------------------------
            t_TO = exp_data(rat_idx, cond_idx).phase_data.events.right.exo.t_TO;

            % remove NaN if any
            t_TO = t_TO(~isnan(t_TO));

            % -------------------------------------------------------------
            % Gait cycle period
            % -------------------------------------------------------------
            gait_period_raw = diff(t_TO);
            valid_idx = gait_period_raw < 1.0;
            gait_period = gait_period_raw(valid_idx);
            n_removed = sum(~valid_idx);

            % -------------------------------------------------------------
            % Statistics=
            % -------------------------------------------------------------
            mean_period = mean(gait_period);
            sd_period   = std(gait_period);
            N_cycle     = length(gait_period);

            % -------------------------------------------------------------
            % Frequency-domain statistics
            % -------------------------------------------------------------
            gait_freq = 1 ./ gait_period;
            mean_freq = 1 / mean_period;
            sd_freq = std(gait_freq);

            mean_freq_all(rat_idx,k) = mean_freq;
            sd_freq_all(rat_idx,k)   = sd_freq;

            % -------------------------------------------------------------
            % Print
            % -------------------------------------------------------------
            fprintf('%-8s %-20s %12.4f %12.4f %12.3f %12.3f %8d %8d\n', ...
                rat_name, ...
                cond_name, ...
                mean_period, ...
                sd_period, ...
                mean_freq, ...
                sd_freq, ...
                N_cycle, ...
                n_removed);

        catch

            fprintf('%-8s %-20s %12s %12s %10s\n', ...
                rat_name, cond_name, 'NaN', 'NaN', '-');

        end

    end
end

fprintf('==============================================================\n\n');

figure
hold on

for k = 1:nCond

    errorbar( ...
        1:nRat,...
        mean_freq_all(:,k),...
        sd_freq_all(:,k),...
        'o-',...
        'LineWidth',1.5);

end

xticks(1:nRat)
xticklabels(rat_list)

xlabel('Rat')
ylabel('Gait Frequency (Hz)')

legend(cond_cycle_list,'Location','best')

grid on
box off
ylim([1, 3.5])

end