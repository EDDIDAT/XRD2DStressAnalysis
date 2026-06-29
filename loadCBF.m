function img = loadCBF(cbfPath, pythonExe)
% LOADCBF  Liest eine CBF-Detektordatei über Python/fabio.
%
%   img = loadCBF(cbfPath, pythonExe)
%
%   cbfPath   – vollständiger Pfad zur .cbf-Datei
%   pythonExe – Pfad zur Python-Executable

if nargin < 2 || isempty(pythonExe)
    pythonExe = 'python';
end

% Temporäre Dateien
tmpScript = [tempname '.py'];
tmpMat    = [tempname '.mat'];

% Pfade mit Forward-Slashes für Python
cbfPathPy = strrep(cbfPath, '\', '/');
tmpMatPy  = strrep(tmpMat,  '\', '/');

% Python-Script als Datei schreiben (vermeidet Escaping-Probleme)
fid = fopen(tmpScript, 'w');
fprintf(fid, 'import fabio\n');
fprintf(fid, 'import numpy as np\n');
fprintf(fid, 'from scipy.io import savemat\n');
fprintf(fid, 'd = fabio.open(r"%s")\n', cbfPathPy);
fprintf(fid, 'img = np.asarray(d.data, dtype=np.float32)\n');
fprintf(fid, 'savemat(r"%s", {"img": img})\n', tmpMatPy);
fclose(fid);

% Python aufrufen
cmd = sprintf('"%s" "%s" 2>&1', pythonExe, tmpScript);
[status, cmdout] = system(cmd);

% Temp-Script löschen
if exist(tmpScript, 'file'), delete(tmpScript); end

if status ~= 0
    if exist(tmpMat, 'file'), delete(tmpMat); end
    error('loadCBF: Python-Aufruf fehlgeschlagen:\n%s\nDatei: %s', ...
        cmdout, cbfPath);
end

% Ergebnis laden
if ~exist(tmpMat, 'file')
    error('loadCBF: Ausgabedatei nicht gefunden: %s', tmpMat);
end

try
    data = load(tmpMat);
    img  = double(data.img);
catch ME
    delete(tmpMat);
    error('loadCBF: Fehler beim Laden: %s', ME.message);
end

delete(tmpMat);
end