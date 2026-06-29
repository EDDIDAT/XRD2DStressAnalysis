function dataset = loadDataset(dataDir, pythonExe)

if nargin < 2 || isempty(pythonExe)
    pythonExe = 'python';
end

% ── 1. log_all.txt einlesen ──────────────────────────────────────────
logAllPath = fullfile(dataDir, 'log_all.txt');
if ~isfile(logAllPath)
    error('loadDataset: log_all.txt nicht gefunden in:\n  %s', dataDir);
end
meta = readLogAll(logAllPath);
N    = numel(meta);

wb = waitbar(0, 'Lade Messungen ...', 'Name', 'Dataset laden');

% ── 2. Alle Messungen durchlaufen (unverändert) ───────────────────────
dataset(N) = struct();
for i = 1:N
    if mod(i, 5) == 0 || i == N
        waitbar(i / N, wb, sprintf('Messung %d / %d laden ...', i, N));
    end
    idx = meta(i).measurement;
    tag = sprintf('%07d', idx);

    dataset(i).index    = idx;
    dataset(i).datetime = meta(i).datetime;
    dataset(i).meta     = meta(i);

    % 1D-Daten (.dat)
    datPath = fullfile(dataDir, ['image_' tag '_integrated.dat']);
    if isfile(datPath)
        try
            [dataset(i).q, dataset(i).I, dataset(i).poni] = loadDAT(datPath);
        catch ME
            warning('loadDataset: DAT-Fehler #%d: %s', idx, strrep(ME.message, '%', '%%'));
            dataset(i).q    = [];
            dataset(i).I    = [];
            dataset(i).poni = struct();
        end
    else
        dataset(i).q    = [];
        dataset(i).I    = [];
        dataset(i).poni = struct();
    end

    % CBF-Pfad (lazy)
    cbfPath = fullfile(dataDir, ['image_' tag '.cbf']);
    if isfile(cbfPath)
        dataset(i).cbfPath = cbfPath;
    else
        dataset(i).cbfPath = '';
    end
    dataset(i).img       = [];
    dataset(i).imgLoaded = false;

    % Gecaktes 2D-Bild — wird später per Batch befüllt
    dataset(i).caked       = struct('I',[],'radial',[],'azimuthal',[]);
    dataset(i).cakedLoaded = false;

    % Log-File
    logPath = fullfile(dataDir, ['log_' tag '.txt']);
    if isfile(logPath)
        try
            dataset(i).log = readLogSingle(logPath);
        catch ME
            warning('loadDataset: Log-Fehler #%d: %s', idx, strrep(ME.message, '%', '%%'));
            dataset(i).log = struct();
        end
    else
        dataset(i).log = struct();
    end
end

% ── 3. Relative Zeit ──────────────────────────────────────────────────
t0 = dataset(1).datetime;
for i = 1:N
    dataset(i).time_s = seconds(dataset(i).datetime - t0);
end

% ── 4. PONI suchen und 2D-Batch-Integration starten ──────────────────
waitbar(1, wb, 'pyFAI-Integration läuft ...');
dataset = tryAutoCake(dataset, dataDir, pythonExe, wb);

if isvalid(wb), close(wb); end

end  % loadDataset

% =========================================================================
%  tryAutoCake — sucht PONI im Ordner und integriert alle CBF als 2D-Batch
% =========================================================================
function dataset = tryAutoCake(dataset, dataDir, pythonExe, wb)

% ── PONI-Dateien im Ordner suchen ─────────────────────────────────────
poniFiles = dir(fullfile(dataDir, '*.poni'));
if isempty(poniFiles)
    fprintf('tryAutoCake: Keine PONI-Datei gefunden — Caked Images nicht verfügbar.\n');
    return
end

