classdef GaitMetricCollector
    %GAITMETRICCOLLECTOR Plot-ready values with one independent point per rat.
    methods (Static)
        function output=collectPaw(root,conditions,phaseSamples)
            folders=dir(root); names=string({folders([folders.isdir]).name})';
            names=names(~cellfun(@isempty,regexp(cellstr(names),'^#\d+$','once')));
            [~,order]=sort(str2double(extractAfter(names,1))); rats=names(order);
            if isempty(rats), error('GaitMetrics:NoRats','No #number folders in %s.',root); end
            conditions=string(conditions(:)); nR=numel(rats); nC=numel(conditions);
            peak=NaN(nR,nC); peakSD=peak; meanPeak=peak; excursion=peak;
            ratio=peak; ratioSD=peak; counts=zeros(nR,nC);
            traces=cell(nR,1); details=cell(nR,nC); allCycles=table();
            analyzer=PawTrajectoryAnalyzer();
            for r=1:nR
                available=strings(0,1);
                for c=1:nC
                    files=dir(fullfile(root,rats(r),conditions(c),'**','*_paw_clearance.mat'));
                    if ~isempty(files), available(end+1,1)=conditions(c); end %#ok<AGROW>
                end
                if isempty(available), continue; end
                result=analyzer.collect(fullfile(root,rats(r)),'Conditions',cellstr(available), ...
                    'CoordinateReference','ilium_x','PhaseSamples',phaseSamples,'UseTimeRangeFiles',true);
                traces{r}=result;
                for c=1:nC
                    name=char(conditions(c)); if ~isfield(result.Conditions,name), continue; end
                    item=result.Conditions.(name); values=zeros(0,1); ratios=values;
                    for f=1:numel(item.SourceFiles)
                        loaded=load(item.SourceFiles(f),'data'); pairs=loaded.data;
                        for j=1:numel(item.Cycles)
                            cycle=item.Cycles(j);
                            if cycle.SourceFile~=item.SourceFiles(f), continue; end
                            k=find(pairs.Cycle==cycle.SourceCycle);
                            if numel(k)~=1, error('GaitMetrics:CycleID','Ambiguous source cycle in %s.',item.SourceFiles(f)); end
                            v=double(pairs.PeakPawHeight_mm(k));
                            recording=item.SourceRecordings(f); t=recording.Time;
                            a=pairs.StanceStartIndex(k); b=pairs.SwingStartIndex(k); z=pairs.SwingEndIndex(k)+1;
                            stance=t(b)-t(a); swing=t(z)-t(b); sr=swing/stance;
                            values(end+1,1)=v; ratios(end+1,1)=sr; %#ok<AGROW>
                            row=table(rats(r),conditions(c),cycle.SourceFile,cycle.SourceCycle, ...
                                t(a),t(z),v,stance,swing,sr,'VariableNames', ...
                                {'Rat','Condition','SourceFile','SourceCycle','StartTime_s','EndTime_s', ...
                                'PeakPawHeight_mm','StanceDuration_s','SwingDuration_s','SwingStanceRatio'});
                            allCycles=[allCycles;row]; %#ok<AGROW>
                        end
                    end
                    counts(r,c)=numel(values);
                    if ~isempty(values)
                        peak(r,c)=mean(values); peakSD(r,c)=std(values,0);
                        ratio(r,c)=mean(ratios); ratioSD(r,c)=std(ratios,0);
                        y=mean(item.YCycles_mm,2);
                        meanPeak(r,c)=max(y); excursion(r,c)=max(y)-min(y);
                    end
                    detail.SourceFiles=item.SourceFiles;
                    detail.Recordings=item.SourceRecordings;
                    detail.CycleCount=numel(values); detail.PeakPawHeight_mm=values;
                    detail.SwingStanceRatio=ratios; detail.MeanX_mm=mean(item.XCycles_mm,2);
                    detail.MeanY_mm=mean(item.YCycles_mm,2); detail.Phase_percent=result.Phase_percent;
                    detail.SkippedLegacyFiles=item.SkippedLegacyFiles;
                    details{r,c}=detail;
                end
            end
            output.SchemaVersion=1; output.RootDirectory=string(root);
            output.RatIDs=rats; output.ConditionNames=conditions;
            output.MeanPeakPawHeight=GaitMetricCollector.pack(rats,conditions,peak,peakSD,counts,'mm', ...
                'Mean of per-cycle swing maxima minus preceding stance minima');
            output.MeanTrajectoryPeakHeight=GaitMetricCollector.pack(rats,conditions,meanPeak,NaN(size(peak)),counts,'mm', ...
                'Maximum of the phase-averaged Toe-Y trajectory after one mean stance-minimum offset per recording; not mean of individual cycle peaks');
            output.MeanTrajectoryVerticalExcursion=GaitMetricCollector.pack(rats,conditions,excursion,NaN(size(peak)),counts,'mm', ...
                'Maximum minus minimum of the phase-averaged Toe-Y trajectory; not ground clearance');
            output.SwingStanceRatio=GaitMetricCollector.pack(rats,conditions,ratio,ratioSD,counts,'ratio', ...
                'Mean across complete cycles of (next IC - TO) / (TO - IC), using original timestamps');
            output.PerAnimalDetails=details; output.RatTrajectories=traces; output.PerCycle=allCycles;
            output.PrimaryPlotMetric="MeanTrajectoryPeakHeight";
            output.PhaseSamples=phaseSamples;
            output.Coordinates="X=TO_x_filtered-IL_x_filtered; Y=TO_y_filtered minus one mean stance-minimum offset per recording. No IL-Y subtraction.";
            output.Inclusion="Same IL-enabled files and complete IC-to-IC cycles as PawTrajectoryAnalyzer. time_range.txt respected; legacy exports skipped; no automatic outlier removal.";
            output.Averaging="Pool cycles within each rat/condition across recordings, then weight each rat equally. Phase averaging uses output.PhaseSamples samples.";
            output.Uncertainty="Within-rat SD is undefined for a single mean-trajectory peak (NaN). Group SD is computed across rat-level values.";
            output.DraggingIncidence="Not inferred from peak height. Requires explicit per-swing dragging annotations.";
        end

        function output=collectDorsiflexion(metaPath,baselinePath,side,ratIDs,conditions)
            loaded=load(metaPath,'exp_data'); records=loaded.exp_data;
            if strlength(string(baselinePath))>0
                extra=load(baselinePath,'exp_data'); records=[records(:);extra.exp_data(:)];
            end
            names=["Baseline","intact_Exo shoe","intact_Rex","lido_Exo shoe","lido_Rex"];
            codes=["Baseline","IE","IR","LE","LR"];
            nR=numel(ratIDs); nC=numel(conditions);
            m=NaN(nR,nC); sd=m; counts=zeros(nR,nC); details=cell(nR,nC);
            values=cell(nR,nC); allSwings=table();
            for j=1:numel(records)
                record=records(j); r=find(ratIDs==string(record.rat));
                c=find(conditions==string(record.cond));
                if isempty(c)
                    k=find(names==string(record.cond),1);
                    if ~isempty(k), c=find(conditions==codes(k)); end
                end
                if isempty(r) || isempty(c), continue; end
                extracted=GaitEventAnalyzer.extract(record,'Side',side,'EventTimeOffsetSeconds',0);
                swings=extracted.SwingIntervals;
                if ~isempty(swings)
                    v=swings.PeakDorsiflexionAngle_deg(swings.ValidForAngle);
                    values{r,c}=[values{r,c};v];
                    Rat=repmat(ratIDs(r),height(swings),1); Condition=repmat(conditions(c),height(swings),1);
                    SourceRecord=repmat(j,height(swings),1);
                    allSwings=[allSwings;[table(Rat,Condition,SourceRecord),swings]]; %#ok<AGROW>
                end
                if isempty(details{r,c}), details{r,c}={extracted};
                else, details{r,c}{end+1}=extracted; end
            end
            for r=1:nR
                for c=1:nC
                    v=values{r,c}; counts(r,c)=numel(v);
                    if ~isempty(v), m(r,c)=mean(v); sd(r,c)=std(v,0); end
                end
            end
            output=GaitMetricCollector.pack(ratIDs,conditions,m,sd,counts,'deg', ...
                'Mean of the minimum original Hall angle during each complete [TO, next IC) swing');
            output.SchemaVersion=1; output.MetaPath=string(metaPath); output.BaselineMetaPath=string(baselinePath);
            output.Side=string(side); output.PerSwing=allSwings; output.PerAnimalDetails=details;
            output.AngleConvention="Lower stored Hall angle means greater dorsiflexion. No sign inversion, ROM normalization, or anatomical neutral offset.";
            output.TimeConvention="Stored event times used directly; t_bias is not added again. Uses metadata analysis intervals, not paw-video time_range.txt.";
            output.MissingRule="Unavailable rat/condition cells remain NaN with Count=0; no substitution from toe coordinates or other conditions.";
            output.Exclusions="Only complete swings, >=2 samples, all finite Hall angles. Excluded complete swings retained in PerSwing.";
        end

        function metric=pack(rats,conditions,means,sds,counts,unit,definition)
            rats=string(rats(:)); conditions=string(conditions(:));
            metric.RatIDs=rats; metric.ConditionNames=conditions;
            metric.RatMeans=means; metric.RatSDs=sds; metric.CycleCounts=counts;
            metric.Units=string(unit); metric.Definition=string(definition);
            metric.GroupRule="Unweighted mean and sample SD of available individual-rat means; missing values excluded and N reported.";
            groupMean=NaN(numel(conditions),1); groupSD=groupMean; n=zeros(size(groupMean));
            metric.Conditions=struct();
            for c=1:numel(conditions)
                good=isfinite(means(:,c)); n(c)=nnz(good);
                if n(c)>0, groupMean(c)=mean(means(good,c)); end
                if n(c)>1, groupSD(c)=std(means(good,c),0); end
                d.RatIDs=rats; d.RatMeans=means(:,c); d.RatSDs=sds(:,c); d.CycleCounts=counts(:,c);
                d.Mean=groupMean(c); d.SD=groupSD(c); d.N=n(c);
                metric.Conditions.(char(conditions(c)))=d;
            end
            metric.GroupSummary=table(conditions,n,groupMean,groupSD,'VariableNames',{'Condition','N','Mean','SD'});
            metric.RatMeanTable=[table(rats,'VariableNames',{'Rat'}),array2table(means,'VariableNames',cellstr(conditions))];
        end

        function saveMetric(data,path)
            directory=fileparts(path); if ~isfolder(directory), mkdir(directory); end
            save(path,'data','-v7.3');
            fprintf('Saved: %s\n',path);
        end

        function output=collectDraggingWorkbook(workbookPath,pawMatPath,conditions)
            loaded=load(pawMatPath,'data'); paw=loaded.data;
            rats=string(paw.RatIDs(:)); conditions=string(conditions(:));
            cells=readcell(workbookPath,'Sheet',1);
            headers=string(cells(1,:)); inputRats=string(cells(2:end,1));
            incidence=NaN(numel(rats),numel(conditions)); totals=zeros(size(incidence));
            dragging=NaN(size(incidence)); closed=totals; open=totals; meanCycles=totals;
            perFile=table(); summary=table();
            for r=1:numel(rats)
                row=find(strtrim(inputRats)==rats(r));
                if numel(row)~=1, error('GaitMetrics:DraggingRat','Expected one Excel row for %s.',rats(r)); end
                for c=1:numel(conditions)
                    col=find(upper(strtrim(headers))==upper(conditions(c)));
                    if numel(col)~=1, error('GaitMetrics:DraggingCondition','Expected one Excel column for %s.',conditions(c)); end
                    value=cells{row+1,col};
                    if ismissing(string(value)) || strlength(strtrim(string(value)))==0
                        count=NaN;
                    else
                        count=str2double(string(value));
                        if ~isfinite(count) || count<0 || mod(count,1)~=0
                            error('GaitMetrics:DraggingCount','Invalid count for %s/%s in Excel.',rats(r),conditions(c));
                        end
                    end
                    sourceColumn=find(paw.ConditionNames==conditions(c));
                    detail=paw.PerAnimalDetails{r,sourceColumn};
                    if isempty(detail), error('GaitMetrics:MissingPawSource','No source MAT for %s/%s.',rats(r),conditions(c)); end
                    files=string(detail.SourceFiles(:));
                    if numel(unique(files))~=numel(files), error('GaitMetrics:DuplicateSource','Repeated source files.'); end
                    n=0; nClosed=0; nOpen=0;
                    for f=1:numel(files)
                        original=load(files(f),'data'); pair=original.data;
                        nFile=numel(pair.Cycle);
                        if numel(unique(pair.Cycle))~=nFile, error('GaitMetrics:DuplicateCycle','Duplicate cycles in %s.',files(f)); end
                        nClosedFile=nnz(pair.SwingEndObserved==1); nOpenFile=nnz(pair.SwingEndObserved==0);
                        if nClosedFile+nOpenFile~=nFile, error('GaitMetrics:BoundaryFlag','Invalid source boundary flags.'); end
                        n=n+nFile; nClosed=nClosed+nClosedFile; nOpen=nOpen+nOpenFile;
                        fileRow=table(rats(r),conditions(c),files(f),nFile,nClosedFile,nOpenFile, ...
                            'VariableNames',{'Rat','Condition','SourceMAT','DetectedPairs','ClosedSwings','OpenTrailingSwings'});
                        perFile=[perFile;fileRow]; %#ok<AGROW>
                    end
                    if n<=0 || (~isnan(count) && count>n)
                        error('GaitMetrics:DraggingDenominator','%s/%s: dragging %g exceeds detected pairs %d (or denominator is zero).',rats(r),conditions(c),count,n);
                    end
                    dragging(r,c)=count; totals(r,c)=n; closed(r,c)=nClosed; open(r,c)=nOpen;
                    meanCycles(r,c)=paw.MeanPeakPawHeight.CycleCounts(r,sourceColumn);
                    incidence(r,c)=100*count/n;
                    inputCell=string(char(64+col))+string(row+1);
                    summaryRow=table(rats(r),conditions(c),count,n,incidence(r,c),nClosed,nOpen,meanCycles(r,c),inputCell, ...
                        'VariableNames',{'Rat','Condition','DraggingCount','TotalCycles','Incidence_percent', ...
                        'ClosedSwings','OpenTrailingSwings','MeanTrajectoryCycles','ExcelCell'});
                    summary=[summary;summaryRow]; %#ok<AGROW>
                end
            end
            output=GaitMetricCollector.pack(rats,conditions,incidence,NaN(size(incidence)),totals,'%', ...
                '100 * manually scored dragging steps / original per-video MAT detected pairs, including observed open trailing swings');
            output.DraggingCounts=dragging; output.TotalScoredCycles=totals;
            output.ClosedSwingCounts=closed; output.OpenTrailingSwingCounts=open;
            output.MeanTrajectoryCycleCounts=meanCycles;
            output.PerAnimalSummary=summary; output.FileSummary=perFile;
            output.SourceWorkbook=string(workbookPath); output.SourceSheet=1;
            output.SourcePawCollection=string(pawMatPath);
            output.DenominatorRule="User confirmed full-video counts including final observed step. Count every Cycle entry in each original current IL-enabled pair MAT; sum videos within rat/condition. No time_range filtering. Leading partial steps absent from these pair MATs are not added.";
            output.ScoringRule="Forward limb advancement: toe touches and scrapes the ground before the next normal placement. Normal terminal stance/toe-off and next landing are excluded. Counts are imported unchanged; contact duration is not inferred.";
            output.MissingRule="Blank numerator stays NaN, measured zero stays zero. No capping at 100% or invented counts.";
        end

        function output=collectDragging(csvPath,rats,conditions)
            rats=string(rats(:)); conditions=string(conditions(:));
            annotations=readtable(csvPath,'TextType','string');
            needed={'Rat','Condition','DraggingCount','TotalCycles'};
            if ~all(ismember(needed,annotations.Properties.VariableNames))
                error('GaitMetrics:DraggingColumns','CSV requires Rat, Condition, DraggingCount, TotalCycles.');
            end
            rat=string(annotations.Rat); condition=string(annotations.Condition);
            count=str2double(string(annotations.DraggingCount));
            total=str2double(string(annotations.TotalCycles));
            means=NaN(numel(rats),numel(conditions)); counts=zeros(size(means));
            numerator=NaN(size(means)); denominator=numerator;
            for j=1:height(annotations)
                r=find(rats==rat(j)); c=find(conditions==condition(j));
                if isempty(r) || isempty(c)
                    error('GaitMetrics:DraggingIdentity','Unknown rat/condition in CSV row %d.',j);
                end
                if nnz(rat==rat(j) & condition==condition(j))~=1
                    error('GaitMetrics:DraggingDuplicate','Duplicate rat/condition in CSV row %d.',j);
                end
                if isnan(count(j)) && isnan(total(j)), continue; end
                if ~isfinite(count(j)) || ~isfinite(total(j)) || total(j)<=0 || ...
                        count(j)<0 || count(j)>total(j) || mod(count(j),1)~=0 || mod(total(j),1)~=0
                    error('GaitMetrics:DraggingCounts', ...
                        'CSV row %d requires integer 0 <= DraggingCount <= TotalCycles, TotalCycles > 0; leave both blank if unscored.',j);
                end
                numerator(r,c)=count(j); denominator(r,c)=total(j);
                means(r,c)=100*count(j)/total(j); counts(r,c)=total(j);
            end
            output=GaitMetricCollector.pack(rats,conditions,means,NaN(size(means)),counts,'%', ...
                'Per-rat percentage of scored swings with dragging: 100 * DraggingCount / TotalCycles');
            output.DraggingCounts=numerator; output.TotalScoredCycles=denominator;
            output.SourceCSV=string(csvPath); output.Annotations=annotations;
            output.MissingRule="Unscored values are NaN / N=0, not zero dragging. Each rat contributes one incidence percentage.";
            output.ScoringRule="Input manually scored counts. No dragging classification inferred from peak paw height.";
        end

        function colors=conditionPalette()
            % Bar colors sampled from the supplied ROM-symmetry/similarity figure.
            colors.Baseline=[165 165 165]/255;
            colors.IE=[170 209 229]/255;
            colors.IR=[103 168 212]/255;
            colors.LE=[227 203 70]/255;
            colors.LR=[230 152 89]/255;
        end

        function [fig,axesHandles]=plotComparison(metrics,titles)
            fig=figure('Name','Functional gait metrics','Color','w','Position',[100 100 600*numel(metrics) 500]);
            layout=tiledlayout(fig,1,numel(metrics),'TileSpacing','compact','Padding','compact');
            axesHandles=gobjects(numel(metrics),1);
            for k=1:numel(metrics)
                metric=metrics{k}; ax=nexttile(layout); axesHandles(k)=ax; hold(ax,'on');
                nC=numel(metric.ConditionNames); palette=GaitMetricCollector.conditionPalette();
                for c=1:nC
                    condition=char(metric.ConditionNames(c));
                    if ~isfield(palette,condition), error('GaitMetrics:UnknownConditionColor','No color defined for %s.',condition); end
                    barColor=palette.(condition); detailColor=barColor;
                    v=metric.RatMeans(:,c); valid=find(isfinite(v));
                    if isempty(valid)
                        text(ax,c,0,'No data','HorizontalAlignment','center','VerticalAlignment','bottom'); continue;
                    end
                    mu=mean(v(valid)); bar(ax,c,mu,0.65,'FaceColor',barColor,'EdgeColor','none');
                    if numel(valid)>1
                        errorbar(ax,c,mu,std(v(valid),0),'Color',detailColor,'LineStyle','none','CapSize',8,'LineWidth',1.5);
                    end
                    offsets=linspace(-0.18,0.18,numel(metric.RatIDs));
                    for r=valid(:)'
                        scatter(ax,c+offsets(r),v(r),45,detailColor,'filled','MarkerEdgeColor','w','LineWidth',0.6,'MarkerFaceAlpha',1, ...
                            'DisplayName',metric.RatIDs(r));
                    end
                end
                set(ax,'XTick',1:nC,'XTickLabel',cellstr(metric.ConditionNames), ...
                    'FontName','Times New Roman','FontSize',14,'XLim',[0.4 nC+0.6]);
                if ~any(isfinite(metric.RatMeans(:))) && metric.Units=="%", ylim(ax,[0 100]); end
                xlabel(ax,'Condition'); ylabel(ax,titles{k}); grid(ax,'on'); box(ax,'off');
                title(ax,'Mean +/- SD across rats; dots: individual rats','FontSize',13);
            end
        end
    end
end
