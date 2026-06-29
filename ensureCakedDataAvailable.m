% =========================================================================
%  ensureCakedDataAvailable — startet 2D-Batch-Integration on-demand
% =========================================================================
function h = ensureCakedDataAvailable(h)

% Bereits geladen? Dann nichts tun.
if isfield(h, 'dataset') && ~isempty(h.dataset) && ...
   isfield(h.dataset(1), 'cakedLoaded') && ...
   any([h.dataset.cakedLoaded])
    return
end

if ~isfield(h, 'dataDir') || isempty(h.dataDir)
    return
end

cacheDir  = fullfile(h.dataDir, 'caked_cache');
cachePath = fullfile(cacheDir, 'caked_batch.mat');

% Cache existiert bereits → einfach laden, kein Python-Aufruf nötig
if isfile(cachePath)
    try
        result    = load(cachePath);
        h.dataset = fillCakedFromResult(h.dataset, result);
        fprintf('ensureCakedDataAvailable: %d gecakte Bilder aus Cache geladen.\n', ...
            sum([h.dataset.cakedLoaded]));
    catch ME
        warning('ensureCakedDataAvailable: Cache-Fehler: %s', strrep(ME.message, '%', '%%'));
    end
    return
end

% ── Kein Cache vorhanden: jetzt erst integrieren ──────────────────────
cbfPaths = {h.dataset.cbfPath};
hasCBF   = ~cellfun(@isempty, cbfPaths);
if ~any(hasCBF)
    return
end

% PONI-Dateien erneut suchen (gleiche Logik wie in tryAutoCake)
poniFiles = dir(fullfile(h.dataDir, '*.poni'));
if isempty(poniFiles)
    warndlg('Keine PONI-Datei gefunden — Caked Image nicht verfügbar.', 'Keine PONI');
    return
end

[~, sortIdx] = sort({poniFiles.name});
poniMap = struct('alpha', {}, 'path', {});
for k = 1:numel(poniFiles)
    fname = poniFiles(sortIdx(k)).name;
    tok   = regexp(fname, '(?<=alpha)([\d.+-]+)', 'match');
    if ~isempty(tok)
        poniMap(k).alpha = str2double(tok{1});
    else
        poniMap(k).alpha = NaN;
    end
    poniMap(k).path = fullfile(h.dataDir, fname);
end
fallbackPoni = poniMap(1).path;
for k = 1:numel(poniMap)
    if isnan(poniMap(k).alpha), fallbackPoni = poniMap(k).path; break; end
end

% Wellenlänge
lambda_m = 1.34143847484e-10;
for i = 1:numel(h.dataset)
    p = h.dataset(i).poni;
    if isstruct(p) && isfield(p,'wavelength') && p.wavelength > 0
        lambda_m = p.wavelength;
        break
    end
end

% Script-Pfad
guiFile    = which('XRD2DStressAnalysis_modPV_pyFAI');
scriptPath = '';
if ~isempty(guiFile)
    candidate = fullfile(fileparts(guiFile), 'pyfai_multigeom_run.py');
    if isfile(candidate), scriptPath = candidate; end
end
if isempty(scriptPath)
    warning('ensureCakedDataAvailable: pyfai_multigeom_run.py nicht gefunden.');
    return
end

% PONI pro Bild zuordnen (alpha-basiert)
poniPaths_all = cell(numel(h.dataset), 1);
for i = 1:numel(h.dataset)
    alpha_i = NaN;
    if isfield(h.dataset(i), 'meta') && isstruct(h.dataset(i).meta) && ...
       isfield(h.dataset(i).meta, 'motorsChi_cor')
        val = h.dataset(i).meta.motorsChi_cor;
        if isnumeric(val) && isscalar(val) && isfinite(val)
            alpha_i = abs(val);
        end
    end
    if ~isnan(alpha_i)
        alphaVals = [poniMap.alpha];
        validIdx  = find(~isnan(alphaVals));
        if ~isempty(validIdx)
            [~, bestK] = min(abs(alphaVals(validIdx) - alpha_i));
            poniPaths_all{i} = poniMap(validIdx(bestK)).path;
        else
            poniPaths_all{i} = fallbackPoni;
        end
    else
        poniPaths_all{i} = fallbackPoni;
    end
end

validCBF  = cbfPaths(hasCBF);
validPONI = poniPaths_all(hasCBF);
N_cbf     = numel(validCBF);

if ~exist(cacheDir, 'dir'), mkdir(cacheDir); end

job              = struct();
job.img_paths    = validCBF(:);
job.poni_paths   = validPONI(:);
job.wavelength_m = lambda_m;
job.mode         = '2d_batch';
job.unit         = '2th_deg';
job.npt_rad      = 1500;
job.npt_azim     = 360;
job.method       = 'csr';
job.error_model  = 'poisson';
job.out_npz      = fullfile(cacheDir, 'caked_batch.npz');
job.out_mat      = cachePath;
job.out_json     = fullfile(cacheDir, 'caked_batch_meta.json');

jobPath = fullfile(cacheDir, 'caked_job.json');
fid = fopen(jobPath, 'w');
fprintf(fid, '%s', jsonencode(job));
fclose(fid);

pythonExe = 'python';
if isfield(h, 'pythonExeEdit') && isvalid(h.pythonExeEdit)
    pythonExe = strtrim(get(h.pythonExeEdit, 'String'));
end

fprintf('ensureCakedDataAvailable: Starte 2D-Batch-Integration (%d Bilder) ...\n', N_cbf);
cmd = sprintf('"%s" "%s" "%s" 2>&1', pythonExe, scriptPath, jobPath);
[status, cmdout] = system(cmd);
if isfile(jobPath), delete(jobPath); end

if status ~= 0
    warning('ensureCakedDataAvailable: 2D-Integration fehlgeschlagen:\n%s', cmdout);
    return
end

if isfile(cachePath)
    try
        result    = load(cachePath);
        h.dataset = fillCakedFromResult(h.dataset, result);
        fprintf('ensureCakedDataAvailable: Caking abgeschlossen — %d Bilder gecacht.\n', N_cbf);
    catch ME
        warning('ensureCakedDataAvailable: Cache laden fehlgeschlagen: %s', strrep(ME.message, '%', '%%'));
    end
end

end  % ensureCakedDataAvailable