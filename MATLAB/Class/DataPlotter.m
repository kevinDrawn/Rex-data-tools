classdef DataPlotter
    %DATAPLOTTER Plot each cell of N-by-M signals in a separate subplot.
    properties (SetAccess = private)
        Config
    end

    methods
        function obj = DataPlotter()
            configDirectory = fullfile(fileparts(mfilename('fullpath')), 'config');
            originalPath = path;
            restorePath = onCleanup(@() path(originalPath)); %#ok<NASGU>
            addpath(configDirectory);
            obj.Config = PlotConfig();
        end

        function [fig, axesHandles, displayData] = plotPawTrajectories(obj, result, varargin)
            parser=inputParser;
            addParameter(parser,'Visible','on');
            addParameter(parser,'HideDuplicateConditions',true);
            addParameter(parser,'DisplaySamples',1001);
            addParameter(parser,'CenterX',false,@(value) islogical(value) && isscalar(value));
            parse(parser,varargin{:});
            sampleCount=parser.Results.DisplaySamples;
            validateattributes(sampleCount,{'numeric'},{'scalar','integer','>=',20});
            displayData.Method="One continuous time-ordered PCHIP XY trace per recording; one constant translation per recording";
            displayData.GrayTraceClosure="None: no cycle splitting, no endpoint bridge, no per-cycle translation";
            displayData.MeanRule="Phase average of complete cycles in the same fixed recording coordinates; mean loop closure is display-only";
            iliumRelative=isfield(result,'CoordinateReference') && result.CoordinateReference=="ilium";
            iliumXOnly=isfield(result,'CoordinateReference') && result.CoordinateReference=="ilium_x";
            displayData.CoordinateReference="fixed recording reference";
            if iliumRelative
                displayData.CoordinateReference="ipsilateral ilium marker, framewise TO - IL";
                displayData.Method="One continuous time-ordered PCHIP XY trace per recording; framewise TO - IL, no cycle translation";
                displayData.MeanRule="Phase average of complete cycles in framewise IL-relative coordinates; mean loop closure is display-only";
            end
            if iliumXOnly
                displayData.CoordinateReference="X relative to ipsilateral IL; Y minus a constant mean stance-minimum offset per recording";
                displayData.Method="One continuous time-ordered PCHIP trace; X = TO_x - IL_x; Y = TO_y - mean stance minimum (one constant per recording)";
                displayData.MeanRule="Complete-cycle phase mean in X-only IL-relative coordinates; mean loop closure is display-only";
            end
            displayData.CenterX=parser.Results.CenterX;
            displayData.XCenteringRule="If enabled: subtract mean X across all original timestamps once per recording, after the coordinate-reference correction";
            displayData.Conditions=struct();
            names=result.ConditionNames; allX=[]; allY=[];
            for c=1:numel(names)
                name=char(names(c)); data=result.Conditions.(name);
                shown.Recordings=struct([]); meanX=[]; meanY=[];
                for f=1:numel(data.SourceRecordings)
                    source=data.SourceRecordings(f);
                    membership=false(1,numel(data.Cycles));
                    for j=1:numel(data.Cycles)
                        membership(j)=erase(data.Cycles(j).SourceFile,'_paw_clearance')==source.File;
                    end
                    selected=find(membership);
                    % One fixed reference for the entire recording, never reset
                    % at IC, TO, or cycle boundaries.
                    if iliumRelative || iliumXOnly
                        xOrigin=source.IL_x_filtered(:);
                        if iliumXOnly, yOrigin=source.GroundHeightMean_mm; else, yOrigin=source.IL_y_filtered(:); end
                    elseif isempty(selected)
                        xOrigin=mean(source.TO_x_filtered);
                        yOrigin=min(source.TO_y_filtered);
                    else
                        xOrigin=mean([data.Cycles(selected).XOrigin_mm]);
                        yOrigin=mean([data.Cycles(selected).GroundHeight_mm]);
                    end
                    fullTime=source.Time(:);
                    included=true(size(fullTime));
                    if isfield(source,'IncludeMask'), included=source.IncludeMask; end
                    sourceRows=find(included);
                    t=fullTime(included);
                    x=source.TO_x_filtered(:)-xOrigin;
                    y=source.TO_y_filtered(:)-yOrigin;
                    xCenterOffset=0;
                    if parser.Results.CenterX
                        xCenterOffset=mean(x(included));
                        x=x-xCenterOffset;
                    end
                    fullX=x; fullY=y;
                    x=x(included); y=y(included);
                    validateattributes(x,{'numeric'},{'vector','finite'});
                    validateattributes(y,{'numeric'},{'vector','finite'});
                    % Retain every original timestamp exactly in the dense grid.
                    query=unique([t;linspace(t(1),t(end),max(sampleCount,10*numel(t)))']);
                    recording.File=source.File; recording.Time_s=query;
                    recording.X_mm=interp1(t,x,query,'pchip');
                    recording.Y_mm=interp1(t,y,query,'pchip');
                    recording.SourceRowIndices=sourceRows;
                    recording.SourceTime_s=t; recording.SourceX_mm=x; recording.SourceY_mm=y;
                    recording.XOrigin_mm=xOrigin; recording.YOrigin_mm=yOrigin;
                    recording.XCenterOffset_mm=xCenterOffset;
                    if f==1, shown.Recordings=recording; else, shown.Recordings(f)=recording; end
                    for j=selected
                        cycle=data.Cycles(j); indices=cycle.StartIndex:cycle.EndIndex;
                        phase=cycle.Phase_percent; phase(1)=0; phase(end)=100;
                        meanX(:,end+1)=interp1(phase,fullX(indices),result.Phase_percent,'linear'); %#ok<AGROW>
                        meanY(:,end+1)=interp1(phase,fullY(indices),result.Phase_percent,'linear'); %#ok<AGROW>
                    end
                    allX=[allX;recording.X_mm]; allY=[allY;recording.Y_mm]; %#ok<AGROW>
                end
                shown.MeanX_phase_mm=mean(meanX,2); shown.MeanY_phase_mm=mean(meanY,2);
                if ~isempty(meanX)
                    [shown.MeanX_mm,shown.MeanY_mm]=DataPlotter.interpolateClosedTrajectory( ...
                        shown.MeanX_phase_mm,shown.MeanY_phase_mm,sampleCount);
                else
                    shown.MeanX_mm=[]; shown.MeanY_mm=[];
                end
                displayData.Conditions.(name)=shown;
            end
            if isempty(allX), error('PawTrajectory:NoRecordings','No recorded XY coordinates found.'); end
            xLimits=[min(allX),max(allX)]; yLimits=[min(allY),max(allY)];
            xLimits=xLimits+[-1,1]*max(1,0.05*diff(xLimits));
            if parser.Results.CenterX, xLimits=[-1 1]*max(abs(xLimits)); end
            yLimits=yLimits+[-1,1]*max(1,0.05*diff(yLimits));
            baselineLayout=numel(names)==5 && strcmpi(names(1),'Baseline');
            figureHeight=650;
            if baselineLayout, figureHeight=950; end
            fig=figure('Name','Continuous toe trajectories','Color','w', ...
                'Position',[100 50 1100 figureHeight],'Visible',parser.Results.Visible);
            if baselineLayout
                layout=tiledlayout(fig,3,4,'TileSpacing','compact','Padding','loose');
            else
                layout=tiledlayout(fig,ceil(numel(names)/2),2,'TileSpacing','compact','Padding','compact');
            end
            axesHandles=gobjects(numel(names),1); average=gobjects(0);
            for c=1:numel(names)
                if baselineLayout
                    tilePositions=[2 5 7 9 11];
                    ax=nexttile(layout,tilePositions(c),[1 2]);
                else
                    ax=nexttile(layout);
                end
                axesHandles(c)=ax; hold(ax,'on');
                data=result.Conditions.(char(names(c))); shown=displayData.Conditions.(char(names(c)));
                set(ax,'FontName',obj.Config.FontName,'FontSize',15,'Box','off','TitleFontSizeMultiplier',1);
                hidden=parser.Results.HideDuplicateConditions && strlength(data.DuplicateOf)>0;
                if hidden
                    text(ax,mean(xLimits),mean(yLimits),'Verify duplicate source recording', ...
                        'HorizontalAlignment','center','FontSize',12);
                else
                    for f=1:numel(shown.Recordings)
                        recording=shown.Recordings(f);
                        individual=plot(ax,recording.X_mm,recording.Y_mm, ...
                            'Color',[0.78 0.78 0.78],'LineWidth',0.9,'Tag','ContinuousRecording');
                    end
                    if ~isempty(shown.MeanX_mm)
                        average=plot(ax,shown.MeanX_mm,shown.MeanY_mm,'k','LineWidth',3,'Tag','CycleMean');
                    end
                end
                title(ax,names(c),'Interpreter','none');
                if iliumXOnly
                    xlabel(ax,'Horizontal position (mm)'); ylabel(ax,'Relative toe height (mm)');
                elseif iliumRelative
                    xlabel(ax,'Toe - IL X (mm)'); ylabel(ax,'Toe - IL Y (mm)');
                else
                    xlabel(ax,'Toe X (mm)'); ylabel(ax,'Toe height (mm)');
                end
                if parser.Results.CenterX, xlabel(ax,'Horizontal position (mm)'); end
                axis(ax,'equal'); xlim(ax,xLimits); ylim(ax,yLimits); grid(ax,'off');
            end
            if ~isempty(average)
                sharedLegend=legend([individual,average],{'Continuous recording','Mean (complete cycles)'}, ...
                    'Box','off','Orientation','horizontal','FontSize',12);
                sharedLegend.Layout.Tile='south';
            end
        end

        function [fig, axesHandles] = plotPawTrajectoryComparisons(obj, displayData, varargin)
            % Reuse displayed coordinates exactly; no alignment or rescaling.
            parser=inputParser;
            addParameter(parser,'Visible','on');
            parse(parser,varargin{:});
            groups={{'Baseline','IE','IR'},{'LE','LR'}};
            titles={'Transparency comparison','Assistance comparison'};
            colors.Baseline=[0.1 0.1 0.1]; colors.IE=[0 0.45 0.74];
            colors.IR=[0.1 0.6 0.3]; colors.LE=[0.85 0.33 0.1];
            colors.LR=[0.49 0.18 0.56];
            allX=[]; allY=[];
            for g=1:2
                for c=1:numel(groups{g})
                    name=groups{g}{c};
                    if ~isfield(displayData.Conditions,name)
                        error('PawTrajectory:MissingComparison','Comparison requires condition %s.',name);
                    end
                    data=displayData.Conditions.(name);
                    for f=1:numel(data.Recordings)
                        allX=[allX;data.Recordings(f).X_mm]; %#ok<AGROW>
                        allY=[allY;data.Recordings(f).Y_mm]; %#ok<AGROW>
                    end
                    allX=[allX;data.MeanX_mm]; allY=[allY;data.MeanY_mm]; %#ok<AGROW>
                end
            end
            xExtent=max(abs(allX)); xLimits=[-1 1]*(xExtent+max(1,0.05*2*xExtent));
            yLimits=[min(allY),max(allY)]; yLimits=yLimits+[-1 1]*max(1,0.05*diff(yLimits));
            fig=figure('Name','Toe trajectories: transparency and assistance', ...
                'Color','w','Position',[100 100 1250 420],'Visible',parser.Results.Visible);
            layout=tiledlayout(fig,1,2,'TileSpacing','compact','Padding','loose');
            axesHandles=gobjects(2,1);
            for g=1:2
                ax=nexttile(layout); axesHandles(g)=ax; hold(ax,'on');
                set(ax,'FontName',obj.Config.FontName,'FontSize',15,'Box','off','TitleFontSizeMultiplier',1);
                % Draw all continuous recordings first so none cover mean lines.
                for c=1:numel(groups{g})
                    name=groups{g}{c}; data=displayData.Conditions.(name);
                    pale=0.84*[1 1 1]+0.16*colors.(name);
                    for f=1:numel(data.Recordings)
                        line=plot(ax,data.Recordings(f).X_mm,data.Recordings(f).Y_mm, ...
                            'Color',pale,'LineWidth',0.65,'HandleVisibility','off','Tag','ContinuousRecording');
                        line.UserData=name;
                    end
                end
                means=gobjects(numel(groups{g}),1);
                for c=1:numel(groups{g})
                    name=groups{g}{c}; data=displayData.Conditions.(name);
                    means(c)=plot(ax,data.MeanX_mm,data.MeanY_mm,'Color',colors.(name), ...
                        'LineWidth',2.7,'DisplayName',name,'Tag','ComparisonMean');
                    means(c).UserData=name;
                end
                title(ax,titles{g}); xlabel(ax,'Horizontal position (mm)');
                ylabel(ax,'Relative toe height (mm)');
                axis(ax,'equal'); xlim(ax,xLimits); ylim(ax,yLimits); grid(ax,'off');
                legend(ax,means,groups{g},'Location','southoutside','Orientation','horizontal', ...
                    'Box','off','FontSize',12);
            end
        end

        function [fig, axesHandles] = plotEventAngle(obj, result, varargin)
            %PLOTEVENTANGLE Separate disjoint recording intervals into panels.
            parser = inputParser;
            addParameter(parser,'Visible','on');
            addParameter(parser,'ZeroTimeAtIntervalStart',true);
            parse(parser,varargin{:});
            count = numel(result.Segments);
            fig = figure('Name',char(result.Rat+" | "+result.Condition+" | "+result.Side), ...
                'Color','w','Visible',parser.Results.Visible,'Position',[100 100 1400 450*count]);
            layout = tiledlayout(fig,count,1,'TileSpacing','compact','Padding','compact');
            axesHandles = gobjects(count,1);
            for q = 1:count
                segment = result.Segments(q);
                origin = 0;
                if parser.Results.ZeroTimeAtIntervalStart, origin = segment.TimeRange_s(1); end
                ax = nexttile(layout); axesHandles(q) = ax;
                set(ax,'FontName',obj.Config.FontName,'FontSize',obj.Config.FontSize, ...
                    'Box','off','TitleFontSizeMultiplier',1);
                yyaxis(ax,'left'); hold(ax,'on');
                angleLine = plot(ax,segment.Time_s-origin,segment.Angle_deg,'k', ...
                    'LineWidth',obj.Config.LineWidth);
                icAngle = interp1(segment.Time_s,segment.Angle_deg,segment.IC_Time_s,'linear',NaN);
                toAngle = interp1(segment.Time_s,segment.Angle_deg,segment.TO_Time_s,'linear',NaN);
                ic = scatter(ax,segment.IC_Time_s-origin,icAngle,45,[0 0.4 0.75],'v','filled');
                to = scatter(ax,segment.TO_Time_s-origin,toAngle,45,[0.9 0.35 0.05],'^','filled');
                ylabel(ax,'Hall ankle angle (deg)');
                yyaxis(ax,'right'); hold(ax,'on');
                % Add exact event knots so transitions occur at the video event,
                % rather than the next Hall sample. Preserve NaN if no events.
                knots = [segment.TimeRange_s(1);segment.Events.Time_s;segment.TimeRange_s(2)];
                states = [segment.StanceState(1);segment.Events.StateAfterEvent;segment.StanceState(end)];
                stateLine = stairs(ax,knots-origin,states,'Color',[0.6 0.6 0.6],'LineWidth',1.2);
                ylim(ax,[-0.1 1.1]); yticks(ax,[0 1]); yticklabels(ax,{'Swing (0)','Stance (1)'});
                ylabel(ax,'Gait state');
                ax.YAxis(1).Color = [0 0 0]; ax.YAxis(2).Color = [0.5 0.5 0.5];
                yyaxis(ax,'left');
                xlim(ax,segment.TimeRange_s-origin);
                if parser.Results.ZeroTimeAtIntervalStart
                    xlabel(ax,'Time from interval start (s)');
                else
                    xlabel(ax,'Time (s)');
                end
                title(ax,sprintf('%s | %s | %s | interval %d: %.3f-%.3f s', ...
                    result.Rat,result.Condition,result.Side,q,segment.TimeRange_s), 'Interpreter','none');
                grid(ax,'off'); box(ax,'off');
                legend(ax,[angleLine,ic,to,stateLine],{'Hall angle','IC','TO','Stance state'}, ...
                    'Location','northeastoutside','Box','off');
            end
        end

        function [fig, ax, traces] = plotStanceOverlay(obj, mocapTime, toeHeight, ...
                stanceTime, stanceState, timeRange, varargin)
            %PLOTSTANCEOVERLAY Toe height and binary stance on one time axis.
            % Each trace retains its own timestamps; no interpolation is used.
            % Left: toe height in mm. Right: 0 = swing, 1 = stance.
            if nargin < 6
                timeRange = [];
            end
            validateattributes(mocapTime, {'numeric'}, ...
                {'vector', 'real', 'finite', 'nonempty', 'increasing'});
            validateattributes(stanceTime, {'numeric'}, ...
                {'vector', 'real', 'finite', 'nonempty', 'increasing'});
            validateattributes(toeHeight, {'numeric'}, ...
                {'vector', 'real', 'numel', numel(mocapTime)});
            validateattributes(stanceState, {'numeric', 'logical'}, ...
                {'vector', 'real', 'finite', 'numel', numel(stanceTime)});
            if any(stanceState(:) ~= 0 & stanceState(:) ~= 1)
                error('DataPlotter:InvalidStance', 'Stance must be 0 (swing) or 1 (stance).');
            end
            mocapTime = double(mocapTime(:));
            stanceTime = double(stanceTime(:));
            if isempty(timeRange)
                timeRange = [max(mocapTime(1), stanceTime(1)), ...
                    min(mocapTime(end), stanceTime(end))];
            end
            parser = inputParser;
            addParameter(parser, 'Title', 'Left hind paw: toe height and stance');
            addParameter(parser, 'Visible', 'on');
            parse(parser, varargin{:});
            [fig, axesHandles] = obj.plotGroups(mocapTime, {double(toeHeight(:))}, ...
                timeRange, 'vertical', 'Titles', {parser.Results.Title}, ...
                'YLabels', {'Toe marker height (mm)'}, 'XLabel', 'Time (s)', ...
                'Colors', {[0 0 0]}, 'Visible', parser.Results.Visible);
            ax = axesHandles(1);
            traces.ToeHeight = findobj(ax, 'Type', 'line');
            yyaxis(ax, 'right');
            hold(ax, 'on');
            traces.Stance = stairs(ax, stanceTime, double(stanceState(:)), ...
                'Color', [0.55 0.55 0.55], 'LineWidth', obj.Config.LineWidth);
            ylim(ax, [-0.1 1.1]);
            yticks(ax, [0 1]);
            yticklabels(ax, {'Swing (0)', 'Stance (1)'});
            ylabel(ax, 'Gait state', 'Interpreter', 'none');
            hold(ax, 'off');
            ax.YAxis(1).Color = [0 0 0];
            ax.YAxis(2).Color = [0.45 0.45 0.45];
            yyaxis(ax, 'left');
            legend(ax, [traces.ToeHeight, traces.Stance], ...
                {'Toe height (left)', 'Stance (left hind paw)'}, ...
                'Interpreter', 'none', 'Box', 'off', ...
                'FontSize', obj.Config.FontSize, 'FontName', obj.Config.FontName, ...
                'Location', 'northeastoutside');
        end

        function markers = annotatePawClearance(~, ax, result)
            %ANNOTATEPAWCLEARANCE Mark per-cycle stance minima and swing maxima.
            yyaxis(ax, 'left');
            hold(ax, 'on');
            markers.Ground = scatter(ax, result.GroundTime_s, result.GroundHeight_mm, ...
                45, [0.00 0.35 0.70], 'v', 'filled', ...
                'DisplayName', 'Stance minimum');
            markers.Peak = scatter(ax, result.PeakTime_s, result.PeakToeHeight_mm, ...
                45, [0.89 0.36 0.09], '^', 'filled', ...
                'DisplayName', 'Swing maximum');
            hold(ax, 'off');
        end

        function [individualFigure, groupFigure] = plotPawClearanceCollection(obj, collection, varargin)
            %PLOTPAWCLEARANCECOLLECTION Within-rat SD and between-rat SD are distinct.
            parser = inputParser;
            addParameter(parser,'Visible','on');
            parse(parser,varargin{:});
            conditions = collection.ConditionNames;
            nConditions = numel(conditions);
            nRats = numel(collection.RatIDs);
            conditionColors = [0.25 0.25 0.25;0.90 0.40 0.10;0.00 0.35 0.75];
            individualFigure = figure('Name','Paw clearance: individual rats', ...
                'Color',obj.Config.FigureColor,'Position',[80 80 1500 560], ...
                'Visible',parser.Results.Visible);
            layout = tiledlayout(individualFigure,1,nConditions,'TileSpacing','compact','Padding','compact');
            individualAxes = gobjects(nConditions,1);
            bounds = [];
            for c = 1:nConditions
                condition = collection.Conditions.(char(conditions(c)));
                ax = nexttile(layout); individualAxes(c) = ax;
                color = conditionColors(mod(c-1,3)+1,:);
                errorbar(ax,1:nRats,condition.RatMeans_mm,condition.RatSDs_mm, ...
                    'o','LineStyle','none','Color',color,'MarkerFaceColor',color, ...
                    'MarkerSize',7,'CapSize',10,'LineWidth',obj.Config.LineWidth, ...
                    'DisplayName','Rat mean +/- within-rat SD');
                set(ax,'XTick',1:nRats,'XTickLabel',cellstr(collection.RatIDs), ...
                    'FontName',obj.Config.FontName,'FontSize',obj.Config.FontSize, ...
                    'Box',obj.Config.Box,'XGrid','off','YGrid','off','TickLabelInterpreter','none');
                xlim(ax,[0.5 nRats+0.5]);
                title(ax,sprintf('%s (n=%d rats)',conditions(c),condition.NAnimals),'Interpreter','none');
                xlabel(ax,'Rat');
                if c==1, ylabel(ax,'Peak paw height (mm)'); end
                bounds = [bounds;condition.RatMeans_mm-condition.RatSDs_mm; ...
                    condition.RatMeans_mm+condition.RatSDs_mm]; %#ok<AGROW>
            end
            title(layout,'Individual rat mean +/- within-rat SD (videos pooled within rat/condition)', ...
                'FontName',obj.Config.FontName,'FontSize',obj.Config.FontSize,'Interpreter','none');
            linkaxes(individualAxes,'y');

            groupFigure = figure('Name','Paw clearance: condition comparison', ...
                'Color',obj.Config.FigureColor,'Position',[150 150 1100 700], ...
                'Visible',parser.Results.Visible);
            ax = axes('Parent',groupFigure); hold(ax,'on');
            ratColors = lines(nRats); ratHandles = gobjects(nRats,1);
            offsets = linspace(-0.12,0.12,nRats);
            for r = 1:nRats
                values = NaN(nConditions,1);
                for c = 1:nConditions
                    condition = collection.Conditions.(char(conditions(c)));
                    values(c) = condition.RatMeans_mm(r);
                end
                x = (1:nConditions)' + offsets(r);
                plot(ax,x,values,'-','Color',[0.80 0.80 0.80], ...
                    'LineWidth',0.75,'HandleVisibility','off');
                ratHandles(r) = scatter(ax,x,values,55,ratColors(r,:), ...
                    'filled','DisplayName',char(collection.RatIDs(r)));
            end
            summary = collection.GroupSummary;
            meanHandle = errorbar(ax,1:nConditions,summary.MeanOfRatMeans_mm, ...
                summary.SDOfRatMeans_mm,'kd','LineStyle','none', ...
                'MarkerFaceColor','k','MarkerSize',10,'CapSize',14, ...
                'LineWidth',2,'DisplayName','Mean +/- SD of rat means');
            hold(ax,'off');
            set(ax,'XTick',1:nConditions,'XTickLabel',cellstr(conditions), ...
                'FontName',obj.Config.FontName,'FontSize',obj.Config.FontSize, ...
                'Box',obj.Config.Box,'XGrid','off','YGrid','off','TickLabelInterpreter','none');
            xlim(ax,[0.5 nConditions+0.5]);
            ylabel(ax,'Peak paw height (mm)'); xlabel(ax,'Condition');
            title(ax,'Condition comparison: each rat has equal weight','Interpreter','none');
            legend(ax,[ratHandles;meanHandle], ...
                [cellstr(collection.RatIDs);{'Mean +/- SD of rat means'}], ...
                'Location','northeastoutside','Box','off','Interpreter','none', ...
                'FontName',obj.Config.FontName,'FontSize',14);
            bounds = [bounds;summary.MeanOfRatMeans_mm-summary.SDOfRatMeans_mm; ...
                summary.MeanOfRatMeans_mm+summary.SDOfRatMeans_mm];
            bounds = bounds(isfinite(bounds));
            if ~isempty(bounds)
                low = min(0,min(bounds)); high = max(bounds);
                limits = [low, high+max(1,0.08*(high-low))];
                if limits(2)<=limits(1), limits(2)=limits(1)+1; end
                for c = 1:nConditions, ylim(individualAxes(c),limits); end
                ylim(ax,limits);
            end
        end

        function [fig, axesHandles] = plotGroups(obj, time, groups, timeRange, direction, varargin)
            %PLOTGROUPS One group = one subplot; matrix columns = curves.
            % timeRange: [start end] in the same units as time; [] = all.
            % direction: 'vertical' (N-by-1) or 'horizontal' (1-by-N).
            % Options: Titles, YLabels, Legends, Colors (one cell per group),
            % XLabel (text), Visible ('on'/'off'). Returns figure and axes.
            if nargin < 4
                timeRange = [];
            end
            if nargin < 5
                direction = 'vertical';
            end
            validateattributes(time, {'numeric'}, {'vector', 'real', 'finite', 'nonempty'});
            time = time(:);
            if any(diff(time) < 0) || time(end) <= time(1)
                error('DataPlotter:InvalidTime', 'Time must be nondecreasing and span a nonzero interval.');
            end
            direction = validatestring(direction, {'vertical', 'horizontal'});
            if ~iscell(groups) || isempty(groups) || ~isvector(groups)
                error('DataPlotter:InvalidGroups', 'groups must be a nonempty cell vector of signal matrices.');
            end
            count = numel(groups);
            if isempty(timeRange)
                timeRange = [time(1) time(end)];
            end
            validateattributes(timeRange, {'numeric'}, {'vector', 'numel', 2, 'real', 'finite'});
            if timeRange(1) >= timeRange(2)
                error('DataPlotter:InvalidRange', 'Time range must satisfy start < end.');
            end
            selected = time >= timeRange(1) & time <= timeRange(2);
            if ~any(selected)
                error('DataPlotter:EmptyRange', 'No samples fall within the requested time range.');
            end
            parser = inputParser;
            addParameter(parser, 'Titles', repmat({''}, 1, count));
            addParameter(parser, 'YLabels', repmat({''}, 1, count));
            addParameter(parser, 'Legends', repmat({{}}, 1, count));
            addParameter(parser, 'Colors', repmat({[]}, 1, count));
            addParameter(parser, 'XLabel', 'Time', @(x) ischar(x) || (isstring(x) && isscalar(x)));
            addParameter(parser, 'Visible', 'on', @(x) any(strcmp(x, {'on', 'off'})));
            parse(parser, varargin{:});
            options = parser.Results;
            for name = {'Titles', 'YLabels', 'Legends', 'Colors'}
                value = options.(name{1});
                if ~iscell(value) || numel(value) ~= count
                    error('DataPlotter:InvalidOptions', '%s must have one cell per group.', name{1});
                end
            end
            % Validate all groups before opening a figure.
            for index = 1:count
                signals = groups{index};
                validateattributes(signals, {'numeric'}, {'2d', 'real', 'nonempty'});
                if size(signals, 1) ~= numel(time)
                    error('DataPlotter:RowCountMismatch', 'Group %d must have one row per time sample.', index);
                end
                for name = {'Titles', 'YLabels'}
                    label = options.(name{1}){index};
                    if ~(ischar(label) && (isrow(label) || isempty(label))) && ...
                            ~(isstring(label) && isscalar(label))
                        error('DataPlotter:InvalidOptions', '%s must contain text scalars.', name{1});
                    end
                end
                labels = options.Legends{index};
                if ~isempty(labels) && (~iscellstr(labels) && ~isstring(labels)) %#ok<ISCLSTR>
                    error('DataPlotter:InvalidLegend', 'Legend labels must be a cell array of text or string array.');
                end
                if ~isempty(labels) && numel(labels) ~= size(signals, 2)
                    error('DataPlotter:InvalidLegend', 'Group %d requires one legend label per curve.', index);
                end
                colors = options.Colors{index};
                if ~isempty(colors)
                    validateattributes(colors, {'numeric'}, ...
                        {'real', 'finite', 'size', [size(signals, 2) 3], '>=', 0, '<=', 1});
                end
            end

            fig = figure('Color', obj.Config.FigureColor, ...
                'Position', obj.Config.FigurePosition, 'Visible', options.Visible);
            if strcmp(direction, 'vertical')
                layout = tiledlayout(fig, count, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
            else
                layout = tiledlayout(fig, 1, count, 'TileSpacing', 'compact', 'Padding', 'compact');
            end
            axesHandles = gobjects(count, 1);
            for index = 1:count
                ax = nexttile(layout);
                axesHandles(index) = ax;
                colors = options.Colors{index};
                if isempty(colors)
                    colors = obj.Config.ColorOrder;
                end
                colororder(ax, colors);
                lines = plot(ax, time(selected), groups{index}(selected, :), 'LineWidth', obj.Config.LineWidth);
                % Assign actual line colors explicitly, independent of axes resets.
                for curve = 1:numel(lines)
                    colorIndex = mod(curve - 1, size(colors, 1)) + 1;
                    lines(curve).Color = colors(colorIndex, :);
                end
                set(ax, 'Box', obj.Config.Box, 'XGrid', obj.Config.Grid, ...
                    'YGrid', obj.Config.Grid, 'XMinorGrid', obj.Config.Grid, ...
                    'YMinorGrid', obj.Config.Grid, 'FontSize', obj.Config.FontSize, ...
                    'FontName', obj.Config.FontName, 'TickLabelInterpreter', 'none', ...
                    'TitleFontSizeMultiplier', 1, 'LabelFontSizeMultiplier', 1);
                title(ax, options.Titles{index}, 'Interpreter', 'none');
                ylabel(ax, options.YLabels{index}, 'Interpreter', 'none');
                xlabel(ax, options.XLabel, 'Interpreter', 'none');
                xlim(ax, timeRange);
                if ~isempty(options.Legends{index})
                    legend(ax, options.Legends{index}, 'Interpreter', 'none', ...
                        'Box', 'off', 'FontSize', obj.Config.FontSize, ...
                        'FontName', obj.Config.FontName, 'Location', 'northeastoutside');
                end
            end
            linkaxes(axesHandles, 'x');
        end
    end
    methods (Static)
        function [displayX,displayY] = interpolateObservedTrajectory(x,y,sampleCount)
            % Include every observed point without closing incomplete recordings.
            points=[double(x(:)),double(y(:))];
            points=points([true;any(diff(points,1,1)~=0,2)],:);
            if size(points,1)==1
                displayX=repmat(points(1,1),sampleCount,1);
                displayY=repmat(points(1,2),sampleCount,1);
                return;
            end
            distance=[0;cumsum(sqrt(sum(diff(points,1,1).^2,2)))];
            query=unique([distance;linspace(0,distance(end),sampleCount)']);
            displayX=interp1(distance,points(:,1),query,'pchip');
            displayY=interp1(distance,points(:,2),query,'pchip');
        end

        function [displayX,displayY] = interpolateClosedTrajectory(x,y,sampleCount)
            % Display-only closed interpolation. Preserve all distinct observed
            % points and bridge the endpoint gap; no drift correction or filtering.
            validateattributes(x,{'numeric'},{'vector','real','finite','nonempty'});
            validateattributes(y,{'numeric'},{'vector','real','finite','numel',numel(x)});
            validateattributes(sampleCount,{'numeric'},{'scalar','integer','>=',20});
            points=[double(x(:)),double(y(:))];
            points=points([true;any(diff(points,1,1)~=0,2)],:);
            if size(points,1)>1 && isequal(points(end,:),points(1,:))
                points(end,:)=[];
            end
            if size(points,1)<3
                error('DataPlotter:DegenerateTrajectory','A closed trajectory needs at least three distinct consecutive points.');
            end
            closed=[points;points(1,:)];
            distance=[0;cumsum(sqrt(sum(diff(closed,1,1).^2,2)))];
            period=distance(end);
            % One neighbor from the previous and next period makes the PCHIP
            % tangents consistent at the loop seam. Coordinate overshoot is avoided.
            extendedDistance=[distance(end-1)-period;distance;period+distance(2)];
            extendedPoints=[points(end,:);closed;points(2,:)];
            query=linspace(0,period,sampleCount)';
            displayX=interp1(extendedDistance,extendedPoints(:,1),query,'pchip');
            displayY=interp1(extendedDistance,extendedPoints(:,2),query,'pchip');
            displayX(end)=displayX(1); displayY(end)=displayY(1);
        end
    end
end
