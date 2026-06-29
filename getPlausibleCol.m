function [yCol, yErrCol, idxFin] = getPlausibleCol(mat)
% GETPLAUSIBLECOL  Bestimmt die plausible 2theta-Spalte in FitDataMod.
%
% Initialwerte sind exakt ganzzahlig (1.0, 2.0, ...) und werden gefiltert.
% Echte gefittete 2theta-Werte sind nie exakt ganzzahlig.
%
% Eingabe:
%   mat      - FitDataMod{k} Matrix [nBins x nCols]
%
% Ausgabe:
%   yCol     - Spaltenindex für 2theta-Werte (9 oder 2)
%   yErrCol  - Spaltenindex für 2theta-Fehler (10 oder 3)
%   idxFin   - logischer Vektor: true für plausible Zeilen

nC = size(mat, 2);

% Spaltenauswahl: Spalte 9+10 bevorzugen wenn vorhanden und plausibel
if nC >= 10 && any(isfinite(mat(:,9)) & mat(:,9) > 1.0 & ...
                   abs(mat(:,9) - round(mat(:,9))) > 1e-5)
    yCol    = 9;
    yErrCol = 10;
elseif nC >= 3 && any(isfinite(mat(:,2)) & mat(:,2) > 1.0 & ...
                      abs(mat(:,2) - round(mat(:,2))) > 1e-5)
    yCol    = 2;
    yErrCol = 3;
else
    % Fallback: Spalte 2/3 ohne Plausibilitätsprüfung
    yCol    = 2;
    yErrCol = min(3, nC);
end

% Sicherheitscheck: Spaltenindex darf Array-Breite nicht überschreiten
yCol    = min(yCol,    nC);
yErrCol = min(yErrCol, nC);

% Plausibilitätsfilter:
% 1. finite Werte in yCol und yErrCol
% 2. 2theta > 1° (Initialwerte sind oft 0 oder NaN)
% 3. nicht exakt ganzzahlig (Initialwerte sind exakt 1.0, 2.0, ...)
idxFin = isfinite(mat(:, yCol))    & ...
         isfinite(mat(:, yErrCol)) & ...
         (mat(:, yCol) > 1.0)      & ...
         (abs(mat(:, yCol) - round(mat(:, yCol))) > 1e-5);

end