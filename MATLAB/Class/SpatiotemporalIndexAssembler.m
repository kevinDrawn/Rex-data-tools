classdef SpatiotemporalIndexAssembler
    %SPATIOTEMPORALINDEXASSEMBLER Combine existing per-index MATs, without raw-data extraction.
    methods (Static)
        function result=collect(root,varargin)
            parser=inputParser;
            addParameter(parser,'PawMetric','MeanTrajectoryPeakHeight');
            addParameter(parser,'PawFile',"");
            addParameter(parser,'DorsiflexionFile',"");
            addParameter(parser,'DraggingFile',"");
            parse(parser,varargin{:});
            root=string(root);
            pawPath=SpatiotemporalIndexAssembler.resolve(root,'Paw_clearance', ...
                ["paw_clearance_plot_data.mat"],parser.Results.PawFile);
            dfPath=SpatiotemporalIndexAssembler.resolve(root,'Dorsiflexion_angle', ...
                ["peak_swing_dorsiflexion_plot_data.mat","peak_swing_dorsiflexion_by_rat.mat"],parser.Results.DorsiflexionFile);
            dragPath=SpatiotemporalIndexAssembler.resolve(root,'Dragging_incidence', ...
                ["dragging_incidence.mat","dragging_incidence_plot_data.mat"],parser.Results.DraggingFile);
            [paw,pawVariable]=SpatiotemporalIndexAssembler.read(pawPath);
            [df,dfVariable]=SpatiotemporalIndexAssembler.read(dfPath);
            [drag,dragVariable]=SpatiotemporalIndexAssembler.read(dragPath);
            pawField=char(parser.Results.PawMetric);
            if ~isfield(paw,pawField), error('Spatiotemporal:MissingPawMetric','Paw MAT has no %s.',pawField); end
            rats=string(paw.RatIDs(:));
            if numel(unique(rats))~=numel(rats), error('Spatiotemporal:DuplicateRat','Repeated Paw RatIDs.'); end
            [~,order]=sort(str2double(extractAfter(rats,'#'))); rats=rats(order);
            result.SchemaVersion=1;
            result.RootDirectory=root; result.RatIDs=rats;
            result.ConditionOrder=["Baseline";"IE";"IR";"LE";"LR"];
            result.PawSourceMetric=string(pawField);
            result.Metrics.PawClearance=SpatiotemporalIndexAssembler.align( ...
                paw.(pawField),rats,result.ConditionOrder,'mm');
            result.Metrics.PeakSwingDorsiflexion=SpatiotemporalIndexAssembler.align( ...
                df,rats,["LE";"LR"],'deg');
            result.Metrics.DraggingIncidence=SpatiotemporalIndexAssembler.align( ...
                drag,rats,["LE";"LR"],'%');
            result.Metrics.PeakSwingDorsiflexion.AngleConvention= ...
                "Lower stored Hall angle means greater dorsiflexion; no anatomical neutral conversion.";
            for field=["DenominatorRule","ScoringRule","MissingRule","SourceWorkbook","FileSummary","PerAnimalSummary"]
                if isfield(drag,field), result.Metrics.DraggingIncidence.(field)=drag.(field); end
            end
            % Preserve counts, reindexed by identity just like the plotted percentages.
            [~,ri]=ismember(rats,string(drag.RatIDs(:)));
            if isfield(drag,'ConditionNames'), dc=string(drag.ConditionNames(:));
            else, dc=string(drag.ConditionCodes(:)); end
            [~,ci]=ismember(["LE";"LR"],dc);
            for field=["DraggingCounts","TotalScoredCycles","OpenTrailingSwingCounts","ClosedSwingCounts"]
                if isfield(drag,field)
                    source=drag.(field); mapped=NaN(numel(rats),2);
                    good=ri>0;
                    for c=1:2
                        if ci(c)>0, mapped(good,c)=source(ri(good),ci(c)); end
                    end
                    result.Metrics.DraggingIncidence.(field)=mapped;
                end
            end
            result.MetricOrder=["PawClearance";"PeakSwingDorsiflexion";"DraggingIncidence"];
            result.GroupSummary=table(); result.IndividualValues=table();
            for k=1:numel(result.MetricOrder)
                key=result.MetricOrder(k); metric=result.Metrics.(key);
                summary=metric.GroupSummary;
                summary=[table(repmat(key,height(summary),1),'VariableNames',{'Metric'}),summary];
                summary.Units=repmat(metric.Units,height(summary),1);
                result.GroupSummary=[result.GroupSummary;summary]; %#ok<AGROW>
                for c=1:numel(metric.ConditionNames)
                    n=numel(rats);
                    row=table(rats,repmat(metric.ConditionNames(c),n,1),repmat(key,n,1), ...
                        metric.RatMeans(:,c),metric.RatSDs(:,c),metric.CycleCounts(:,c), ...
                        'VariableNames',{'Rat','Condition','Metric','Value','WithinRatSD','CycleCount'});
                    row.Units=repmat(metric.Units,n,1);
                    result.IndividualValues=[result.IndividualValues;row]; %#ok<AGROW>
                end
            end
            Metric=result.MetricOrder; SourceMAT=[pawPath;dfPath;dragPath];
            Variable=[pawVariable;dfVariable;dragVariable]; Modified=strings(3,1); Bytes=zeros(3,1);
            for k=1:3
                file=dir(SourceMAT(k)); Modified(k)=string(file.date); Bytes(k)=file.bytes;
            end
            result.InputFiles=table(Metric,SourceMAT,Variable,Modified,Bytes);
            result.Rule="Read only existing MATs from each index folder. Reorder by RatID/condition. No raw signal processing, denominator inference, or p-value calculation.";
            result.GroupRule="Equal-weight individual rats; group sample SD. Missing data remain NaN, with actual N reported.";
        end

        function output=analyzeAssistance(combined)
            keys=["PeakSwingDorsiflexion";"DraggingIncidence"];
            rows=table(); individual=table();
            for k=1:numel(keys)
                metric=combined.Metrics.(keys(k));
                a=find(metric.ConditionNames=="LE"); b=find(metric.ConditionNames=="LR");
                le=metric.RatMeans(:,a); lr=metric.RatMeans(:,b);
                valid=isfinite(le)&isfinite(lr); d=lr(valid)-le(valid); n=numel(d);
                if n<2, error('Spatiotemporal:TooFewPairs','Fewer than two paired rats for %s.',keys(k)); end
                [~,pt,ci,tstats]=ttest(d,0,'Tail','both','Alpha',0.05);
                % Explicit sign enumeration handles zeros and tied absolute ranks.
                nz=d(d~=0); nEffective=numel(nz);
                if nEffective>20, error('Spatiotemporal:TooManyPermutations','Exact enumeration limited to 20 nonzero pairs.'); end
                if isempty(nz)
                    pw=1; pp=1; ps=1;
                else
                    ranks=tiedrank(abs(nz));
                    signs=2*double(dec2bin(0:2^nEffective-1,nEffective)-'0')-1;
                    observedRank=abs(sum(sign(nz).*ranks));
                    pw=mean(abs(signs*ranks)>=observedRank-1e-10);
                    observedSum=abs(sum(nz));
                    pp=mean(abs(signs*abs(nz))>=observedSum-1e-10);
                    ps=mean(abs(sum(signs,2))>=abs(sum(sign(nz)))-1e-10);
                end
                unit=metric.Units; if unit=="%", unit="percentage points"; end
                row=table(keys(k),unit,n,nEffective,nnz(d==0),mean(le(valid)),std(le(valid),0), ...
                    mean(lr(valid)),std(lr(valid),0),mean(d),std(d,0),ci(1),ci(2), ...
                    tstats.tstat,tstats.df,pt,pw,pp,ps,'VariableNames', ...
                    {'Metric','DifferenceUnits','PairedRats','NonzeroPairs','ZeroPairs', ...
                    'LE_Mean','LE_SD','LR_Mean','LR_SD','MeanDifference_LRminusLE','SDDifference', ...
                    'PairedT_CI95_Low','PairedT_CI95_High','TStatistic','DF', ...
                    'PairedT_P','WilcoxonExact_P','PairedPermutationExact_P','SignExact_P'});
                rows=[rows;row]; %#ok<AGROW>
                Rat=metric.RatIDs; Metric=repmat(keys(k),numel(Rat),1);
                individual=[individual;table(Rat,Metric,le,lr,lr-le,valid,'VariableNames', ...
                    {'Rat','Metric','LE','LR','Difference_LRminusLE','Included'})]; %#ok<AGROW>
            end
            for name=["PairedT_P","WilcoxonExact_P","PairedPermutationExact_P","SignExact_P"]
                p=rows.(name); [sorted,index]=sort(p); m=numel(p);
                adjusted=min(1,cummax((m-(1:m)'+1).*sorted));
                holm=zeros(m,1); holm(index)=adjusted; rows.(name+"_Holm")=holm;
            end
            output.Alpha=0.05; output.Comparison="LR minus LE; all tests two-sided";
            output.ExperimentalUnit="Rat; one stored rat-level value per condition. Individual steps are not treated as independent rats.";
            output.Multiplicity="Holm adjustment across these two endpoints, separately for each method. Raw values also reported; methods are sensitivity analyses, not a menu for choosing significance.";
            output.Assumptions="Paired t requires approximately normal paired differences. Signed-rank uses symmetry of the paired-difference distribution. Exact sign test uses directions without magnitudes. Small n limits assessment.";
            output.ExactRule="Enumerate all 2^m signs of nonzero paired differences; zeros retained in paired N but omitted from exact-test enumeration. Ties use average ranks. No asymptotic approximation.";
            output.CINote="Unadjusted paired-t 95% confidence intervals for the mean LR-minus-LE difference; incidence units are percentage points.";
            output.Interpretation="Lower Hall angle means greater swing dorsiflexion; lower dragging percentage means less observed dragging. No mechanistic or population-wide recovery conclusion follows from p alone.";
            output.InputFiles=combined.InputFiles;
            output.Summary=rows; output.IndividualDifferences=individual;
        end

        function metric=align(source,rats,conditions,unit)
            if isfield(source,'RatMeans')
                values=source.RatMeans; sds=source.RatSDs; counts=source.CycleCounts;
                sourceConditions=string(source.ConditionNames(:));
            elseif isfield(source,'MeanAngle_deg')
                values=source.MeanAngle_deg; sds=source.SDAngle_deg; counts=source.ValidSwingCount;
                sourceConditions=string(source.ConditionCodes(:));
            else
                error('Spatiotemporal:Schema','Unsupported metric MAT schema.');
            end
            sourceRats=string(source.RatIDs(:)); rats=string(rats(:)); conditions=string(conditions(:));
            if numel(unique(sourceRats))~=numel(sourceRats) || numel(unique(sourceConditions))~=numel(sourceConditions)
                error('Spatiotemporal:DuplicateIdentity','Repeated rat/condition identities in source MAT.');
            end
            if ~isequal(size(values),[numel(sourceRats),numel(sourceConditions)]) || ...
                ~isequal(size(sds),size(values)) || ~isequal(size(counts),size(values))
                error('Spatiotemporal:Dimensions','Metric matrix dimensions do not match source identities.');
            end
            [presentR,ri]=ismember(rats,sourceRats);
            [presentC,ci]=ismember(conditions,sourceConditions);
            means=NaN(numel(rats),numel(conditions)); sd=means; n=zeros(size(means));
            for c=1:numel(conditions)
                if presentC(c)
                    means(presentR,c)=values(ri(presentR),ci(c));
                    sd(presentR,c)=sds(ri(presentR),ci(c));
                    n(presentR,c)=counts(ri(presentR),ci(c));
                end
            end
            if any(~presentR) || any(~presentC)
                warning('Spatiotemporal:MissingValues','Missing rat/condition cells remain NaN.');
            end
            if isfield(source,'Definition'), definition=string(source.Definition);
            else, definition="Original stored per-rat values; see source MAT for definition."; end
            metric=GaitMetricCollector.pack(rats,conditions,means,sd,n,unit,definition);
        end

        function path=resolve(root,folder,preferred,override)
            if strlength(string(override))>0
                path=string(override);
                if ~isfile(path), path=string(fullfile(root,path)); end
                if ~isfile(path), error('Spatiotemporal:MissingFile','Missing explicit input: %s',override); end
                return;
            end
            directory=fullfile(root,folder);
            for name=preferred(:)'
                files=dir(fullfile(directory,'**',name));
                if numel(files)>1
                    error('Spatiotemporal:AmbiguousMAT','Multiple %s files under %s; set the explicit file override.',name,directory);
                elseif numel(files)==1
                    path=string(fullfile(files.folder,files.name)); return;
                end
            end
            error('Spatiotemporal:MissingMAT','No supported metric MAT under %s.',directory);
        end

        function [data,variable]=read(path)
            payload=load(path);
            if isfield(payload,'data'), data=payload.data; variable="data";
            elseif isfield(payload,'dorsiflexionResults'), data=payload.dorsiflexionResults; variable="dorsiflexionResults";
            elseif isfield(payload,'swingDorsiflexionMetrics'), data=payload.swingDorsiflexionMetrics; variable="swingDorsiflexionMetrics";
            else, error('Spatiotemporal:MATVariable','Unsupported MAT variable in %s.',path); end
        end
    end
end
