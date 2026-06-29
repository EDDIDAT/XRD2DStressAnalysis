function tsOpenFitBoundsDialog(hObj, ~)
h = guidata(hObj);

nPeaks = 1;
if isfield(h,'tsUserPeaks') && ~isempty(h.tsUserPeaks)
    nPeaks = numel(h.tsUserPeaks);
end

peakModel = 'symmetric';
if isfield(h,'tsPeakModel'), peakModel = h.tsPeakModel; end
useAsym = strcmp(peakModel, 'asymmetric');

fb_old = struct();
if isfield(h,'tsFitBounds') && ~isempty(h.tsFitBounds)
    fb_old = h.tsFitBounds;
end

% ── Tabelle aufbauen ─────────────────────────────────────────────────
tableData = {};
for pk = 1:nPeaks
    amp_min_pk  = getBound(fb_old, 'amp_min',  pk, 0);
    amp_max_pk  = getBound(fb_old, 'amp_max',  pk, Inf);
    pos_lb_pk   = getBound(fb_old, 'pos_lb',   pk, 1.0);
    pos_ub_pk   = getBound(fb_old, 'pos_ub',   pk, 1.0);
    fwhm_min_pk = getBound(fb_old, 'fwhm_min', pk, 0.1);
    fwhm_max_pk = getBound(fb_old, 'fwhm_max', pk, 1.5);

    tableData(end+1,:) = {pk, 'Amplitude', num2str(amp_min_pk), '<', 'Amplitude', '<', num2str(amp_max_pk,'%g')}; %#ok<AGROW>
    tableData(end+1,:) = {pk, 'Pos -', num2str(pos_lb_pk), ' ', '  Pos  ', ' ', num2str(pos_ub_pk)};
    if useAsym
        fwhm_min_r_pk = getBound(fb_old, 'fwhm_min_r', pk, 0.1);
        fwhm_max_r_pk = getBound(fb_old, 'fwhm_max_r', pk, 1.5);
        tableData(end+1,:) = {pk, 'FWHM_L', num2str(fwhm_min_pk),   '<', 'FWHM_L', '<', num2str(fwhm_max_pk)};
        tableData(end+1,:) = {pk, 'FWHM_R', num2str(fwhm_min_r_pk), '<', 'FWHM_R', '<', num2str(fwhm_max_r_pk)};
    else
        tableData(end+1,:) = {pk, 'FWHM',   num2str(fwhm_min_pk),   '<', 'FWHM',   '<', num2str(fwhm_max_pk)};
    end
    tableData(end+1,:) = {pk, 'Eta', '0', '≤', 'Eta', '≤', '1'};
end

nRows = size(tableData,1);
figH  = min(115 + nRows*28 + 65, 620);

fig = uifigure('Name', 'Fit-Grenzen', ...
    'Position',    [300 200 646 figH], ...
    'WindowStyle', 'modal', ...
    'Resize',      'off');

uilabel(fig, 'Text', 'Schranken', ...
    'FontSize', 12, 'FontWeight', 'bold', ...
    'Position', [12 figH-35 300 26]);

uilabel(fig, 'Text', 'Position: LB = pos - Wert(links), UB = pos + Wert(rechts). Eta ist fest (0–1).', ...
    'FontSize', 8, 'FontColor', [0.55 0.55 0.55], ...
    'Position', [12 figH-57 620 18]);

tblH = figH - 122;
tbl  = uitable(fig, ...
    'Data',           tableData, ...
    'ColumnName',     {'Nr.', 'Param.', 'Untere / -', ' ', 'Parameter', ' ', 'Obere / +'}, ...
    'ColumnEditable', [false false true false false false true], ...
    'ColumnWidth',    {35, 95, 115, 28, 105, 28, 115}, ...
    'Position',       [12 65 622 tblH], ...
    'RowName',        []);

uibutton(fig, 'Text', 'OK', ...
    'Position', [524 18 100 38], ...
    'ButtonPushedFcn', @okCb);

uibutton(fig, 'Text', 'Abbrechen', ...
    'Position', [414 18 100 38], ...
    'ButtonPushedFcn', @(~,~) close(fig));

uibutton(fig, 'Text', 'Zurücksetzen', ...
    'Position', [12 18 125 38], ...
    'ButtonPushedFcn', @resetCb);

uiwait(fig);

    function okCb(~,~)
        d = tbl.Data;
        nPP = 4 + useAsym;
        try
            fb.amp_min  = zeros(1,nPeaks);  fb.amp_max  = zeros(1,nPeaks);
            fb.pos_lb   = zeros(1,nPeaks);  fb.pos_ub   = zeros(1,nPeaks);
            fb.fwhm_min = zeros(1,nPeaks);  fb.fwhm_max = zeros(1,nPeaks);
            if useAsym
                fb.fwhm_min_r = zeros(1,nPeaks);
                fb.fwhm_max_r = zeros(1,nPeaks);
            end

            for pk = 1:nPeaks
                r0 = (pk-1)*nPP;
                fb.amp_min(pk)  = str2double(d{r0+1, 3});
                fb.amp_max(pk)  = str2double(d{r0+1, 7});
                fb.pos_lb(pk)   = str2double(d{r0+2, 3});
                fb.pos_ub(pk)   = str2double(d{r0+2, 7});
                fb.fwhm_min(pk) = str2double(d{r0+3, 3});
                fb.fwhm_max(pk) = str2double(d{r0+3, 7});
                if useAsym
                    fb.fwhm_min_r(pk) = str2double(d{r0+4, 3});
                    fb.fwhm_max_r(pk) = str2double(d{r0+4, 7});
                end
            end

            chk = [fb.amp_min fb.pos_lb fb.pos_ub fb.fwhm_min fb.fwhm_max];
            if any(isnan(chk))
                uialert(fig,'Ungültige Werte — Zahlen eingeben (Inf für unbegrenzt).','Fehler');
                return
            end
            if any(fb.fwhm_min >= fb.fwhm_max)
                uialert(fig,'FWHM Untergrenze muss kleiner als Obergrenze sein.','Fehler');
                return
            end

            h.tsFitBounds = fb;
            guidata(hObj, h);

            parts = arrayfun(@(pk) sprintf('P%d: FWHM[%.2f,%.2f] Pos[−%.2f,+%.2f]', ...
                pk, fb.fwhm_min(pk), fb.fwhm_max(pk), fb.pos_lb(pk), fb.pos_ub(pk)), ...
                1:nPeaks, 'UniformOutput', false);
            set(h.TSFitStatusText, 'String', strjoin(parts, '  '));
        catch ME
            uialert(fig, ME.message, 'Fehler'); return
        end
        close(fig);
    end

    function resetCb(~,~)
        defData = {};
        for pk2 = 1:nPeaks
            defData(end+1,:) = {pk2,'Amplitude',  '0',   '<','Amplitude', '<','Inf'};    %#ok<AGROW>
            defData(end+1,:) = {pk2,'Pos -',      '1.0', ' ','  Pos  ',   ' ','1.0'};
            if useAsym
                defData(end+1,:) = {pk2,'FWHM_L','0.1','<','FWHM_L','<','1.5'};
                defData(end+1,:) = {pk2,'FWHM_R','0.1','<','FWHM_R','<','1.5'};
            else
                defData(end+1,:) = {pk2,'FWHM',  '0.1','<','FWHM',  '<','1.5'};
            end
            defData(end+1,:) = {pk2,'Eta','0','≤','Eta','≤','1'};
        end
        tbl.Data = defData;
    end
end
