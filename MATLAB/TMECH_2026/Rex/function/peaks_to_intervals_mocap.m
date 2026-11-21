function intervals = peaks_to_intervals_mocap(main_struct)

intervals = [];

for k = 1:numel(main_struct)

    if ~isfield(main_struct(k),'t_TO_mocap') || ...
       isempty(main_struct(k).t_TO_mocap)
        continue;
    end

    tk = sort(main_struct(k).t_TO_mocap(:)');

    if numel(tk) < 2, continue; end

    intervals = [intervals; ...
        [tk(1:end-1).' tk(2:end).']]; %#ok<AGROW>
end

end