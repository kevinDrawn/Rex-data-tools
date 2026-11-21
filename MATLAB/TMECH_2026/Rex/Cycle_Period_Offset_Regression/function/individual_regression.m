function [slopes, intercepts, r2_each] = ...
    individual_regression(raw, trial_num)

% =========================================================
% individual_regression
%
% 각 Trial에 대해 linear regression 수행
%
% Input
%   raw(k).x   : Cycle period
%   raw(k).y   : Offset time
%   trial_num  : Trial number
%
% Output
%   slopes     : 각 Trial regression slope
%   intercepts : 각 Trial regression intercept
%   r2_each    : 각 Trial adjusted R^2
% =========================================================

n = numel(raw);

slopes     = nan(n,1);
intercepts = nan(n,1);
r2_each    = nan(n,1);


for k = 1:n

    % 데이터가 없으면 skip
    if isempty(raw(k).x)
        continue;
    end

    % Linear regression
    mdl_k = fitlm(raw(k).x, raw(k).y);

    % Regression parameters
    intercepts(k) = ...
        mdl_k.Coefficients.Estimate(1);

    slopes(k) = ...
        mdl_k.Coefficients.Estimate(2);

    r2_each(k) = ...
        mdl_k.Rsquared.Adjusted;


    % Result
    fprintf( ...
        ['Data %d: slope = %.4f, ' ...
        'intercept = %.4f, Adj.R² = %.3f\n'], ...
        trial_num(k), ...
        slopes(k), ...
        intercepts(k), ...
        r2_each(k));

end

end