% ── PONI-Dateien parsen und Alpha-Winkel extrahieren ──────────────────
[~, sortIdx] = sort({poniFiles.name});
poniMap      = struct('alpha', {}, 'path', {});
for k = 1:numel(poniFiles)
    fname = poniFiles(sortIdx(k)).name;
    tok   = regexp(fname, '(?<=alpha)([\d.+-]+)', 'match');
    if ~isempty(tok)
        poniMap(k).alpha = str2double(tok{1});
        poniMap(k).path  = fullfile(dataDir, fname);
        fprintf('tryAutoCake: PONI "%s" → α=%.1f°\n', fname, poniMap(k).alpha);
    else
        poniMap(k).alpha = NaN;
        poniMap(k).path  = fullfile(dataDir, fname);
        fprintf('tryAutoCake: PONI "%s" → kein Alpha gefunden (Fallback)\n', fname);
    end
end

% Fallback-PONI: erste ohne Alpha-Angabe, sonst erste insgesamt
fallbackPoni = poniMap(1).path;
for k = 1:numel(poniMap)
    if isnan(poniMap(k).alpha)
        fallbackPoni = poniMap(k).path;
        break
    end
end

% ── Cache-Pfade definieren ────────────────────────────────────────────
cacheDir    = fullfile(dataDir, 'caked_cache');
cachePath   = fullfile(cacheDir, 'caked_batch.mat');
cache1dPath = fullfile(cacheDir, 'profiles_1d_std.mat');

% ── 2D-Cache prüfen ───────────────────────────────────────────────────
if isfile(cachePath)
    fprintf('tryAutoCake: Gecakter Cache gefunden, lade ...\n');
    try
        result  = load(cachePath);
        dataset = fillCakedFromResult(dataset, result);
        fprintf('tryAutoCake: %d gecakte Bilder geladen.\n', sum([dataset.cakedLoaded]));
    catch ME
        warning('tryAutoCake: Cache-Fehler, neu integrieren: %s', strrep(ME.message, '%', '%%'));
    end
end

% ── 1D-Cache prüfen ───────────────────────────────────────────────────
if isfile(cache1dPath)
    fprintf('tryAutoCake: 1D-Cache gefunden, lade ...\n');
    try
        res1d      = load(cache1dPath);
        q_vec      = double(res1d.radial(:));
        I_stack_1d = double(res1d.I);

        if ndims(I_stack_1d) ~= 2
            warning('tryAutoCake: 1D-Cache enthält keine 2D-Matrix — übersprungen.');
            delete(cache1dPath);
        else
            qMin = min(q_vec);
            qMax = max(q_vec);
            fprintf('tryAutoCake: 1D-Cache radial: %.4f – %.4f nm^-1  (%.4f – %.4f Å^-1)\n', ...
                qMin, qMax, qMin/10, qMax/10);

            if qMax > 200 || qMax < 0.1
                warning('tryAutoCake: 1D-Cache radial-Werte unplausibel (%.2f–%.2f) — Cache wird neu erzeugt.', ...
                    qMin, qMax);
                delete(cache1dPath);
            else
                cbfPaths_tmp = {dataset.cbfPath};
                hasCBF_tmp   = ~cellfun(@isempty, cbfPaths_tmp);
                cbfIdx_tmp   = find(hasCBF_tmp);
                for ii = 1:min(size(I_stack_1d,1), numel(cbfIdx_tmp))
                    ds_i            = cbfIdx_tmp(ii);
                    dataset(ds_i).q = q_vec;
                    dataset(ds_i).I = I_stack_1d(ii,:)';
                end
                fprintf('tryAutoCake: %d berechnete 1D-Profile geladen (Priorität über .dat-Dateien).\n', ...
                    numel(cbfIdx_tmp));
            end
        end
    catch ME
        warning('tryAutoCake: 1D-Cache Fehler: %s', strrep(ME.message, '%', '%%'));
    end
end

% ── Wenn beide Caches vorhanden: fertig ──────────────────────────────
if isfile(cachePath) && isfile(cache1dPath)
    return
end

% ── CBF-Pfade sammeln ─────────────────────────────────────────────────
cbfPaths = {dataset.cbfPath};
hasCBF   = ~cellfun(@isempty, cbfPaths);
if ~any(hasCBF)
    fprintf('tryAutoCake: Keine CBF-Dateien vorhanden.\n');
    return
