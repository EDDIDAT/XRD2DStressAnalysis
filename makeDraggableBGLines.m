function makeDraggableBGLines(ax, bgIntervals, figHandle)
% Zeichnet BG-Grenzen als verschiebbare vertikale Linien in ax.
% bgIntervals: Nx2 Matrix [links, rechts]
% figHandle:   Handle der GUI-Figur (für guidata Zugriff)

for g = 1:size(bgIntervals, 1)
    for side = 1:2
        xPos = bgIntervals(g, side);
        hL = xline(ax, xPos, '--', 'Color', [0.8 0.4 0], ...
            'LineWidth', 1.5, 'HitTest', 'on', 'PickableParts', 'all');
        hL.UserData = struct('group', g, 'side', side, 'fig', figHandle);
        hL.ButtonDownFcn = @(src, ~) startDragBG(src);
    end
end
end

function startDragBG(hLine)
    fig = hLine.UserData.fig;
    ax  = hLine.Parent;
    fig.UserData.dragBGLine = hLine;
    fig.UserData.origMotionFcn = fig.WindowButtonMotionFcn;
    fig.UserData.origUpFcn = fig.WindowButtonUpFcn;
    fig.UserData.origPointer = fig.Pointer;
    fig.Pointer = 'left';
    fig.WindowButtonMotionFcn = @(~,~) onDragBG(fig, ax);
    fig.WindowButtonUpFcn     = @(~,~) stopDragBG(fig);
end

function onDragBG(fig, ax)
    cp = get(ax, 'CurrentPoint');
    fig.UserData.dragBGLine.Value = cp(1,1);
end

function stopDragBG(fig)
    hLine = fig.UserData.dragBGLine;
    info  = hLine.UserData;

    % Aktuellen Stand aus guidata lesen
    h = guidata(info.fig);
    h.tsBgIntervals(info.group, info.side) = hLine.Value;

    % links < rechts sicherstellen
    for g = 1:size(h.tsBgIntervals, 1)
        if h.tsBgIntervals(g,1) > h.tsBgIntervals(g,2)
            h.tsBgIntervals(g,:) = h.tsBgIntervals(g, [2 1]);
        end
    end

    % BG-Regionen pro Peak neu zuordnen
    if isfield(h, 'tsUserPeaks') && ~isempty(h.tsUserPeaks)
        nPeaks = numel(h.tsUserPeaks);
        h.tsBgRegions = cell(nPeaks, 1);
        for pk = 1:nPeaks
            for gg = 1:size(h.tsBgIntervals, 1)
                if h.tsUserPeaks(pk) >= h.tsBgIntervals(gg,1) && ...
                   h.tsUserPeaks(pk) <= h.tsBgIntervals(gg,2)
                    h.tsBgRegions{pk} = h.tsBgIntervals(gg,:);
                    break
                end
            end
        end
    end

    guidata(info.fig, h);

    fig.WindowButtonMotionFcn = fig.UserData.origMotionFcn;
    fig.WindowButtonUpFcn     = fig.UserData.origUpFcn;
    fig.Pointer = fig.UserData.origPointer;
end
