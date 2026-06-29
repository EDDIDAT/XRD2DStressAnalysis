% =========================================================================
%  loadDAT — liest pyFAI-integrierte .dat-Datei (q, I, PONI-Header)
% =========================================================================
function [q, I, poni] = loadDAT(datPath)
% LOADDAT  Liest eine pyFAI-integrierte .dat-Datei.
%
%   [q, I, poni] = loadDAT(datPath)

fid = fopen(datPath, 'r');
if fid == -1
    error('loadDAT: Datei nicht lesbar: %s', datPath);
end

jsonLines  = {};
inJson     = false;
braceDepth = 0;   % geschweifte Klammern zählen statt nur auf '}' prüfen

while ~feof(fid)
    raw = fgetl(fid);
    if ~ischar(raw), break; end

    line = strtrim(raw);
    if ~startsWith(line, '#'), break; end

    content = strtrim(line(2:end));   % '#' abschneiden

    if startsWith(content, '{')
        inJson     = true;
        braceDepth = braceDepth + 1;
    end
    if inJson
        jsonLines{end+1} = content; %#ok<AGROW>
        % Klammern in dieser Zeile zählen (außer der öffnenden ersten Zeile)
        if ~startsWith(content, '{')
            braceDepth = braceDepth + sum(content == '{') - sum(content == '}');
        end
        if braceDepth <= 0
            inJson = false;
        end
    end
end
fclose(fid);

% PONI-Parameter parsen
if isempty(jsonLines)
    poni = struct();
else
    try
        poni = jsondecode(strjoin(jsonLines, newline));
    catch
        poni = struct();
    end
end

% Datenspalten: alle #-Zeilen überspringen, zwei Spalten lesen
try
    raw_data = readmatrix(datPath, ...
        'FileType',             'text', ...
        'CommentStyle',         '#', ...
        'ExpectedNumVariables', 2);
    q = raw_data(:, 1);
    I = raw_data(:, 2);
catch ME
    error('loadDAT: Fehler beim Lesen von %s:\n%s', datPath, ME.message);
end
end