end

% ── Wellenlänge aus erstem gültigen poni-Struct lesen ─────────────────
lambda_m = 1.34143847484e-10;   % Ga K-alpha Fallback
for i = 1:numel(dataset)
    p = dataset(i).poni;
    if isstruct(p) && isfield(p,'wavelength') && p.wavelength > 0
        lambda_m = p.wavelength;
        break
    end
end

% ── Script-Pfad ermitteln ─────────────────────────────────────────────
guiFile    = which('XRD2DStressAnalysis_modPV_pyFAI');
scriptPath = '';
if ~isempty(guiFile)
    candidate = fullfile(fileparts(guiFile), 'pyfai_multigeom_run.py');
    if isfile(candidate), scriptPath = candidate; end
end
if isempty(scriptPath)
    candidate = fullfile(dataDir, 'pyfai_multigeom_run.py');
    if isfile(candidate), scriptPath = candidate; end
end
if isempty(scriptPath)
    candidate = fullfile(pwd, 'pyfai_multigeom_run.py');
    if isfile(candidate), scriptPath = candidate; end
end
if isempty(scriptPath)
    warning('tryAutoCake: pyfai_multigeom_run.py nicht gefunden.');
    return
end
fprintf('tryAutoCake: Script gefunden: %s\n', scriptPath);

% Cache-Ordner anlegen
if ~exist(cacheDir, 'dir'), mkdir(cacheDir); end

% ── Alpha-Winkel pro Messung aus meta.motorsChi_cor lesen ─────────────
poniPaths_all = cell(numel(dataset), 1);
fprintf('\ntryAutoCake: Ordne PONI-Dateien zu ...\n');
for i = 1:numel(dataset)
    alpha_i = NaN;
    if isfield(dataset(i), 'meta') && isstruct(dataset(i).meta) && ...
       isfield(dataset(i).meta, 'motorsChi_cor')
        val = dataset(i).meta.motorsChi_cor;
        if isnumeric(val) && isscalar(val) && isfinite(val)
            alpha_i = abs(val);
        end
    end

    if ~isnan(alpha_i)
        alphaVals = [poniMap.alpha];
        validIdx  = find(~isnan(alphaVals));
        if ~isempty(validIdx)
            [minDiff, bestK] = min(abs(alphaVals(validIdx) - alpha_i));
            poniPaths_all{i} = poniMap(validIdx(bestK)).path;
            if minDiff > 1.0
                fprintf('  Warnung: Messung #%d α=%.1f° → nächste PONI α=%.1f° (Δ=%.1f°)\n', ...
                    dataset(i).index, alpha_i, alphaVals(validIdx(bestK)), minDiff);
            end
        else
            poniPaths_all{i} = fallbackPoni;
        end
    else
        poniPaths_all{i} = fallbackPoni;
        fprintf('  Warnung: Messung #%d kein Alpha gefunden → Fallback\n', dataset(i).index);
    end
end

% PONI-Zuordnung zusammenfassen
[uniquePoni, ~, ic] = unique(poniPaths_all);
fprintf('\ntryAutoCake: PONI-Zuordnung (%d Messungen):\n', numel(dataset));
for up = 1:numel(uniquePoni)
    [~, poniShort] = fileparts(uniquePoni{up});
    fprintf('  %s → %d Messungen\n', poniShort, sum(ic == up));
end
fprintf('\n');

% ── 2D-Cache: wird lazy bei Bedarf erzeugt ────────────────────────────
if ~isfile(cachePath)
    fprintf('tryAutoCake: Kein 2D-Cache vorhanden — wird bei Bedarf (Caked-Modus) erzeugt.\n');
end

