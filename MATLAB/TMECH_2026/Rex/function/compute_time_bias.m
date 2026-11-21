function time_bias = compute_time_bias(t_interval, mocap_index, main_right, varargin)
% compute_time_bias
% mocap TO와 exo TO를 정렬하기 위한 time bias 계산
%
% INPUT
%   t_interval   : [N x 2] interval time
%   mocap_index  : mocap event struct
%   main_right   : exo TO struct (main_right(k).t_TO)
%
% OPTIONAL
%   'BiasMax'    : 최대 탐색 범위 (default = 0.5 sec)
%   'dt'         : resolution (default = 0.001 sec)
%
% OUTPUT
%   time_bias    : [N x 1] interval별 bias

% -------------------------------
% 옵션 파싱
% -------------------------------
opt.BiasMax = 6.0;
opt.dt      = 0.001;

for i = 1:2:numel(varargin)
    opt.(varargin{i}) = varargin{i+1};
end

% -------------------------------
% 초기화
% -------------------------------
N = size(t_interval,1);
time_bias = nan(N,1);

bias_range = -opt.BiasMax : opt.dt : opt.BiasMax;

% -------------------------------
% Main loop
% -------------------------------
for k = 1:N
    
    % --- 데이터 유효성 체크 ---
    if k > numel(mocap_index) || ...
       ~isfield(mocap_index(k),'right') || ...
       ~isfield(mocap_index(k).right,'hind') || ...
       ~isfield(mocap_index(k).right.hind,'TO') || ...
       isempty(mocap_index(k).right.hind.TO) || ...
       isempty(main_right(k).t_TO)
        continue;
    end

    % --- 시간 정렬 ---
    t_start = t_interval(k,1);
    mocap_TO = t_start + mocap_index(k).right.hind.TO(:);
    exo_TO   = main_right(k).t_TO(:);

    % -------------------------------
    % bias 탐색
    % -------------------------------
    cost = zeros(size(bias_range));

    for i = 1:length(bias_range)

        b = bias_range(i);
        mocap_shifted = mocap_TO + b;

        % 양방향 거리 (Chamfer-like)
        D = abs(mocap_shifted - exo_TO');

        err1 = min(D, [], 2);
        err2 = min(D, [], 1)';

        cost(i) = median([err1; err2].^2);
    end

    % -------------------------------
    % 최적 bias
    % -------------------------------
    [~, idx_best] = min(cost);
    time_bias(k) = bias_range(idx_best);

    fprintf('[Interval %d] Time bias = %.3f s\n', k, time_bias(k));
end
s=dbstack;
fprintf('[%s - %s] Exo and Mocap time bias optimization Done\n', s(2).name, s(1).name);

end