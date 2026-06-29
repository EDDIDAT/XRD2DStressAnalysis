% =========================================================
% Hilfsfunktion: Job ausführen und Ergebnis laden
% =========================================================
function result = runJob(job, cacheDir, pythonExe, scriptPath)
    jobPath = fullfile(cacheDir, 'tmp_job.json');
    fid = fopen(jobPath, 'w'); fprintf(fid, '%s', jsonencode(job)); fclose(fid);
    [~, cmdout] = system(sprintf('"%s" "%s" "%s" 2>&1', pythonExe, scriptPath, jobPath));
    fprintf('%s\n', strtrim(cmdout));
    result = load(job.out_mat);
end