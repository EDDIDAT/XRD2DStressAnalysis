function result = hasNonZeroData(data)
% Prüft ob eine Tabellen-Data-Variable (cell oder numeric) 
% mindestens einen nicht-null finiten Wert enthält
result = false;
if isempty(data), return; end
if iscell(data)
    for i = 1:numel(data)
        val = data{i};
        if isnumeric(val) && isscalar(val) && isfinite(val) && val ~= 0
            result = true;
            return
        end
    end
elseif isnumeric(data)
    result = any(data(:) ~= 0 & isfinite(data(:)));
end
end