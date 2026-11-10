%% === Calibration Stable Segment Extractor (std-binning + level merge, one-per-level) ===
clear; clc;

%% 0) CSV 선택 & 로드
[filename, pathname] = uigetfile('*.csv', '칼리브레이션 CSV 선택');
if isequal(filename, 0), error('파일이 선택되지 않았습니다.'); end
csv_path = fullfile(pathname, filename);
T = readtable(csv_path);

% time_ms는 필수
assert(ismember('time_ms', T.Properties.VariableNames), 'CSV에 time_ms가 없습니다.');

%% ☆☆☆ 여기만 추가한 부분: 몇 번째 열을 쓸지 지정 ☆☆☆
DATA_COL_IDX = 4;     % ← 너 CSV에서 각도/센서값이 들어있는 열 번호로 바꿔
                      % 예) time_ms, CH1_raw, CH2_raw, CH1_lpf ... 이면 4 이런 식으로

if DATA_COL_IDX < 1 || DATA_COL_IDX > width(T)
    error('DATA_COL_IDX가 테이블 열 개수 범위를 벗어났습니다.');
end

t  = T.time_ms * 1e-3;          % [s]
y  = T{:, DATA_COL_IDX};        % 내가 지정한 열의 데이터

% ===== LPF 추가 (1차) =====
USE_LPF   = true;               % 필요 없으면 false
LPF_FC_HZ = 5;                  % 컷오프 주파수(Hz) 원하는 값
if USE_LPF
    dt = median(diff(t));
    RC = 1/(2*pi*LPF_FC_HZ);
    alpha = dt / (RC + dt);
    y_f = zeros(size(y));
    y_f(1) = y(1);
    for i = 2:numel(y)
        y_f(i) = y_f(i-1) + alpha * (y(i) - y_f(i-1));
    end
    y = y_f;   % 이후 코드는 전부 필터된 걸로 진행
end

fs = 1 / median(diff(t));       % 샘플링 주파수 추정

% 1) 분석 구간 선택 (마우스 2클릭 또는 수동 지정)
USE_INTERACTIVE = true;            % true면 그래프에서 시작/끝 클릭

if USE_INTERACTIVE
    figure('Color','w'); hold on; grid on; box on;
    scatter(t, y, 6, [0.75 0.75 0.75], 'filled');
    xlabel('Time [s]'); ylabel('Ankle Angle [deg]');
    title('전체 데이터: 구간 시작/끝을 차례대로 클릭하세요 (2번 클릭)');
    [xsel, ~] = ginput(2);
    t0 = min(xsel); t1 = max(xsel);
    close;
else
    t0 = 0;                         % 수동 시작시간 [s]
    t1 = max(t);                    % 수동 종료시간 [s]
end

mask = (t >= t0) & (t <= t1);
tt = t(mask); yy = y(mask);
if numel(tt) < 5, error('선택한 구간 데이터가 너무 적습니다.'); end
fs_win = 1 / median(diff(tt));

%% 2) 파라미터 (필요 부분만 조정하면 됨)
win_sec        = 1.5;
step_sec       = 0.20;
std_thresh_deg = 0.50;
range_thresh   = 0.60;
bin_width_deg  = 0.50;
merge_gap_sec  = 4.0;
y_tol_deg      = 0.40;
gap_tol_sec    = 0.60;
SNAP_GRID_DEG  = [];
PICK_CRITERION = 'longest';

% 3) 선택 구간 미리 보기
close all;
figure('Color','w'); hold on; grid on; box on;
scatter(t, y, 6, [0.85 0.85 0.85], 'filled');     % 전체
scatter(tt, yy, 8, [0.30 0.30 0.30], 'filled');   % 선택 구간
xlim([t0 t1]); xlabel('Time [s]'); ylabel('Ankle Angle [deg]');
title(sprintf('선택 구간 [%0.3f ~ %0.3f] s', t0, t1));

% 4) 이동창 기반 평탄 후보 검출 (아래부터는 네가 처음 보낸 구조 그대로)
fsx   = 1 / median(diff(tt));
Nw    = max(3, round(win_sec  * fsx));
Step  = max(1, round(step_sec * fsx));
Nmerge_idx = round(merge_gap_sec * fsx);

W = [];  % [t_start t_end mean std range bin_id start_idx end_idx]
for i = 1:Step:(numel(yy)-Nw+1)
    idx = i:(i+Nw-1);
    yi  = yy(idx);
    m   = mean(yi);
    s   = std(yi,0,'omitnan');
    r   = max(yi)-min(yi);
    if s <= std_thresh_deg && r <= range_thresh
        bin_id = round(m / bin_width_deg);   % 평균값으로 binning
        W = [W; tt(idx(1)) tt(idx(end)) m s r bin_id i (i+Nw-1)];
    end
