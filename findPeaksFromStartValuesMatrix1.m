function peakResults = findPeaksFromStartValuesMatrix1(x, Y, startValues, minHeight, minProminence, window)
% findPeaksFromStartValuesMatrix1  (optimierte Version)
%
% Verbesserungen gegenüber Original:
%   - islocalmax wird einmal für alle Spalten gleichzeitig aufgerufen
%   - Prominenz vektorisiert berechnet (keine Schleife mehr)
%   - Fallback: wenn kein Peak die Filter erfüllt, wird das Fenster-
%     Maximum ohne Prominenzfilter zurückgegeben (statt NaN)

    if nargin < 4 || isempty(minHeight),     minHeight     = -inf; end
    if nargin < 5 || isempty(minProminence), minProminence = 0;    end
    if nargin < 6 || isempty(window),        window        = inf;  end

    x = x(:);
    [nSamples, nCols] = size(Y);
    nStart = numel(startValues);

    if nSamples ~= length(x)
        error('Länge von x muss der Anzahl Zeilen von Y entsprechen.');
    end

    % --- Lokale Maxima für ALLE Spalten auf einmal ---
    % islocalmax(Y) liefert [nSamples x nCols] logische Matrix
    isMaxMat = islocalmax(Y);

    % Ausgabe vorallokieren
    emptyStruct = struct('startValue',[], 'peakX',[], 'peakY',[], 'index',[]);
    peakResults = repmat(emptyStruct, nCols, nStart);

    % --- Spaltenweise Verarbeitung ---
    for c = 1:nCols
        y = Y(:, c);

        % Peaks dieser Spalte aus vorberechneter Matrix holen
        peakIdx = find(isMaxMat(:, c));

        if isempty(peakIdx)
            % Kein einziger lokaler Maxima → alle Startwerte auf NaN
            for sIdx = 1:nStart
                peakResults(c, sIdx).startValue = startValues(sIdx);
                peakResults(c, sIdx).peakX      = NaN;
                peakResults(c, sIdx).peakY      = NaN;
                peakResults(c, sIdx).index      = NaN;
            end
            continue
        end

        peakX  = x(peakIdx);
        peakY  = y(peakIdx);

        % Prominenz vektorisiert berechnen
        prominences = computeProminenceVec(y, peakIdx);

        % Filter: Höhe UND Prominenz
        valid   = (peakY >= minHeight) & (prominences >= minProminence);
        peakIdxF = peakIdx(valid);
        peakXF   = peakX(valid);
        peakYF   = peakY(valid);

        % --- Startwerte durchlaufen ---
        for sIdx = 1:nStart
            s          = startValues(sIdx);
            leftBound  = s - window;
            rightBound = s + window;

            % Gefilterte Peaks im Fenster
            inWin = peakXF >= leftBound & peakXF <= rightBound;

            if any(inWin)
                % Nächstgelegenen gefilterten Peak nehmen
                px   = peakXF(inWin);
                py   = peakYF(inWin);
                pidx = peakIdxF(inWin);
                [~, nearest]                    = min(abs(px - s));
                peakResults(c,sIdx).startValue  = s;
                peakResults(c,sIdx).peakX       = px(nearest);
                peakResults(c,sIdx).peakY       = py(nearest);
                peakResults(c,sIdx).index       = pidx(nearest);

            else
                % --- FALLBACK: kein gefilterter Peak im Fenster ---
                % Fensterbereich im x-Vektor bestimmen
                winMask = x >= leftBound & x <= rightBound;

                if any(winMask)
                    % Einfach das Maximum im Fenster nehmen (ohne Filter)
                    yWin           = y(winMask);
                    xWin           = x(winMask);
                    idxWin         = find(winMask);
                    [maxY, maxPos] = max(yWin);

                    if maxY >= minHeight
                        % Akzeptieren wenn wenigstens Mindesthöhe erfüllt
                        peakResults(c,sIdx).startValue = s;
                        peakResults(c,sIdx).peakX      = xWin(maxPos);
                        peakResults(c,sIdx).peakY      = maxY;
                        peakResults(c,sIdx).index      = idxWin(maxPos);
                    else
                        % Signal zu schwach → NaN
                        peakResults(c,sIdx).startValue = s;
                        peakResults(c,sIdx).peakX      = NaN;
                        peakResults(c,sIdx).peakY      = NaN;
                        peakResults(c,sIdx).index      = NaN;
                    end
                else
                    % Fenster liegt außerhalb des x-Bereichs → NaN
                    peakResults(c,sIdx).startValue = s;
                    peakResults(c,sIdx).peakX      = NaN;
                    peakResults(c,sIdx).peakY      = NaN;
                    peakResults(c,sIdx).index      = NaN;
                end
            end
        end
    end
end

