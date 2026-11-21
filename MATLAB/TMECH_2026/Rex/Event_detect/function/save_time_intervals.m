function save_time_intervals(root_dir, t_interval)

% =========================================================
% save_time_intervals
%
% t_interval을 logging/t_interval.txt로 저장
% =========================================================

logging_dir = fullfile(root_dir, 'logging');

assert(isfolder(logging_dir), ...
    'logging 폴더를 찾을 수 없습니다: %s', ...
    logging_dir);

outfile = fullfile( ...
    logging_dir, ...
    't_interval.txt');


%% Save

fid = fopen(outfile, 'w');

assert(fid ~= -1, ...
    '파일을 열 수 없습니다: %s', outfile);

fprintf(fid, '%.6g %.6g\n', t_interval.');

fclose(fid);


fprintf( ...
    'Saved t_interval: %s\n', ...
    outfile);

end