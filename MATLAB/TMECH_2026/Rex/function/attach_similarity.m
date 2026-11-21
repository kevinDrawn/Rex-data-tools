function [exp_data, exp_data_summary] = attach_similarity( ...
    exp_data, exp_data_summary, sim_data, field_name, cond_list)

[n_rat, n_cond] = size(sim_data);

%% ===============================
% 1. exp_data에 저장 (개별)
%% ===============================
for r = 1:n_rat
    for c = 1:n_cond
        exp_data(r,c).similarity.(field_name) = sim_data(r,c);
    end
end

%% ===============================
% 2. exp_data_summary에 저장 (집단)
%% ===============================
for c = 1:n_cond

    % 값 추출 (안전한 방식)
    vals = nan(n_rat,1);
    for r = 1:n_rat
        if isfield(exp_data(r,c), 'similarity') && ...
           isfield(exp_data(r,c).similarity, field_name)
           
            vals(r) = exp_data(r,c).similarity.(field_name);
        end
    end

    % mean / std
    exp_data_summary(c).similarity.(field_name).mean = mean(vals, 'omitnan');
    exp_data_summary(c).similarity.(field_name).std  = std(vals, 0, 'omitnan');
    exp_data_summary(c).similarity.(field_name).all  = vals;
    
end

end