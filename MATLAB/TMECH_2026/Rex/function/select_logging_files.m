function [log_file, t_interval] = select_logging_files(root_dir)

log_dir = fullfile(root_dir, 'logging');
assert(isfolder(log_dir), 'logging 폴더가 없습니다: %s', log_dir);

s= dbstack;

% ===============================
% Log Excel 선택
% ===============================
xls_list = [ ...
    dir(fullfile(log_dir,'*.csv')); ...
    dir(fullfile(log_dir,'*.xls')); ...
    dir(fullfile(log_dir,'*.xlsx'))];

assert(~isempty(xls_list), '[%s] logging 폴더에 엑셀 파일이 없습니다.', s(1).name);

if numel(xls_list) == 1
    log_file = fullfile(log_dir, xls_list(1).name);
else
    [efn, edir] = uigetfile({'*.xlsx;*.xls;*.csv','Excel logs'}, ...
        '로그 엑셀을 선택하세요', log_dir);
    assert(~isequal(efn,0), '[%s] 로그 엑셀을 선택하지 않았습니다.', s(1).name);
    log_file = fullfile(edir, efn);
end

% ===============================
% Interval TXT 선택
% ===============================
txt_list = dir(fullfile(log_dir, '*.txt'));
assert(~isempty(txt_list), '[%s] logging 폴더에 interval TXT 파일이 없습니다.', s(1).name);

if numel(txt_list) == 1
    interval_file = fullfile(log_dir, txt_list(1).name);
else
    [tfn, tdir] = uigetfile({'*.txt','Interval TXT'}, ...
        '인터벌 TXT를 선택하세요', log_dir);
    assert(~isequal(tfn,0), '[%s] 인터벌 TXT를 선택하지 않았습니다.', s(1).name);
    interval_file = fullfile(tdir, tfn);
end

% ---------------- 인터벌 TXT 읽기 → t_interval ----------------
t_interval = load_intervals_file(interval_file);
assert(size(t_interval,2)==2, '[%s] interval 파일은 2열 [start final]이어야 합니다.', s(1).name);
assert(all(isfinite(t_interval(:))), '[%s] interval 파일에 NaN/Inf가 있습니다.', s(1).name);
assert(all(t_interval(:,2) > t_interval(:,1)), '[%s] final_time > start_time 조건 위반 행이 있습니다.', s(1).name);

% ===============================
% 출력
% ===============================
fprintf('[%s] Log Excel: %s\n', s(1).name, log_file);
fprintf('[%s] Interval TXT: %s\n', s(1).name, interval_file);

end