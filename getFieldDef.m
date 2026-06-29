function val = getFieldDef(s, field, default)
if isfield(s, field) && ~isempty(s.(field)) && isfinite(s.(field))
    val = s.(field);
else
    val = default;
end
end