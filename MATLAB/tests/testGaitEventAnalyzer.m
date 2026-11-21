function testGaitEventAnalyzer()
% Boundary events, leading phases, gaps, and intervals without events.
record.rat = '#synthetic'; record.cond = 'test';
record.int_data.t = (0:0.01:2)';
record.int_data.t(131)=1.3; record.int_data.t(161)=1.6; % Exact event/sample coincidences.
record.int_data.left.angle = 70+record.int_data.t;
record.int_data.t_interval = [0 0.8;1.2 2];
record.phase_data.events.t_bias = [-0.5 -0.7];
record.phase_data.events.left.mocap.t_IC = [0.2;1.6];
record.phase_data.events.left.mocap.t_TO = [0.6;1.3];
r = GaitEventAnalyzer.extract(record);
assert(numel(r.Segments)==2);
assert(r.Segments(1).StanceState(1)==0); % Next IC implies initial swing.
assert(r.Segments(2).StanceState(1)==1); % Next TO implies initial stance.
assert(r.Segments(1).StanceState(21)==1); % IC is stance-inclusive.
assert(r.Segments(1).StanceState(61)==0); % TO is swing-inclusive.
assert(height(r.SwingIntervals)==1); % Never pair across the recording gap.
assert(abs(r.SwingIntervals.SwingStart_s-1.3)<1e-12);
assert(r.SwingIntervals.ValidForAngle);
assert(abs(r.SwingIntervals.PeakDorsiflexionAngle_deg-71.3)<1e-12);
assert(abs(r.SwingIntervals.PeakTime_s-1.3)<1e-12);
% An extreme angle exactly at IC must not enter the preceding swing.
record.int_data.left.angle(abs(record.int_data.t-1.6)<1e-12)=-10;
check=GaitEventAnalyzer.extract(record);
assert(abs(check.SwingIntervals.PeakDorsiflexionAngle_deg-71.3)<1e-12);
% A dropout remains visible as an invalid swing rather than a false minimum.
record.int_data.left.angle(abs(record.int_data.t-1.4)<1e-12)=NaN;
check=GaitEventAnalyzer.extract(record);
assert(~check.SwingIntervals.ValidForAngle && isnan(check.SwingIntervals.PeakDorsiflexionAngle_deg));
record.int_data.left.angle=70+record.int_data.t;
assert(isequal(r.StoredSyncBias_s,[-0.5 -0.7]));
assert(r.Segments(1).IC_Time_s==0.2); % Stored bias is not applied twice.
record.phase_data.events.left.mocap.t_IC = [];
record.phase_data.events.left.mocap.t_TO = [];
r = GaitEventAnalyzer.extract(record);
assert(all(isnan(r.StanceState)));
assert(isempty(r.SwingIntervals));
record.phase_data.events.left.mocap.t_IC = 0;
record.phase_data.events.left.mocap.t_TO = 0.6;
r = GaitEventAnalyzer.extract(record);
assert(r.Segments(1).StanceState(1)==1); % IC exactly at range start.
fprintf('PASS: gait event boundaries, gaps, empty events, and sync provenance.\n');
end
