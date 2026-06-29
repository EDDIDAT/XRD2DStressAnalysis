function [muCell, dmuCell] = extractPeaksByUP(fitOut, UP, tol)
% EXTRACTPEAKSBYUP
%   Gibt für jeden Peak (entsprechend UP) ein separates Cell-Array zurück.
%   Fehlende Peaks oder Peaks außerhalb der Toleranz werden als NaN eingetragen.
%
% INPUT:
%   fitOut : Struktur von fitGaussiansFromPeakResults
%   UP     : Vektor der Peaks in gewünschter Reihenfolge
%   tol    : maximale erlaubte Abweichung (optional, Default: 0.05)
%
% OUTPUT:
%   muCell   : Cell-Array (1 x nUP), jede Zelle enthält μ für alle Spektren
%   dmuCell  : Cell-Array (1 x nUP), jede Zelle enthält Fehler μ für alle Spektren

    if nargin < 3
        tol = 0.05; % Standardtoleranz
    end

    [nCols, nPeaks] = size(fitOut);
    nUP = length(UP);

    % Initialisierung: eine Zelle pro Peak
    muCell  = cell(1,nUP);
    dmuCell = cell(1,nUP);

    % Zellen vorbereiten mit NaNs
    for u = 1:nUP
        muCell{u}  = nan(1,nCols);
        dmuCell{u} = nan(1,nCols);
    end

    % Für jedes Spektrum
    for c = 1:nCols
        % Alle gefundenen Peaks extrahieren
        mus  = nan(1,nPeaks);
        dmus = nan(1,nPeaks);

        for p = 1:nPeaks
            if fitOut(c,p).success
                mus(p)  = fitOut(c,p).params(2);  % μ
                dmus(p) = fitOut(c,p).errors(2);  % Fehler von μ
            end
        end

        % Peaks anhand UP sortieren
        for u = 1:nUP
            % finde Peak in fitOut, der am nächsten an UP(u) liegt
            [minDiff, idx] = min(abs(mus - UP(u)));

            % Prüfen, ob Peak innerhalb der Toleranz liegt
            if ~isnan(mus(idx)) && minDiff <= tol
                muCell{u}(c)  = mus(idx);
                dmuCell{u}(c) = dmus(idx);
            else
                % Kein Peak gefunden oder außerhalb Toleranz → NaN
                muCell{u}(c)  = NaN;
                dmuCell{u}(c) = NaN;
            end
        end
    end
end
