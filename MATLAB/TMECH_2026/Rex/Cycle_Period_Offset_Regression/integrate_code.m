%% === 통합: *_right_cycles_with_left_delay.csv → combined_right_...csv ===
% 사용자가 폴더 지정
targetdir = uigetdir(pwd, 'Select folder containing *_right_cycles_with_left_delay.csv');
if targetdir == 0
    error('No folder selected. Process cancelled.');
end

files  = dir(fullfile(targetdir,'*_right_cycles_with_left_delay.csv'));
assert(~isempty(files), '선택한 폴더에 *_right_cycles_with_left_delay.csv 가 없습니다.');

ALL = table();
for k = 1:numel(files)
    fp = fullfile(files(k).folder, files(k).name);
    fprintf('Reading: %s\n', files(k).name);
    try
        T = readtable(fp, 'VariableNamingRule','preserve');   % R2019b+
    catch
        T = readtable(fp, 'PreserveVariableNames', true);     % 구버전 대비
    end
    T.source_file = repmat(string(files(k).name), height(T), 1);

    if isempty(ALL)
        ALL = T;
    else
        try
            ALL = [ALL; T];
        catch
            vnA = ALL.Properties.VariableNames; 
            vnB = T.Properties.VariableNames;
            missB = setdiff(vnA, vnB);  
            for i=1:numel(missB), T.(missB{i}) = NaN(height(T),1); end
            missA = setdiff(vnB, vnA);  
            for i=1:numel(missA), ALL.(missA{i}) = NaN(height(ALL),1); end
            ALL = [ALL; T];
        end
    end
end

out_combined = fullfile(targetdir,'combined_right_cycles_with_left_delay.csv');
writetable(ALL, out_combined);
fprintf('Combined saved: %s\n', out_combined);
