function result = combined_regression(x_all, y_all, outlier_threshold)

% =========================================================
% combined_regression
%
% 전체 Trial 데이터를 통합하여
% 1) Original linear regression
% 2) Studentized residual 기반 outlier 검출
% 3) Outlier 제거 후 linear regression
% 을 수행한다.
%
% Input
%   x_all              : Cycle period T_R
%   y_all              : Offset time Δt
%   outlier_threshold  : Studentized residual threshold
%
% Output
%   result             : Regression 결과 구조체
% =========================================================


%% ---------------------------------------------------------
% Input check
% ---------------------------------------------------------

assert(~isempty(x_all), ...
    'Regression에 사용할 데이터가 없습니다.');

assert(numel(x_all) == numel(y_all), ...
    'x와 y 데이터 개수가 다릅니다.');


%% ---------------------------------------------------------
% Original Regression
% ---------------------------------------------------------

mdl_original = fitlm(x_all, y_all);

b0_original  = mdl_original.Coefficients.Estimate(1);
b1_original  = mdl_original.Coefficients.Estimate(2);
rsq_original = mdl_original.Rsquared.Adjusted;


%% ---------------------------------------------------------
% Outlier Detection
% ---------------------------------------------------------

studentized_residual = ...
    mdl_original.Residuals.Studentized;

is_outlier = ...
    abs(studentized_residual) > outlier_threshold;


% Outlier data
x_out = x_all(is_outlier);
y_out = y_all(is_outlier);


% Clean data
x_clean = x_all(~is_outlier);
y_clean = y_all(~is_outlier);


%% ---------------------------------------------------------
% Regression after Outlier Removal
% ---------------------------------------------------------

mdl_clean = fitlm(x_clean, y_clean);

b0_clean  = mdl_clean.Coefficients.Estimate(1);
b1_clean  = mdl_clean.Coefficients.Estimate(2);
rsq_clean = mdl_clean.Rsquared.Adjusted;


%% ---------------------------------------------------------
% Regression curve
% ---------------------------------------------------------

xq = linspace( ...
    min(x_all), ...
    max(x_all), ...
    200)';

yhat_original = ...
    predict(mdl_original, xq);

[yhat_clean, yCI_clean] = ...
    predict( ...
        mdl_clean, ...
        xq, ...
        'Prediction','observation');


%% ---------------------------------------------------------
% Output
% ---------------------------------------------------------

result.mdl_original = mdl_original;
result.mdl_clean = mdl_clean;

result.b0_original = b0_original;
result.b1_original = b1_original;
result.rsq_original = rsq_original;

result.b0_clean = b0_clean;
result.b1_clean = b1_clean;
result.rsq_clean = rsq_clean;

result.studentized_residual = studentized_residual;
result.is_outlier = is_outlier;

result.x_out = x_out;
result.y_out = y_out;

result.x_clean = x_clean;
result.y_clean = y_clean;

result.xq = xq;
result.yhat_original = yhat_original;
result.yhat_clean = yhat_clean;
result.yCI_clean = yCI_clean;

result.outlier_threshold = outlier_threshold;


%% ---------------------------------------------------------
% Result
% ---------------------------------------------------------

fprintf('\n=== Outlier Detection ===\n');

fprintf( ...
    'Threshold  : |Studentized residual| > %.1f\n', ...
    outlier_threshold);

fprintf('Total      : %d\n', numel(x_all));
fprintf('Outlier    : %d\n', nnz(is_outlier));
fprintf('Remaining  : %d\n', nnz(~is_outlier));


fprintf('\n=== Original Combined Model ===\n');

fprintf( ...
    'y = %.6f + %.6f x\n', ...
    b0_original, ...
    b1_original);

fprintf( ...
    'Adjusted R^2 = %.4f\n', ...
    rsq_original);


fprintf('\n=== Outlier-Removed Combined Model ===\n');

fprintf( ...
    'y = %.6f + %.6f x\n', ...
    b0_clean, ...
    b1_clean);

fprintf( ...
    'Adjusted R^2 = %.4f\n', ...
    rsq_clean);

end