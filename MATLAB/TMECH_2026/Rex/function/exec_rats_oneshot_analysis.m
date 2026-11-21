function exec_rats_oneshot_analysis(rat_list, root_dir, cond_list, plot_on)
    % ===============================
    % Input check (optional but good)
    % ===============================
    if nargin < 3
        error('Usage: exec_rats_oneshot_analysis(rat_list, root_dir, cond_list)');
    end

    % ===============================
    % Main loop
    % ===============================
    for i = 1:length(rat_list)
        close all;
        rat_name = rat_list{i};
        rat_dir = fullfile(root_dir, rat_name);

        if ~isfolder(rat_dir)
            warning('Skipping %s (not found)', rat_name);
            continue;
        end

        fprintf('\n============================\n');
        fprintf('[Rat] %s\n', rat_name);

        for j = 1:length(cond_list)
            cond_name = cond_list{j};
            cond_dir = fullfile(rat_dir, cond_name);
            fprintf('  → Condition: %s\n', cond_name);

            try
               % One shot analysis function                
                func_run_single_analysis_ver_2(cond_dir, cond_name, plot_on);

            catch ME
                warning('Error in %s - %s', rat_name, cond_name);
                disp(ME.message);
            end
   
        end
    end

    fprintf('\n✅ All analysis finished.\n');

end