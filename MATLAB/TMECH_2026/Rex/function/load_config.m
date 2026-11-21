function [cfg, params] = load_config(root_dir, cfg)

config_file = fullfile(root_dir, 'config.txt');
s = dbstack;

% ===============================
% default 값
% ===============================
cfg.IC_AngleDiff = 0;
cfg.SearchWinSec = 0.1;

params.TO_IC_time_bias = 0.0;
params.refractory_time = 0.3;
params.left_right_video_flip = 1;

% ===============================
% config 파일 읽기
% ===============================
if isfile(config_file)

    fid = fopen(config_file, 'r');
    assert(fid ~= -1, '[%s] config.txt 파일을 열 수 없습니다.', s(1).name);

    while ~feof(fid)

        line = strtrim(fgetl(fid));
        if isempty(line), continue; end

        tokens = strsplit(line);
        if numel(tokens) < 2, continue; end

        key = tokens{1};
        val = str2double(tokens{2});

        if isnan(val), continue; end

        switch key
            case 'refractory_time'
                params.refractory_time = val;

            case 'TO_IC_time_bias'
                params.TO_IC_time_bias = val;

            case 'IC_AngleDiff'
                cfg.IC_AngleDiff = val;

            case 'SearchWinSec'
                cfg.SearchWinSec = val;

            case 'left_right_video_flip'
                params.left_right_video_flip = val;

            otherwise
                warning('Unknown config key: %s', key);
        end
    end

    fclose(fid);
    fprintf('[%s] config.txt loaded\n', s(1).name);

else
    fprintf('[%s] config.txt 없음 → default 값 사용\n', s(1).name);
end

% ===============================
% 출력 로그
% ===============================
fprintf('[%s] refractory_time: %.3f s\n', s(1).name, params.refractory_time);
fprintf('[%s] TO_IC_time_bias: %.3f s\n', s(1).name, params.TO_IC_time_bias);
fprintf('[%s] IC_AngleDiff: %.3f deg\n', s(1).name, cfg.IC_AngleDiff);
fprintf('[%s] SearchWinSec: %.3f s\n', s(1).name, cfg.SearchWinSec);
fprintf('[%s] left_right_video_flip: %d\n', s(1).name, params.left_right_video_flip);
fprintf('[%s] load config clear \n', s(1).name);

end