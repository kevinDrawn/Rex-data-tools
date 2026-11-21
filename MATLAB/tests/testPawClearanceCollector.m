function testPawClearanceCollector()
%TESTPAWCLEARANCECOLLECTOR Hierarchical aggregation and recursive file discovery.
originalPath=path; restore=onCleanup(@() path(originalPath)); %#ok<NASGU>
addpath(fullfile(fileparts(fileparts(mfilename('fullpath'))),'Class'));
folder=tempname; mkdir(folder);
cleanup=onCleanup(@() rmdir(folder,'s')); %#ok<NASGU>
writeResult(fullfile(folder,'#2','IE','1','a_paw_clearance.mat'),[1;3],[1;1]);
writeResult(fullfile(folder,'#2','IE','2','b_paw_clearance.mat'),9,0);
writeResult(fullfile(folder,'#10','IE','c_paw_clearance.mat'),[10;12],[1;1]);
writeResult(fullfile(folder,'#2','LE','a_paw_clearance.mat'),[4;6],[1;1]);
writeResult(fullfile(folder,'#2','LR','a_paw_clearance.mat'),[8;NaN;10],[1;1;0]);
writeResult(fullfile(folder,'#10','LR','a_paw_clearance.mat'),[2;4],[1;1]);
% Ordinary per-frame MAT files and collected outputs must not be ingested.
writeResult(fullfile(folder,'#2','IE','ignored_stance.mat'),1000,1);
writeResult(fullfile(folder,'_collected','ignored_paw_clearance.mat'),1000,1);
collector=PawClearanceCollector();
result=collector.collect(folder,'ExpectedRatCount',2);
assert(isequal(result.RatIDs,["#2";"#10"]));
ie=result.Conditions.IE;
assert(abs(ie.Animals(1).Mean_mm-13/3)<1e-12);
assert(ie.Animals(1).VideoCount==2 && ie.Animals(1).UsedCycleCount==3);
assert(abs(ie.MeanOfRatMeans_mm-((13/3)+11)/2)<1e-12);
assert(abs(ie.MeanOfRatMeans_mm-7)>0.1); % NOT the pooled-cycle mean.
assert(abs(ie.SDOfRatMeans_mm-std([13/3;11]))<1e-12);
assert(height(result.FileSummary)==6);
assert(result.Conditions.LE.NAnimals==1 && isnan(result.Conditions.LE.RatMeans_mm(2)));
assert(result.Conditions.LR.Animals(1).NonfiniteCycleCount==1);
assert(result.Conditions.LR.Animals(1).Mean_mm==9);
assert(isnan(result.Conditions.LR.Animals(1).Recordings(1).Data.PeakPawHeight_mm(2)));
closed=collector.collect(folder,'ExpectedRatCount',2,'IncludeOpenSwings',false);
assert(closed.Conditions.IE.Animals(1).Mean_mm==2);
assert(closed.Conditions.LR.Animals(1).Mean_mm==8);
output=fullfile(folder,'roundtrip.mat'); collector.saveMat(result,output);
loaded=load(output); assert(isequaln(loaded.data,result));
plotter=DataPlotter();
[fig1,fig2]=plotter.plotPawClearanceCollection(result,'Visible','off');
cleanupFig=onCleanup(@() close([fig1 fig2])); %#ok<NASGU>
axes1=findobj(fig1,'Type','axes'); assert(numel(axes1)==3);
assert(numel(findobj(fig2,'Type','scatter'))==2);
summary=findobj(fig2,'Type','errorbar','DisplayName','Mean +/- SD of rat means');
assert(isequaln(summary.YData(:),result.GroupSummary.MeanOfRatMeans_mm));
assert(isequaln(summary.YPositiveDelta(:),result.GroupSummary.SDOfRatMeans_mm));
% Malformed candidate files fail explicitly rather than silently disappearing.
mkdir(fullfile(folder,'#2','LR','broken')); data=struct('Other',1); %#ok<NASGU>
save(fullfile(folder,'#2','LR','broken','bad_paw_clearance.mat'),'data');
caught=false;
try, collector.collect(folder,'ExpectedRatCount',2); catch e, caught=strcmp(e.identifier,'PawCollector:InvalidFile'); end
assert(caught);
disp('Collector tests passed: pooled videos, equal rat weights, numeric sorting, boundaries, NaN provenance, missing data, MAT and plots.');
end

function writeResult(output,values,boundaries)
parent=fileparts(output); if ~isfolder(parent), mkdir(parent); end
values=values(:); boundaries=boundaries(:);
data=struct('Cycle',(1:numel(values))','PeakPawHeight_mm',values, ...
    'SwingEndObserved',boundaries);
save(output,'data');
end
