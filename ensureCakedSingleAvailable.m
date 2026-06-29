% =========================================================================
%  ensureCakedSingleAvailable — integriert EIN Bild lazy als 2D-Caked
% =========================================================================
function h = ensureCakedSingleAvailable(h, value)

ds = h.dataset(value);

% Bereits geladen? Dann nichts tun.
if isfield(ds, 'cakedLoaded') && ds.cakedLoaded
    return
end

if isempty(ds.cbfPath)
    return
end

if ~isfield(h, 'dataDir') || isempty(h.dataDir)
    return
end

cacheDir = fullfile(h.dataDir, 'caked_cache');
if ~exist(cacheDir, 'dir'), mkdir(cacheDir); end

tag       = sprintf('%07d', ds.index);
cachePath = fullfile(cacheDir, sprintf('single_%s.mat', tag));

% ── Pro-Bild-Cache bereits vorhanden? ─────────────────────────────────
if isfile(cachePath)
    try
        result        = load(cachePath);
        h.dataset(value).caked = struct( ...
            'I',         result.I, ...
            'radial',    result.radial(:), ...
            'azimuthal', result.azimuthal(:));
        if isfield(result, 'caked_mask')
            h.dataset(value).caked.caked_mask     = result.caked_mask;
            h.dataset(value).caked.valid_fraction = result.valid_fraction;
        end
        h.dataset(value).cakedLoaded = true;
        fprintf('ensureCakedSingleAvailable: #%d aus Pro-Bild-Cache geladen.\n', ds.index);
        return
    catch ME
        warning('ensureCakedSingleAvailable: Cache-Fehler #%d: %s', ...
            ds.index, strrep(ME.message, '%', '%%'));
    end
end

% ── PONI-Datei für dieses Bild bestimmen ──────────────────────────────
poniFiles = dir(fullfile(h.dataDir, '*.poni'));
if isempty(poniFiles)
    warning('ensureCakedSingleAvailable: Keine PONI-Datei gefunden.');
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

alpha_i = NaN;
if isfield(ds, 'meta') && isstruct(ds.meta) && isfield(ds.meta, 'motorsChi_cor')
    val = ds.meta.motorsChi_cor;
    if isnumeric(val) && isscalar(val) && isfinite(val)
        alpha_i = abs(val);
    end
end
if ~isnan(alpha_i)
    alphaVals = [poniMap.alpha];
    validIdx  = find(~isnan(alphaVals));
    if ~isempty(validIdx)
        [~, bestK] = min(abs(alphaVals(validIdx) - alpha_i));
        poniPath   = poniMap(validIdx(bestK)).path;
    else
        poniPath = fallbackPoni;
    end
else
    poniPath = fallbackPoni;
end

% ── Wellenlänge ────────────────────────────────────────────────────────
lambda_m = 1.34143847484e-10;
if isstruct(ds.poni) && isfield(ds.poni,'wavelength') && ds.poni.wavelength > 0
    lambda_m = ds.poni.wavelength;
elseif isfield(h,'datasetLambda_m') && ~isempty(h.datasetLambda_m) && h.datasetLambda_m > 0
    lambda_m = h.datasetLambda_m;
end

% ── Script-Pfad ────────────────────────────────────────────────────────
scriptPath = '';
% 1. Aus GUI-Feld lesen (falls vorhanden)
if isfield(h, 'scriptPathEdit') && isvalid(h.scriptPathEdit)
    candidate = strtrim(get(h.scriptPathEdit, 'String'));
    if isfile(candidate), scriptPath = candidate; end
end
% 2. Neben der GUI/Exe suchen
if isempty(scriptPath)
    guiFile = which('XRD2DStressAnalysis_modPV_pyFAI');
    if ~isempty(guiFile)
        candidate = fullfile(fileparts(guiFile), 'pyfai_multigeom_run.py');
        if isfile(candidate), scriptPath = candidate; end
    end
