function [T, idx_windows] = events_to_cycles_table(main, t, signame)
% main: find_main_peaks_by_minima 결과(struct 배열)
% t    : 시간 벡터
% signame: 'left' 같은 라벨(저장/식별용)
%
% 반환:
%  T: 테이블
%    - interval_id           : 몇 번째 t_interval인지
%    - cycle_id_in_interval  : 해당 구간 내 사이클 번호 (1..p-1)
%    - global_cycle_id       : 모든 구간 이어붙인 순번
%    - start_peak_idx        : 사이클 시작(0%) 피크의 원본 인덱스
%    - start_peak_time_s     : 위 피크 시각
%    - end_peak_idx          : 다음 이벤트(사이클 끝) 인덱스
%    - end_peak_time_s       : 끝 시각
%    - period_s              : 주기 (끝-시작)
%    - n_samples             : 포함 샘플 수 (start_idx:end_idx)
%    - signal                : 신호 이름('left' 등)
%
%  idx_windows: 각 사이클의 샘플 인덱스 벡터(start_idx:end_idx)를 담은 cell

rows = {};
idx_windows = {};
g = 0;  % global_cycle_id

for k = 1:numel(main)
    if isempty(main(k).idx), continue; end

    % 시간 기준 정렬(안전)
    [tpk, o] = sort(main(k).t(:));
    idxpk    = main(k).idx(o);
    P = numel(tpk);

    for i = 1:(P-1)
        g = g + 1;

        s_idx = idxpk(i);
        e_idx = idxpk(i+1);
        s_t   = tpk(i);
        e_t   = tpk(i+1);

        % 방어: 혹시라도 뒤집힌 경우 정렬
        if e_idx < s_idx
            tmp = s_idx; s_idx = e_idx; e_idx = tmp;
            tmp = s_t;   s_t   = e_t;   e_t   = tmp;
        end

        period = e_t - s_t;
        n_samp = e_idx - s_idx + 1;

        rows(end+1, :) = { ...
            k, i, g, ...
            s_idx, s_t, ...
            e_idx, e_t, ...
            period, n_samp, ...
            string(signame) ...
        }; %#ok<AGROW>

        idx_windows{end+1,1} = s_idx:e_idx; %#ok<AGROW>
    end
end

T = cell2table(rows, 'VariableNames', { ...
    'interval_id','cycle_id_in_interval','global_cycle_id', ...
    'start_peak_idx','start_peak_time_s', ...
    'end_peak_idx','end_peak_time_s', ...
    'period_s','n_samples','signal' ...
});
end
