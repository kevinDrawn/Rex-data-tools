classdef PawTrajectoryInspector < handle
    %PAWTRAJECTORYINSPECTOR Drag XY or time plots to locate source samples.
    % Selection is diagnostic only. Source data and reported metrics are unchanged.
    properties (SetAccess=private)
        Figure
        XYAxes
        TimeAxes
        SelectedMask
        SelectedRanges
        SelectedSamples
        Condition
        RecordingIndex = 1
    end
    properties (Access=private)
        Analysis
        Display
        Conditions
        OutputDirectory
        ConditionMenu
        RecordingMenu
        RangeTable
        Status
        XYSelection
        TimeSelections
        TimeSeries
        CurrentSource
        CurrentDisplay
        CurrentSourceRows
        DragAxes
        DragStart
        DragOutline
        IsDragging = false
    end
    methods
        function obj=PawTrajectoryInspector(analysis,displayData,varargin)
            parser=inputParser;
            addParameter(parser,'Condition','Baseline');
            addParameter(parser,'OutputDirectory','');
            addParameter(parser,'Visible','on');
            parse(parser,varargin{:});
            obj.Analysis=analysis; obj.Display=displayData;
            obj.Conditions=string(fieldnames(displayData.Conditions));
            obj.OutputDirectory=string(parser.Results.OutputDirectory);
            obj.Condition=string(parser.Results.Condition);
            if ~ismember(obj.Condition,obj.Conditions), obj.Condition=obj.Conditions(1); end
            obj.Figure=figure('Name','Toe trajectory time inspector','Color','w', ...
                'Position',[60 60 1450 900],'Visible',parser.Results.Visible, ...
                'WindowButtonDownFcn',@(~,~)obj.startDrag(), ...
                'WindowButtonMotionFcn',@(~,~)obj.moveDrag(), ...
                'WindowButtonUpFcn',@(~,~)obj.finishDrag());
            uicontrol(obj.Figure,'Style','text','Units','normalized','Position',[.02 .955 .07 .025], ...
                'String','Condition','BackgroundColor','w','HorizontalAlignment','left');
            obj.ConditionMenu=uicontrol(obj.Figure,'Style','popupmenu','Units','normalized', ...
                'Position',[.09 .95 .1 .035],'String',cellstr(obj.Conditions), ...
                'Value',find(obj.Conditions==obj.Condition,1),'Callback',@(~,~)obj.changeCondition());
            obj.RecordingMenu=uicontrol(obj.Figure,'Style','popupmenu','Units','normalized', ...
                'Position',[.21 .95 .17 .035],'Callback',@(~,~)obj.changeRecording());
            uicontrol(obj.Figure,'Style','pushbutton','Units','normalized','Position',[.40 .95 .1 .035], ...
                'String','Clear selection','Callback',@(~,~)obj.clearSelection());
            uicontrol(obj.Figure,'Style','pushbutton','Units','normalized','Position',[.51 .95 .12 .035], ...
                'String','Export selection','Callback',@(~,~)obj.exportSelection());
            uicontrol(obj.Figure,'Style','text','Units','normalized','Position',[.02 .91 .96 .03], ...
                'String','Drag a box in XY to locate times. Drag horizontally in any time plot to inspect the same trajectory samples.', ...
                'BackgroundColor','w','HorizontalAlignment','left','FontSize',11);
            obj.XYAxes=axes('Parent',obj.Figure,'Position',[.065 .45 .40 .41]);
            obj.TimeAxes=gobjects(3,1);
            for j=1:3
                obj.TimeAxes(j)=axes('Parent',obj.Figure,'Position',[.57 .715-(j-1)*.245 .40 .18]);
            end
            obj.RangeTable=uitable(obj.Figure,'Units','normalized','Position',[.025 .09 .46 .26], ...
                'ColumnName',{'Start (s)','End (s)','CSV row start','CSV row end','Samples'}, ...
                'ColumnWidth',{85,85,100,100,75},'Data',cell(0,5));
            obj.Status=uicontrol(obj.Figure,'Style','text','Units','normalized','Position',[.025 .015 .95 .055], ...
                'String','','BackgroundColor','w','HorizontalAlignment','left','FontSize',10);
            obj.loadCondition();
        end

        function setCondition(obj,name)
            name=string(name);
            if ~ismember(name,obj.Conditions), error('PawInspector:Condition','Unknown condition %s.',name); end
            obj.Condition=name; obj.ConditionMenu.Value=find(obj.Conditions==name,1);
            obj.RecordingIndex=1; obj.loadCondition();
        end

        function selectXYRegion(obj,bounds)
            % Bounds: [xmin ymin xmax ymax], evaluated on ORIGINAL sample rows.
            validateattributes(bounds,{'numeric'},{'vector','numel',4,'real','finite'});
            x=obj.CurrentDisplay.SourceX_mm; y=obj.CurrentDisplay.SourceY_mm;
            lo=min(bounds(1:2),bounds(3:4)); hi=max(bounds(1:2),bounds(3:4));
            mask=x>=lo(1) & x<=hi(1) & y>=lo(2) & y<=hi(2);
            obj.applySelection(mask,'XY region');
        end

        function selectTimeRange(obj,range)
            validateattributes(range,{'numeric'},{'vector','numel',2,'real','finite'});
            range=sort(range); t=obj.CurrentDisplay.SourceTime_s;
            obj.applySelection(t>=range(1) & t<=range(2),'Time range');
        end

        function clearSelection(obj)
            if ~isempty(obj.DragOutline) && isgraphics(obj.DragOutline), delete(obj.DragOutline); end
            obj.applySelection(false(size(obj.CurrentDisplay.SourceTime_s)),'Cleared');
        end

        function exportSelection(obj)
            if ~any(obj.SelectedMask)
                obj.Status.String='No samples selected. Drag in an XY or time plot first.'; return;
            end
            folder=obj.OutputDirectory;
            if strlength(folder)==0, folder=string(tempdir); end
            if ~isfolder(folder), mkdir(folder); end
            stem="trajectory_selection_"+obj.Condition+"_recording"+obj.RecordingIndex;
            ranges=obj.SelectedRanges; samples=obj.SelectedSamples;
            sourceFile=obj.CurrentSource.File;
            writetable(ranges,fullfile(folder,stem+"_ranges.csv"));
            writetable(samples,fullfile(folder,stem+"_samples.csv"));
            save(fullfile(folder,stem+".mat"),'ranges','samples','sourceFile');
            obj.Status.String="Selection exported to "+folder+" (source data unchanged).";
            fprintf('Trajectory selection exported to %s\n',folder);
        end
    end
    methods (Access=private)
        function changeCondition(obj)
            obj.Condition=obj.Conditions(obj.ConditionMenu.Value);
            obj.RecordingIndex=1; obj.loadCondition();
        end
        function changeRecording(obj)
            obj.RecordingIndex=obj.RecordingMenu.Value; obj.loadRecording();
        end
        function loadCondition(obj)
            records=obj.Display.Conditions.(char(obj.Condition)).Recordings;
            labels=strings(numel(records),1);
            for j=1:numel(records), labels(j)="Recording "+j; end
            obj.RecordingMenu.String=cellstr(labels); obj.RecordingMenu.Value=1;
            obj.loadRecording();
        end
        function loadRecording(obj)
            condition=obj.Analysis.Conditions.(char(obj.Condition));
            shown=obj.Display.Conditions.(char(obj.Condition));
            obj.CurrentDisplay=shown.Recordings(obj.RecordingIndex);
            matched=find(string({condition.SourceRecordings.File})==obj.CurrentDisplay.File);
            if numel(matched)~=1, error('PawInspector:Source','Cannot identify the source recording.'); end
            source=condition.SourceRecordings(matched);
            rows=(1:numel(source.Time))';
            if isfield(obj.CurrentDisplay,'SourceRowIndices'), rows=obj.CurrentDisplay.SourceRowIndices; end
            obj.CurrentSourceRows=rows;
            fields={'Time','TO_x_filtered','TO_y_filtered','IL_x_filtered','IL_y_filtered'};
            for field=fields, source.(field{1})=source.(field{1})(rows); end
            obj.CurrentSource=source;
            obj.IsDragging=false; obj.DragOutline=[];
            t=obj.CurrentDisplay.SourceTime_s;
            source=obj.CurrentSource;
            cla(obj.XYAxes,'reset'); hold(obj.XYAxes,'on');
            plot(obj.XYAxes,obj.CurrentDisplay.X_mm,obj.CurrentDisplay.Y_mm, ...
                'Color',[.65 .65 .65],'LineWidth',1,'HitTest','off');
            plot(obj.XYAxes,obj.CurrentDisplay.SourceX_mm,obj.CurrentDisplay.SourceY_mm,'.', ...
                'Color',[.35 .35 .35],'MarkerSize',4,'HitTest','off');
            obj.XYSelection=scatter(obj.XYAxes,NaN,NaN,18,[.9 .1 .1],'filled','HitTest','off');
            axis(obj.XYAxes,'equal'); axis(obj.XYAxes,'tight');
            obj.XYAxes.XLimMode='manual'; obj.XYAxes.YLimMode='manual';
            xlabel(obj.XYAxes,'Horizontal position (mm)'); ylabel(obj.XYAxes,'Relative toe height (mm)');
            title(obj.XYAxes,obj.Condition+" | drag to select original samples",'Interpreter','none');
            % The first and third time plots show filtered source coordinates,
            % before centering / offset shifts, so IL tracking can be inspected.
            obj.TimeSeries={ [source.TO_x_filtered,source.IL_x_filtered], ...
                obj.CurrentDisplay.SourceX_mm, [source.TO_y_filtered,source.IL_y_filtered] };
            labels={{'Toe X','IL X'},{'Centered toe - IL X'},{'Toe Y','IL Y'}};
            titles={'Filtered X coordinates','Corrected horizontal trajectory','Filtered Y coordinates'};
            obj.TimeSelections=cell(3,1);
            for j=1:3
                ax=obj.TimeAxes(j); cla(ax,'reset'); hold(ax,'on');
                colors=[0 .45 .74;.1 .6 .3];
                if j==2, colors=[0 0 0]; end
                handles=gobjects(size(obj.TimeSeries{j},2),1);
                selected=gobjects(size(obj.TimeSeries{j},2),1);
                for k=1:numel(handles)
                    handles(k)=plot(ax,t,obj.TimeSeries{j}(:,k),'Color',colors(k,:),'LineWidth',1);
                    selected(k)=scatter(ax,NaN,NaN,12,[.9 .1 .1],'filled','HandleVisibility','off');
                end
                obj.TimeSelections{j}=selected;
                title(ax,titles{j}); ylabel(ax,'Position (mm)'); xlabel(ax,'Video time (s)');
                xlim(ax,[t(1),t(end)]); legend(ax,handles,labels{j},'Location','best','Box','off');
            end
            linkaxes(obj.TimeAxes,'x');
            obj.applySelection(false(size(t)),'Ready');
        end
        function startDrag(obj)
            if ~strcmp(obj.Figure.SelectionType,'normal'), return; end
            hit=hittest(obj.Figure); ax=ancestor(hit,'axes');
            if isempty(ax) || ~(ax==obj.XYAxes || any(ax==obj.TimeAxes)), return; end
            if ~isempty(obj.DragOutline) && isgraphics(obj.DragOutline), delete(obj.DragOutline); end
            point=ax.CurrentPoint;
            obj.DragAxes=ax; obj.DragStart=point(1,1:2); obj.IsDragging=true;
            obj.DragOutline=plot(ax,NaN,NaN,'--','Color',[.9 .1 .1],'LineWidth',1,'HitTest','off');
        end
        function moveDrag(obj)
            if ~obj.IsDragging, return; end
            point=obj.DragAxes.CurrentPoint; endpoint=point(1,1:2);
            if obj.DragAxes==obj.XYAxes
                lo=min(obj.DragStart,endpoint); hi=max(obj.DragStart,endpoint);
            else
                lo=[min(obj.DragStart(1),endpoint(1)),obj.DragAxes.YLim(1)];
                hi=[max(obj.DragStart(1),endpoint(1)),obj.DragAxes.YLim(2)];
            end
            set(obj.DragOutline,'XData',[lo(1) hi(1) hi(1) lo(1) lo(1)], ...
                'YData',[lo(2) lo(2) hi(2) hi(2) lo(2)]);
        end
        function finishDrag(obj)
            if ~obj.IsDragging, return; end
            obj.moveDrag(); point=obj.DragAxes.CurrentPoint; endpoint=point(1,1:2);
            obj.IsDragging=false;
            if obj.DragAxes==obj.XYAxes
                obj.selectXYRegion([obj.DragStart,endpoint]);
            else
                obj.selectTimeRange([obj.DragStart(1),endpoint(1)]);
            end
        end
        function applySelection(obj,mask,description)
            shown=obj.CurrentDisplay; source=obj.CurrentSource;
            obj.SelectedMask=logical(mask(:));
            obj.SelectedRanges=PawTrajectoryInspector.contiguousRanges(shown.SourceTime_s,obj.SelectedMask,obj.CurrentSourceRows);
            SourceRow=obj.CurrentSourceRows(obj.SelectedMask); Time_s=shown.SourceTime_s(obj.SelectedMask);
            DisplayX_mm=shown.SourceX_mm(obj.SelectedMask); DisplayY_mm=shown.SourceY_mm(obj.SelectedMask);
            ToeX_mm=source.TO_x_filtered(obj.SelectedMask); IliumX_mm=source.IL_x_filtered(obj.SelectedMask);
            ToeY_mm=source.TO_y_filtered(obj.SelectedMask); IliumY_mm=source.IL_y_filtered(obj.SelectedMask);
            obj.SelectedSamples=table(SourceRow,Time_s,DisplayX_mm,DisplayY_mm,ToeX_mm,IliumX_mm,ToeY_mm,IliumY_mm);
            set(obj.XYSelection,'XData',DisplayX_mm,'YData',DisplayY_mm);
            for j=1:3
                for k=1:numel(obj.TimeSelections{j})
                    set(obj.TimeSelections{j}(k),'XData',Time_s,'YData',obj.TimeSeries{j}(obj.SelectedMask,k));
                end
            end
            obj.RangeTable.Data=table2cell(obj.SelectedRanges(:, ...
                {'StartTime_s','EndTime_s','StartSourceRow','EndSourceRow','SampleCount'}));
            obj.Status.String=sprintf('%s | %d selected samples in %d separate time runs. Source rows are 1-based.\n%s', ...
                description,nnz(obj.SelectedMask),height(obj.SelectedRanges),source.File);
            if any(obj.SelectedMask)
                fprintf('\n%s / recording %d: %d samples, %d distinct time runs.\n', ...
                    obj.Condition,obj.RecordingIndex,nnz(obj.SelectedMask),height(obj.SelectedRanges));
                disp(obj.SelectedRanges);
            end
            selection.Condition=obj.Condition; selection.RecordingIndex=obj.RecordingIndex;
            selection.SourceFile=source.File; selection.Ranges=obj.SelectedRanges;
            selection.Samples=obj.SelectedSamples;
            assignin('base','trajectorySelection',selection);
        end
    end
    methods (Static)
        function ranges=contiguousRanges(time,mask,sourceRows)
            time=double(time(:)); mask=logical(mask(:));
            if nargin<3, sourceRows=(1:numel(time))'; end
            sourceRows=sourceRows(:);
            validateattributes(time,{'numeric'},{'vector','increasing','finite','numel',numel(mask)});
            edges=diff([false;mask;false]); first=find(edges==1); last=find(edges==-1)-1;
            StartTime_s=time(first); EndTime_s=time(last);
            StartSourceRow=sourceRows(first); EndSourceRow=sourceRows(last); SampleCount=last-first+1;
            ranges=table(StartTime_s,EndTime_s,StartSourceRow,EndSourceRow,SampleCount);
        end
    end
end
