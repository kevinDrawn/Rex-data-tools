function [raw, x_all, y_all, trial_num] = load_regression_trials( ...
    base_path, rat_id, condition_name, ix, iy)

% =========================================================
% load_regression_trials
%
% Rat의 특정 condition에 해당하는 Trial 폴더를 자동 검출하고,
% 각 Trial의 Cycle Period / Offset 데이터를 불러온다.
%
% Input
%   base_path      : Data root directory
%   rat_id         : Rat number
%   condition_name : Condition folder prefix
%   ix             : Cycle period column index
%   iy             : Offset time column index
%
% Output
%   raw(k).x       : Trial k의 cycle period
%   raw(k).y       : Trial k의 offset time
%   raw(k).trial   : Trial number
%   x_all          : 모든 Trial의 cycle period 통합
%   y_all          : 모든 Trial의 offset time 통합
%   trial_num      : 검출된 Trial 번호
% =========================================================

%% ---------------------------------------------------------
% Rat folder
% ---------------------------------------------------------

rat_path = fullfile(base_path, sprintf('#%d', rat_id));

assert(isfolder(rat_path), ...
    'Rat folder not found: %s', rat_path);


%% ---------------------------------------------------------
% Trial folder 자동 검출
% ---------------------------------------------------------

d = dir(fullfile(rat_path, [condition_name '_*']));
d = d([d.isdir]);

assert(~isempty(d), ...
    'No "%s_*" folders found in %s', ...
    condition_name, rat_path);


%% ---------------------------------------------------------
% Trial 번호 추출
% ---------------------------------------------------------

trial_num = nan(numel(d),1);

for k = 1:numel(d)

    token = regexp( ...
        d(k).name, ...
        '_([0-9]+)$', ...
        'tokens', ...
        'once');

    if ~isempty(token)
        trial_num(k) = str2double(token{1});
    end

end

% 정상적인 Trial 번호만 사용
valid = isfinite(trial_num);

d = d(valid);
trial_num = trial_num(valid);

assert(~isempty(trial_num), ...
    'Valid trial folder was not found.');


% Trial 번호 순서대로 정렬
[trial_num, order] = sort(trial_num);

trial_dirs = d(order);

n = numel(trial_dirs);


fprintf('\n========================================\n');
fprintf('Rat #%d\n', rat_id);
fprintf('Condition : %s\n', condition_name);
fprintf('Detected  : %d trials\n', n);
fprintf('========================================\n');


%% ---------------------------------------------------------
% Output 초기화
% ---------------------------------------------------------

raw = repmat( ...
    struct('x', [], 'y', [], 'trial', []), ...
    n, 1);

x_all = [];
y_all = [];


%% ---------------------------------------------------------
% 각 Trial 데이터 로드
% ---------------------------------------------------------

for k = 1:n

    trial_path = fullfile( ...
        rat_path, ...
        trial_dirs(k).name);


    target_path = fullfile( ...
        trial_path, ...
        'Cycle Period + Offset 추정 인덱스');


    %% CSV 검색

    csv_files = dir(fullfile(target_path, '*.csv'));

    if isempty(csv_files)

        warning( ...
            'Trial %d: No CSV in %s', ...
            trial_num(k), ...
            target_path);

        continue;

    end


    % 현재는 첫 번째 CSV 사용
    fp = fullfile( ...
        target_path, ...
        csv_files(1).name);


    fprintf( ...
        'Loading Data %d: %s\n', ...
        trial_num(k), ...
        csv_files(1).name);


    %% CSV 읽기

    T = readtable( ...
        fp, ...
        'VariableNamingRule','preserve', ...
        'TextType','string');


    %% Column 확인

    if width(T) < max(ix, iy)

        warning( ...
            'Data %d: Column 부족 → skip', ...
            trial_num(k));

        continue;

    end


    %% Cycle period / Offset 추출

    xk = T{:, ix};
    yk = T{:, iy};


    if ~isnumeric(xk)
        xk = str2double(xk);
    end

    if ~isnumeric(yk)
        yk = str2double(yk);
    end


    %% NaN / Inf 제거

    valid_data = ...
        isfinite(xk) & ...
        isfinite(yk);

    xk = xk(valid_data);
    yk = yk(valid_data);


    %% 개별 Trial 저장

    raw(k).x = xk;
    raw(k).y = yk;
    raw(k).trial = trial_num(k);


    %% 전체 데이터 통합

    x_all = [x_all; xk];
    y_all = [y_all; yk];


    fprintf( ...
        '  -> %d cycles loaded\n', ...
        numel(xk));

end


%% ---------------------------------------------------------
% 최종 확인
% ---------------------------------------------------------

assert(~isempty(x_all), ...
    'No valid regression data were loaded.');

fprintf('----------------------------------------\n');
fprintf('Total cycles: %d\n', numel(x_all));
fprintf('========================================\n\n');

end