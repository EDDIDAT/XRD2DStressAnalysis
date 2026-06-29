% function fitOut = fitGaussiansFromPeakResults(x, Y, peakResults, fitWindow)
% % FITGAUSSIANSFROMPEAKRESULTS
% %   Führt für jeden gefundenen Peak (peakResults) einen Gaussian-Fit durch.
% %   Gibt Fitparameter + deren Fehler zurück.
% %
% % INPUT:
% %   x            - x-Achse
% %   Y            - Spektrenmatrix (N x M)
% %   peakResults  - Struktur aus findPeaksFromStartValues(...)
% %   fitWindow    - Halbbreite des Fitbereichs um Peakmaximum
% %
% % OUTPUT:
% %   fitOut(c,p).params = [A, mu, sigma, offset]
% %   fitOut(c,p).errors = [dA, dmu, dsigma, doffset]
% %   fitOut(c,p).success = true/false
% 
%     x = x(:);
%     [nSamples, nCols] = size(Y);
% 
%     [nCols_PR, nPeaks] = size(peakResults);
%     if nCols_PR ~= nCols
%         error('peakResults und Y müssen gleich viele Spalten haben.');
%     end
% 
%     % Struktur initialisieren
%     empty = struct('params', [], 'errors', [], 'peakX', [], 'success', false);
%     fitOut = repmat(empty, nCols, nPeaks);
% 
%     % Gaussian Modell
%     gaussFun = @(b, x) ...
%         b(1) .* exp(-(x - b(2)).^2 ./ (2*b(3).^2)) + b(4);
%     % b = [A, mu, sigma, offset]
% 
%     for c = 1:nCols
%         y = Y(:,c);
% 
%         for p = 1:nPeaks
% 
%             idxPeak = peakResults(c,p).index;
%             if isnan(idxPeak)
%                 continue;
%             end
%             mu_est = x(idxPeak);
% 
%             % Peaklage prüfen
%             if isnan(mu_est) || mu_est < min(x) || mu_est > max(x)
%                 continue;
%             end
% 
%             % --- Fitbereich ---
%             leftBoundary  = mu_est - fitWindow;
%             rightBoundary = mu_est + fitWindow;
% 
%             % Maske erzeugen – ABGESICHERT!
%             mask = (x >= leftBoundary) & (x <= rightBoundary);
% 
%             % Sicherstellen, dass mask immer gleiche Länge wie x hat
%             mask = mask(:);                 % garantiert Spaltenvektor
%             mask = mask(1:length(x));       % falls mask zu lang ist
%             mask(length(x)+1:end) = [];     % redundanter Schutz
% 
%             % Falls Keine Punkte im Fenster
%             if sum(mask) < 5
%                 continue;
%             end
% 
%             xFit = x(mask);
%             yFit = y(mask);
% 
%             if numel(xFit) < 5
%                 continue;   % Zu wenige Punkte
%             end
% 
%             % -------------------------------
%             % Startparameter schätzen
%             % -------------------------------
%             [ymax, idxLocal] = max(yFit);
%             mu0 = xFit(idxLocal);
%             A0 = ymax - median(yFit);
%             sigma0 = fitWindow/4;
%             offset0 = median(yFit);
% 
%             beta0 = [A0, mu0, sigma0, offset0];
% 
%             % -------------------------------
%             % Fit-Optionen
%             % -------------------------------
%             opts = optimoptions('lsqcurvefit',...
%                 'Display','off',...
%                 'MaxIterations',300,...
%                 'FiniteDifferenceType','central');
% 
%             lb = [0, mu0 - fitWindow, 0, -Inf];
%             ub = [Inf, mu0 + fitWindow, fitWindow, Inf];
% 
%             try
%                 % -------------------------------
%                 % Fitting
%                 % -------------------------------
%                 [beta,resnorm,~,~,~,~,J] = lsqcurvefit(gaussFun, beta0, xFit, yFit, lb, ub, opts);
% 
%                 % -------------------------------
%                 % Kovarianzmatrix -> Fehler
%                 % -------------------------------
%                 covB = inv(J'*J) * (resnorm/(length(yFit)-length(beta0)));
%                 errBeta = sqrt(diag(covB));
% 
%                 fitOut(c,p).params  = beta;
%                 fitOut(c,p).errors  = errBeta;
%                 fitOut(c,p).peakX   = mu_est;
%                 fitOut(c,p).success = true;
% 
%             catch
%                 % Fit fehlgeschlagen
%                 fitOut(c,p).params  = [NaN NaN NaN NaN];
%                 fitOut(c,p).errors  = [NaN NaN NaN NaN];
%                 fitOut(c,p).peakX   = mu_est;
%                 fitOut(c,p).success = false;
%             end
%         end
%     end
% end

function fitOut = fitGaussiansFromPeakResults(x, Y, peakResults, fitWindow)
% FITGAUSSIANSFROMPEAKRESULTS
%   Führt für jeden Peak einen Gaussian-Fit durch.
%   Garantiert funktionierende Fitfenster.
%   Gibt Fitparameter + deren Fehler zurück.

    x = x(:);
    [nSamples, nCols] = size(Y);

    [nCols_PR, nPeaks] = size(peakResults);
    if nCols_PR ~= nCols
        error('peakResults und Y müssen gleich viele Spalten haben.');
    end

    % Struktur initialisieren
    empty = struct('params', [], 'errors', [], 'peakX', [], 'success', false);
    fitOut = repmat(empty, nCols, nPeaks);

    % Gaussian Modell
    gaussFun = @(b, x) b(1).*exp(-(x - b(2)).^2 ./ (2*b(3).^2)) + b(4);

    % --- Falls fitWindow ein einziger Skalar ist, übernehmen wir ihn für alle Peaks
    if isscalar(fitWindow)
        fitWindow = repmat(fitWindow, nCols, nPeaks);
    end

    for c = 1:nCols
        y = Y(:,c);

        for p = 1:nPeaks

            idxPeak = peakResults(c,p).index;
            if isnan(idxPeak)
                continue;
            end

            mu_est = x(idxPeak);

            % --- Fitfenster extrahieren und absichern ---
            if isempty(fitWindow)
                fw = (max(x) - min(x)) / 20;   % fallback
            else
                fw = fitWindow(c,p);
            end

            % Falls fitWindow ein Vektor ist → nur erstes Element benutzen
            if ~isscalar(fw)
                fw = fw(1);
            end

            % Falls Fenster ungültig → fallback
            if isempty(fw) || isnan(fw) || fw <= 0
                fw = (max(x) - min(x)) / 20;
            end

            % --- Fitbereich ---
            leftBoundary  = mu_est - fw;
            rightBoundary = mu_est + fw;

            % --- Maske sicher erzeugen ---
            mask = (x >= leftBoundary) & (x <= rightBoundary);

            % Falls zu wenig Punkte
            if sum(mask) < 5
                continue;
            end

            xFit = x(mask);
            yFit = y(mask);

            if numel(xFit) < 5
                continue;
            end

            % --- Startwerte ---
            [ymax, idxLocal] = max(yFit);
            mu0 = xFit(idxLocal);
            A0 = ymax - median(yFit);
            sigma0 = fw/4;
            offset0 = median(yFit);

            beta0 = [A0, mu0, sigma0, offset0];

            opts = optimoptions('lsqcurvefit',...
                'Display','off','MaxIterations',300,...
                'FiniteDifferenceType','central');

            lb = [0, mu0 - fw, 0, -Inf];
            ub = [Inf, mu0 + fw, fw, Inf];

            try
                [beta,resnorm,~,~,~,~,J] = lsqcurvefit(gaussFun, beta0, xFit, yFit, lb, ub, opts);

                % Kovarianzmatrix & Fehler
                covB = inv(J'*J) * (resnorm/(length(yFit)-length(beta0)));
                errBeta = sqrt(diag(covB));

                fitOut(c,p).params  = beta;
                fitOut(c,p).errors  = errBeta;
                fitOut(c,p).peakX   = mu_est;
                fitOut(c,p).success = true;

            catch
                fitOut(c,p).params  = [NaN NaN NaN NaN];
                fitOut(c,p).errors  = [NaN NaN NaN NaN];
                fitOut(c,p).peakX   = mu_est;
                fitOut(c,p).success = false;
            end
        end
    end
end
