function peakDefs = interactive_define_peak_windows(out, opts)
%INTERACTIVE_DEFINE_PEAK_WINDOWS
% Interaktive Definition von Peakfenstern und Peaks aus dem über alle chi/gamma
% aufsummierten Profil.
%
% VERSION:
%   - Fitfenster wird per 2 Klicks definiert
%   - BG-Bereiche werden automatisch aus dem Fitfenster abgeleitet
%   - Peak-Klicks werden auf lokale Maxima gesnappt
%   - Backspace/Delete entfernt den letzten Peak
%   - Enter beendet die Peakwahl des aktuellen Fensters
%
% WORKFLOW
%   1) globales Summenprofil anzeigen
%   2) pro Fenster:
%      - linken Rand des Fitfensters klicken
%      - rechten Rand des Fitfensters klicken
%      - BG links/rechts wird automatisch erzeugt
%      - Peaks innerhalb des Fensters klicken
%      - ENTER beendet die Peakwahl des aktuellen Fensters
%      - BACKSPACE/DELETE entfernt den letzten Peak
%   3) Dialog wiederholen, bis kein weiteres Fenster definiert werden soll
%
% INPUT
%   out.I         : [nRad x nChi] oder [nChi x nRad]
%   out.radial    : radiale Achse
%   out.azimuthal : chi/gamma-Achse
%
%   opts:
%       opts.profileChiRange          = [] oder [chiMin chiMax]
%       opts.smoothPoints             = 5
%       opts.useLog                   = false
%       opts.baselineMode             = "none" | "movmin"
%       opts.baselineWin              = 51
%       opts.defaultShape             = "pvoigt"
%       opts.defaultBackgroundModel   = "linear"
%       opts.showProcessed            = true
%
%       opts.snapToLocalMax           = true
%       opts.snapSearchRadiusDeg      = 0.08
%       opts.minPeakDistanceDeg       = 0.02
%
%       opts.autoBackgroundFromFitRange = true
%       opts.bgGapDeg                 = 0.03
%       opts.bgWidthDeg               = 0.06
%       opts.bgGapFactor              = 0.10
%       opts.bgWidthFactor            = 0.20
%       opts.snapBgToRawGrid          = true
%       opts.snapBgToLocalMin         = true
%       opts.bgSnapSearchRadiusDeg    = 0.08
%       opts.clipBgToDataRange        = true
%
% OUTPUT
%   peakDefs : Cell-Array von Peakdefinitionen
%
% Jedes peakDef enthält:
%   .name
%   .shape
%   .nPeaks
%   .peakGuessDeg
%   .fitRange
%   .bgLeftRange
%   .bgRightRange
%   .backgroundModel
%
% BEISPIEL
%   peakDefs = interactive_define_peak_windows(out);

if nargin < 2 || isempty(opts)
    opts = struct();
end

opts = setd(opts, "profileChiRange", []);
opts = setd(opts, "smoothPoints", 5);
opts = setd(opts, "useLog", false);
opts = setd(opts, "baselineMode", "none");
opts = setd(opts, "baselineWin", 51);
opts = setd(opts, "defaultShape", "pvoigt");
opts = setd(opts, "defaultBackgroundModel", "linear");
opts = setd(opts, "showProcessed", true);

opts = setd(opts, "snapToLocalMax", true);
opts = setd(opts, "snapSearchRadiusDeg", 0.08);
opts = setd(opts, "minPeakDistanceDeg", 0.02);

opts = setd(opts, "autoBackgroundFromFitRange", true);
opts = setd(opts, "bgGapDeg", 0.03);
opts = setd(opts, "bgWidthDeg", 0.06);
opts = setd(opts, "bgGapFactor", 0.10);
opts = setd(opts, "bgWidthFactor", 0.20);
opts = setd(opts, "snapBgToRawGrid", true);
opts = setd(opts, "snapBgToLocalMin", true);
opts = setd(opts, "bgSnapSearchRadiusDeg", 0.08);
opts = setd(opts, "clipBgToDataRange", true);