end

if isempty(W)
    warning('조건을 만족하는 평탄 창이 없습니다. (std/range 기준)');
    seg_st = []; seg_ed = []; seg_bin = [];
else
    % 5) bin별 시간 병합 → 세그먼트 생성
    seg_st = []; seg_ed = []; seg_bin = []; seg_m = []; seg_s = [];
    [~,ord] = sort(W(:,1)); W = W(ord,:);         % 시작시간 정렬
    bins = unique(W(:,6)).';
    for b = bins
        Wi = W(W(:,6)==b, :);                     % 같은 레벨(bin)
        st = Wi(1,7); ed = Wi(1,8); ms = Wi(1,3); ss = Wi(1,4); n=1;
        for k = 2:size(Wi,1)
            gap_idx = Wi(k,7) - ed - 1;
            if gap_idx <= Nmerge_idx
                ed = Wi(k,8);
                ms = ms + Wi(k,3); ss = ss + Wi(k,4); n = n+1;
            else
                seg_st(end+1) = st; seg_ed(end+1) = ed; seg_bin(end+1) = b; %#ok<AGROW>
                seg_m(end+1)  = ms/n; seg_s(end+1)  = ss/n;
                st = Wi(k,7);  ed = Wi(k,8);  ms = Wi(k,3);  ss = Wi(k,4); n=1;
            end
        end
        seg_st(end+1) = st; seg_ed(end+1) = ed; seg_bin(end+1) = b; %#ok<AGROW>
        seg_m(end+1)  = ms/n; seg_s(end+1)  = ss/n;
    end

    % 시간 순 정렬
    [~,ord] = sort(tt(seg_st));
    seg_st = seg_st(ord); seg_ed = seg_ed(ord);
    seg_bin = seg_bin(ord); seg_m = seg_m(ord); seg_s = seg_s(ord);

    % 6) 레벨 병합 (빈이 달라도 y가 비슷하고 틈이 짧으면 하나로)
    if ~isempty(seg_st)
        nseg    = numel(seg_st);
        seg_t0  = tt(seg_st);                 % 시작시각
        seg_t1  = tt(seg_ed);                 % 종료시각
        seg_mid = (seg_t0 + seg_t1)/2;
        seg_med = zeros(nseg,1); seg_std = zeros(nseg,1);
        for i = 1:nseg
            yi = yy(seg_st(i):seg_ed(i));
            seg_med(i) = median(yi,'omitnan');
            seg_std(i) = std(yi,0,'omitnan');
        end

        % ★여기 구조 그대로★
        merged = struct('st',{},'ed',{},'t0',{},'t1',{},'med',{},'mid',{},'std',{},'len',{});
        cur_st = seg_st(1); cur_ed = seg_ed(1);
        cur_t0 = seg_t0(1); cur_t1 = seg_t1(1);
        cur_med= seg_med(1); cur_mid= seg_mid(1);
        cur_std= seg_std(1);

        for i = 2:nseg
            gap_s = seg_t0(i) - cur_t1;
            if abs(seg_med(i) - cur_med) <= y_tol_deg && gap_s <= gap_tol_sec
                cur_ed = max(cur_ed, seg_ed(i));
                cur_t1 = max(cur_t1, seg_t1(i));
                len_prev = cur_t1 - cur_t0;
                len_i    = seg_t1(i) - seg_t0(i);
                if (len_prev + len_i) > eps
                    cur_med = (cur_med*len_prev + seg_med(i)*len_i) / (len_prev + len_i);
                    cur_std = (cur_std*len_prev + seg_std(i)*len_i) / (len_prev + len_i);
                end
                cur_mid = (cur_t0 + cur_t1)/2;
            else
                merged(end+1) = struct('st',cur_st,'ed',cur_ed,'t0',cur_t0,'t1',cur_t1,...
                                       'med',cur_med,'mid',cur_mid,'std',cur_std,'len',cur_t1-cur_t0); %#ok<AGROW>
                cur_st = seg_st(i); cur_ed = seg_ed(i);
                cur_t0 = seg_t0(i); cur_t1 = seg_t1(i);
                cur_med= seg_med(i); cur_mid= seg_mid(i); cur_std= seg_std(i);
            end
        end
        merged(end+1) = struct('st',cur_st,'ed',cur_ed,'t0',cur_t0,'t1',cur_t1,...
                               'med',cur_med,'mid',cur_mid,'std',cur_std,'len',cur_t1-cur_t0);

        % 병합 결과를 배열로 변환
        seg_st = arrayfun(@(z) z.st,  merged);
        seg_ed = arrayfun(@(z) z.ed,  merged);
        seg_t0 = arrayfun(@(z) z.t0,  merged);
        seg_t1 = arrayfun(@(z) z.t1,  merged);
        seg_med= arrayfun(@(z) z.med, merged);
        seg_std= arrayfun(@(z) z.std, merged);
        seg_len= arrayfun(@(z) z.len, merged);

        % 레벨 키 계산
        if ~isempty(SNAP_GRID_DEG)
            level_key = round(seg_med / SNAP_GRID_DEG) * SNAP_GRID_DEG;
        else
            level_key = round(seg_med / bin_width_deg) * bin_width_deg;
        end

        % 7) 레벨당 1개만 남기기
        levels   = unique(level_key(:));
        keep_idx = zeros(numel(levels),1);
        for k = 1:numel(levels)
            idxs = find(level_key == levels(k));
            switch PICK_CRITERION
                case 'longest'
                    [~, j] = max(seg_len(idxs));
                case 'lowest_std'
                    [~, j] = min(seg_std(idxs));
            end
            keep_idx(k) = idxs(j);
        end

        seg_st   = seg_st(keep_idx);
        seg_ed   = seg_ed(keep_idx);
        seg_t0   = seg_t0(keep_idx);
        seg_t1   = seg_t1(keep_idx);
        seg_med  = seg_med(keep_idx);
        seg_std  = seg_std(keep_idx);
        seg_len  = seg_len(keep_idx);
        level_key= level_key(keep_idx);
    end
