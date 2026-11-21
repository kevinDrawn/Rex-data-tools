function exp_data_summary = attach_peak_value(exp_data, exp_data_summary, data_type)

n_cond = size(exp_data, 2);
n_rat  = size(exp_data, 1);

for j = 1:n_cond

    %% ===============================
    % LEFT
    %% ===============================
    peak_pos_L = nan(n_rat,1);
    peak_neg_L = nan(n_rat,1);

    for r = 1:n_rat
        try
            peak_pos_L(r) = exp_data(r,j).phase_data.results.exo.(data_type).left.peak_pos_mean;
            peak_neg_L(r) = exp_data(r,j).phase_data.results.exo.(data_type).left.peak_neg_mean;
        catch
            peak_pos_L(r) = NaN;
            peak_neg_L(r) = NaN;
        end
    end

    %% ===============================
    % RIGHT
    %% ===============================
    peak_pos_R = nan(n_rat,1);
    peak_neg_R = nan(n_rat,1);

    for r = 1:n_rat
        try
            peak_pos_R(r) = exp_data(r,j).phase_data.results.exo.(data_type).right.peak_pos_mean;
            peak_neg_R(r) = exp_data(r,j).phase_data.results.exo.(data_type).right.peak_neg_mean;
        catch
            peak_pos_R(r) = NaN;
            peak_neg_R(r) = NaN;
        end
    end

    %% ===============================
    % Summary 저장
    %% ===============================

    % LEFT
    exp_data_summary(j).peak.(data_type).left.pos.mean = mean(peak_pos_L, 'omitnan');
    exp_data_summary(j).peak.(data_type).left.pos.std  = std(peak_pos_L, 0, 'omitnan');
    exp_data_summary(j).peak.(data_type).left.pos.all = peak_pos_L(:);
    
    exp_data_summary(j).peak.(data_type).left.neg.mean = mean(peak_neg_L, 'omitnan');
    exp_data_summary(j).peak.(data_type).left.neg.std  = std(peak_neg_L, 0, 'omitnan');
    exp_data_summary(j).peak.(data_type).left.neg.all = peak_neg_L(:);

    % RIGHT
    exp_data_summary(j).peak.(data_type).right.pos.mean = mean(peak_pos_R, 'omitnan');
    exp_data_summary(j).peak.(data_type).right.pos.std  = std(peak_pos_R, 0, 'omitnan');
    exp_data_summary(j).peak.(data_type).right.pos.all = peak_pos_R(:);


    exp_data_summary(j).peak.(data_type).right.neg.mean = mean(peak_neg_R, 'omitnan');
    exp_data_summary(j).peak.(data_type).right.neg.std  = std(peak_neg_R, 0, 'omitnan');
    exp_data_summary(j).peak.(data_type).right.neg.all = peak_neg_R(:);

end
end

function val = getfield_safe(s, data_type, field_name)

try
    val = s.phase_data.results.exo.(data_type).(field_name);
catch
    val = NaN;
end

end