% ---------------- normalize input ----------------
I = out.I;
r = out.radial(:);
chi = out.azimuthal(:);

nRad = numel(r);
nChi = numel(chi);
sz = size(I);

if isequal(sz, [nRad nChi])
    % ok
elseif isequal(sz, [nChi nRad])
    I = I.';
else
    error("Dimension mismatch: size(out.I)=[%d %d], numel(radial)=%d, numel(azimuthal)=%d", ...
        sz(1), sz(2), nRad, nChi);
end

if nRad >= 2 && r(2) < r(1)
    r = flipud(r);
    I = flipud(I);
end
if nChi >= 2 && chi(2) < chi(1)
    chi = flipud(chi);
    I = fliplr(I);
end

% ---------------- global profile ----------------
profileMask = true(nChi,1);
if ~isempty(opts.profileChiRange)
    profileMask = chi >= opts.profileChiRange(1) & chi <= opts.profileChiRange(2);
end
profileIdx = find(profileMask);
if isempty(profileIdx)
    error("opts.profileChiRange selects no chi bins.");
end

Iprof = mean(I(:, profileIdx), 2);
IprofSm = smooth1(Iprof, opts.smoothPoints);

if opts.useLog
    IprofSm = log10(max(IprofSm, 0) + 1);
end

[IprofProc, ~] = baseline_remove(IprofSm, opts.baselineMode, opts.baselineWin);

localMaxIdx = local_maxima_simple(IprofProc);
localMinIdx = local_minima_simple(IprofProc);

% ---------------- main figure ----------------
fig = figure('Name', 'Interactive peak window definition', 'NumberTitle', 'off', 'Color', 'w');
ax = axes(fig);
hold(ax, 'on');
grid(ax, 'on');

plot(ax, r, Iprof, '-', 'DisplayName', 'raw');
if opts.showProcessed
    plot(ax, r, IprofProc, '-', 'DisplayName', 'processed');
end

if ~isempty(localMaxIdx)
    plot(ax, r(localMaxIdx), IprofProc(localMaxIdx), 'k.', ...
        'MarkerSize', 8, 'DisplayName', 'local maxima');
end

xlabel(ax, '2\theta / radial');
ylabel(ax, 'Intensity');
title(ax, ['Fenster definieren: Fitfenster (2 Klicks), Peaks klicken, ', ...
    'ENTER beendet Fenster, BACKSPACE löscht letzten Peak']);
legend(ax, 'Location', 'best');

disp("Interaktive Peakdefinition gestartet.");
disp("Pro Fenster:");
disp("  1) linken/rechten Rand des Fitfensters klicken");
disp("  2) BG links/rechts wird automatisch aus dem Fitfenster erzeugt");
disp("  3) Peaks innerhalb des Fensters klicken");
disp("     - Klick wird auf nächstes lokales Maximum gesnappt");
disp("     - BACKSPACE/DELETE entfernt den letzten Peak");
disp("     - ENTER beendet die Peakwahl des Fensters");
disp("Danach wird gefragt, ob ein weiteres Fenster angelegt werden soll.");

peakDefs = {};
winCount = 0;

