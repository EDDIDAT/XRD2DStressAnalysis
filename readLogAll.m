% =========================================================================
%  readLogAll — liest log_all.txt → struct-Array
% =========================================================================
function meta = readLogAll(logAllPath)
% Liest log_all.txt und gibt ein struct-Array zurück.
% Felder entsprechen den tab-getrennten Spalten, Datum+Zeit → datetime.

fid = fopen(logAllPath, 'r');
if fid == -1
    error('readLogAll: Datei nicht lesbar: %s', logAllPath);
end

% Kommentarzeilen UND Leerzeilen überspringen, Spaltenzeile finden.
% Das xlab-Format hat nach "########## end Header ##########" eine
% Leerzeile, bevor die tab-getrennte Spaltenzeile kommt.
headerLine = '';
while ~feof(fid)
    raw = fgetl(fid);
    if ~ischar(raw), break; end
    line = strtrim(raw);

    % Kommentarzeilen (#...) und Leerzeilen überspringen
    if startsWith(line, '#') || isempty(line)
        continue;
    end

    % Erste nicht-leere, nicht-#-Zeile muss die Spaltenzeile sein.
    % Plausibilitätscheck: muss Tab-getrennte Spalten enthalten
    % (mindestens 3 Tabs → mindestens 4 Spalten erwartet)
    if count(line, sprintf('\t')) >= 3
        headerLine = line;
        break;
    end
    % Falls Zeile keine Tabs hat, weiter suchen
end

if isempty(headerLine)
    fclose(fid);
    error('readLogAll: Keine Spaltenzeile gefunden in %s\n(Erwartet: tab-getrennte Zeile nach dem Header-Block)', ...
        logAllPath);
end

% Spaltennamen → gültige MATLAB-Feldnamen
rawCols  = strsplit(headerLine, '\t');
rawCols  = rawCols(~cellfun(@isempty, rawCols));
colNames = matlab.lang.makeValidName(rawCols);

% Datenzeilen einlesen
rows = {};
while ~feof(fid)
    raw = fgetl(fid);
    if ~ischar(raw) || isempty(strtrim(raw)), continue; end
    rows{end+1} = raw; %#ok<AGROW>
end
fclose(fid);

if isempty(rows)
    error('readLogAll: Keine Datenzeilen gefunden in %s', logAllPath);
end

% Parsen
meta(numel(rows)) = struct();
for r = 1:numel(rows)
    parts = strsplit(rows{r}, '\t');

    % Datum + Zeit → datetime
    if numel(parts) >= 2
        try
            meta(r).datetime = datetime([strtrim(parts{1}) ' ' strtrim(parts{2})], ...
                'InputFormat', 'yyyy/MM/dd HH:mm:ss');
        catch
            meta(r).datetime = NaT;
        end
    else
        meta(r).datetime = NaT;
    end

    % Alle Spalten als Felder
    for c = 1:min(numel(colNames), numel(parts))
        val = strtrim(parts{c});
        num = str2double(val);
        if ~isnan(num)
            meta(r).(colNames{c}) = num;
        else
            meta(r).(colNames{c}) = val;
        end
    end
end
end