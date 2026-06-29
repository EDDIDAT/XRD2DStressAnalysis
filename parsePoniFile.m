function poni = parsePoniFile(poniPath)
poni = struct();
fid  = fopen(poniPath, 'r');
while ~feof(fid)
    line = strtrim(fgetl(fid));
    if ~ischar(line) || isempty(line) || line(1) == '#', continue; end
    parts = strsplit(line, ':', 'MaxParts', 2);
    if numel(parts) < 2, continue; end
    key = strtrim(parts{1});
    val = strtrim(parts{2});
    num = str2double(val);
    if isfield(poni, matlab.lang.makeValidName(key)), continue; end
    if isfinite(num)
        poni.(matlab.lang.makeValidName(key)) = num;
    else
        poni.(matlab.lang.makeValidName(key)) = val;
    end
end
fclose(fid);
end