while true
    answer = questdlg('Neues Peakfenster definieren?', ...
        'Peakfenster', ...
        'Ja', 'Nein', 'Nein');
    if ~strcmp(answer, 'Ja')
        break;
    end

    winCount = winCount + 1;

    % ---- Fitfenster
    title(ax, sprintf('Fenster %d: linken und rechten Rand des Fitfensters klicken', winCount));
    [xFit, ~] = ginput(2);
    if numel(xFit) < 2
        break;
    end
    fitRange = sort(xFit(:)).';

    delete(findobj(ax, 'Tag', sprintf('fitRange_%d', winCount)));
    xline(ax, fitRange(1), 'm-', 'LineWidth', 1.2, 'Tag', sprintf('fitRange_%d', winCount));
    xline(ax, fitRange(2), 'm-', 'LineWidth', 1.2, 'Tag', sprintf('fitRange_%d', winCount));

    % ---- BG automatisch aus Fitfenster ableiten
    if opts.autoBackgroundFromFitRange
        [bgLeftRange, bgRightRange] = auto_background_ranges_from_fitrange( ...
            r, IprofProc, localMinIdx, fitRange, opts);
    else
        % Fallback auf simple automatische Bereiche
        fitW = fitRange(2) - fitRange(1);
        bgGap = opts.bgGapFactor * fitW;
        bgWidth = opts.bgWidthFactor * fitW;
        bgLeftRange = [fitRange(1)-bgGap-bgWidth, fitRange(1)-bgGap];
        bgRightRange = [fitRange(2)+bgGap, fitRange(2)+bgGap+bgWidth];
        bgLeftRange = sort(bgLeftRange);
        bgRightRange = sort(bgRightRange);
    end

    delete(findobj(ax, 'Tag', sprintf('bgLeft_%d', winCount)));
    delete(findobj(ax, 'Tag', sprintf('bgRight_%d', winCount)));

    xline(ax, bgLeftRange(1), 'g--', 'LineWidth', 1.0, 'Tag', sprintf('bgLeft_%d', winCount));
    xline(ax, bgLeftRange(2), 'g--', 'LineWidth', 1.0, 'Tag', sprintf('bgLeft_%d', winCount));
    xline(ax, bgRightRange(1), 'c--', 'LineWidth', 1.0, 'Tag', sprintf('bgRight_%d', winCount));
    xline(ax, bgRightRange(2), 'c--', 'LineWidth', 1.0, 'Tag', sprintf('bgRight_%d', winCount));

    fprintf('Fenster %d:\n', winCount);
    fprintf('  fitRange   = [%.6f  %.6f]\n', fitRange(1), fitRange(2));
    fprintf('  bgLeft     = [%.6f  %.6f]\n', bgLeftRange(1), bgLeftRange(2));
    fprintf('  bgRight    = [%.6f  %.6f]\n', bgRightRange(1), bgRightRange(2));

    % ---- Peaks im Fenster klicken
    title(ax, sprintf(['Fenster %d: Peaks klicken | ENTER beendet | ', ...
        'BACKSPACE/DELETE entfernt letzten Peak'], winCount));

    peakGuess = [];
    peakMarkerHandles = gobjects(0);

    while true
        [xp, ~, button] = ginput(1);

        % ENTER beendet
        if isempty(button)
            break;
        end

        % BACKSPACE oder DELETE -> letzten Peak löschen
        if ischar(button) && (double(button) == 8 || double(button) == 127)
            if ~isempty(peakGuess)
                peakGuess(end) = [];
                if ~isempty(peakMarkerHandles) && isgraphics(peakMarkerHandles(end))
                    delete(peakMarkerHandles(end));
                end
                if ~isempty(peakMarkerHandles)
                    peakMarkerHandles(end) = [];
                end
                fprintf('Letzten Peak entfernt.\n');
            end
            continue;
        end

        if xp < fitRange(1) || xp > fitRange(2)
            fprintf('Peak liegt außerhalb des Fitfensters und wird ignoriert.\n');
            continue;
        end

        xUse = xp;
        if opts.snapToLocalMax
            [xSnap, okSnap] = snap_to_local_maximum(r, IprofProc, localMaxIdx, xp, fitRange, opts.snapSearchRadiusDeg);
            if okSnap
                xUse = xSnap;
            end
        end

        if ~isempty(peakGuess)
            if min(abs(peakGuess - xUse)) < opts.minPeakDistanceDeg
                fprintf('Peak bei %.5f liegt zu nah an vorhandenem Peak und wird ignoriert.\n', xUse);
                continue;
            end
        end

        peakGuess(end+1) = xUse; %#ok<AGROW>
        yUse = interp1(r, IprofProc, xUse, 'linear', 'extrap');
        h = plot(ax, xUse, yUse, 'rv', 'MarkerSize', 8, 'LineWidth', 1.2, ...
            'Tag', sprintf('peak_%d_%d', winCount, numel(peakGuess)));
        peakMarkerHandles(end+1) = h; %#ok<AGROW>

        fprintf('Peak %d in Fenster %d gesetzt bei %.6f\n', numel(peakGuess), winCount, xUse);
    end

    peakGuess = sort(peakGuess(:)).';
    if isempty(peakGuess)
        warndlg('Keine Peaks gewählt. Fenster wird übersprungen.', 'Keine Peaks');
        continue;
    end

    % ---- Name / Shape / Background
    defaultName = sprintf('window_%02d', winCount);

    prompt = { ...
        'Fenstername:', ...
        'Shape (gauss oder pvoigt):', ...
        'Background (constant oder linear):'};
    defans = { ...
        defaultName, ...
        char(string(opts.defaultShape)), ...
        char(string(opts.defaultBackgroundModel))};

    answ = inputdlg(prompt, 'Peakfenster-Parameter', [1 60], defans);
    if isempty(answ)
        wname = defaultName;
        shape = string(opts.defaultShape);
        bgModel = string(opts.defaultBackgroundModel);
    else
        wname = string(answ{1});
        shape = lower(string(answ{2}));
        bgModel = lower(string(answ{3}));
    end

    if ~(shape == "gauss" || shape == "pvoigt")
        shape = string(opts.defaultShape);
    end
    if ~(bgModel == "constant" || bgModel == "linear")
        bgModel = string(opts.defaultBackgroundModel);
    end

    peakDef = struct();
    peakDef.name = wname;
    peakDef.shape = shape;
    peakDef.nPeaks = numel(peakGuess);
    peakDef.peakGuessDeg = peakGuess;
    peakDef.fitRange = fitRange;
    peakDef.bgLeftRange = bgLeftRange;
    peakDef.bgRightRange = bgRightRange;
    peakDef.backgroundModel = bgModel;

    peakDefs{end+1,1} = peakDef; %#ok<AGROW>

    % Fensterlabel
    xMid = mean(fitRange);
    yMid = interp1(r, IprofProc, xMid, 'linear', 'extrap');
    text(ax, xMid, yMid, char(wname), ...
        'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'bottom', ...
        'FontWeight', 'bold', ...
        'Color', 'm', ...
        'Tag', sprintf('label_%d', winCount));
