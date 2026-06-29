function r = resolveProgramRoot()
persistent cachedPath
if isempty(cachedPath)
    if isdeployed
        % Strategie 1: Umgebungsvariable (von MATLAB Compiler gesetzt)
        % In neueren MATLAB-Versionen zeigt dies auf das exe-Verzeichnis
        candidates = {};

        % Strategie 2: wmic (klassisch, funktioniert auf Win 10)
        try
            [~, exeInfo] = system(['wmic process where processid="' ...
                num2str(feature('getpid')) ...
                '" get ExecutablePath /format:value']);
            exePath = strtrim(regexprep(exeInfo, '[\r\n]*ExecutablePath=', ''));
            exePath = strtrim(exePath);
            if ~isempty(exePath) && exist(exePath, 'file')
                candidates{end+1} = [fileparts(exePath) filesep];
            end
        catch
        end

        % Strategie 3: PowerShell (robuster als wmic auf Windows 11)
        if isempty(candidates)
            try
                [~, psOut] = system(['powershell -NoProfile -Command ' ...
                    '"(Get-Process -Id ' num2str(feature('getpid')) ...
                    ').Path"']);
                psOut = strtrim(psOut);
                if ~isempty(psOut) && exist(psOut, 'file')
                    candidates{end+1} = [fileparts(psOut) filesep];
                end
            catch
            end
        end

        % Strategie 4: ctfroot (zeigt auf CTF-Extrakt, dort liegen
        % eingebettete Dateien, aber NICHT die neben der exe)
        try
            candidates{end+1} = [ctfroot filesep];
        catch
        end

        % Strategie 5: pwd als letzter Fallback
        candidates{end+1} = [pwd filesep];

        % Ersten Kandidaten waehlen, bei dem Data/Materials/ existiert
        cachedPath = candidates{end};  % Default: letzter
        for ci = 1:numel(candidates)
            if isfolder(fullfile(candidates{ci}, 'Data', 'Materials'))
                cachedPath = candidates{ci};
                break;
            end
        end
    else
        % Unkompiliert: diese Datei liegt in Classes/+General/
        cachedPath = [fileparts(fileparts(fileparts( ...
            mfilename('fullpath')))) filesep];
    end
end
r = cachedPath;
end