end
% 3. Via General.ProgramInfo.Path
if isempty(scriptPath)
    try
        candidate = fullfile(General.ProgramInfo.Path, 'pyfai_multigeom_run.py');
        if isfile(candidate), scriptPath = candidate; end
    catch
    end
end
if isempty(scriptPath)
    warning('ensureCakedSingleAvailable: pyfai_multigeom_run.py nicht gefunden.');
    return
end

pythonExe = 'python';
if isfield(h, 'pythonExeEdit') && isvalid(h.pythonExeEdit)
    pythonExe = strtrim(get(h.pythonExeEdit, 'String'));
end

% ── Job für genau EIN Bild ─────────────────────────────────────────────
% job              = struct();
% job.img_paths    = {ds.cbfPath};
% job.poni_paths   = {poniPath};
% job.wavelength_m = lambda_m;
% job.mode         = '2d';
% job.unit         = '2th_deg';
% job.npt_rad      = 1500;
% job.npt_azim     = 360;
% job.polarization_factor = 0;
% job.correctSolidAngle   = false;   % NEU: testweise deaktiviert
% job.method       = 'no'; % csr
% job.error_model  = 'poisson';
% job.save_raw_stack  = false;
% job.save_ring_image = false;
% job.save_ring_det   = false;
% job.out_npz      = fullfile(cacheDir, sprintf('single_%s.npz', tag));
% job.out_mat      = cachePath;
% job.out_json     = fullfile(cacheDir, sprintf('single_%s_meta.json', tag));

job              = struct();
job.img_paths    = {ds.cbfPath};
job.poni_paths   = {poniPath};
job.wavelength_m = lambda_m;
job.mode         = '2d';
job.unit         = '2th_deg';
job.npt_rad      = 1500;
job.npt_azim     = 360;
job.polarization_factor = 0;
job.correctSolidAngle   = false;
job.method       = 'csr';
job.error_model  = 'poisson';
job.save_raw_stack  = false;
job.save_ring_image = false;
job.save_ring_det   = false;
job.out_npz      = fullfile(cacheDir, sprintf('single_%s.npz', tag));
job.out_mat      = cachePath;
job.out_json     = fullfile(cacheDir, sprintf('single_%s_meta.json', tag));

jobPath = fullfile(cacheDir, sprintf('single_%s_job.json', tag));
fid = fopen(jobPath, 'w');
fprintf(fid, '%s', jsonencode(job));
fclose(fid);

fprintf('ensureCakedSingleAvailable: Integriere Bild #%d ...\n', ds.index);
cmd = sprintf('"%s" "%s" "%s" 2>&1', pythonExe, scriptPath, jobPath);
[status, cmdout] = system(cmd);
if isfile(jobPath), delete(jobPath); end

fprintf('── Python-Ausgabe ──────────────────────────────\n%s\n──────────────────────────────────────────────\n', cmdout);

if status ~= 0
    warning('ensureCakedSingleAvailable: Integration #%d fehlgeschlagen:\n%s', ...
        ds.index, cmdout);
    return
end

if isfile(cachePath)
    try
        result = load(cachePath);
        h.dataset(value).caked = struct( ...
            'I',         result.I, ...
            'radial',    result.radial(:), ...
            'azimuthal', result.azimuthal(:));
        if isfield(result, 'caked_mask')
            h.dataset(value).caked.caked_mask     = result.caked_mask;
            h.dataset(value).caked.valid_fraction = result.valid_fraction;
        end
        h.dataset(value).cakedLoaded = true;
        fprintf('ensureCakedSingleAvailable: Bild #%d integriert und gecacht.\n', ds.index);
    catch ME
        warning('ensureCakedSingleAvailable: Laden fehlgeschlagen #%d: %s', ...
            ds.index, strrep(ME.message, '%', '%%'));
    end
end

end  % ensureCakedSingleAvailable