function outcsv = save_cycle_offset( ...
    root_dir, fname, right_cycles_tbl)

% =========================================================
% save_cycle_offset
%
% Cycle period + Right-to-Left offset 결과를 CSV로 저장
% =========================================================


%% ---------------------------------------------------------
% Save directory
% ---------------------------------------------------------

savedir = fullfile( ...
    root_dir, ...
    'Cycle Period + Offset 추정 인덱스');


if ~isfolder(savedir)

    mkdir(savedir);

    fprintf( ...
        'Created folder: %s\n', ...
        savedir);

end


%% ---------------------------------------------------------
% Output filename
% ---------------------------------------------------------

[~, base, ~] = fileparts(fname);

outcsv = fullfile( ...
    savedir, ...
    sprintf( ...
    '%s_right_cycles_with_left_delay.csv', ...
    base));


%% ---------------------------------------------------------
% Save
% ---------------------------------------------------------

writetable( ...
    right_cycles_tbl, ...
    outcsv);


fprintf( ...
    'Saved cycle period + offset: %s\n', ...
    outcsv);

end