end

if isempty(peakDefs)
    disp("Keine Peakfenster definiert.");
else
    disp("Definierte Peakfenster:");
    for k = 1:numel(peakDefs)
        pd = peakDefs{k};
        fprintf('  %2d: %s | N=%d | fitRange=[%.4f %.4f] | bgL=[%.4f %.4f] | bgR=[%.4f %.4f]\n', ...
            k, pd.name, pd.nPeaks, ...
            pd.fitRange(1), pd.fitRange(2), ...
            pd.bgLeftRange(1), pd.bgLeftRange(2), ...
            pd.bgRightRange(1), pd.bgRightRange(2));
    end
end

end

% =====================================================================
% automatic background ranges
% =====================================================================

function [bgLeftRange, bgRightRange] = auto_background_ranges_from_fitrange(x, y, localMinIdx, fitRange, opts)
x = x(:);
y = y(:); %#ok<NASGU>

fitL = fitRange(1);
fitR = fitRange(2);
fitW = fitR - fitL;

% gap / width bestimmen
if ~isempty(opts.bgGapFactor)
    bgGap = opts.bgGapFactor * fitW;
else
    bgGap = opts.bgGapDeg;
end

if ~isempty(opts.bgWidthFactor)
    bgWidth = opts.bgWidthFactor * fitW;
else
    bgWidth = opts.bgWidthDeg;
end

% Rohbereiche
bgLeftRange = [fitL - bgGap - bgWidth, fitL - bgGap];
bgRightRange = [fitR + bgGap, fitR + bgGap + bgWidth];

% an Datenbereich clippen
if opts.clipBgToDataRange
    xmin = min(x);
    xmax = max(x);

    bgLeftRange(1) = max(bgLeftRange(1), xmin);
    bgLeftRange(2) = max(bgLeftRange(2), xmin);

    bgRightRange(1) = min(bgRightRange(1), xmax);
    bgRightRange(2) = min(bgRightRange(2), xmax);
