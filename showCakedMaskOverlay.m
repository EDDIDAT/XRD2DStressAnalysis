function showCakedMaskOverlay(h, alphaGrpIdx)
% Zeigt das Caked Image mit überlagerter caked_mask in einem neuen Fenster
%
% alphaGrpIdx: Index der Alpha-Gruppe (default: 1)

if nargin < 2, alphaGrpIdx = 1; end

if ~isfield(h, 'pyfaiOutPerAlpha') || numel(h.pyfaiOutPerAlpha) < alphaGrpIdx
    errordlg('Keine pyFAI-Daten verfügbar.', 'Fehler');
    return
end

out_k = h.pyfaiOutPerAlpha{alphaGrpIdx};

if ~isfield(out_k, 'caked_mask') || isempty(out_k.caked_mask)
    errordlg('Keine caked_mask verfügbar. Bitte PONI-Dateien neu laden.', 'Fehler');
    return
end

I_k        = double(out_k.I);          % [npt_azim x npt_rad]
cakedMask  = double(out_k.caked_mask); % [npt_azim x npt_rad]
radialAll  = double(out_k.radial(:));  % [npt_rad x 1]
azimAll    = double(out_k.azimuthal(:)); % [npt_azim x 1]

% ── Figure erstellen ─────────────────────────────────────────────────
fig = figure('Name', sprintf('Caked Image + Maske  |  α=%.1f°', ...
    h.uniqueAlpha(alphaGrpIdx)), ...
    'NumberTitle', 'off', ...
    'Units', 'normalized', ...
    'Position', [0.05 0.05 0.90 0.85]);

% ── Subplot 1: Caked Image (log) ──────────────────────────────────────
ax1 = subplot(1, 3, 1);
I_log = log10(1 + max(I_k, 0));
v     = I_log(isfinite(I_log) & I_log > 0);
clims = prctile(v, [1 99]);
imagesc(ax1, radialAll, azimAll, I_log);
clim(ax1, clims);
colormap(ax1, 'hot');
colorbar(ax1);
ax1.YDir = 'normal';
xlabel(ax1, '2\theta (°)');
ylabel(ax1, '\chi (°)');
title(ax1, 'Caked Image (log)');
box(ax1, 'on');

% ── Subplot 2: caked_mask ─────────────────────────────────────────────
ax2 = subplot(1, 3, 2);
imagesc(ax2, radialAll, azimAll, cakedMask);
clim(ax2, [0 1]);
colormap(ax2, gray(2));   % nur schwarz/weiß
colorbar(ax2);
ax2.YDir = 'normal';
xlabel(ax2, '2\theta (°)');
ylabel(ax2, '\chi (°)');
title(ax2, 'Caked Mask (1=valide, 0=maskiert)');
box(ax2, 'on');

% ── Subplot 3: Overlay ───────────────────────────────────────────────
ax3 = subplot(1, 3, 3);

% Caked Image als Hintergrund
imagesc(ax3, radialAll, azimAll, I_log);
clim(ax3, clims);
colormap(ax3, 'hot');
ax3.YDir = 'normal';
hold(ax3, 'on');

% Maskierte Bereiche als halbtransparentes Blau überlagern
maskOverlay = zeros(size(cakedMask, 1), size(cakedMask, 2), 3);
maskOverlay(:,:,3) = 1 - cakedMask;   % blauer Kanal wo maskiert

% Alpha-Kanal für Transparenz
alphaData = (1 - cakedMask) * 0.6;    % 60% Deckkraft wo maskiert

hImg = imagesc(ax3, radialAll, azimAll, maskOverlay);
set(hImg, 'AlphaData', alphaData);
ax3.YDir = 'normal';

% BinnedGamma-Positionen als horizontale Linien einzeichnen
if isfield(h, 'BinnedGammaRaw') && numel(h.BinnedGammaRaw) >= alphaGrpIdx
    gammaRaw  = h.BinnedGammaRaw{alphaGrpIdx};
    validBin  = h.BinnedGammaValid{alphaGrpIdx};

    for bn = 1:numel(gammaRaw)
        if validBin(bn)
            yline(ax3, gammaRaw(bn), '-', ...
                'Color', [0 0.8 0], 'LineWidth', 0.5, 'Alpha', 0.4);
        else
            yline(ax3, gammaRaw(bn), '-', ...
                'Color', [1 0 0], 'LineWidth', 1.2, 'Alpha', 0.8);
        end
    end
end

xlabel(ax3, '2\theta (°)');
ylabel(ax3, '\chi (°)');
title(ax3, 'Overlay: blau=maskiert, grün=valide γ-Bins, rot=ungültige γ-Bins');
box(ax3, 'on');

% ── chiFracValid-Profil als viertes Panel ─────────────────────────────
% Zeigt den Verlauf von frac_valid über chi
if isfield(out_k, 'valid_fraction') && ~isempty(out_k.valid_fraction)
    % Neues Figure für Profil — oder als zweite Zeile
    figure('Name', sprintf('chiFracValid Profil  |  α=%.1f°', ...
        h.uniqueAlpha(alphaGrpIdx)), ...
        'NumberTitle', 'off', ...
        'Units', 'normalized', ...
        'Position', [0.1 0.1 0.55 0.45]);

    validFrac = double(out_k.valid_fraction);  % [npt_azim x npt_rad]

    % 2theta-Bereich einschränken
    if isfield(h, 'dataX') && numel(h.dataX) >= alphaGrpIdx
        tthMin = min(h.dataX{alphaGrpIdx});
        tthMax = max(h.dataX{alphaGrpIdx});
        idxTth = find(radialAll >= tthMin & radialAll <= tthMax);
    else
        idxTth = 1:numel(radialAll);
    end

    cakedMaskROI = cakedMask(:, idxTth);
    chiFracValid = mean(cakedMaskROI, 2);

    ax4 = gca;
    plot(ax4, azimAll, chiFracValid, '-b', 'LineWidth', 1.5);
    hold(ax4, 'on');

    % Ungültige Bins markieren
    if isfield(h, 'BinnedGammaRaw') && numel(h.BinnedGammaRaw) >= alphaGrpIdx
        gammaRaw = h.BinnedGammaRaw{alphaGrpIdx};
        validBin = h.BinnedGammaValid{alphaGrpIdx};
        for bn = 1:numel(gammaRaw)
            chiIdx = find(abs(azimAll - gammaRaw(bn)) == ...
                min(abs(azimAll - gammaRaw(bn))), 1);
            if ~validBin(bn)
                plot(ax4, azimAll(chiIdx), chiFracValid(chiIdx), ...
                    'rv', 'MarkerFaceColor', 'r', 'MarkerSize', 8);
            else
                plot(ax4, azimAll(chiIdx), chiFracValid(chiIdx), ...
                    'g^', 'MarkerFaceColor', 'g', 'MarkerSize', 5);
            end
        end
    end

    % Schwellenlinie
    yline(ax4, 0.85 * median(chiFracValid), '--r', ...
        'Label', 'ContrastThresh', 'LineWidth', 1.0);

    xlabel(ax4, '\chi (°)');
    ylabel(ax4, 'frac\_valid');
    title(ax4, sprintf('Anteil valider Pixel pro \\chi-Bin  |  2\\theta=[%.1f°, %.1f°]', ...
        radialAll(idxTth(1)), radialAll(idxTth(end))));
    grid(ax4, 'on');
    box(ax4, 'on');
    ylim(ax4, [0 1.05]);
end

fprintf('showCakedMaskOverlay: Alpha-Gruppe %d angezeigt\n', alphaGrpIdx);
end