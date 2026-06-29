function fitWindow = computeAutoFitWindows(x, Y, peakResults, varargin)
% COMPUTEAUTOFITWINDOWS
%   Bestimmt automatische Fitfenster für jeden Peak eines Spektrums.
%
%   OUTPUT:
%     fitWindow(c,p)  - automatisches Fenster für FitGaussiansFromPeakResults
%
%   OPTIONALE PARAMETER:
%     'MinWidth'      - minimal erlaubtes Fenster (default = dx*5)
%     'MaxWidth'      - maximal erlaubtes Fenster (default = range(x)/10)
%     'ScaleFactor'   - Fenster = scaleFactor * geschätzte Peakbreite
%
%   Die Peakbreite wird lokal durch den Abstand
%     (y >= 0.5 * peakHeight)
%   bestimmt — also analog zur FWHM-Schätzung.

    dx = mean(diff(x));
    xRange = max(x) - min(x);

    % Defaultwerte
    p = inputParser;
    addParameter(p, 'MinWidth', dx*5);
    addParameter(p, 'MaxWidth', xRange/10);
    addParameter(p, 'ScaleFactor', 1.0);
    parse(p, varargin{:});

    minW  = p.Results.MinWidth;
    maxW  = p.Results.MaxWidth;
    sf    = p.Results.ScaleFactor;

    [~, nCols] = size(Y);
    nPeaks = size(peakResults,2);

    fitWindow = nan(nCols, nPeaks);

    for c = 1:nCols
        y = Y(:,c);

        for p = 1:nPeaks
            mu = peakResults(c,p).peakX;
            if isnan(mu), continue; end

            % Index des Peaks finden
            [~, idxMu] = min(abs(x - mu));

            % Peak-Höhe
            peakY = peakResults(c,p).peakY;

            % Falls der Peak sehr klein oder fehlerhaft ist
            if idxMu <= 1 || idxMu >= length(x)
                fitWindow(c,p) = minW;
                continue;
            end

            % ---- FWHM-SCHÄTZUNG -----------------------------------------

            halfHeight = peakY * 0.5;

            % Linke Seite: erster Punkt < halfHeight
            leftIdx = idxMu;
            while leftIdx > 1 && y(leftIdx) > halfHeight
                leftIdx = leftIdx - 1;
            end

            % Rechte Seite: erster Punkt < halfHeight
            rightIdx = idxMu;
            while rightIdx < length(y) && y(rightIdx) > halfHeight
                rightIdx = rightIdx + 1;
            end

            % Falls unzureichend definiert
            if leftIdx == idxMu || rightIdx == idxMu
                estWidth = minW;
            else
                estWidth = abs(x(rightIdx) - x(leftIdx));
                if estWidth == 0
                    estWidth = minW;
                end
            end

            % Skalieren (z. B. 1x, 2x FWHM etc.)
            win = estWidth * sf;

            % Begrenzen
            win = max(minW, win);
            win = min(maxW, win);

            fitWindow(c,p) = win;
        end
    end
end
