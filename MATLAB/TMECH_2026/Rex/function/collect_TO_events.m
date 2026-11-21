function t_all = collect_TO_events(main_struct, field_name)

t_all = [];

for k = 1:numel(main_struct)
    if isfield(main_struct(k), field_name) && ~isempty(main_struct(k).(field_name))
        t_all = [t_all; main_struct(k).(field_name)(:)];
    end
end

end