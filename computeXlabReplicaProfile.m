function result = computeXlabReplicaProfile(ds, h, npt_xlab, maskB)
% Berechnet ein 1D-Profil, das xlab's AzimuthalIntegrator.integrate1d-Aufruf
% exakt nachbildet (kein dummy, keine Detektor-Maske, negative Pixel fließen
% direkt in die Mittelung ein, Ergebnis wird danach auf 0 geclippt).
%
% ds:        ein Element aus h.dataset (mit ds.cbfPath)
% h:         GUI-Handle-Struct (für pythonExe, scriptPath, dataDir)
% npt_xlab:  Anzahl radialer Punkte (Default 1000, wie xlab)
% maskB:     optional, Pixel-Zeile ab der maskiert wird (leer = keine Maske)

if nargin < 3 || isempty(npt_xlab), npt_xlab = 1000; end
if nargin < 4, maskB = []; end

poniFiles = dir(fullfile(h.dataDir, '*.poni'));
poniPath  = fullfile(h.dataDir, poniFiles(1).name);

pythonExe  = strtrim(get(h.pythonExeEdit, 'String'));
guiFile    = which('XRD2DStressAnalysis_modPV_pyFAI');
scriptPath = fullfile(fileparts(guiFile), 'pyfai_multigeom_run.py');
cacheDir   = fullfile(h.dataDir, 'caked_cache');
if ~exist(cacheDir, 'dir'), mkdir(cacheDir); end

tag = sprintf('%07d_xlab', ds.index);

job              = struct();
job.img_paths    = {ds.cbfPath};
job.poni_paths   = {poniPath};
job.wavelength_m = h.datasetLambda_m;
job.mode         = '1d_xlab';
job.npt_xlab     = npt_xlab;
if ~isempty(maskB)
    job.maskB = maskB;
end
job.out_npz  = fullfile(cacheDir, sprintf('single_%s.npz', tag));
job.out_mat  = fullfile(cacheDir, sprintf('single_%s.mat', tag));
job.out_json = fullfile(cacheDir, sprintf('single_%s_meta.json', tag));

jobPath = fullfile(cacheDir, sprintf('single_%s_job.json', tag));
fid = fopen(jobPath, 'w');
fprintf(fid, '%s', jsonencode(job));
fclose(fid);

cmd = sprintf('"%s" "%s" "%s" 2>&1', pythonExe, scriptPath, jobPath);
[status, cmdout] = system(cmd);
if isfile(jobPath), delete(jobPath); end

if status ~= 0
    error('computeXlabReplicaProfile: Integration fehlgeschlagen:\n%s', cmdout);
end

result = load(job.out_mat);
end