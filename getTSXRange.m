function [xMin, xMax] = getTSXRange(h)
% Liest die eingegebenen x-Bereichsgrenzen aus.
% Gibt [] zurück wenn das Feld leer oder ungültig ist.
xMin = str2double(get(h.TSXRangeMinEdit, 'String'));
xMax = str2double(get(h.TSXRangeMaxEdit, 'String'));
if isnan(xMin), xMin = []; end
if isnan(xMax), xMax = []; end