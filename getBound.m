function val = getBound(fb, field, pkIdx, default)
% Liest per-Peak-Grenze aus fb; fällt auf default zurück falls nicht vorhanden
if isfield(fb, field) && numel(fb.(field)) >= pkIdx && ...
   (isfinite(fb.(field)(pkIdx)) || isinf(fb.(field)(pkIdx)))
    val = fb.(field)(pkIdx);
else
    val = default;
end
end