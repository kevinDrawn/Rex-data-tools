function TI = load_intervals_file(fpath)
% load_intervals_file  TXT/CSV에서 [start, final] 두 열을 숫자 행렬로 반환
% - 공백/탭/쉼표 구분자 자동 처리
% - 헤더가 있어도 시도하여 숫자만 추림
% - 잘못된/빈 행 제거, start>final이면 자동 스왑(경고)

    TI = [];
    ok = false;

    % 1) readmatrix 시도 (R2019a+)
    try
        M = readmatrix(fpath);  % 숫자만 오면 가장 깔끔
        if ~isempty(M)
            ok = true;
        end
    catch
        ok = false;
    end

    % 2) readtable 로 재시도 (헤더 있는 경우)
    if ~ok
        try
            T = readtable(fpath, 'FileType','text');
            M = table2array(T);
            ok = ~isempty(M);
        catch
            ok = false;
        end
    end

    % 3) textscan 최후 시도 (공백/탭/쉼표)
    if ~ok
        try
            fid = fopen(fpath, 'r');
            assert(fid>0, '파일을 열 수 없습니다.');
            C = textscan(fid, '%f%f', 'Delimiter', {' ', '\t', ','}, ...
                         'MultipleDelimsAsOne', true, 'HeaderLines', 0);
            fclose(fid);
            M = [C{1}, C{2}];
            ok = ~isempty(M);
        catch
            try, fclose(fid); end %#ok<*TRYNC>
            error('interval 파일을 읽을 수 없습니다: %s', fpath);
        end
    end

    % 숫자만 남기고 선별
    if ~isnumeric(M), M = double(M); end
    if size(M,2) < 2
        error('interval 파일에 2개 이상의 열이 필요합니다. (start, final)');
    end
    TI = M(:,1:2);

    % NaN/Inf 행 제거
    bad = any(~isfinite(TI),2);
    if any(bad)
        warning('interval의 %d개 행에 NaN/Inf가 있어 제거합니다.', sum(bad));
        TI = TI(~bad,:);
    end

    % start > final 인 행 스왑 (경고)
    inv = TI(:,1) > TI(:,2);
    if any(inv)
        warning('%d개 행에서 start>final 입니다. 두 값을 스왑합니다.', sum(inv));
        TI(inv,:) = fliplr(TI(inv,:));
    end

    % 중복/정렬(선택) : 필요하면 주석 해제
    % TI = unique(TI, 'rows', 'stable');
    % TI = sortrows(TI, 1);
end
