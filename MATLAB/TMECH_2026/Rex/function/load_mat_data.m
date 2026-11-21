function [exp_data, exp_data_summary] = load_mat_data(root_dir, rat_list, cond_list, cfg)

n_rat  = numel(rat_list);
n_cond = numel(cond_list);

exp_data(n_rat, n_cond) = struct();
exp_data_summary = struct( ...
    'cond', '', ...
    'ROM', struct( ...
        'left',  struct('mean', [], 'std', []), ...
        'right', struct('mean', [], 'std', []), ...
        'SI',    struct('mean', [], 'std', []) ...
    ), ...
    'similarity', struct( ...
        'vel',  struct('mean', [], 'std', []), ...
        'torque', struct('mean', [], 'std', []), ...
        'power',    struct('mean', [], 'std', []) ...
    ), ...
    'power', struct(), ...
    'torque', struct(), ...
    'work', struct() ...
    );

exp_data_summary = repmat(exp_data_summary, n_cond, 1);

for i = 1:n_rat
    for j = 1:n_cond

        rat  = rat_list{i};
        cond = cond_list{j};

        proj_dir = fullfile(root_dir, rat, cond);

        int_file   = fullfile(proj_dir, 'int_data.mat');
        phase_file = fullfile(proj_dir, 'phase_data.mat');

        % 기본 정보
        exp_data(i,j).rat  = rat;
        exp_data(i,j).cond = cond;

        % ===============================
        % int_data 로드
        % ===============================
        if isfile(int_file)
            S = load(int_file);
            exp_data(i,j).int_data = S.int_data;
        else
            warning('[%s - %s] int_data 없음', rat, cond);
            exp_data(i,j).int_data = [];
        end

        % ===============================
        % phase_data 로드
        % ===============================
        if isfile(phase_file)
            S = load(phase_file);
            exp_data(i,j).phase_data = S.phase_data;
        else
            warning('[%s - %s] phase_data 없음', rat, cond);
            exp_data(i,j).phase_data = [];
        end

        % ===============================
        % meta 정보
        % ===============================
        try
            if ~isempty(exp_data(i,j).phase_data)
                exp_data(i,j).meta.n_cycle_left_exo  = size(exp_data(i,j).phase_data.left.exo.angle,1);
                exp_data(i,j).meta.n_cycle_right_exo = size(exp_data(i,j).phase_data.right.exo.angle,1);

                exp_data(i,j).meta.n_cycle_left_mocap  = size(exp_data(i,j).phase_data.left.mocap.angle,1);
                exp_data(i,j).meta.n_cycle_right_mocap = size(exp_data(i,j).phase_data.right.mocap.angle,1);
            else
                exp_data(i,j).meta = [];
            end
        catch
            warning('[%s - %s] meta 계산 실패', rat, cond);
            exp_data(i,j).meta = [];
        end

        % ===============================
        % 로그
        % ===============================
        fprintf('[Loaded] %s - %s\n', rat, cond);
    end
end

s=dbstack;
fprintf('\n[%s] Data loading complete (%d rats × %d conditions)\n', s(1).name, n_rat, n_cond);

%% n=6에 대한 종합 Result 계산 및 저장

% 0. condition 이름 붙이기
cond_name = {'IE','IR','LE','LR'};
for i = 1:n_cond
    exp_data_summary(i).cond = cond_name{i};
end

% 1. Range of motion Symmetric Index
[~, exp_data_summary]  = plot_ROM_SI(exp_data, exp_data_summary, rat_list, cond_list);

% 2. Similarity of velocity cycloid 
save_path = fullfile(root_dir, 'sim_vel.mat');
S = load(save_path, 'sim_struct');
sim_vel = S.sim_struct.data;
fprintf('[Load] sim_vel: %s\n', save_path);

[exp_data, exp_data_summary] = attach_similarity( ...
    exp_data, exp_data_summary, sim_vel, 'vel', cond_list);
print_similarity_stats(sim_vel, cond_list, 'Velocity');

% 3. Peak torque / Power
type_list = {'angle', 'vel', 'torque', 'power'};
for i=1:numel(type_list)
    exp_data_summary = attach_peak_value(exp_data, exp_data_summary, type_list{i});
    fprintf('[Load] Peak value load clear [%s] \n', type_list{i});
end

% 4. Work 지표 추가
exp_data = compute_work_all(exp_data);
exp_data_summary = plot_work_summary(exp_data, exp_data_summary, rat_list, cond_list, cfg);

% 5. Stance / Swing 지표 추가
for r = 1:size(exp_data,1)
    for c = 1:size(exp_data,2)
        exp_data = compute_spatiotemporal(exp_data, r, c);
    end
end

fprintf('[Load] Spatiotemporal load clear \n');

end