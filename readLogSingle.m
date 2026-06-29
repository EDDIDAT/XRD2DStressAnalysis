% =========================================================================
%  readLogSingle — liest log_NNNNNNN.txt → struct
% =========================================================================
function logData = readLogSingle(logPath)
% Liest eine einzelne log_NNNNNNN.txt-Datei.
% Format: "Kategorie Schlüssel = Wert" nach dem Header-Block.

fid = fopen(logPath, 'r');
if fid == -1
    error('readLogSingle: Datei nicht lesbar: %s', logPath);
end

logData  = struct();
inHeader = false;

while ~feof(fid)
    raw = fgetl(fid);
    if ~ischar(raw), break; end
    line = strtrim(raw);

    if contains(line, 'start Header'), inHeader = true;  continue; end
    if contains(line, 'end Header'),   inHeader = false; continue; end
    if inHeader || isempty(line),      continue; end

    % "Kategorie Schlüssel = Wert" parsen
    eqPos = strfind(line, ' = ');
    if isempty(eqPos), continue; end

    key  = strtrim(line(1 : eqPos(1)-1));
    val  = strtrim(line(eqPos(1)+3 : end));
    fName = matlab.lang.makeValidName(key);

    num = str2double(val);
    if ~isnan(num)
        logData.(fName) = num;
    else
        logData.(fName) = val;
    end
end
fclose(fid);
end