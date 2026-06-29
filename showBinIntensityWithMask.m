function showBinIntensityWithMask(h, alphaGrpIdx, binIndices)
% Zeigt für ausgewählte γ-Bins die Intensität und die caked_mask
% als Funktion von 2theta übereinander.
%
% alphaGrpIdx: Index der Alpha-Gruppe (default: 1)
% binIndices:  Vektor mit den anzuzeigenden Bin-Indizes (default: alle)

if nargin < 2, alphaGrpIdx = 1; end

out_k = h.pyfaiOutPerAlpha{alphaGrpIdx};

if ~isfield(out_k, 'caked_mask') || isempty(out_k.caked_mask)
    errordlg('Keine caked_mask verfügbar.', 'Fehler');
    return
end

I_k       = double(out_k.I);
cakedMask = double(out_k.caked_mask);
radialAll = double(out_k.radial(:));
azimAll   = double(out_k.azimuthal(:));
alphaVal  = h.uniqueAlpha(alphaGrpIdx);
gammaRaw  = h.BinnedGammaRaw{alphaGrpIdx};
validBin  = h.BinnedGammaValid{alphaGrpIdx};

% 2theta-Bereich einschränken
if isfield(h, 'dataX') && numel(h.dataX) >= alphaGrpIdx
    tthMin  = min(h.dataX{alphaGrpIdx});
    tthMax  = max(h.dataX{alphaGrpIdx});
    idxTth  = find(radialAll >= tthMin & radialAll <= tthMax);
else
    idxTth  = 1:numel(radialAll);
end
radROI = radialAll(idxTth);

% Standard: alle Bins anzeigen
if nargin < 3 || isempty(binIndices)
    binIndices = 1:numel(gammaRaw);
end
binIndices = binIndices(:)';
nBins      = numel(binIndices);

% Layout: max 4 Spalten
nCols = min(4, nBins);
nRows = ceil(nBins / nCols);

fig = figure('Name', sprintf('Intensität + Maske pro γ-Bin  |  α=%.1f°', alphaVal), ...
    'NumberTitle', 'off', ...
    'Units',       'normalized', ...
    'Position',    [0.02 0.02 0.96 0.90]);

for bi = 1:nBins
    bn = binIndices(bi);
    if bn < 1 || bn > numel(gammaRaw), continue; end

    % chi-Index für diesen Bin
    [~, chiIdx] = min(abs(azimAll - gammaRaw(bn)));

    % Intensität und Maske für diesen Bin im genutzten 2theta-Bereich
    intensRow = I_k(chiIdx,       idxTth);
    maskRow   = cakedMask(chiIdx, idxTth);

    ax = subplot(nRows, nCols, bi);
    hold(ax, 'on');

    % ── Maskierte Bereiche als graue Patches ─────────────────────────
    isMasked = maskRow < 0.5;
    if any(isMasked)
        changes  = diff([false, isMasked, false]);
        blkStart = find(changes ==  1);
        blkEnd   = find(changes == -1) - 1;
        yLims    = [0, max(intensRow(isfinite(intensRow)), [], 'all') * 1.15];
        if yLims(2) <= 0, yLims(2) = 1; end
        for bb = 1:numel(blkStart)
            xL = radROI(blkStart(bb));
            xR = radROI(blkEnd(bb));
            patch(ax, [xL xR xR xL], ...
                [yLims(1) yLims(1) yLims(2) yLims(2)], ...
                [0.75 0.75 0.75], ...
                'FaceAlpha', 0.5, ...
                'EdgeColor', 'none');
        end
    end

    % ── Intensitätsprofil ─────────────────────────────────────────────
    plot(ax, radROI, intensRow, '-', ...
        'Color',     [0.094 0.373 0.647], ...
        'LineWidth', 1.0);

    % ── Formatierung ──────────────────────────────────────────────────
    gammaDisp = gammaRaw(bn) + 90;   % +90° verschoben
    if validBin(bn)
        titleColor = [0 0.5 0];
        validStr   = 'valide';
    else
        titleColor = [0.8 0 0];
        validStr   = 'ungültig';
    end

    title(ax, sprintf('\\gamma=%.1f°  [%s]', gammaDisp, validStr), ...
        'Color',    titleColor, ...
        'FontSize', 8);
    xlabel(ax, '2\theta (°)', 'FontSize', 7);
    ylabel(ax, 'I [a.u.]',   'FontSize', 7);
    ax.FontSize = 7;
    xlim(ax, [min(radROI), max(radROI)]);
    box(ax, 'on');
    grid(ax, 'on');
    hold(ax, 'off');
end

sgtitle(fig, sprintf('Intensität + Detektormaske (grau) pro \\gamma-Bin  |  \\alpha=%.1f°', ...
    alphaVal), 'FontSize', 11);

fprintf('showBinIntensityWithMask: %d Bins angezeigt (Alpha-Gruppe %d)\n', ...
    nBins, alphaGrpIdx);
end