classdef PawTrajectoryAnalyzer
    %PAWTRAJECTORYANALYZER Phase-average complete, stance-aligned toe XY cycles.
    methods
        function result = collect(~, rootDirectory, varargin)
            parser = inputParser;
            addParameter(parser,'Conditions',{'IE','IR','LE','LR'});
            addParameter(parser,'PhaseSamples',201);
            addParameter(parser,'CoordinateReference','stance');
            addParameter(parser,'UseTimeRangeFiles',true,@(value) islogical(value) && isscalar(value));
            parse(parser,varargin{:});
            referenceMode=validatestring(parser.Results.CoordinateReference,{'stance','ilium','ilium_x'});
            count = parser.Results.PhaseSamples;
            validateattributes(count,{'numeric'},{'scalar','integer','>=',3});
            result.RootDirectory = string(rootDirectory);
            result.CoordinateReference=string(referenceMode);
            result.ConditionNames = string(parser.Results.Conditions(:));
            result.Phase_percent = linspace(0,100,count)';
            result.Coordinates = "X minus mean X of preceding stance; Y minus preceding stance minimum; mm. Not pelvis-relative.";
            result.CycleDefinition = "Stance start (IC) through next stance start (IC), including the next IC sample. Complete cycles only; no forced loop closure.";
            result.DisplayRule = "All observed frames included; complete cycles closed, leading/trailing partial traces remain open; average uses complete cycles";
            if ismember(referenceMode,{'ilium','ilium_x'})
                result.Coordinates="Framewise TO_x_filtered - IL_x_filtered; TO_y_filtered - IL_y_filtered, mm; translation only, no rotation or ground recentering";
            end
            if strcmp(referenceMode,'ilium_x')
                result.Coordinates="X = TO_x_filtered - IL_x_filtered; Y = TO_y_filtered minus one mean stance-minimum offset per recording (mm). No IL-Y subtraction, per-cycle reset, or rotation.";
            end
            result.TimeRangeRule="Optional time_range.txt: two clip-time seconds [start end], inclusive. Display all selected samples; average only complete cycles within the range. Read recording folder first, then condition folder.";
            result.Filter = "Uses stored TO_x_filtered / TO_y_filtered; no additional filtering.";
            result.Conditions = struct();
            for c = 1:numel(result.ConditionNames)
                name = char(result.ConditionNames(c));
                files = dir(fullfile(rootDirectory,name,'**','*_paw_clearance.mat'));
                [~,order] = sort(string(fullfile({files.folder},{files.name}))); files = files(order);
                % Legacy exports without IL must not double-count a recording
                % that has since been re-exported with its ilium coordinates.
                skippedLegacy=strings(0,1);
                if ismember(referenceMode,{'ilium','ilium_x'})
                    keep=false(size(files));
                    for check=1:numel(files)
                        traceFile=fullfile(files(check).folder,erase(string(files(check).name),'_paw_clearance'));
                        if ~isfile(traceFile), error('PawTrajectory:MissingTrace','Missing trace: %s',traceFile); end
                        payload=load(traceFile,'data');
                        keep(check)=all(isfield(payload.data,{'IL_x_filtered','IL_y_filtered'}));
                        if ~keep(check), skippedLegacy(end+1,1)=string(fullfile(files(check).folder,files(check).name)); end
                    end
                    files=files(keep);
                    if isempty(files)
                        error('PawTrajectory:MissingIlium','No IL-enabled MAT in %s. Re-run exec_paw_clearance for this condition.',fullfile(rootDirectory,name));
                    end
                    if ~isempty(skippedLegacy)
                        fprintf('%s: ignoring %d legacy exports without IL; using %d IL-enabled recordings.\n',name,numel(skippedLegacy),numel(files));
                    end
                end
                item.Name = string(name); item.SourceFiles = strings(0,1);
                item.SourceRecordings = struct([]); item.Cycles = struct([]);
                item.AllTrajectories=struct([]); item.TotalRecordedSamples=0; item.DisplayedUniqueSamples=0;
                item.XCycles_mm = zeros(count,0); item.YCycles_mm = zeros(count,0);
                item.FoundPairs = 0; item.OpenCyclesSkipped = 0;
                item.NonfiniteCyclesSkipped = 0; item.TimeRangeCyclesExcluded=0;
                item.DuplicateOf = ""; item.SkippedLegacyFiles=skippedLegacy;
                for f = 1:numel(files)
                    cyclePath = fullfile(files(f).folder,files(f).name);
                    tracePath = fullfile(files(f).folder,erase(string(files(f).name),'_paw_clearance'));
                    if ~isfile(tracePath)
                        error('PawTrajectory:MissingTrace','Matching per-frame MAT not found: %s',tracePath);
                    end
                    payload = load(cyclePath,'data'); pairs = payload.data;
                    payload = load(tracePath,'data'); trace = payload.data;
                    needed = {'Time','TO_x_filtered','TO_y_filtered'};
                    if ~all(isfield(trace,needed))
                        error('PawTrajectory:MissingXY','Re-run exec_paw_clearance with X/Y enabled: %s',tracePath);
                    end
                    t = double(trace.Time(:)); x = double(trace.TO_x_filtered(:)); y = double(trace.TO_y_filtered(:));
                    validateattributes(t,{'numeric'},{'vector','finite','increasing','nonempty'});
                    validateattributes(x,{'numeric'},{'vector','real','numel',numel(t)});
                    validateattributes(y,{'numeric'},{'vector','real','numel',numel(t)});
                    if ~isfield(pairs,'SwingEndObserved')
                        error('PawTrajectory:MissingBoundaryFlag','SwingEndObserved is required: %s',cyclePath);
                    end
                    if isfield(pairs,'LPFCutoff_Hz') && any(abs(pairs.LPFCutoff_Hz-15)>1e-9)
                        warning('PawTrajectory:FilterCutoff','Source cutoff differs from 15 Hz: %s',cyclePath);
                    end
                    timeRangeFile=""; requestedRange=[];
                    if parser.Results.UseTimeRangeFiles
                        localFile=fullfile(files(f).folder,'time_range.txt');
                        conditionFile=fullfile(rootDirectory,name,'time_range.txt');
                        if isfile(localFile), timeRangeFile=string(localFile);
                        elseif isfile(conditionFile), timeRangeFile=string(conditionFile); end
                        if strlength(timeRangeFile)>0
                            requestedRange=PawTrajectoryAnalyzer.readTimeRange(timeRangeFile);
                        end
                    end
                    include=true(size(t));
                    if ~isempty(requestedRange)
                        include=t>=requestedRange(1) & t<=requestedRange(2);
                    end
                    if nnz(include)<2
                        error('PawTrajectory:EmptyTimeRange','Fewer than two samples in selected time range: %s',tracePath);
                    end
                    groundIncluded=true(size(pairs.GroundHeight_mm));
                    if ~isempty(requestedRange)
                        groundIncluded=pairs.GroundTime_s>=requestedRange(1) & pairs.GroundTime_s<=requestedRange(2);
                    end
                    if ~any(groundIncluded)
                        error('PawTrajectory:MissingGroundInRange','No stance minimum in selected range: %s',tracePath);
                    end
                    recording=struct();
                    if ismember(referenceMode,{'ilium','ilium_x'})
                        ilX=double(trace.IL_x_filtered(:)); ilY=double(trace.IL_y_filtered(:));
                        validateattributes(ilX,{'numeric'},{'vector','real','finite','numel',numel(t)});
                        validateattributes(ilY,{'numeric'},{'vector','real','finite','numel',numel(t)});
                        recording.IL_x_filtered=ilX; recording.IL_y_filtered=ilY;
                    end
                    recording.GroundHeightMean_mm=mean(pairs.GroundHeight_mm(groundIncluded));
                    recording.TimeRangeFile=timeRangeFile; recording.RequestedTimeRange_s=requestedRange;
                    recording.IncludeMask=include; recording.IncludedSourceRows=find(include);
                    validateattributes(recording.GroundHeightMean_mm,{'numeric'},{'scalar','real','finite'});
                    recording.File = string(tracePath); recording.Time = t;
                    recording.TO_x_filtered = x; recording.TO_y_filtered = y;
                    if f==1, item.SourceRecordings = recording; else, item.SourceRecordings(f) = recording; end
                    item.SourceFiles(end+1,1) = string(cyclePath);
                    item.FoundPairs = item.FoundPairs+numel(pairs.Cycle);
                    for j = 1:numel(pairs.Cycle)
                        first = pairs.StanceStartIndex(j);
                        stanceLast = pairs.StanceEndIndex(j);
                        last = pairs.SwingEndIndex(j)+1;
                        if pairs.SwingEndObserved(j)~=1 || last>numel(t)
                            item.OpenCyclesSkipped = item.OpenCyclesSkipped+1;
                            continue;
                        end
                        validateattributes([first,stanceLast,last],{'numeric'}, ...
                            {'vector','integer','positive','<=',numel(t)});
                        if first>stanceLast || stanceLast>=last
                            error('PawTrajectory:InvalidCycle','Invalid cycle indices in %s',cyclePath);
                        end
                        indices = first:last;
                        if ~all(include(indices))
                            item.TimeRangeCyclesExcluded=item.TimeRangeCyclesExcluded+1;
                            continue;
                        end
                        if any(~isfinite(x(indices))) || any(~isfinite(y(indices)))
                            item.NonfiniteCyclesSkipped = item.NonfiniteCyclesSkipped+1;
                            continue;
                        end
                        ground = pairs.GroundHeight_mm(j);
                        if ~isfinite(ground)
                            item.NonfiniteCyclesSkipped = item.NonfiniteCyclesSkipped+1;
                            continue;
                        end
                        xOrigin = mean(x(first:stanceLast));
                        cycle.Time_s = t(indices);
                        cycle.X_mm = x(indices)-xOrigin;
                        cycle.Y_mm = y(indices)-ground;
                        if ismember(referenceMode,{'ilium','ilium_x'})
                            cycle.X_mm=x(indices)-ilX(indices);
                            cycle.Y_mm=y(indices);
                            if strcmp(referenceMode,'ilium')
                                cycle.Y_mm=cycle.Y_mm-ilY(indices);
                            else
                                cycle.Y_mm=cycle.Y_mm-recording.GroundHeightMean_mm;
                            end
                        end
                        cycle.Phase_percent = 100*(cycle.Time_s-cycle.Time_s(1))/(cycle.Time_s(end)-cycle.Time_s(1));
                        cycle.Phase_percent(1)=0; cycle.Phase_percent(end)=100; % Prevent roundoff gaps at phase endpoints.
                        cycle.SourceFile = string(cyclePath); cycle.SourceCycle = pairs.Cycle(j);
                        cycle.StartIndex = first; cycle.EndIndex = last;
                        cycle.GroundHeight_mm = ground; cycle.XOrigin_mm = xOrigin;
                        if isempty(item.Cycles), item.Cycles=cycle; else, item.Cycles(end+1)=cycle; end
                        item.XCycles_mm(:,end+1) = interp1(cycle.Phase_percent,cycle.X_mm,result.Phase_percent,'linear');
                        item.YCycles_mm(:,end+1) = interp1(cycle.Phase_percent,cycle.Y_mm,result.Phase_percent,'linear');
                    end
                    % Keep every recorded frame for gray trajectories, including
                    % the leading and trailing partial cycles. Mean uses complete
                    % IC-to-IC cycles only. Never force a partial cycle closed.
                    if isempty(pairs.Cycle)
                        error('PawTrajectory:NoGroundReference','No stance baseline available in %s',cyclePath);
                    end
                    boundaries=unique([1;pairs.StanceStartIndex(:);numel(t)]);
                    covered=false(numel(t),1);
                    for h=1:numel(boundaries)-1
                        first=boundaries(h); last=boundaries(h+1);
                        reference=find(pairs.StanceStartIndex<=first,1,'last');
                        if isempty(reference), reference=1; end
                        stanceIndices=pairs.StanceStartIndex(reference):pairs.StanceEndIndex(reference);
                        observed.StartIndex=first; observed.EndIndex=last;
                        observed.SourceRecording=f; observed.SourceFile=string(cyclePath);
                        observed.Time_s=t(first:last);
                        observed.XOrigin_mm=mean(x(stanceIndices));
                        observed.GroundHeight_mm=pairs.GroundHeight_mm(reference);
                        observed.X_mm=x(first:last)-observed.XOrigin_mm;
                        observed.Y_mm=y(first:last)-observed.GroundHeight_mm;
                        if ismember(referenceMode,{'ilium','ilium_x'})
                            observed.X_mm=x(first:last)-ilX(first:last);
                            observed.Y_mm=y(first:last);
                            if strcmp(referenceMode,'ilium')
                                observed.Y_mm=observed.Y_mm-ilY(first:last);
                            else
                                observed.Y_mm=observed.Y_mm-recording.GroundHeightMean_mm;
                            end
                        end
                        observed.IsComplete=first==pairs.StanceStartIndex(reference) && ...
                            pairs.SwingEndObserved(reference)==1 && last==pairs.SwingEndIndex(reference)+1;
                        if any(~isfinite(observed.X_mm)) || any(~isfinite(observed.Y_mm))
                            error('PawTrajectory:NonfiniteDisplay','Nonfinite recorded XY needs explicit handling: %s',cyclePath);
                        end
                        if isempty(item.AllTrajectories), item.AllTrajectories=observed;
                        else, item.AllTrajectories(end+1)=observed; end
                        covered(first:last)=true;
                    end
                    item.TotalRecordedSamples=item.TotalRecordedSamples+numel(t);
                    item.DisplayedUniqueSamples=item.DisplayedUniqueSamples+nnz(covered & include);
                    if ~isempty(requestedRange)
                        fprintf('%s recording %d: time_range.txt [%.6f %.6f] s, %d/%d samples, original rows %d-%d.\n', ...
                            name,f,requestedRange,nnz(include),numel(t),find(include,1),find(include,1,'last'));
                    end
                end
                item.UsedCycles = numel(item.Cycles);
                item.MeanX_mm = mean(item.XCycles_mm,2);
                item.MeanY_mm = mean(item.YCycles_mm,2);
                item.SDX_mm = std(item.XCycles_mm,0,2);
                item.SDY_mm = std(item.YCycles_mm,0,2);
                % Flag identical recordings across nominally different conditions.
                previousNames = fieldnames(result.Conditions);
                for p = 1:numel(previousNames)
                    prior = result.Conditions.(previousNames{p});
                    same = ~isempty(item.SourceRecordings) && numel(item.SourceRecordings)==numel(prior.SourceRecordings);
                    for q = 1:numel(item.SourceRecordings)
                        if ~same, break; end
                        a = item.SourceRecordings(q); b = prior.SourceRecordings(q);
                        same = isequaln(a.Time,b.Time) && isequaln(a.TO_x_filtered,b.TO_x_filtered) && isequaln(a.TO_y_filtered,b.TO_y_filtered);
                        if same && ismember(referenceMode,{'ilium','ilium_x'})
                            same=isequaln(a.IL_x_filtered,b.IL_x_filtered) && isequaln(a.IL_y_filtered,b.IL_y_filtered);
                        end
                    end
                    if same
                        item.DuplicateOf = string(previousNames{p});
                        warning('PawTrajectory:DuplicateCondition','%s has identical filtered XY recordings to %s. Verify the condition folder.',name,previousNames{p});
                        break;
                    end
                end
                item.PartialTrajectories=nnz(~[item.AllTrajectories.IsComplete]);
                result.Conditions.(name) = item;
                fprintf('%s: %d/%d recorded samples selected (%d original partial trajectories).\n', ...
                    name,item.DisplayedUniqueSamples,item.TotalRecordedSamples,item.PartialTrajectories);
                fprintf('%s: %d complete cycles; %d open and %d nonfinite cycles excluded from mean; %d files.\n', ...
                    name,item.UsedCycles,item.OpenCyclesSkipped,item.NonfiniteCyclesSkipped,numel(files));
            end
        end
    end
    methods (Static)
        function range=readTimeRange(filePath)
            content=fileread(filePath);
            content=regexprep(content,'(?m)[#%].*$','');
            tokens=regexp(content,'[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?','match');
            range=str2double(tokens);
            if numel(range)~=2 || any(~isfinite(range)) || range(2)<=range(1)
                error('PawTrajectory:InvalidTimeRange','time_range.txt must contain two finite seconds, start < end: %s',filePath);
            end
            range=reshape(range,1,2);
        end
    end
end
