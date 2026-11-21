function intervals = peaks_to_intervals(main_struct)
% main_struct(k).t 의 인접 쌍을 [start, final]로 변환
    intervals = [];
    for k = 1:numel(main_struct)
        if ~isfield(main_struct(k),'t_TO') || isempty(main_struct(k).t_TO), continue; end
        tk = sort(main_struct(k).t_TO(:)');
        if numel(tk) < 2, continue; end
        intervals = [intervals; [tk(1:end-1).' tk(2:end).']]; %#ok<AGROW>
    end
end
