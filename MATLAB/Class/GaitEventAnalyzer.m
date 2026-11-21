classdef GaitEventAnalyzer
    %GAITEVENTANALYZER Extract Hall angles and video-labelled gait events.
    methods (Static)
        function result = extract(record, varargin)
            parser = inputParser;
            addParameter(parser,'Side','left');
            addParameter(parser,'EventTimeOffsetSeconds',0);
            parse(parser,varargin{:});
            side = validatestring(parser.Results.Side,{'left','right'});
            offset = parser.Results.EventTimeOffsetSeconds;
            validateattributes(offset,{'numeric'},{'scalar','real','finite'});
            time = double(record.int_data.t(:));
            angle = double(record.int_data.(side).angle(:));
            validateattributes(time,{'numeric'},{'vector','finite','increasing','nonempty'});
            validateattributes(angle,{'numeric'},{'vector','real','numel',numel(time)});
            ranges = double(record.int_data.t_interval);
            if isvector(ranges) && numel(ranges)==2, ranges = ranges(:)'; end
            validateattributes(ranges,{'numeric'},{'2d','ncols',2,'real','finite'});
            if any(ranges(:,2)<=ranges(:,1)) || any(ranges(2:end,1)<=ranges(1:end-1,2))
                error('GaitEvents:InvalidIntervals','Intervals must be ordered, disjoint start/end rows.');
            end
            events = record.phase_data.events.(side).mocap;
            ic = double(events.t_IC(:)) + offset;
            to = double(events.t_TO(:)) + offset;
            if ~isempty(ic), validateattributes(ic,{'numeric'},{'vector','real','finite'}); end
            if ~isempty(to), validateattributes(to,{'numeric'},{'vector','real','finite'}); end
            [eventTime,order] = sort([ic;to]);
            eventState = [ones(numel(ic),1);zeros(numel(to),1)];
            eventState = eventState(order);
            if any(diff(eventTime)==0)
                error('GaitEvents:DuplicateEvent','IC/TO timestamps must be distinct.');
            end
            result.Rat = string(record.rat);
            result.Condition = string(record.cond);
            result.Side = string(side);
            result.TimeRanges_s = ranges;
            result.StoredSyncBias_s = record.phase_data.events.t_bias;
            result.AdditionalEventTimeOffset_s = offset;
            result.TimeConvention = "Stored event timestamps used directly; t_bias retained as provenance, not added again";
            result.AngleConvention = "Stored Hall ankle angle (deg); no neutral-angle or dorsiflexion sign conversion";
            result.StanceConvention = "IC inclusive to TO exclusive = 1; TO inclusive to IC exclusive = 0; no events = NaN";
            result.Segments = struct([]);
            result.Time_s = zeros(0,1); result.Angle_deg = zeros(0,1);
            result.StanceState = zeros(0,1); result.SegmentIndex = zeros(0,1);
            result.SwingIntervals = table();
            for q = 1:size(ranges,1)
                range = ranges(q,:);
                selected = time>=range(1) & time<=range(2);
                t = time(selected); a = angle(selected);
                if numel(t)<2
                    error('GaitEvents:EmptyInterval','Interval %d has fewer than two Hall samples.',q);
                end
                inRange = eventTime>=range(1) & eventTime<=range(2);
                et = eventTime(inRange); es = eventState(inRange);
                if any(diff(es)==0)
                    error('GaitEvents:NonalternatingEvents', ...
                        '%s / %s interval %d: IC and TO must alternate.',record.rat,record.cond,q);
                end
                state = NaN(size(t));
                if ~isempty(et)
                    % Infer the leading partial phase from the next transition.
                    state(:) = 1-es(1);
                    for j = 1:numel(et)
                        state(t>=et(j)) = es(j);
                    end
                end
                types = repmat("TO",numel(et),1); types(es==1) = "IC";
                segment.TimeRange_s = range;
                segment.Time_s = t; segment.Angle_deg = a;
                segment.StanceState = state;
                segment.Events = table(et,types,es,'VariableNames', ...
                    {'Time_s','Type','StateAfterEvent'});
                segment.LeadingPhaseInferred = ~isempty(et) && t(1)<et(1);
                segment.TrailingPhaseOpen = ~isempty(et) && t(end)>et(end);
                segment.IC_Time_s = et(es==1); segment.TO_Time_s = et(es==0);
                % Only event-bounded complete swings enter this table.
                starts = zeros(0,1);
                if numel(es)>=2
                    starts = find(es(1:end-1)==0 & es(2:end)==1);
                end
                SwingStart_s = et(starts); SwingEnd_s = et(starts+1);
                Duration_s = SwingEnd_s-SwingStart_s;
                Segment = repmat(q,numel(starts),1);
                segment.SwingIntervals = table(Segment,SwingStart_s,SwingEnd_s,Duration_s);
                % Lower stored Hall angle means greater dorsiflexion.
                % Use TO-inclusive / IC-exclusive observed Hall samples only.
                nSwings=numel(starts);
                peakAngle=NaN(nSwings,1); peakTime=NaN(nSwings,1);
                peakSourceIndex=NaN(nSwings,1); sampleCount=zeros(nSwings,1);
                validAngle=false(nSwings,1); reason=strings(nSwings,1);
                sourceIndices=find(selected);
                for swing=1:nSwings
                    local=find(t>=SwingStart_s(swing) & t<SwingEnd_s(swing));
                    sampleCount(swing)=numel(local);
                    if numel(local)<2
                        reason(swing)="Fewer than two Hall samples";
                    elseif any(~isfinite(a(local)))
                        reason(swing)="Nonfinite Hall samples";
                    else
                        [peakAngle(swing),position]=min(a(local));
                        peakTime(swing)=t(local(position));
                        peakSourceIndex(swing)=sourceIndices(local(position));
                        validAngle(swing)=true;
                    end
                end
                segment.SwingIntervals.PeakDorsiflexionAngle_deg=peakAngle;
                segment.SwingIntervals.PeakTime_s=peakTime;
                segment.SwingIntervals.PeakSourceIndex=peakSourceIndex;
                segment.SwingIntervals.HallSampleCount=sampleCount;
                segment.SwingIntervals.ValidForAngle=validAngle;
                segment.SwingIntervals.ExclusionReason=reason;
                if q==1, result.Segments = segment; else, result.Segments(q) = segment; end
                result.Time_s = [result.Time_s;t]; %#ok<AGROW>
                result.Angle_deg = [result.Angle_deg;a]; %#ok<AGROW>
                result.StanceState = [result.StanceState;state]; %#ok<AGROW>
                result.SegmentIndex = [result.SegmentIndex;repmat(q,numel(t),1)]; %#ok<AGROW>
                result.SwingIntervals = [result.SwingIntervals;segment.SwingIntervals]; %#ok<AGROW>
            end
        end

        function output = dorsiflexionTable(records, conditionNames, conditionCodes)
            % One row per rat, no pooling between rats and no statistical tests.
            conditionNames=string(conditionNames(:)); conditionCodes=string(conditionCodes(:));
            if numel(conditionNames)~=numel(conditionCodes)
                error('GaitEvents:ConditionNames','Condition names and codes must match.');
            end
            ratIDs=unique(string({records.Rat})','stable');
            nRats=numel(ratIDs); nConditions=numel(conditionCodes);
            means=NaN(nRats,nConditions); sds=means;
            counts=zeros(nRats,nConditions); total=counts;
            cells=repmat("NA",nRats,nConditions);
            allSwings=table();
            recordRats=string({records.Rat}); recordConditions=string({records.Condition});
            for r=1:nRats
                for c=1:nConditions
                    index=find(recordRats==ratIDs(r) & recordConditions==conditionNames(c));
                    if numel(index)>1
                        error('GaitEvents:DuplicateRecord','Duplicate %s / %s record.',ratIDs(r),conditionCodes(c));
                    elseif isempty(index)
                        warning('GaitEvents:MissingRecord','No %s / %s record.',ratIDs(r),conditionCodes(c));
                        continue;
                    end
                    swings=records(index).SwingIntervals;
                    total(r,c)=height(swings);
                    values=swings.PeakDorsiflexionAngle_deg(swings.ValidForAngle);
                    counts(r,c)=numel(values);
                    if ~isempty(values)
                        means(r,c)=mean(values); sds(r,c)=std(values,0);
                        cells(r,c)=sprintf('%.2f +/- %.2f',means(r,c),sds(r,c));
                    end
                    Rat=repmat(ratIDs(r),height(swings),1);
                    Condition=repmat(conditionCodes(c),height(swings),1);
                    Side=repmat(records(index).Side,height(swings),1);
                    allSwings=[allSwings;[table(Rat,Condition,Side),swings]]; %#ok<AGROW>
                end
            end
            output.RatIDs=ratIDs; output.ConditionCodes=conditionCodes;
            output.ConditionNames=conditionNames;
            output.MeanAngle_deg=means; output.SDAngle_deg=sds;
            output.ValidSwingCount=counts; output.CompleteSwingCount=total;
            output.DisplayTable=[table(ratIDs,'VariableNames',{'Rat'}), ...
                array2table(cells,'VariableNames',cellstr(conditionCodes))];
            output.CycleCountTable=[table(ratIDs,'VariableNames',{'Rat'}), ...
                array2table(counts,'VariableNames',cellstr(conditionCodes))];
            output.PerSwing=allSwings;
            output.MeanTable=[table(ratIDs,'VariableNames',{'Rat'}), ...
                array2table(means,'VariableNames',cellstr(conditionCodes))];
            output.Definition="Each swing: minimum original Hall angle over [TO, next IC). Each table cell: mean +/- sample SD across valid complete swings of that rat/condition, in degrees.";
            output.Interpretation="Lower Hall angle means greater dorsiflexion; no neutral-angle conversion or ROM normalization.";
            output.Exclusions="Open swings are not used. Complete swings with fewer than two samples or any nonfinite angle are retained in PerSwing with ValidForAngle=false.";
            output.GroupStatistics="None. Rats are reported individually; no pooled six-rat mean or p-values.";
        end
    end
end
