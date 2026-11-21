%% === (대화형) 8,15열 기준 중복 제거 후 저장 ===
% 1) 원본 파일 선택
[fn, fp_in] = uigetfile({'*.csv','CSV files'}, 'Select source CSV');
if isequal(fn,0), error('No file selected.'); end
src = fullfile(fp_in, fn);

% 2) 읽기
T = readtable(src, 'VariableNamingRule','preserve', 'TextType','string');

% 3) 8열 & 15열 기준 중복 제거
[~, ia] = unique(T(:, [8 15]), 'rows', 'stable');
T_dedup = T(ia, :);

% 4) 저장 위치/이름 선택(기본 이름은 _dedup)
[~, base, ~] = fileparts(src);
[fn_out, fp_out] = uiputfile({'*.csv','CSV files'}, 'Save dedup CSV as', ...
                             fullfile(fp_in, base + "_dedup.csv"));
if isequal(fn_out,0), error('Save cancelled.'); end
outfp = fullfile(fp_out, fn_out);

% 5) 저장
writetable(T_dedup, outfp);
fprintf('Removed %d duplicate rows. Saved file: %s\n', ...
        height(T) - height(T_dedup), outfp);