% ── 1D-Batch-Integration falls Cache fehlt ────────────────────────────
if ~isfile(cache1dPath)
    missingIdx = find(hasCBF);

    if ~isempty(missingIdx)
        fprintf('tryAutoCake: %d fehlende 1D-Profile werden erzeugt ...\n', numel(missingIdx));

        validCBF_1d  = cbfPaths(missingIdx);
        validPONI_1d = poniPaths_all(missingIdx);
        N_1d         = numel(validCBF_1d);

        % ── Azimutbereich aus gecakten Daten lesen (falls vorhanden) ──
        az_range = [];
        cakedLoaded_idx = find([dataset.cakedLoaded]);
        if ~isempty(cakedLoaded_idx)
            az       = dataset(cakedLoaded_idx(1)).caked.azimuthal;
            az_range = [min(az), max(az)];
            fprintf('tryAutoCake: Azimutbereich aus Caked-Daten: [%.1f°, %.1f°]\n', ...
                az_range(1), az_range(2));
        else
            fprintf('tryAutoCake: Kein Azimutbereich verfügbar — integriere über vollen Detektor.\n');
        end

        % ── 1D-Jobs in Batches ────────────────────────────────────────
        BATCH_SIZE = 20;
        nBatches   = ceil(N_1d / BATCH_SIZE);
        q_vec_all  = [];
        I_all      = [];

        for bIdx = 1:nBatches
            iStart = (bIdx-1) * BATCH_SIZE + 1;
            iEnd   = min(bIdx * BATCH_SIZE, N_1d);
            batchRange = iStart:iEnd;

            if nargin >= 4 && isvalid(wb)
                waitbar(bIdx / nBatches * 0.8, wb, ...
                    sprintf('pyFAI 1D-Integration: Batch %d/%d (%d-%d von %d) ...', ...
                    bIdx, nBatches, iStart, iEnd, N_1d));
            end
            fprintf('tryAutoCake: Batch %d/%d (Bilder %d-%d) ...\n', bIdx, nBatches, iStart, iEnd);

            try
                batchMatPath = fullfile(cacheDir, sprintf('batch_%03d.mat', bIdx));

                job1d              = struct();
                job1d.img_paths    = validCBF_1d(batchRange);
                job1d.poni_paths   = validPONI_1d(batchRange);
                job1d.wavelength_m = lambda_m;
                job1d.mode         = '1d_batch_standard';
                job1d.correctSolidAngle    = true;
                job1d.polarization_factor  = 0;
                job1d.npt_rad      = 1000;
                if ~isempty(az_range)
                    job1d.azimuth_range = az_range;
                end
                job1d.out_npz  = fullfile(cacheDir, sprintf('batch_%03d.npz', bIdx));
                job1d.out_mat  = batchMatPath;
                job1d.out_json = fullfile(cacheDir, sprintf('batch_%03d_meta.json', bIdx));

                jobPath1d = fullfile(cacheDir, sprintf('batch_%03d_job.json', bIdx));
                fid = fopen(jobPath1d, 'w');
                fprintf(fid, '%s', char(jsonencode(job1d)));
                fclose(fid);

                cmd1d = sprintf('"%s" "%s" "%s" 2>&1', pythonExe, scriptPath, jobPath1d);
                [status1d, cmdout1d] = system(cmd1d);
                if isfile(jobPath1d), delete(jobPath1d); end

                if status1d ~= 0
                    fprintf('tryAutoCake: Batch %d Fehler:\n%s\n', bIdx, cmdout1d);
                    warning('tryAutoCake: Batch %d fehlgeschlagen.', bIdx);
                    continue
                end

                if isfile(batchMatPath)
                    res1d   = load(batchMatPath);
                    q_vec   = double(res1d.radial(:));
                    I_batch = double(res1d.I);

                    if isempty(q_vec_all)
                        q_vec_all = q_vec;
                    end
                    I_all = [I_all; I_batch]; %#ok<AGROW>

                    for ii = 1:size(I_batch, 1)
                        ds_i            = missingIdx(iStart + ii - 1);
                        dataset(ds_i).q = q_vec;
                        dataset(ds_i).I = I_batch(ii,:)';
                    end
                    fprintf('tryAutoCake: Batch %d — %d Profile geladen.\n', bIdx, size(I_batch, 1));
                    delete(batchMatPath);
                end

                % Temporaere Variablen freigeben
                clear res1d I_batch;

            catch ME
                warning('tryAutoCake: Batch %d Fehler: %s', ...
                    bIdx, strrep(ME.message, '%', '%%'));
                continue
            end
        end

        % Gesamtcache speichern
        if ~isempty(q_vec_all) && ~isempty(I_all)
            radial = q_vec_all; I = I_all; %#ok<NASGU>
            save(cache1dPath, 'radial', 'I', '-v7.3');
            fprintf('tryAutoCake: Gesamt-Cache gespeichert (%d Profile).\n', size(I_all, 1));
            if nargin >= 4 && isvalid(wb)
                waitbar(0.9, wb, 'Profile geladen.');
            end
        end
    else
        fprintf('tryAutoCake: Alle 1D-Profile bereits vorhanden.\n');
    end

    % ── PONI-Parameter ausgeben ────────────────────────────────────────
    fprintf('\n── PONI-Datei Parameter ─────────────────────────────────\n');
    for k = 1:numel(poniMap)
        [~, poniName] = fileparts(poniMap(k).path);
        fprintf('\n  %s  (α=%.1f°)\n', poniName, poniMap(k).alpha);
        fprintf('  %s\n', repmat('-', 1, 50));
        fid = fopen(poniMap(k).path, 'r');
        if fid == -1
            fprintf('  Datei nicht lesbar.\n');
            continue
        end
        while ~feof(fid)
            line = strtrim(fgetl(fid));
            if ~ischar(line) || isempty(line) || line(1) == '#', continue; end
            colonIdx = strfind(line, ':');
            if isempty(colonIdx), continue; end
            key = strtrim(line(1:colonIdx(1)-1));
            val = strtrim(line(colonIdx(1)+1:end));
            num = str2double(val);
            if isfinite(num)
                switch key
                    case 'Wavelength'
                        fprintf('  %-25s = %.6e m  (%.4f Å)\n', key, num, num*1e10);
                    case 'Dist'
                        fprintf('  %-25s = %.6f m  (%.2f mm)\n', key, num, num*1000);
                    case {'Poni1','Poni2'}
                        fprintf('  %-25s = %.6f m  (%.4f mm)\n', key, num, num*1000);
                    case {'Rot1','Rot2','Rot3'}
                        fprintf('  %-25s = %.6f rad  (%.4f°)\n', key, num, rad2deg(num));
                    otherwise
                        fprintf('  %-25s = %s\n', key, val);
                end
            else
                fprintf('  %-25s = %s\n', key, val);
            end
        end
        fclose(fid);
    end
    fprintf('\n────────────────────────────────────────────────────────\n\n');
