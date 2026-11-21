function t_interval = make_time_intervals(mode, varargin)

% =========================================================
% make_time_intervals
%
% Time interval 생성
%
% mode
%   'auto'   : Start / End / Step 기반 자동 생성
%   'manual' : 사용자가 직접 interval 지정
% =========================================================

p = inputParser;

addParameter(p, 'Start', []);
addParameter(p, 'End', []);
addParameter(p, 'Step', []);
addParameter(p, 'Intervals', []);

parse(p, varargin{:});

opt = p.Results;


switch lower(mode)

    %% -----------------------------------------------------
    % Automatic
    % ------------------------------------------------------
    case 'auto'

        assert( ...
            ~isempty(opt.Start) && ...
            ~isempty(opt.End) && ...
            ~isempty(opt.Step), ...
            'auto mode에서는 Start, End, Step이 필요합니다.');

        assert(opt.End > opt.Start, ...
            'End는 Start보다 커야 합니다.');

        assert(opt.Step > 0, ...
            'Step은 0보다 커야 합니다.');

        t0 = opt.Start : opt.Step : (opt.End - opt.Step);
        t1 = t0 + opt.Step;

        t_interval = [t0(:), t1(:)];


        %% -----------------------------------------------------
        % Manual
        % ------------------------------------------------------
    case 'manual'

        assert(~isempty(opt.Intervals), ...
            'manual mode에서는 Intervals가 필요합니다.');

        assert(size(opt.Intervals,2) == 2, ...
            'Intervals는 N x 2 matrix여야 합니다.');

        t_interval = opt.Intervals;


    otherwise

        error( ...
            'Unknown interval mode: %s', ...
            mode);

end


%% Check

assert(all(t_interval(:,2) > t_interval(:,1)), ...
    '모든 interval의 종료 시간은 시작 시간보다 커야 합니다.');


fprintf('Time intervals: %d\n', ...
    size(t_interval,1));

end