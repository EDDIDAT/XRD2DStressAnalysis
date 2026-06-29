function [I_1D, gapMask] = cakedToProfileWithGapMask(result)
% I_1D:   einfache, robuste Mittelung über alle gültigen Chi-Bins
%         (mit method='no' bereits stabile Intensitätsskala)
% gapMask: logischer Vektor [1 x nRad] — true = Lücke/ungültiger Bereich,
%          unabhängig von der Integrationsmethode, direkt aus caked_mask

nRad = size(result.sum_signal, 2);
I_1D = NaN(1, nRad);

for col = 1:nRad
    validMask = result.count(:, col) > 0;
    if any(validMask)
        I_1D(col) = mean(result.sum_signal(validMask, col));
    end
end

% Lücken-Markierung aus caked_mask/valid_fraction ableiten,
% unabhängig von I_1D selbst
if isfield(result, 'valid_fraction')
    % Mittlerer Anteil gültiger Pixel über alle Chi-Bins, pro 2theta-Spalte
    meanValidFraction = mean(result.valid_fraction, 1);
    gapMask = meanValidFraction < 0.85;   % Schwelle anpassbar
elseif isfield(result, 'caked_mask')
    meanCakedMask = mean(double(result.caked_mask), 1);
    gapMask = meanCakedMask < 0.85;
else
    gapMask = false(1, nRad);   % keine Maskeninfo verfügbar
end

end