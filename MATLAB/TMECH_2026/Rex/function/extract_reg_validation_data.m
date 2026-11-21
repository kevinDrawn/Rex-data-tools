function data = extract_reg_validation_data(root_dir, rat_list, cond_name)

num_rat  = numel(rat_list);
data = struct();

for i = 1:num_rat
    rat_name = rat_list{i};
    base_path = fullfile(root_dir, rat_name, cond_name, 'Regression_validation');
    
    if ~isfolder(base_path)
        warning('[Missing folder] %s', base_path);
        continue;
    end
    
    tmp = load(fullfile(base_path, 'Regression_validation_result.mat'));
    
    data(i).rat    = rat_list{i};
    data(i).result = tmp.result;
end
end