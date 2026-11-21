function [TBL, raw, cfg] = parse_log_data(log_file, cfg)

s = dbstack;

% ===============================
% 1. CSV 로드
% ===============================
TBL = readtable(log_file, 'VariableNamingRule','preserve');

% ===============================
% 2. base 이름 생성
% ===============================
[~, base_raw, ~] = fileparts(log_file);
base_safe = regexprep(base_raw, '[^\w\-]+', '_');
base_safe = regexprep(base_safe, '_+', '_');
cfg.base_name = base_safe;

% ===============================
% 3. 열 인덱스 검증
% ===============================
assert(cfg.col_t>=1     && cfg.col_t    <= width(TBL),  '[%s] cfg.col_t 범위 오류', s(1).name);
assert(cfg.col_left>=1  && cfg.col_left <= width(TBL), '[%s] cfg.col_left 범위 오류', s(1).name);
assert(cfg.col_right>=1 && cfg.col_right<= width(TBL), '[%s] cfg.col_right 범위 오류', s(1).name);

assert(cfg.col_left_tor>=1  && cfg.col_left_tor  <= width(TBL), '[%s] cfg.col_left_tor 범위 오류', s(1).name);
assert(cfg.col_right_tor>=1 && cfg.col_right_tor <= width(TBL), '[%s] cfg.col_right_tor 범위 오류', s(1).name);

% ===============================
% 4. 데이터 추출
% ===============================
raw.t     = TBL{:, cfg.col_t} * 0.001; % ms → s
raw.left  = TBL{:, cfg.col_left};
raw.right = TBL{:, cfg.col_right};

raw.left_torque  = TBL{:, cfg.col_left_tor};
raw.right_torque = TBL{:, cfg.col_right_tor};

% ===============================
% 5. 유효성 검사
% ===============================
t    = raw.t;
left = raw.left;
right= raw.right;
lt   = raw.left_torque;
rt   = raw.right_torque;

assert(isvector(t) && isvector(left) && isvector(right) && ...
       isvector(lt) && isvector(rt), ...
       '[%s] 데이터는 모두 벡터여야 합니다.', s(1).name);

assert(numel(t)==numel(left) && numel(t)==numel(right) && ...
       numel(t)==numel(lt)   && numel(t)==numel(rt), ...
       '[%s] 데이터 길이 불일치', s(1).name);

assert(all(isfinite(t)) && all(isfinite(left)) && ...
       all(isfinite(right)) && all(isfinite(lt)) && ...
       all(isfinite(rt)), ...
       '[%s] NaN/Inf 존재', s(1).name);

assert(all(diff(t)>0), '[%s] t는 단조 증가해야 합니다.', s(1).name);

% ===============================
% 6. 로그
% ===============================
fprintf('[%s] Parsed log data: %s\n', s(1).name, log_file);
fprintf('[%s] Data length: %d samples\n', s(1).name, numel(t));

end