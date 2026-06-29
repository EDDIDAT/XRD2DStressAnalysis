function [muSorted, dmuSorted] = extractPeakPositionsInOrder(fitOut, UP)
% extractPeakPositionsInOrder
%   Gibt die Peakpositionen (mu) und Fehler (dmu) sortiert gemäß Reihenfolge in UP aus.
%
% INPUT:
%   fitOut(c,p).params = [A, mu, sigma, offset]
%   fitOut(c,p).errors = [dA, dmu, dsigma, doffset]
%   UP = Vektor gewünschter Peaklagen in Reihenfolge
%
% OUTPUT:
%   muSorted  : Cell-Array (1 pro Spektrum), enthält μ in UP-Reihenfolge
%   dmuSorted : Cell-Array (1 pro Spektrum), enthält Fehler in UP-Reihenfolge

    [nCols, nPeaks] = size(fitOut);
    nUP = length(UP);

    muSorted  = cell(nCols,1);
    dmuSorted = cell(nCols,1);

    for c = 1:nCols
        
        % --- extrahiere alle gefundenen Fit-Peaks ---
        mus  = nan(1,nPeaks);
        dmus = nan(1,nPeaks);

        for p = 1:nPeaks
            if fitOut(c,p).success
                mus(p)  = fitOut(c,p).params(2);   % μ
                dmus(p) = fitOut(c,p).errors(2);   % Fehler von μ
            end
        end

        % --- sortiere anhand der vorgegebenen UP-Reihenfolge ---
        muRow  = nan(1,nUP);
        dmuRow = nan(1,nUP);

        for u = 1:nUP
            % finde Peak in fitOut, der am nächsten an UP(u) liegt
            [~, idx] = min(abs(mus - UP(u)));

            if ~isnan(mus(idx))
                muRow(u)  = mus(idx);
                dmuRow(u) = dmus(idx);
            else
                muRow(u)  = NaN;
                dmuRow(u) = NaN;
            end
        end

        % Speichern
        muSorted{c}  = muRow;
        dmuSorted{c} = dmuRow;
    end
end