end

bgLeftRange = sort(bgLeftRange);
bgRightRange = sort(bgRightRange);

% auf Minima / Rohgitter snappen
bgLeftRange = snap_bg_range(x, localMinIdx, bgLeftRange, opts);
bgRightRange = snap_bg_range(x, localMinIdx, bgRightRange, opts);

bgLeftRange = sort(bgLeftRange);
bgRightRange = sort(bgRightRange);
end

function xr = snap_bg_range(x, localMinIdx, xr, opts)
xr = xr(:).';

for i = 1:2
    xTmp = xr(i);

    if opts.snapBgToLocalMin
        [xSnap, okSnap] = snap_to_local_minimum(x, localMinIdx, xTmp, opts.bgSnapSearchRadiusDeg);
        if okSnap
            xTmp = xSnap;
        elseif opts.snapBgToRawGrid
            xTmp = snap_to_raw_grid(x, xTmp);
        end
    elseif opts.snapBgToRawGrid
        xTmp = snap_to_raw_grid(x, xTmp);
    end

    xr(i) = xTmp;
end
end

% =====================================================================
% helpers
% =====================================================================

function y = smooth1(x, w)
x = x(:);
w = max(1, round(w));
if mod(w,2)==0
    w = w + 1;
end
if w == 1
    y = x;
    return;
end
k = ones(w,1) / w;
y = conv(x, k, 'same');
end

function [yproc, base] = baseline_remove(y, mode, win)
y = y(:);
switch lower(string(mode))
    case "none"
        base = zeros(size(y));
        yproc = y;
    case "movmin"
        win = max(5, round(win));
        if mod(win,2)==0
            win = win + 1;
        end
        base = movmin(y, win);
        yproc = y - base;
        yproc(yproc < 0) = 0;
    otherwise
        error("Unknown baselineMode: %s", string(mode));
end
end

function locs = local_maxima_simple(y)
y = y(:);
if numel(y) < 3
    locs = [];
    return;
end
dy1 = [0; diff(y)];
dy2 = [diff(y); 0];
locs = find(dy1 > 0 & dy2 < 0);
end

function locs = local_minima_simple(y)
y = y(:);
if numel(y) < 3
    locs = [];
    return;
end
dy1 = [0; diff(y)];
dy2 = [diff(y); 0];
locs = find(dy1 < 0 & dy2 > 0);
end

function [xSnap, ok] = snap_to_local_maximum(x, y, localMaxIdx, xClick, fitRange, searchRadiusDeg)
x = x(:);
y = y(:); %#ok<NASGU>
ok = false;
xSnap = xClick;

if isempty(localMaxIdx)
    return;
end

mask = x(localMaxIdx) >= fitRange(1) & x(localMaxIdx) <= fitRange(2);
candIdx = localMaxIdx(mask);
if isempty(candIdx)
    return;
end

candX = x(candIdx);
d = abs(candX - xClick);
[dmin, iMin] = min(d);

if isempty(dmin) || ~isfinite(dmin) || dmin > searchRadiusDeg
    return;
end

xSnap = candX(iMin);
ok = true;
end

function [xSnap, ok] = snap_to_local_minimum(x, localMinIdx, xClick, searchRadiusDeg)
x = x(:);
ok = false;
xSnap = xClick;

if isempty(localMinIdx)
    return;
end

candX = x(localMinIdx);
d = abs(candX - xClick);
mask = d <= searchRadiusDeg;

if ~any(mask)
    return;
end

candX = candX(mask);
[~, iMin] = min(abs(candX - xClick));
xSnap = candX(iMin);
ok = true;
end

function xSnap = snap_to_raw_grid(x, xClick)
x = x(:);
[~, idx] = min(abs(x - xClick));
xSnap = x(idx);
end

function s = setd(s, f, v)
if ~isfield(s, f) || isempty(s.(f))
    s.(f) = v;
end
end