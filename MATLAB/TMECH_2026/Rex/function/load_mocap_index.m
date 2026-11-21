function mocap_index = load_mocap_index(motion_dir, camera_fs, left_right_video_flip)

% ===============================
% 초기화
% ===============================
mocap_index = struct();
trial_map = containers.Map();

trial_count = 0;

% ===============================
% 폴더 탐색
% ===============================
folders = dir(motion_dir);
folders = folders([folders.isdir]);
folders = folders(~ismember({folders.name}, {'.','..'}));

s = dbstack;

% ===============================
% Loop
% ===============================
for i = 1:length(folders)

    folder_name = folders(i).name;

    % -------------------------
    % Side 판별
    % -------------------------
    side = parse_side(folder_name);
    if isempty(side), continue; end

    % flip 적용
    if left_right_video_flip == 0
        side = flip_side(side);
    end

    % -------------------------
    % Trial key 추출
    % -------------------------
    trial_key = parse_trial_key(folder_name);
    if isempty(trial_key), continue; end

    % -------------------------
    % trial index
    % -------------------------
    if isKey(trial_map, trial_key)
        t = trial_map(trial_key);
    else
        trial_count = trial_count + 1;
        t = trial_count;
        trial_map(trial_key) = t;

        mocap_index(t).trial = trial_key;
        mocap_index(t).left  = struct();
        mocap_index(t).right = struct();
    end

    % -------------------------
    % CSV 로드
    % -------------------------
    data = load_stance_csv(motion_dir, folder_name);
    if isempty(data), continue; end

    % -------------------------
    % 데이터 파싱
    % -------------------------
    frame = data(:,1);
    frame_sec = frame / camera_fs;

    fore = data(:,2:3);
    hind = data(:,4:5);

    % -------------------------
    % 저장
    % -------------------------
    mocap_index(t).(side).time = frame_sec;

    mocap_index(t).(side).fore.IC = frame_sec(fore(:,1) > 0);
    mocap_index(t).(side).fore.TO = frame_sec(fore(:,2) > 0);

    mocap_index(t).(side).hind.IC = frame_sec(hind(:,1) > 0);
    mocap_index(t).(side).hind.TO = frame_sec(hind(:,2) > 0);

    mocap_index(t).(side).folder = folder_name;

    fprintf('[Trial %d] %s (%s)\n', t, trial_key, side);

end

fprintf('[%s] mocap_index 생성 완료 (%d trials)\n', s(1).name, trial_count);

end

function side = parse_side(folder_name)

if contains(lower(folder_name), 'left')
    side = 'left';
elseif contains(lower(folder_name), 'right')
    side = 'right';
else
    side = '';
end

end

function side_out = flip_side(side)

if strcmp(side, 'left')
    side_out = 'right';
else
    side_out = 'left';
end

end

function trial_key = parse_trial_key(folder_name)

tokens = regexp(folder_name, '\d{2}-\d{2}-\d{2}', 'match');

if isempty(tokens)
    trial_key = '';
else
    trial_key = tokens{end};
end

end

function data = load_stance_csv(root_dir, folder_name)

joint_path = fullfile(root_dir, folder_name, 'joint_data');

if ~isfolder(joint_path)
    data = [];
    return;
end

csv_files = dir(fullfile(joint_path, '*stance*.csv'));

if isempty(csv_files)
    data = [];
    return;
end

file_path = fullfile(joint_path, csv_files(1).name);

data = readmatrix(file_path);

% fprintf('[%s] loading mocap data clear', s(1).name);

end
