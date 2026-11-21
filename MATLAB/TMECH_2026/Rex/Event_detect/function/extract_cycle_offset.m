function right_cycles_tbl = extract_cycle_offset( ...
    main_left, main_right, t)

% =========================================================
% extract_cycle_offset
%
% Right gait cycle을 기준으로
% cycle period T_R 및 다음 Left peak까지의
% time offset Δt를 계산한다.
%
% Matching condition:
%   1. Same time interval
%   2. Left peak must lie inside current Right cycle
%
% Output
%   right_cycles_tbl.period_s
%   right_cycles_tbl.delay_to_next_left_s
% =========================================================


%% ---------------------------------------------------------
% Right Gait Cycle 생성
% ---------------------------------------------------------

[right_cycles_tbl, ~] = ...
    events_to_cycles_table( ...
        main_right, ...
        t, ...
        'right');


assert(~isempty(right_cycles_tbl), ...
    '검출된 Right gait cycle이 없습니다.');


%% ---------------------------------------------------------
% Right Cycle Statistics
% ---------------------------------------------------------

valid = ...
    right_cycles_tbl.period_s > 0 & ...
    isfinite(right_cycles_tbl.period_s);

fprintf( ...
    ['[RIGHT] cycles: N=%d, ' ...
     'meanT=%.3f s, medianT=%.3f s\n'], ...
    nnz(valid), ...
    mean(right_cycles_tbl.period_s(valid)), ...
    median(right_cycles_tbl.period_s(valid)));


%% ---------------------------------------------------------
% Left Peak Flattening
% ---------------------------------------------------------

l_times = [];
l_idx   = [];
l_int   = [];
l_seq   = [];


for k = 1:numel(main_left)

    if isempty(main_left(k).idx)
        continue;
    end

    n = numel(main_left(k).t);


    % Peak time
    l_times = [ ...
        l_times; ...
        main_left(k).t(:)];


    % Original index
    l_idx = [ ...
        l_idx; ...
        main_left(k).idx(:)];


    % Interval ID
    l_int = [ ...
        l_int; ...
        repmat(k, n, 1)];


    % Peak ID within interval
    l_seq = [ ...
        l_seq; ...
        (1:n)'];

end


%% Time 순으로 정렬

[lt, order] = sort(l_times);

l_idx = l_idx(order);
l_int = l_int(order);
l_seq = l_seq(order);


%% ---------------------------------------------------------
% Right Cycle → Left Peak Matching
% ---------------------------------------------------------

R = height(right_cycles_tbl);

next_l_time = nan(R,1);
next_l_idx  = nan(R,1);

left_int = nan(R,1);
left_seq = nan(R,1);

within_cycle = false(R,1);


for i = 1:R

    % Current Right cycle
    t0 = ...
        right_cycles_tbl.start_peak_time_s(i);

    t1 = ...
        right_cycles_tbl.end_peak_time_s(i);

    right_int = ...
        right_cycles_tbl.interval_id(i);


    %% Same interval + inside current Right cycle

    j = find( ...
        lt >= t0 & ...
        lt <= t1 & ...
        l_int == right_int, ...
        1, ...
        'first');


    if isempty(j)
        continue;
    end


    next_l_time(i) = lt(j);
    next_l_idx(i)  = l_idx(j);

    left_int(i) = l_int(j);
    left_seq(i) = l_seq(j);

    within_cycle(i) = true;

end


%% ---------------------------------------------------------
% Table에 결과 추가
% ---------------------------------------------------------

right_cycles_tbl.next_left_peak_time_s = ...
    next_l_time;

right_cycles_tbl.next_left_peak_idx = ...
    next_l_idx;

right_cycles_tbl.left_interval_id = ...
    left_int;

right_cycles_tbl.left_peak_id_in_interval = ...
    left_seq;


% Right → Left offset Δt
right_cycles_tbl.delay_to_next_left_s = ...
    next_l_time - ...
    right_cycles_tbl.start_peak_time_s;


right_cycles_tbl.left_within_right_cycle = ...
    within_cycle;


%% ---------------------------------------------------------
% Matching Statistics
% ---------------------------------------------------------

fprintf( ...
    '[MATCH] Left peak matched: %d / %d cycles\n', ...
    nnz(within_cycle), ...
    R);

end