end

% 8) 시각화 (최종 세그만 강조)
figure('Color','w'); hold on; grid on; box on;
scatter(t, y, 6, [0.85 0.85 0.85], 'filled');      % 전체
scatter(tt, yy, 8, [0.30 0.30 0.30], 'filled');    % 선택 구간
xlim([t0 t1]); xlabel('Time [s]'); ylabel('Ankle Angle [deg]');
title('최종 평탄 세그먼트(레벨당 1개)');

nseg = numel(seg_st);
repr_time = zeros(nseg,1);
repr_val  = zeros(nseg,1);
cmap = lines(max(1,nseg));

for k = 1:nseg
    idx   = seg_st(k):seg_ed(k);
    v_rep = median(yy(idx), 'omitnan');
    t_mid = mean([tt(idx(1)) tt(idx(end))]);
    scatter(tt(idx), yy(idx), 16, cmap(k,:), 'filled');
    plot([tt(idx(1)) tt(idx(end))], [v_rep v_rep], '-', 'Color', cmap(k,:), 'LineWidth', 2.5);
    plot(t_mid, v_rep, 'o', 'MarkerFaceColor', cmap(k,:), 'MarkerEdgeColor','k');

    repr_time(k) = t_mid;
    repr_val(k)  = v_rep;
end

%% 9) 저장 (네가 원래 쓰던 방식 그대로)
[in_dir, in_name, ~] = fileparts(csv_path);
suffix  = sprintf('_stdBin_w%.1fs_bw%.2f', win_sec, bin_width_deg);
out_csv = fullfile(in_dir, [in_name suffix '_final.csv']);

if nseg > 0
    [repr_time_sorted, sort_idx] = sort(repr_time, 'ascend');
    repr_val_sorted  = repr_val(sort_idx);
    seg_t0_sorted    = seg_t0(sort_idx);
    seg_t1_sorted    = seg_t1(sort_idx);
    seg_len_sorted   = seg_len(sort_idx);
    seg_std_sorted   = seg_std(sort_idx);
    level_key_sorted = level_key(sort_idx);

    Res = table(repr_time_sorted, repr_val_sorted, seg_t0_sorted(:), seg_t1_sorted(:), ...
                seg_len_sorted(:), seg_std_sorted(:), level_key_sorted(:), ...
        'VariableNames', {'time_s','angle_deg','seg_t0','seg_t1','duration_s','seg_std','level'});

    writetable(Res, out_csv);
    fprintf('[DONE] segments(final)=%d (sorted by time ↑) → saved: %s\n', nseg, out_csv);

    out_txt = fullfile(in_dir, [in_name '_angles.txt']);
    fid = fopen(out_txt, 'w');

    fprintf(fid, '%.2f', repr_val_sorted(1));
    for i = 2:length(repr_val_sorted)
        fprintf(fid, ',%.2f', repr_val_sorted(i));
    end
    fprintf(fid, '\n');

    ref_vals = 45:-4:(45 - 4*(length(repr_val_sorted)-1));
    fprintf(fid, '%.2f', ref_vals(1));
    for i = 2:length(ref_vals)
        fprintf(fid, ',%.2f', ref_vals(i));
    end
    fprintf(fid, '\n');

    fclose(fid);
    fprintf('[TXT] Saved (time-sorted) angle list → %s\n', out_txt);
else
    warning('최종 세그먼트가 없습니다.');
end