end

end  % tryAutoCake


% =========================================================================
%  fillCakedFromResult — verteilt I_stack auf dataset(i).caked
% =========================================================================
function dataset = fillCakedFromResult(dataset, result)

I_stack = double(result.I);          % [N x npt_azim x npt_rad]
N_cbf   = size(I_stack, 1);

% radial/azimuthal: entweder [N x npt] (pro Bild) oder [1 x npt] (gemeinsam)
radialAll = double(result.radial);
azimAll   = double(result.azimuthal);

hasPerImageAxes = size(radialAll, 1) == N_cbf;

cbfIdx = find(~cellfun(@isempty, {dataset.cbfPath}));

for ii = 1:min(N_cbf, numel(cbfIdx))
    ds_i = cbfIdx(ii);

    if hasPerImageAxes
        radial_i = radialAll(ii, :)';   % eigene Achse pro Bild
        azim_i   = azimAll(ii, :)';
    else
        radial_i = radialAll(:);        % gemeinsame Achse
        azim_i   = azimAll(:);
    end

    dataset(ds_i).caked = struct( ...
        'I',         squeeze(I_stack(ii,:,:)), ...
        'radial',    radial_i, ...
        'azimuthal', azim_i);
    dataset(ds_i).cakedLoaded = true;
end

end  % fillCakedFromResult