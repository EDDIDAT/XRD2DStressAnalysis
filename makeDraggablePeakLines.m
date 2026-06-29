function makeDraggablePeakLines(ax, peakPositions, figHandle)
% Zeichnet Peak-Positionen als verschiebbare vertikale Linien in ax.
% peakPositions: Vektor mit Peak-Positionen
% figHandle:     Handle der GUI-Figur (für guidata Zugriff)

for pk = 1:numel(peakPositions)
    hL = xline(ax, peakPositions(pk), 'r-', sprintf('P%d', pk), ...
        'LineWidth', 1.2, 'HitTest', 'on', 'PickableParts', 'all', ...
        'LabelOrientation', 'horizontal', 'LabelVerticalAlignment', 'top');
    hL.UserData = struct('index', pk, 'fig', figHandle);
    hL.ButtonDownFcn = @(src, ~) startDragPeak(src);
end
end

function startDragPeak(hLine)
    fig = hLine.UserData.fig;
    ax  = hLine.Parent;
    fig.UserData.dragPeakLine = hLine;
    fig.UserData.origMotionFcn_pk = fig.WindowButtonMotionFcn;
    fig.UserData.origUpFcn_pk = fig.WindowButtonUpFcn;
    fig.UserData.origPointer_pk = fig.Pointer;
    fig.Pointer = 'left';
    fig.WindowButtonMotionFcn = @(~,~) onDragPeak(fig, ax);
    fig.WindowButtonUpFcn     = @(~,~) stopDragPeak(fig);
end

function onDragPeak(fig, ax)
    cp = get(ax, 'CurrentPoint');
    fig.UserData.dragPeakLine.Value = cp(1,1);
end

function stopDragPeak(fig)
    hLine = fig.UserData.dragPeakLine;
    info  = hLine.UserData;

    % Aktuellen Stand aus guidata lesen
    h = guidata(info.fig);
    h.tsUserPeaks(info.index) = hLine.Value;
    h.tsUserPeaks = sort(h.tsUserPeaks(:));
    guidata(info.fig, h);

    fig.WindowButtonMotionFcn = fig.UserData.origMotionFcn_pk;
    fig.WindowButtonUpFcn     = fig.UserData.origUpFcn_pk;
    fig.Pointer = fig.UserData.origPointer_pk;
end
