function result = compute_TO_error(exp_data, rat_list, cond_list)

[n_rat, n_cond] = size(exp_data);

% ===============================
% 구조 초기화
% ===============================
result.per_rat = struct();
result.summary = struct();

result.meta.rat_list  = rat_list;
result.meta.cond_list = cond_list;

% ===============================
% 1. per-rat 계산
% ===============================
for i = 1:n_cond
    for j = 1:n_rat

        % LEFT
        [err_L, stats_L] = compute_single_TO_error( ...
            exp_data(j,i).phase_data.events.left);

        result.per_rat(j,i).left = stats_L;
        result.per_rat(j,i).left.err = err_L;

        % RIGHT
        [err_R, stats_R] = compute_single_TO_error( ...
            exp_data(j,i).phase_data.events.right);

        result.per_rat(j,i).right = stats_R;
        result.per_rat(j,i).right.err = err_R;

        % meta
        result.per_rat(j,i).rat  = rat_list{j};
        result.per_rat(j,i).cond = cond_list{i};
    end
end

% ===============================
% 2. summary 계산
% ===============================
for i = 1:n_cond

    % LEFT
    tmp = result.per_rat(:,i);
    
    all_err_L = vertcat(tmp.left);
    all_err_L = vertcat(all_err_L.err);

    result.summary(i).left.mean = mean(all_err_L,'omitnan');
    result.summary(i).left.std  = std(all_err_L,'omitnan');
    result.summary(i).left.rmse = sqrt(mean(all_err_L.^2,'omitnan'));

    % RIGHT
    tmp = result.per_rat(:,i);
    
    all_err_R = vertcat(tmp.right);     
    all_err_R = vertcat(all_err_R.err); 

    result.summary(i).right.mean = mean(all_err_R,'omitnan');
    result.summary(i).right.std  = std(all_err_R,'omitnan');
    result.summary(i).right.rmse = sqrt(mean(all_err_R.^2,'omitnan'));
end

fprintf('[compute_TO_error_pipeline] Done\n');

end

function [err, stats] = compute_single_TO_error(event_struct)

err = [];
stats = struct('mean',NaN,'std',NaN,'rmse',NaN);

if ~isfield(event_struct,'mocap') || ~isfield(event_struct,'exo')
    return;
end

mocap_TO = event_struct.mocap.t_TO;
exo_TO   = event_struct.exo.t_TO;

if isempty(mocap_TO) || isempty(exo_TO)
    return;
end

% ===============================
% nearest matching
% ===============================
D = abs(mocap_TO - exo_TO');
[~, idx] = min(D, [], 2);

err = mocap_TO - exo_TO(idx);

% ===============================
% 통계
% ===============================
stats.mean = mean(err,'omitnan');
stats.std  = std(err,'omitnan');
stats.rmse = sqrt(mean(err.^2,'omitnan'));

end