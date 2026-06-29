function heaterData = readHeaterCSV(csvPath, t0_datetime)
% READHEATERCSV  Liest ein PVD-Heizprotokoll (CSV mit #-Header).
%
%   heaterData = readHeaterCSV(csvPath, t0_datetime)
%
%   csvPath      – Pfad zur CSV-Datei
%   t0_datetime  – datetime der ersten XRD-Messung (für rel. Zeit in min)
%
%   Rückgabe: struct mit Feldern:
%     .time_min   – relative Zeit in Minuten seit t0
%     .datetime   – datetime-Array
%     .colNames   – Spaltennamen (Cell-Array)
%     .<ColName>  – Datenspalten als Vektoren (MATLAB-gültige Feldnamen)

heaterData = [];

fid = fopen(csvPath, 'r');
if fid == -1
    error('readHeaterCSV: Datei nicht lesbar: %s', csvPath);
end

% ── Header überspringen, Spaltenzeile finden ─────────────────────────
headerLine = '';
while ~feof(fid)
    raw = fgetl(fid);
    if ~ischar(raw), break; end
    line = strtrim(raw);
    if startsWith(line, '#') || isempty(line)
        continue;
    end
    % Erste nicht-leere, nicht-#-Zeile mit Tabs = Spaltenzeile
    if count(line, sprintf('	')) >= 2
        headerLine = line;
        break;
    end
end

if isempty(headerLine)
    fclose(fid);
    error('readHeaterCSV: Keine Spaltenzeile gefunden in %s', csvPath);
end

% ── Spaltennamen parsen ───────────────────────────────────────────────
rawCols  = strsplit(headerLine, '	');
rawCols  = rawCols(~cellfun(@isempty, strtrim(rawCols)));
colNames = rawCols;   % Originalnamen für Anzeige
colFields = matlab.lang.makeValidName(rawCols);   % MATLAB-Feldnamen

% ── Datenzeilen lesen ─────────────────────────────────────────────────
rows = {};
while ~feof(fid)
    raw = fgetl(fid);
    if ~ischar(raw) || isempty(strtrim(raw)), continue; end
    rows{end+1} = strtrim(raw); %#ok<AGROW>
end
fclose(fid);

if isempty(rows)
    error('readHeaterCSV: Keine Datenzeilen in %s', csvPath);
end

% ── Parsen ────────────────────────────────────────────────────────────
nRows = numel(rows);
nCols = numel(colFields);

% Spalten als Cell-Array vorbelegen
data = cell(nRows, nCols);
for r = 1:nRows
    parts = strsplit(rows{r}, '	');
    for c = 1:min(nCols, numel(parts))
        data{r,c} = strtrim(parts{c});
    end
end

% ── Datetime aus Spalte 1 (HH:MM:SS) ─────────────────────────────────
% Datum aus t0_datetime übernehmen (CSV enthält nur Uhrzeit)
dateStr = datestr(t0_datetime, 'yyyy/mm/dd');
dtArr   = NaT(nRows, 1);
for r = 1:nRows
    try
        dtArr(r) = datetime([dateStr ' ' data{r,1}], ...
            'InputFormat', 'yyyy/MM/dd HH:mm:ss');
        % Tagesübergang abfangen (Messung über Mitternacht)
        if r > 1 && dtArr(r) < dtArr(r-1)
            dtArr(r) = dtArr(r) + days(1);
        end
    catch
        if r > 1
            dtArr(r) = dtArr(r-1) + seconds(5);
        else
            dtArr(r) = t0_datetime;
        end
    end
end

% ── Relative Zeit in Minuten ──────────────────────────────────────────
heaterData.datetime  = dtArr;
heaterData.time_min  = seconds(dtArr - t0_datetime) / 60;
heaterData.colNames  = colNames;

% ── Numerische Spalten als Felder ─────────────────────────────────────
for c = 2:nCols   % Spalte 1 = Time (schon als datetime)
    vals = zeros(nRows, 1);
    for r = 1:nRows
        if c <= size(data,2) && ~isempty(data{r,c})
            vals(r) = str2double(data{r,c});
        else
            vals(r) = NaN;
        end
    end
    heaterData.(colFields{c}) = vals;
end
end  % readHeaterCSV