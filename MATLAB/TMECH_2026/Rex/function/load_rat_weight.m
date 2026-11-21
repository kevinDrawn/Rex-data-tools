function rat_weight = load_rat_weight(root_dir)

s = dbstack;

% ---------------- rat weight 읽기 ----------------
parent_dir = fileparts(root_dir);
weight_file = fullfile(parent_dir, 'rat_weight.txt');

assert(isfile(weight_file), 'rat_weight.txt 파일이 없습니다: %s', weight_file);

fid = fopen(weight_file, 'r');
assert(fid ~= -1, 'rat_weight.txt 파일을 열 수 없습니다.');

rat_weight = fscanf(fid, '%f', 1);
fclose(fid);

assert(~isempty(rat_weight) && isfinite(rat_weight) && rat_weight > 0, ...
    '[%s] rat_weight 값이 올바르지 않습니다.', s(1).name);

fprintf('[%s] Rat weight: %.3f kg (%s)\n', s(1).name, rat_weight, weight_file);

end