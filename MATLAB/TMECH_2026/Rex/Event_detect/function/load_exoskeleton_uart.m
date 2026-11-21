function [data, cfg] = load_exoskeleton_uart(root_dir, cfg)

% =========================================================
% load_exoskeleton_uart
%
% Exoskeleton UART CSV 파일을 자동 검출하고,
% angle / torque 데이터를 읽은 뒤 LPF를 적용한다.
%
% Input
%   root_dir : Trial root directory
%   cfg      : Data column / filter configuration
%
% Output
%   data.t              : Time [s]
%   data.left           : Filtered left ankle angle
%   data.right          : Filtered right ankle angle
%   data.left_torque    : Filtered left torque
%   data.right_torque   : Filtered right torque
%   data.fs             : Sampling frequency [Hz]
%   data.Ts             : Sampling period [s]
%   data.file_name      : Selected CSV filename
%
%   cfg.base_name       : CSV base filename
% =========================================================


%% ---------------------------------------------------------
% Logging folder
% ---------------------------------------------------------

logging_dir = fullfile(root_dir, 'logging');

assert(isfolder(logging_dir), ...
    'logging 폴더를 찾을 수 없습니다: %s', ...
    logging_dir);


%% ---------------------------------------------------------
% CSV file detection
% ---------------------------------------------------------

files = dir(fullfile( ...
    logging_dir, ...
    'rex_uart_*.csv'));

assert(~isempty(files), ...
    ['logging 폴더에서 ' ...
     'rex_uart_*.csv 파일을 찾을 수 없습니다.']);


%% ---------------------------------------------------------
% CSV file selection
% ---------------------------------------------------------

if numel(files) == 1

    fname = files(1).name;

else

    file_names = {files.name};

    [idx, tf] = listdlg( ...
        'PromptString', ...
        '분석할 Exoskeleton UART 파일을 선택하세요.', ...
        'SelectionMode','single', ...
        'ListString',file_names, ...
        'ListSize',[500 300]);

    assert(tf == 1, ...
        '파일을 선택하지 않았습니다.');

    fname = files(idx).name;

end


file_path = fullfile(logging_dir, fname);

fprintf('Selected CSV File: %s\n', fname);


%% ---------------------------------------------------------
% CSV Load
% ---------------------------------------------------------

TBL = readtable( ...
    file_path, ...
    'VariableNamingRule','preserve');


%% ---------------------------------------------------------
% Base filename
% ---------------------------------------------------------

[~, base_raw, ~] = fileparts(fname);

base_safe = regexprep( ...
    base_raw, ...
    '[^\w\-]+', ...
    '_');

base_safe = regexprep( ...
    base_safe, ...
    '_+', ...
    '_');

cfg.base_name = base_safe;


%% ---------------------------------------------------------
% Column check
% ---------------------------------------------------------
required_columns = [ ...
    cfg.col_t, ...
    cfg.col_left, ...
    cfg.col_right, ...
    cfg.col_torque_left, ...
    cfg.col_torque_right, ...
    cfg.col_TA, ...
    cfg.col_GM ...
];

assert(all(required_columns >= 1) && ...
       all(required_columns <= width(TBL)), ...
       '설정된 column index가 CSV 범위를 벗어났습니다.');

%% ---------------------------------------------------------
% Data extraction
% ---------------------------------------------------------

t = TBL{:, cfg.col_t} / 1000;

left  = TBL{:, cfg.col_left};
right = TBL{:, cfg.col_right};

left_torque  = TBL{:, cfg.col_torque_left};
right_torque = TBL{:, cfg.col_torque_right};

% Raw EMG (ADS1294 ADC counts)
TA = TBL{:, cfg.col_TA};
GM = TBL{:, cfg.col_GM};

%% ---------------------------------------------------------
% Data validation
% ---------------------------------------------------------

assert( ...
    isvector(t) && ...
    isvector(left) && ...
    isvector(right) && ...
    isvector(TA) && ...
    isvector(GM), ...
    '입력 데이터는 벡터여야 합니다.');

N = numel(t);

assert( ...
    numel(left) == N && ...
    numel(right) == N && ...
    numel(left_torque) == N && ...
    numel(right_torque) == N && ...
    numel(TA) == N && ...
    numel(GM) == N, ...
    '각 signal의 데이터 길이가 서로 다릅니다.');

assert( ...
    all(isfinite(t)) && ...
    all(isfinite(left)) && ...
    all(isfinite(right)) && ...
    all(isfinite(left_torque)) && ...
    all(isfinite(right_torque)) && ...
    all(isfinite(TA)) && ...
    all(isfinite(GM)), ...
    '데이터에 NaN/Inf가 존재합니다.');

assert(all(diff(t) > 0), ...
    'time은 반드시 단조 증가해야 합니다.');

%% ---------------------------------------------------------
% Sampling frequency
% ---------------------------------------------------------

if isempty(cfg.fs)

    dt = diff(t);
    fs = 1 / median(dt);

else

    fs = cfg.fs;

end

assert(isfinite(fs) && fs > 0, ...
    'Sampling frequency 계산에 실패했습니다.');

Ts = 1 / fs;


%% ---------------------------------------------------------
% Low-pass filtering
% ---------------------------------------------------------

if cfg.lpf_on

    [b,a] = butter( ...
        cfg.order, ...
        cfg.fc/(fs/2), ...
        'low');

    left_f = filtfilt(b,a,left);
    right_f = filtfilt(b,a,right);

    left_torque_f = ...
        filtfilt(b,a,left_torque);

    right_torque_f = ...
        filtfilt(b,a,right_torque);

else

    left_f = left;
    right_f = right;

    left_torque_f = left_torque;
    right_torque_f = right_torque;

end


%% ---------------------------------------------------------
% Output
% ---------------------------------------------------------

data.t = t;

data.left = left_f;
data.right = right_f;

data.left_torque = left_torque_f;
data.right_torque = right_torque_f;

% Raw EMG
data.TA = TA;
data.GM = GM;

data.fs = fs;
data.Ts = Ts;

data.file_name = fname;
data.file_path = file_path;

end