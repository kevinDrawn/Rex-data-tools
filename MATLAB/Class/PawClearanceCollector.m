classdef PawClearanceCollector
    %PAWCLEARANCECOLLECTOR Aggregate cycles within rats, then weight rats equally.
    methods
        function collection = collect(~, rootDirectory, varargin)
            parser = inputParser;
            addParameter(parser, 'Conditions', {'IE','LE','LR'});
            addParameter(parser, 'IncludeOpenSwings', true, @(v) islogical(v) && isscalar(v));
            addParameter(parser, 'ExpectedRatCount', 6, ...
                @(v) isnumeric(v) && isscalar(v) && v >= 0 && mod(v,1)==0);
            parse(parser, varargin{:});
            if ~isfolder(rootDirectory)
                error('PawCollector:MissingRoot', 'Root folder not found: %s', rootDirectory);
            end
            conditions = cellstr(string(parser.Results.Conditions));
            if isempty(conditions) || numel(unique(conditions)) ~= numel(conditions) || ...
                    ~all(cellfun(@isvarname,conditions))
                error('PawCollector:InvalidConditions', 'Conditions must be unique valid field names.');
            end
            folders = dir(rootDirectory);
            folders = folders([folders.isdir]);
            names = string({folders.name})';
            isRat = ~cellfun(@isempty,regexp(cellstr(names),'^#\d+$','once'));
            names = names(isRat);
            numbers = arrayfun(@(name) str2double(extractAfter(name,1)), names);
            [numbers, order] = sort(numbers);
            names = names(order);
            if isempty(names)
                error('PawCollector:NoRats', 'No #number rat folders were found.');
            end
            if numel(unique(numbers)) ~= numel(numbers)
                error('PawCollector:DuplicateRat', 'Rat folder numbers must be unique.');
            end
            if parser.Results.ExpectedRatCount > 0 && numel(names) ~= parser.Results.ExpectedRatCount
                warning('PawCollector:RatCount', 'Expected %d rats, found %d.', ...
                    parser.Results.ExpectedRatCount,numel(names));
            end
            collection = struct();
            collection.RootDirectory = string(rootDirectory);
            collection.RatIDs = names;
            collection.ConditionNames = string(conditions(:));
            collection.IncludeOpenSwings = parser.Results.IncludeOpenSwings;
            collection.Metric = 'PeakPawHeight_mm: swing maximum minus preceding stance minimum';
            collection.WithinRatRule = 'Pool included cycles across all videos of the same rat/condition';
            collection.GroupRule = 'Unweighted mean and sample SD of individual rat means';
            collection.OutlierRule = 'No automatic outlier removal; nonfinite values excluded and retained in raw records';
            collection.Conditions = struct();
            nRats = numel(names);
            nConditions = numel(conditions);
            groupMeans = NaN(nConditions,1); groupSD = NaN(nConditions,1);
            nAnimals = zeros(nConditions,1); totalUsed = zeros(nConditions,1);
            totalVideos = zeros(nConditions,1);
            collection.PerAnimalSummary = table();
            collection.FileSummary = table();
            for c = 1:nConditions
                condition = conditions{c};
                animals = repmat(PawClearanceCollector.emptyAnimal(),nRats,1);
                for r = 1:nRats
                    animal = animals(r);
                    animal.RatID = names(r);
                    folder = fullfile(rootDirectory,names(r),condition);
                    if isfolder(folder)
                        files = dir(fullfile(folder,'**','*_paw_clearance.mat'));
                        paths = strings(numel(files),1);
                        for f = 1:numel(files)
                            paths(f) = fullfile(files(f).folder,files(f).name);
                        end
                        paths = sort(paths);
                    else
                        paths = strings(0,1);
                    end
                    if isempty(paths)
                        warning('PawCollector:MissingCondition', ...
                            '%s/%s has no *_paw_clearance.mat files.',names(r),condition);
                    end
                    values = zeros(0,1); boundaries = zeros(0,1);
                    recordingIndex = zeros(0,1); sourceCycle = zeros(0,1);
                    for f = 1:numel(paths)
                        loaded = load(paths(f),'data');
                        if ~isfield(loaded,'data') || ~isstruct(loaded.data) || ...
                                ~isscalar(loaded.data) || ~isfield(loaded.data,'PeakPawHeight_mm')
                            error('PawCollector:InvalidFile', ...
                                'Expected scalar data struct with PeakPawHeight_mm: %s',paths(f));
                        end
                        raw = loaded.data;
                        v = raw.PeakPawHeight_mm;
                        validateattributes(v,{'numeric'},{'real','vector'},mfilename,'PeakPawHeight_mm');
                        v = double(v(:));
                        if isfield(raw,'SwingEndObserved')
                            boundary = double(raw.SwingEndObserved(:));
                            if numel(boundary) ~= numel(v) || ...
                                    any(~isfinite(boundary) | (boundary~=0 & boundary~=1))
                                error('PawCollector:InvalidBoundary','Invalid SwingEndObserved: %s',paths(f));
                            end
                        else
                            boundary = NaN(size(v));
                        end
                        if isfield(raw,'Cycle')
                            cycles = double(raw.Cycle(:));
                            if numel(cycles) ~= numel(v)
                                error('PawCollector:InvalidCycle','Cycle count mismatch: %s',paths(f));
                            end
                        else
                            cycles = (1:numel(v))';
                        end
                        finite = isfinite(v);
                        used = finite;
                        if ~collection.IncludeOpenSwings
                            used = used & boundary~=0;
                        end
                        if any(~finite)
                            warning('PawCollector:NonfiniteCycles', ...
                                '%d nonfinite cycles excluded but raw data retained: %s',nnz(~finite),paths(f));
                        end
                        recording.File = paths(f);
                        recording.Data = raw;
                        animal.Recordings(end+1,1) = recording; %#ok<AGROW>
                        values = [values;v]; %#ok<AGROW>
                        boundaries = [boundaries;boundary]; %#ok<AGROW>
                        recordingIndex = [recordingIndex;repmat(f,numel(v),1)]; %#ok<AGROW>
                        sourceCycle = [sourceCycle;cycles]; %#ok<AGROW>
                        Rat = names(r); Condition = string(condition); File = paths(f);
                        TotalCycles = numel(v); UsedCycles = nnz(used);
                        OpenSwingCycles = nnz(boundary==0); UnknownBoundaryCycles = nnz(isnan(boundary));
                        fileRow = table(Rat,Condition,File,TotalCycles,UsedCycles, ...
                            OpenSwingCycles,UnknownBoundaryCycles);
                        collection.FileSummary = [collection.FileSummary;fileRow]; %#ok<AGROW>
                    end
                    used = isfinite(values);
                    if ~collection.IncludeOpenSwings
                        used = used & boundaries~=0;
                    end
                    animal.SourceFiles = paths;
                    animal.AllPeakPawHeight_mm = values;
                    animal.SwingEndObserved = boundaries;
                    animal.RecordingIndex = recordingIndex;
                    animal.SourceCycle = sourceCycle;
                    animal.Included = used;
                    animal.PeakPawHeight_mm = values(used);
                    animal.VideoCount = numel(paths);
                    animal.TotalCycleCount = numel(values);
                    animal.UsedCycleCount = nnz(used);
                    animal.OpenSwingCount = nnz(boundaries==0);
                    animal.UnknownBoundaryCount = nnz(isnan(boundaries));
                    animal.NonfiniteCycleCount = nnz(~isfinite(values));
                    if any(used)
                        animal.Mean_mm = mean(values(used));
                        animal.SD_mm = std(values(used),0);
                    end
                    animals(r) = animal;
                end
                means = [animals.Mean_mm]'; sds = [animals.SD_mm]';
                Videos = [animals.VideoCount]'; TotalCycles = [animals.TotalCycleCount]';
                UsedCycles = [animals.UsedCycleCount]'; OpenSwingCycles = [animals.OpenSwingCount]';
                NonfiniteCycles = [animals.NonfiniteCycleCount]';
                Rat = names; Condition = repmat(string(condition),nRats,1);
                MeanPeakPawHeight_mm = means; SDPeakPawHeight_mm = sds;
                perAnimal = table(Rat,Condition,Videos,TotalCycles,UsedCycles, ...
                    MeanPeakPawHeight_mm,SDPeakPawHeight_mm,OpenSwingCycles,NonfiniteCycles);
                hasData = isfinite(means);
                nAnimals(c) = nnz(hasData); totalUsed(c) = sum(UsedCycles); totalVideos(c) = sum(Videos);
                if any(hasData)
                    groupMeans(c) = mean(means(hasData));
                    groupSD(c) = std(means(hasData),0);
                end
                conditionData.Name = string(condition);
                conditionData.RatIDs = names;
                conditionData.Animals = animals;
                conditionData.RatMeans_mm = means;
                conditionData.RatSDs_mm = sds;
                conditionData.PerAnimalSummary = perAnimal;
                conditionData.MeanOfRatMeans_mm = groupMeans(c);
                conditionData.SDOfRatMeans_mm = groupSD(c);
                conditionData.NAnimals = nAnimals(c);
                conditionData.TotalUsedCycles = totalUsed(c);
                collection.Conditions.(condition) = conditionData;
                collection.PerAnimalSummary = [collection.PerAnimalSummary;perAnimal]; %#ok<AGROW>
            end
            Condition = string(conditions(:)); NAnimals = nAnimals; Videos = totalVideos;
            UsedCycles = totalUsed; MeanOfRatMeans_mm = groupMeans; SDOfRatMeans_mm = groupSD;
            collection.GroupSummary = table(Condition,NAnimals,Videos,UsedCycles, ...
                MeanOfRatMeans_mm,SDOfRatMeans_mm);
            if ~any(nAnimals)
                error('PawCollector:NoData','No usable paw-clearance cycles were found.');
            end
        end

        function printSummary(~, collection)
            fprintf('\n========== Per-rat paw clearance ==========\n');
            fprintf('Mean +/- SD across pooled cycles of each rat/condition (mm).\n');
            disp(collection.PerAnimalSummary);
            fprintf('\n========== Condition comparison ==========\n');
            fprintf('Mean +/- SD of RAT MEANS; each rat has equal weight.\n');
            disp(collection.GroupSummary);
            for c = 1:numel(collection.ConditionNames)
                row = collection.GroupSummary(c,:);
                fprintf('%s: %.4f +/- %.4f mm (n=%d rats, %d cycles, %d videos).\n', ...
                    row.Condition,row.MeanOfRatMeans_mm,row.SDOfRatMeans_mm, ...
                    row.NAnimals,row.UsedCycles,row.Videos);
            end
            fprintf('Open trailing swings included: %d. No automatic outlier removal.\n', ...
                collection.IncludeOpenSwings);
            fprintf('Exact source files and original per-video structs: FileSummary / Conditions.*.Animals.*.Recordings.\n');
        end

        function results = analyzeStatistics(~, collection)
            % Experimental unit: one rat mean per condition, never individual cycles.
            % Both analyses are reported; do not select a method by its p-value.
            conditions = string(collection.ConditionNames(:));
            values = NaN(numel(collection.RatIDs),numel(conditions));
            for c = 1:numel(conditions)
                values(:,c) = collection.Conditions.(char(conditions(c))).RatMeans_mm;
            end
            complete = all(isfinite(values),2);
            x = values(complete,:);
            [n,k] = size(x);
            if n < 2 || k < 3
                error('PawCollector:InsufficientStatistics', ...
                    'Statistics require at least two complete rats and three conditions.');
            end
            results.RatIDs = collection.RatIDs(complete);
            results.ExcludedIncompleteRatIDs = collection.RatIDs(~complete);
            results.ConditionNames = conditions;
            results.RatMeans_mm = x;
            results.Alpha = 0.05;
            results.ExperimentalUnit = "Rat; complete paired rat means across conditions";
            results.Multiplicity = "Holm correction across all condition pairs, separately for each test family";
            [results.FriedmanAsymptoticP,results.FriedmanTable] = friedman(x,1,'off');
            % Exact within-rat permutation distribution for small data sets.
            % For n=6 and k=3, all 6^6 = 46656 permutations are enumerated.
            ranks = zeros(n,k);
            for r = 1:n
                ranks(r,:) = tiedrank(x(r,:));
            end
            center = n*(k+1)/2;
            observed = sum((sum(ranks,1)-center).^2);
            permutationCount = factorial(k)^n;
            results.FriedmanPermutationCount = permutationCount;
            results.FriedmanExactP = NaN;
            if permutationCount <= 1e6
                rankSums = zeros(1,k);
                for r = 1:n
                    permutations = perms(ranks(r,:));
                    nextSums = zeros(size(rankSums,1)*size(permutations,1),k);
                    for j = 1:size(permutations,1)
                        rows = (j-1)*size(rankSums,1)+(1:size(rankSums,1));
                        nextSums(rows,:) = rankSums + permutations(j,:);
                    end
                    rankSums = nextSums;
                end
                permuted = sum((rankSums-center).^2,2);
                results.FriedmanExactP = mean(permuted >= observed-1e-10);
            end
            pairs = nchoosek(1:k,2);
            m = size(pairs,1);
            ConditionA = conditions(pairs(:,1)); ConditionB = conditions(pairs(:,2));
            NRats = repmat(n,m,1);
            MeanDifference_BminusA_mm = zeros(m,1);
            PairedT_CI95Low_mm = zeros(m,1); PairedT_CI95High_mm = zeros(m,1);
            PairedT_P = zeros(m,1); WilcoxonExact_P = zeros(m,1);
            TStatistic = zeros(m,1); DegreesOfFreedom = zeros(m,1);
            for j = 1:m
                a = x(:,pairs(j,1)); b = x(:,pairs(j,2));
                MeanDifference_BminusA_mm(j) = mean(b-a);
                [~,PairedT_P(j),ci,stats] = ttest(b,a,'Tail','both');
                PairedT_CI95Low_mm(j) = ci(1); PairedT_CI95High_mm(j) = ci(2);
                TStatistic(j) = stats.tstat; DegreesOfFreedom(j) = stats.df;
                if all(a == b)
                    WilcoxonExact_P(j) = 1;
                else
                    WilcoxonExact_P(j) = signrank(b,a,'Method','exact','Tail','both');
                end
            end
            PairedT_P_Holm = PawClearanceCollector.holmAdjust(PairedT_P);
            WilcoxonExact_P_Holm = PawClearanceCollector.holmAdjust(WilcoxonExact_P);
            PairedT_Significant_Holm = PairedT_P_Holm < results.Alpha;
            Wilcoxon_Significant_Holm = WilcoxonExact_P_Holm < results.Alpha;
            results.Pairwise = table(ConditionA,ConditionB,NRats,MeanDifference_BminusA_mm, ...
                PairedT_CI95Low_mm,PairedT_CI95High_mm,TStatistic,DegreesOfFreedom, ...
                PairedT_P,PairedT_P_Holm,PairedT_Significant_Holm, ...
                WilcoxonExact_P,WilcoxonExact_P_Holm,Wilcoxon_Significant_Holm);
            results.CINote = "95% CIs are paired-t intervals for mean differences, without multiplicity adjustment";
            results.Assumptions = "Paired t: approximately normal between-condition differences; signed rank: symmetric difference distribution. Small n limits assumption assessment.";
            fprintf('\n========== Paired statistics: n=%d complete rats ==========\n',n);
            fprintf('Friedman exact permutation p = %.8f; asymptotic p = %.8f.\n', ...
                results.FriedmanExactP,results.FriedmanAsymptoticP);
            fprintf('All pairwise tests are TWO-SIDED; Holm adjusts all %d pairs separately per method.\n',m);
            fprintf('Differences are ConditionB - ConditionA (mm). CIs are unadjusted paired-t intervals.\n');
            disp(results.Pairwise);
            fprintf('Report both methods; significance may depend on distributional assumptions.\n');
        end

        function saveMat(~, data, outputPath)
            % Collection payloads have nested records/tables rather than frame rows.
            validateattributes(data,{'struct'},{'scalar'});
            [~,~,extension] = fileparts(outputPath);
            if ~strcmpi(extension,'.mat')
                error('PawCollector:InvalidOutput','Output path must end with .mat.');
            end
            save(outputPath,'data');
        end
    end

    methods (Static, Access = private)
        function adjusted = holmAdjust(p)
            [sorted,order] = sort(p(:));
            m = numel(p);
            corrected = min(1,cummax((m-(1:m)'+1).*sorted));
            adjusted = zeros(m,1);
            adjusted(order) = corrected;
        end

        function animal = emptyAnimal()
            animal = struct('RatID',"",'SourceFiles',strings(0,1), ...
                'Recordings',repmat(struct('File',"",'Data',struct()),0,1), ...
                'AllPeakPawHeight_mm',zeros(0,1),'PeakPawHeight_mm',zeros(0,1), ...
                'SwingEndObserved',zeros(0,1),'RecordingIndex',zeros(0,1), ...
                'SourceCycle',zeros(0,1),'Included',false(0,1), ...
                'VideoCount',0,'TotalCycleCount',0,'UsedCycleCount',0, ...
                'OpenSwingCount',0,'UnknownBoundaryCount',0,'NonfiniteCycleCount',0, ...
                'Mean_mm',NaN,'SD_mm',NaN);
        end
    end
end