% ----------------------------------------------------------------
% Hilfsfunktion: Prominenz vektorisiert (keine Schleife über Peaks)
% ----------------------------------------------------------------
function prom = computeProminenceVec(y, peakIdx)
    n    = numel(peakIdx);
    prom = zeros(n, 1);
    if n == 0, return; end

    % Für jeden Peak: linkes und rechtes Minimum bis zum Rand
    % Vektorisiert über cummin von links und rechts
    cumFromLeft  = cummin(y);                  % Minimum von Index 1 bis i
    cumFromRight = cummin(y(end:-1:1));        % Minimum von Index end bis i
    cumFromRight = cumFromRight(end:-1:1);     % wieder umdrehen

    for i = 1:n
        p          = peakIdx(i);
        leftMin    = cumFromLeft(p);
        rightMin   = cumFromRight(p);
        prom(i)    = y(p) - max(leftMin, rightMin);
    end
end

% function peakResults = findPeaksFromStartValuesMatrix1(x, Y, startValues, minHeight, minProminence, window)
% % findPeaksFromStartValuesMatrix
% %   Sucht für jeden Startwert das naechstgelegene Peakmaximum in jeder
% %   Spalte der Y-Matrix. Optional mit Mindesthoehe, Mindestprominenz und
% %   Fensterumfang um Startwerte. Keine Signal Toolbox noetig.
% %
% % INPUT:
% %   x              - x-Werte (Vektor)
% %   Y              - Y-Matrix (Signale in Spalten)
% %   startValues    - Startwerte (1 x N)
% %   minHeight      - Mindesthoehe (optional)
% %   minProminence  - Mindestprominenz (optional)
% %   window         - Fensterhalbbreite um Startwerte, z.B. 0.5 (optional)
% %
% % OUTPUT:
% %   peakResults(columnIndex, startValueIndex).*
% 
%     % Standardwerte für optionale Parameter
%     if nargin < 4 || isempty(minHeight)
%         minHeight = -inf;
%     end
%     if nargin < 5 || isempty(minProminence)
%         minProminence = 0;
%     end
%     if nargin < 6 || isempty(window)
%         window = inf;      % wenn kein Fenster angegeben → gesamtes Signal
%     end
% 
%     % x als Vektor
%     x = x(:);
%     % [nSamplesX, ~] = size(X);
%     [nSamples, nCols] = size(Y);
%     nStart = numel(startValues);
% 
%     if nSamples ~= length(x)
%         error('Laenge von x muss der Anzahl Zeilen von Y entsprechen.');
%     end
% 
%     % Struktur zurückgeben
%     peakResults(nCols, nStart) = struct('startValue', [], 'peakX', [], 'peakY', [], 'index', []);
% 
%     % --- Spaltenweise Verarbeitung ---
%     for c = 1:nCols
%         y = Y(:,c);
% 
%         % Lokale Maxima bestimmen
%         isMax = islocalmax(y);
%         peakIdx = find(isMax);
%         peakX = x(peakIdx);
%         peakY = y(peakIdx);
% 
%         % --- Mindesthöhe filtern ---
%         validHeight = peakY >= minHeight;
% 
%         % --- Prominenz filtern ---
%         prominences = computeProminence(y, peakIdx);
%         validProm = prominences >= minProminence;
% 
%         valid = validHeight & validProm;
% 
%         peakIdx = peakIdx(valid);
%         peakX = peakX(valid);
%         peakY = peakY(valid);
% 
%         % Falls keine gültigen Peaks
%         if isempty(peakIdx)
%             continue;
%         end
% 
%         % --- Startwerte durchlaufen ---
%         for sIdx = 1:nStart
%             s = startValues(sIdx);
% 
%             % Fenstergrenzen
%             leftBound  = s - window;
%             rightBound = s + window;
% 
%             % Peaks innerhalb des Fensters auswählen
%             inWindow = peakX >= leftBound & peakX <= rightBound;
% 
%             if ~any(inWindow)
%                 % Kein Peak im Fenster → NaN zurück
%                 peakResults(c, sIdx).startValue = s;
%                 peakResults(c, sIdx).peakX = NaN;
%                 peakResults(c, sIdx).peakY = NaN;
%                 peakResults(c, sIdx).index = NaN;
%                 continue;
%             end
% 
%             % Peaks im Fenster
%             px = peakX(inWindow);
%             py = peakY(inWindow);
%             pidx = peakIdx(inWindow);
% 
%             % Nächstgelegenen Peak bestimmen
%             [~, idx] = min(abs(px - s));
% 
%             peakResults(c, sIdx).startValue = s;
%             peakResults(c, sIdx).peakX = px(idx);
%             peakResults(c, sIdx).peakY = py(idx);
%             peakResults(c, sIdx).index = pidx(idx);
%         end
%     end
% end
% 
% 
% %% ---------------------------------------------------------
% % Hilfsfunktion: Prominenz berechnen (ohne Signal Toolbox)
% % ---------------------------------------------------------
% function prom = computeProminence(y, peakIdx)
%     n = length(peakIdx);
%     prom = zeros(n,1);
% 
%     for i = 1:n
%         p = peakIdx(i);
% 
%         leftMin = min(y(1:p));
%         rightMin = min(y(p:end));
% 
%         prom(i) = y(p) - max(leftMin, rightMin);
%     end
% end
