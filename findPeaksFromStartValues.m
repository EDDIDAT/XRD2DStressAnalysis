function peakResults = findPeaksFromStartValues(x, Y, startValues, minHeight, minProminence, window)
% FINDPEAKSFROMSTARTVALUES
%   Sucht für jeden Startwert das nächstgelegene Peakmaximum in jeder
%   Spalte der Y-Matrix. Keine Signal Toolbox nötig.
%
% INPUT:
%   x              - x-Vektor (Nx1 oder 1xN)
%   Y              - Maße: N x M (M Spektren)
%   startValues    - 1 x K Startwerte
%   minHeight      - Mindesthöhe (optional)
%   minProminence  - Mindestprominenz (optional)
%   window         - Fensterhalbbreite um Startwert (optional)
%
% OUTPUT:
%   peakResults(c,s) mit Feldern:
%       startValue
%       peakX
%       peakY
%       index

    % -------------------------
    % Defaultwerte
    % -------------------------
    if nargin < 4 || isempty(minHeight)
        minHeight = -inf;
    end
    if nargin < 5 || isempty(minProminence)
        minProminence = 0;
    end
    if nargin < 6 || isempty(window)
        window = inf;
    end

    % Vektorisieren
    x = x(:);
    [nSamples, nCols] = size(Y);
    nStart = numel(startValues);

    if nSamples ~= numel(x)
        error('x muss gleiche Länge wie Zeilenzahl von Y haben.');
    end

    % Ergebnisstruktur initialisieren
    emptyStruct = struct('startValue', [], 'peakX', [], 'peakY', [], 'index', []);
    peakResults = repmat(emptyStruct, nCols, nStart);

    % -------------------------
    % Verarbeitung pro Spalte
    % -------------------------
    for c = 1:nCols
        y = Y(:,c);

        % -------- Lokale Maxima --------
        isMax = localMax1D(y);
        peakIdx = find(isMax);

        if isempty(peakIdx)
            continue;
        end

        peakX = x(peakIdx);
        peakY = y(peakIdx);

        % -------- Mindesthöhe --------
        maskH = peakY >= minHeight;

        % -------- Prominenz --------
        prom = computeProminence_noToolbox(y, peakIdx);
        maskP = prom >= minProminence;

        mask = maskH & maskP;

        peakIdx = peakIdx(mask);
        peakX = peakX(mask);
        peakY = peakY(mask);

        if isempty(peakIdx)
            continue;
        end

        % -------- Peaks zu Startwerten zuordnen --------
        for sIdx = 1:nStart
            sv = startValues(sIdx);

            leftB  = sv - window;
            rightB = sv + window;

            inWindow = peakX >= leftB & peakX <= rightB;

            if ~any(inWindow)
                peakResults(c,sIdx).startValue = sv;
                peakResults(c,sIdx).peakX = NaN;
                peakResults(c,sIdx).peakY = NaN;
                peakResults(c,sIdx).index = NaN;
                continue;
            end

            px = peakX(inWindow);
            py = peakY(inWindow);
            pi = peakIdx(inWindow);

            % Nächstgelegenen Peak wählen
            [~, relIdx] = min(abs(px - sv));

            peakResults(c,sIdx).startValue = sv;
            peakResults(c,sIdx).peakX = px(relIdx);
            peakResults(c,sIdx).peakY = py(relIdx);
            peakResults(c,sIdx).index = pi(relIdx);
        end
    end
end


%% ---------------------------------------------------------
% Hilfsfunktion: einfache lokale Maxima OHNE Signal-Toolbox
% ---------------------------------------------------------
function isMax = localMax1D(y)
    dy = diff(y);
    isMax = [false; dy(1:end-1) > 0 & dy(2:end) < 0; false];
end


%% ---------------------------------------------------------
% Hilfsfunktion: Prominenz OHNE Signal-Toolbox
% ---------------------------------------------------------
function prom = computeProminence_noToolbox(y, peakIdx)
    n = numel(peakIdx);
    prom = zeros(n,1);

    for i = 1:n
        p = peakIdx(i);

        leftMin = min(y(1:p));
        rightMin = min(y(p:end));

        prom(i) = y(p) - max(leftMin, rightMin);
    end
end
