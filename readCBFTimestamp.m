function dt = readCBFTimestamp(cbfPath)
% Liest den Zeitstempel aus dem CBF-Header eines Pilatus-Detektorbildes.
% Format: # 2025-12-18T15:55:51.593
% Gibt NaT zurueck wenn kein Zeitstempel gefunden wird.

dt = NaT;

try
    fid = fopen(cbfPath, 'r');
    if fid == -1, return; end

    % Nur die ersten 2000 Bytes lesen (Header ist ASCII, Bilddaten kommen spaeter)
    raw = fread(fid, 2000, '*char')';
    fclose(fid);

    % ISO-8601 Zeitstempel suchen: # YYYY-MM-DDTHH:MM:SS.fff
    tok = regexp(raw, '#\s*(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[\.\d]*)', 'tokens');

    if ~isempty(tok)
        tsStr = tok{1}{1};
        % Millisekunden abschneiden falls laenger als 3 Stellen
        dotIdx = strfind(tsStr, '.');
        if ~isempty(dotIdx) && length(tsStr) - dotIdx(end) > 3
            tsStr = tsStr(1:dotIdx(end)+3);
        end
        try
            dt = datetime(tsStr, 'InputFormat', 'yyyy-MM-dd''T''HH:mm:ss.SSS');
        catch
            try
                dt = datetime(tsStr, 'InputFormat', 'yyyy-MM-dd''T''HH:mm:ss');
            catch
            end
        end
    end
catch
end
end
