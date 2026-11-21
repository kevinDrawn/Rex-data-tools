function print_similarity_stats(sim_mat, cond_list, label)

n_cond = numel(cond_list);

fprintf('\n=== Cycloid Similarity (%s) ===\n', label);

for i = 1:n_cond

    vals = sim_mat(:,i);

    mu = mean(vals, 'omitnan');
    sd = std(vals, 0, 'omitnan');

    fprintf('%-20s : %6.2f ± %5.2f\n', cond_list{i}, mu, sd);

end

fprintf('==============================\n\n');

end