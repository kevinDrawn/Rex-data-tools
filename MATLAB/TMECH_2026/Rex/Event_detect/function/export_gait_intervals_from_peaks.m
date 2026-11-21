function outpath = export_gait_intervals_from_peaks(main_struct, side, varargin)
% export_gait_intervals_from_peaks
%   구조배열 main_struct(k).t 에 들어있는 시점들을 각 세그먼트(k)별로
%   이웃한 쌍 [t_i, t_{i+1}] → [start_time, final_time]로 묶어 파일로 저장.
%
% 사용:
%   outpath = export_gait_intervals_from_peaks(main_left,  'Left',  ...
%                   'OutDir', '', 'BaseName', 'exoskel_log_20250913_050034', 'FileType', 'xlsx');
%   outpath = export_gait_intervals_from_peaks(main_right, 'Right', ...);
%
% 입력:
%   main_struct : 1xN struct, 각 원소에 .t (1xM_k double)가 있어야 함
%   side        : 'Left' or 'Right' (파일명 접두/시트명에 사용)
%
% Name-Value 옵션:
%   'OutDir'   : 저장 폴더 (기본: 폴더 선택창)
%   'BaseName' : 파일명에 붙일 원본 로그명 등 (기본: timestamp)
%   'FileType' : 'xlsx' | 'csv' (기본 'xlsx')
%   'Sheet'    : xlsx 시트명 (기본: 'Intervals')
%   'AddCols'  : 추가 컬럼 출력 여부 (duration 등) (기본 true)
%
% 출력:
%   outpath     : 저장된 파일 경로 (문자열)

    % ---- 옵션 파싱 ----
    p = inputParser;
    p.addRequired('main_struct', @(s) isstruct(s) || isempty(s));
    p.addRequired('side', @(c) ischar(c) || isstring(c));
    p.addParameter('OutDir','', @(c) ischar(c) || isstring(c));
    p.addParameter('BaseName','', @(c) ischar(c) || isstring(c));
    p.addParameter('FileType','xlsx', @(c) any(strcmpi(c,{'xlsx','csv'})));
    p.addParameter('Sheet','Intervals', @(c) ischar(c) || isstring(c));
    p.addParameter('AddCols',true, @(b) islogical(b) && isscalar(b));
    p.parse(main_struct, side, varargin{:});
    opt = p.Results;

    side = char(string(side));
    outDir = char(string(opt.OutDir));
    baseName = char(string(opt.BaseName));
    filetype = lower(char(string(opt.FileType)));
    sheet = char(string(opt.Sheet));
    addCols = opt.AddCols;

    % ---- 출력 폴더 결정 ----
    if isempty(outDir)
        outDir = uigetdir(pwd, sprintf('Select folder to save %s intervals', side));
        assert(~isequal(outDir,0), '저장 폴더를 선택하지 않았습니다.');
    end
    assert(isfolder(outDir), '폴더가 존재하지 않습니다: %s', outDir);

    % ---- 파일명 구성 ----
    if isempty(baseName)
        ts = datestr(now,'yyyymmdd_HHMMSS');
        baseName = sprintf('log_%s', ts);
    end
    switch filetype
        case 'xlsx'
            outpath = fullfile(outDir, sprintf('gait_intervals_%s_%s.xlsx', side, baseName));
        otherwise % 'csv'
            outpath = fullfile(outDir, sprintf('gait_intervals_%s_%s.csv', side, baseName));
    end

    % ---- 메인 로직: 이웃 시점 쌍 만들기 ----
    N = numel(main_struct);
    Seg   = [];           % 세그먼트 인덱스
    Start = [];           % 시작 시간
    Final = [];           % 종료 시간
    Count = [];           % 해당 세그먼트 내 원천 피크 개수(참고용)

    for k = 1:N
        if ~isfield(main_struct(k),'t') || isempty(main_struct(k).t)
            continue;
        end
        tk = sort(main_struct(k).t(:)');  % 시점 오름차순
        if numel(tk) < 2
            % 이웃쌍을 만들 수 없음 → 스킵
            continue;
        end
        % [t1,t2], [t2,t3], ..., [t_{m-1}, t_m]
        start_k = tk(1:end-1);
        final_k = tk(2:end);
        Seg   = [Seg,   k*ones(1, numel(start_k))];
        Start = [Start, start_k];
        Final = [Final, final_k];
        Count = [Count, numel(tk)*ones(1, numel(start_k))];
    end

    % ---- 테이블 구성 ----
    if addCols
        Duration = Final - Start;
        T = table(Seg(:), Start(:), Final(:), Duration(:), Count(:), ...
            'VariableNames', {'segment_id','start_time','final_time','duration','num_peaks_in_segment'});
    else
        T = table(Seg(:), Start(:), Final(:), ...
            'VariableNames', {'segment_id','start_time','final_time'});
    end

    % ---- 저장 ----
    T_out = T(:, {'start_time','final_time'});   % ← 2,3열만 남기기
    
    if strcmp(filetype,'xlsx')
        writetable(T_out, outpath, 'Sheet', sheet);
    else
        writetable(T_out, outpath);
    end

    fprintf('[%s] intervals saved: %s  (rows: %d)\n', side, outpath, height(T));
end
