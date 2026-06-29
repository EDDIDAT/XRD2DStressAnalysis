function result = calcStress(data, DEK, my, spannkomp)
% CALCSTRESS Berechnet Dehnungen, Spannungsfaktoren und Spannungen
%
% EINGABE:
%   data       - Fitdaten [gamma, 2theta, 2theta_err, amp, width, alpha, ...]
%   DEK        - Zeile der DEK-Matrix für diesen Peak [h k l E S1 S2 alpha]
%   my         - Absorptionskoeffizient
%   spannkomp  - Spannungskomponenten (11, 1122, 112213, 112223, 11221323)
%
% AUSGABE:
%   result     - Struktur mit allen Ergebnissen

% --- Grundgrößen ---
alpha  = data(1,7);
theta0 = sum(data(:,2)) / (2*length(data(:,2)));

% Debug:
fprintf('calcStress: %d Datenpunkte, theta0=%.4f°\n', size(data,1), theta0);
fprintf('  data(:,2) range: %.4f° .. %.4f°\n', min(data(:,2)), max(data(:,2)));
fprintf('  data(:,3) range: %.6f .. %.6f\n',   min(data(:,3)), max(data(:,3)));
fprintf('  sind(theta0)=%.6f\n', sind(theta0));

eps_vals = log(sind(theta0) ./ sind(data(:,2)./2));
fprintf('  eps_vals: %d finite, %d NaN\n', sum(isfinite(eps_vals)), sum(~isfinite(eps_vals)));

% --- Dehnung epsilon(gamma) ---
eps_vals = log(sind(theta0) ./ sind(data(:,2)./2));
eps_err  = cotd(data(:,2)./2) .* (data(:,3)./57.3);

result.epsfitdata = [data(:,1), eps_vals, eps_err];

% --- psi ---
psi = zeros(length(data(:,1)), 1);
for l = 1:length(data(:,1))
    val = sind(alpha)*sind(theta0) + cosd(alpha)*cosd(theta0)*cosd(data(l,1));
    val = max(-1, min(1, val));   % Clamp für acosd
    if data(l,1) < 0
        psi(l) = -acosd(val);
    else
        psi(l) =  acosd(val);
    end
end
result.psi = psi;

% --- phi ---
phi = zeros(length(data(:,1)), 1);
for l = 1:length(data(:,1))
    if abs(sind(psi(l))) < 1e-10
        phi(l) = 0;
        continue
    end
    val = (cosd(theta0)*sind(data(l,1))) ./ sind(psi(l));
    val = max(-1, min(1, val));   % Clamp für acosd
    if data(l,1) < 0
        phi(l) = acosd(val) - 180;
    else
        phi(l) = -acosd(val);
    end
end
result.phi = phi;

% --- Informationstiefe tau ---
denom = sind(alpha) + (sind(2*theta0) .* cosd(alpha) .* cosd(data(:,1)) ...
        - cosd(2*theta0) .* sind(alpha));
denom(abs(denom) < 1e-10) = 1e-10;   % Division durch null verhindern

result.tau = (1./my) .* ( ...
    (sind(alpha) .* (sind(2*theta0) .* cosd(alpha) .* cosd(data(:,1)) ...
    - cosd(2*theta0) .* sind(alpha))) ./ denom ...
);

% --- Spannungsfaktoren ---
S1  = DEK(5);
HS2 = DEK(6);

sf11  = HS2 .* cosd(phi).^2 .* sind(psi).^2 + S1;
sf22  = HS2 .* sind(phi).^2 .* sind(psi).^2 + S1;
sf13  = HS2 .* cosd(phi) .* 2 .* sqrt(max(sind(psi).^2 .* (1-sind(psi).^2), 0));
sf23  = HS2 .* sind(phi) .* 2 .* sqrt(max(sind(psi).^2 .* (1-sind(psi).^2), 0));
sfpar = HS2 .* sind(psi).^2 + 2.*S1;

result.sfmatrix = [];
result.sfpar    = sfpar;
result.sf11     = sf11;
result.sf22     = sf22;
result.sf13     = sf13;
result.sf23     = sf23;

% --- Spannungsmatrix je nach Komponenten ---
switch spannkomp
    case 11
        sfmatrix = sfpar;
    case 1122
        sfmatrix = [sf11 sf22];
    case 112213
        sfmatrix = [sf11 sf22 sf13];
    case 112223
        sfmatrix = [sf11 sf22 sf23];
    case 11221323
        sfmatrix = [sf11 sf22 sf13 sf23];
    otherwise
        error('calcStress: Unbekannte Spannungskomponente: %d', spannkomp);
end
result.sfmatrix = sfmatrix;

% --- Gewichte für lscov vorbereiten ---
% Nur positive finite Fehler verwenden
weights = eps_err;
validW  = isfinite(weights) & (weights > 0);

if any(validW)
    medW = median(weights(validW));
else
    medW = 1.0;
end

% Ungültige Gewichte durch Median ersetzen
weights(~validW) = medW;
weights = max(weights, 1e-12);   % Sicherheitsclamp

% --- Gewichteter Fit (Stressfaktormethode) ---
try
    [result.sigma, result.sigmaerr, result.mse, ~] = ...
        lscov(sfmatrix, result.epsfitdata(:,2), weights);
catch ME
    warning('[calcStress] lscov fehlgeschlagen: %s', strrep(ME.message, '%', '%%'));
    % Fallback: ungewichtete Regression
    try
        result.sigma    = sfmatrix \ result.epsfitdata(:,2);
        result.sigmaerr = NaN(size(sfmatrix,2), 1);
        result.mse      = NaN;
        fprintf('  Fallback: ungewichtete Regression verwendet\n');
    catch ME2
        warning('[calcStress] Regression fehlgeschlagen: %s', strrep(ME2.message, '%', '%%'));
        result.sigma    = NaN(size(sfmatrix,2), 1);
        result.sigmaerr = NaN(size(sfmatrix,2), 1);
        result.mse      = NaN;
    end
end

% --- Ergebnisfunktion epsilon(gamma) diskret ---
switch spannkomp
    case 11
        epsgamma_disc = sfpar * result.sigma;
    case 1122
        epsgamma_disc = sf11*result.sigma(1) + sf22*result.sigma(2);
    case 112213
        epsgamma_disc = sf11*result.sigma(1) + sf22*result.sigma(2) + ...
                        sf13*result.sigma(3);
    case 112223
        epsgamma_disc = sf11*result.sigma(1) + sf22*result.sigma(2) + ...
                        sf23*result.sigma(3);
    case 11221323
        epsgamma_disc = sf11*result.sigma(1) + sf22*result.sigma(2) + ...
                        sf13*result.sigma(3) + sf23*result.sigma(4);
end
result.epsgammaergfunc_disc = epsgamma_disc;
% 
% % --- sin²psi Methode ---
% result.epssin2psifitdaten = [ ...
%     sind(psi).^2, ...
%     result.epsfitdata(:,2), ...
%     weights ...
% ];
% 
% try
%     result.sin2psifit = fitlm( ...
%         result.epssin2psifitdaten(:,1), ...
%         result.epssin2psifitdaten(:,2), ...
%         'Weights', result.epssin2psifitdaten(:,3));
% 
%     xdata = (0:0.05:1);
%     result.sin2psiregres = ...
%         result.sin2psifit.Coefficients.Estimate(1) + ...
%         result.sin2psifit.Coefficients.Estimate(2) .* xdata;
% 
%     if abs(HS2) > 1e-12
%         result.sigmapardebye      = result.sin2psifit.Coefficients.Estimate(2) / HS2;
%         result.deltasigmapardebye = result.sin2psifit.Coefficients.SE(2) / HS2;
%     else
%         result.sigmapardebye      = NaN;
%         result.deltasigmapardebye = NaN;
%     end
% 
% catch ME
%     warning('[calcStress] sin²psi-Fit fehlgeschlagen: %s', strrep(ME.message, '%', '%%'));
%     result.sin2psiregres      = NaN(1, 21);
%     result.sigmapardebye      = NaN;
%     result.deltasigmapardebye = NaN;
% end

% --- sin²psi Methode ---
result.epssin2psifitdaten = [ ...
    sind(psi).^2, ...
    result.epsfitdata(:,2), ...
    weights ...
];

try
    % Rank-Deficiency-Warnung unterdrücken
    warning('off', 'stats:LinearModel:RankDefDesignMat');
    warning('off', 'MATLAB:rankDeficientMatrix');

    result.sin2psifit = fitlm( ...
        result.epssin2psifitdaten(:,1), ...
        result.epssin2psifitdaten(:,2), ...
        'Weights', result.epssin2psifitdaten(:,3));

    warning('on', 'stats:LinearModel:RankDefDesignMat');
    warning('on', 'MATLAB:rankDeficientMatrix');

    % Koeffizienten prüfen bevor sie verwendet werden
    coefs = result.sin2psifit.Coefficients;
    if ~isempty(coefs) && height(coefs) >= 2 && ...
       isfinite(coefs.Estimate(1)) && isfinite(coefs.Estimate(2))

        xdata = (0:0.05:1);
        result.sin2psiregres = ...
            coefs.Estimate(1) + coefs.Estimate(2) .* xdata;

        if abs(HS2) > 1e-12
            result.sigmapardebye      = coefs.Estimate(2) / HS2;
            result.deltasigmapardebye = coefs.SE(2) / HS2;
        else
            result.sigmapardebye      = NaN;
            result.deltasigmapardebye = NaN;
        end
    else
        result.sin2psiregres      = zeros(1, 21);
        result.sigmapardebye      = NaN;
        result.deltasigmapardebye = NaN;
    end

catch ME
    warning('on', 'stats:LinearModel:RankDefDesignMat');
    warning('on', 'MATLAB:rankDeficientMatrix');
    warning('[calcStress] sin²psi-Fit fehlgeschlagen: %s', strrep(ME.message, '%', '%%'));
    result.sin2psifit         = [];
    result.sin2psiregres      = zeros(1, 21);
    result.sigmapardebye      = NaN;
    result.deltasigmapardebye = NaN;
end

% --- Glatte Fit-Kurve auf dichtem γ-Gitter ---
% gammaFit = linspace(-90, 90, 500)';
% γ-Bereich aus tatsächlichen Daten bestimmen
gammaMin    = min(data(:,1));
gammaMax    = max(data(:,1));
gammaMargin = max(2.0, (gammaMax - gammaMin) * 0.05);
gammaFit    = linspace(gammaMin - gammaMargin, ...
                       gammaMax + gammaMargin, 500)';

psiFit = zeros(500, 1);
phiFit = zeros(500, 1);
for l = 1:500
    val = sind(alpha)*sind(theta0) + cosd(alpha)*cosd(theta0)*cosd(gammaFit(l));
    val = max(-1, min(1, val));
    if gammaFit(l) < 0
        psiFit(l) = -acosd(val);
    else
        psiFit(l) =  acosd(val);
    end

    if abs(sind(psiFit(l))) < 1e-10
        phiFit(l) = 0;
    else
        val2 = (cosd(theta0)*sind(gammaFit(l))) ./ sind(psiFit(l));
        val2 = max(-1, min(1, val2));
        if gammaFit(l) < 0
            phiFit(l) = acosd(val2) - 180;
        else
            phiFit(l) = -acosd(val2);
        end
    end
end

% Spannungsfaktoren auf dichtem Gitter
sf11fit  = HS2 .* cosd(phiFit).^2 .* sind(psiFit).^2 + S1;
sf22fit  = HS2 .* sind(phiFit).^2 .* sind(psiFit).^2 + S1;
sf13fit  = HS2 .* cosd(phiFit) .* 2 .* sqrt(max(sind(psiFit).^2 .* (1-sind(psiFit).^2), 0));
sf23fit  = HS2 .* sind(phiFit) .* 2 .* sqrt(max(sind(psiFit).^2 .* (1-sind(psiFit).^2), 0));
sfparfit = HS2 .* sind(psiFit).^2 + 2.*S1;

if any(isnan(result.sigma))
    % Keine gültige Spannung — glatte Kurve auf null setzen
    epsFit = zeros(500, 1);
else
    switch spannkomp
        case 11
            epsFit = sfparfit * result.sigma;
        case 1122
            epsFit = sf11fit*result.sigma(1) + sf22fit*result.sigma(2);
        case 112213
            epsFit = sf11fit*result.sigma(1) + sf22fit*result.sigma(2) + ...
                     sf13fit*result.sigma(3);
        case 112223
            epsFit = sf11fit*result.sigma(1) + sf22fit*result.sigma(2) + ...
                     sf23fit*result.sigma(3);
        case 11221323
            epsFit = sf11fit*result.sigma(1) + sf22fit*result.sigma(2) + ...
                     sf13fit*result.sigma(3) + sf23fit*result.sigma(4);
    end
end

result.epsgammaergfunc   = epsFit;
result.epsgammaergfunc_x = gammaFit;

end

% function result = calcStress(data, DEK, my, spannkomp)
% % CALCSTRESS Berechnet Dehnungen, Spannungsfaktoren und Spannungen
% %
% % EINGABE:
% %   data       - Fitdaten [gamma, 2theta, 2theta_err, amp, width, alpha, ...]
% %   DEK        - Zeile der DEK-Matrix für diesen Peak [h k l E S1 S2 alpha]
% %   my         - Absorptionskoeffizient
% %   spannkomp  - Spannungskomponenten (11, 1122, 112213, 112223, 11221323)
% %
% % AUSGABE:
% %   result     - Struktur mit allen Ergebnissen
% 
%     % --- Grundgrößen ---
%     alpha  = data(1,7);
%     theta0 = sum(data(:,2)) / (2*length(data(:,2)));
% 
%     % --- Dehnung epsilon(gamma) ---
%     result.epsfitdata = [ ...
%         data(:,1), ...
%         log(sind(theta0) ./ sind(data(:,2)./2)), ...
%         cotd(data(:,2)./2) .* (data(:,3)./57.3) ...
%     ];
% 
%     % --- psi ---
%     psi = zeros(length(data(:,1)), 1);
%     for l = 1:length(data(:,1))
%         if data(l,1) < 0
%             psi(l) = -acosd(sind(alpha)*sind(theta0) + cosd(alpha)*cosd(theta0)*cosd(data(l,1)));
%         else
%             psi(l) =  acosd(sind(alpha)*sind(theta0) + cosd(alpha)*cosd(theta0)*cosd(data(l,1)));
%         end
%     end
%     result.psi = psi;
% 
%     % --- phi ---
%     phi = zeros(length(data(:,1)), 1);
%     for l = 1:length(data(:,1))
%         if data(l,1) < 0
%             phi(l) = acosd((cosd(theta0)*sind(data(l,1))) ./ sind(psi(l))) - 180;
%         else
%             phi(l) = -acosd((cosd(theta0)*sind(data(l,1))) ./ sind(psi(l)));
%         end
%     end
%     result.phi = phi;
% 
%     % --- Informationstiefe tau ---
%     result.tau = (1./my) .* ( ...
%         (sind(alpha) .* (sind(2*theta0) .* cosd(alpha) .* cosd(data(:,1)) - cosd(2*theta0) .* sind(alpha))) ./ ...
%         (sind(alpha) + (sind(2*theta0) .* cosd(alpha) .* cosd(data(:,1)) - cosd(2*theta0) .* sind(alpha))) ...
%     );
% 
%     % --- Spannungsfaktoren ---
%     S1  = DEK(5);
%     HS2 = DEK(6);
%     sf11  = HS2 .* cosd(phi).^2 .* sind(psi).^2 + S1;
%     sf22  = HS2 .* sind(phi).^2 .* sind(psi).^2 + S1;
%     sf13  = HS2 .* cosd(phi) .* 2 .* sqrt(sind(psi).^2 .* (1 - sind(psi).^2));
%     sf23  = HS2 .* sind(phi) .* 2 .* sqrt(sind(psi).^2 .* (1 - sind(psi).^2));
%     sfpar = HS2 .* sind(psi).^2 + 2.*S1;
% 
%     % --- Spannungsmatrix je nach Komponenten ---
%     switch spannkomp
%         case 11
%             sfmatrix = sfpar;
%         case 1122
%             sfmatrix = [sf11 sf22];
%         case 112213
%             sfmatrix = [sf11 sf22 sf13];
%         case 112223
%             sfmatrix = [sf11 sf22 sf23];
%         case 11221323
%             sfmatrix = [sf11 sf22 sf13 sf23];
%         otherwise
%             error('calcStress: Unbekannte Spannungskomponente: %d', spannkomp);
%     end
% 
%     result.sfmatrix = sfmatrix;
%     result.sfpar    = sfpar;
%     result.sf11     = sf11;
%     result.sf22     = sf22;
%     result.sf13     = sf13;
%     result.sf23     = sf23;
% 
%     % --- Gewichteter Fit (Stressfaktormethode) ---
%     % [result.sigma, result.sigmaerr, result.mse, ~] = ...
%     %     lscov(sfmatrix, result.epsfitdata(:,2), result.epsfitdata(:,3));
% 
%     % NEU:
%     try
%         [result.sigma, result.sigmaerr, result.mse, ~] = ...
%             lscov(sfmatrix, result.epsfitdata(:,2), result.epsfitdata(:,3));
%     catch ME
%         warning('[calcStress] lscov fehlgeschlagen: %s', strrep(ME.message, '%', '%%'));
%         result.sigma    = NaN(size(sfmatrix,2), 1);
%         result.sigmaerr = NaN(size(sfmatrix,2), 1);
%         result.mse      = NaN;
%     end
% 
%     % --- Ergebnisfunktion epsilon(gamma) ---
%     switch spannkomp
%         case 11
%             result.epsgammaergfunc = sfpar * result.sigma;
%         case 1122
%             result.epsgammaergfunc = sf11*result.sigma(1) + sf22*result.sigma(2);
%         case 112213
%             result.epsgammaergfunc = sf11*result.sigma(1) + sf22*result.sigma(2) + sf13*result.sigma(3);
%         case 112223
%             result.epsgammaergfunc = sf11*result.sigma(1) + sf22*result.sigma(2) + sf23*result.sigma(3);
%         case 11221323
%             result.epsgammaergfunc = sf11*result.sigma(1) + sf22*result.sigma(2) + ...
%                                      sf13*result.sigma(3) + sf23*result.sigma(4);
%     end
% 
%     % --- sin²psi Methode ---
%     result.epssin2psifitdaten = [ ...
%         sind(psi).^2, ...
%         result.epsfitdata(:,2), ...
%         result.epsfitdata(:,3) ...
%     ];
% 
%     % result.sin2psifit = fitlm( ...
%     %     result.epssin2psifitdaten(:,1), ...
%     %     result.epssin2psifitdaten(:,2), ...
%     %     'Weights', result.epssin2psifitdaten(:,3));
% 
%     % NEU:
%     try
%         result.sin2psifit = fitlm( ...
%             result.epssin2psifitdaten(:,1), ...
%             result.epssin2psifitdaten(:,2), ...
%             'Weights', result.epssin2psifitdaten(:,3));
% 
%         xdata = (0:0.05:1);
%         result.sin2psiregres = ...
%             result.sin2psifit.Coefficients.Estimate(1) + ...
%             result.sin2psifit.Coefficients.Estimate(2) .* xdata;
% 
%         result.sigmapardebye      = result.sin2psifit.Coefficients.Estimate(2) / HS2;
%         result.deltasigmapardebye = result.sin2psifit.Coefficients.SE(2) / HS2;
% 
%     catch ME
%         warning('[calcStress] sin²psi-Fit fehlgeschlagen: %s', strrep(ME.message, '%', '%%'));
%         result.sin2psiregres      = NaN(1, 21);
%         result.sigmapardebye      = NaN;
%         result.deltasigmapardebye = NaN;
%     end
% 
%     xdata = (0:0.05:1);
%     result.sin2psiregres = ...
%         result.sin2psifit.Coefficients.Estimate(1) + ...
%         result.sin2psifit.Coefficients.Estimate(2) .* xdata;
% 
%     result.sigmapardebye      = result.sin2psifit.Coefficients.Estimate(2) / HS2;
%     result.deltasigmapardebye = result.sin2psifit.Coefficients.SE(2) / HS2;
% 
%     % --- Glatte Fit-Kurve auf dichtem γ-Gitter ---
%     gammaFit = linspace(-90, 90, 500)';
% 
%     % psi und phi auf dichtem Gitter neu berechnen
%     psiFit = zeros(500,1);
%     phiFit = zeros(500,1);
%     for l = 1:500
%         if gammaFit(l) < 0
%             psiFit(l) = -acosd(sind(alpha)*sind(theta0) + ...
%                 cosd(alpha)*cosd(theta0)*cosd(gammaFit(l)));
%         else
%             psiFit(l) =  acosd(sind(alpha)*sind(theta0) + ...
%                 cosd(alpha)*cosd(theta0)*cosd(gammaFit(l)));
%         end
%         if gammaFit(l) < 0
%             phiFit(l) = acosd((cosd(theta0)*sind(gammaFit(l))) ./ ...
%                 sind(psiFit(l))) - 180;
%         else
%             phiFit(l) = -acosd((cosd(theta0)*sind(gammaFit(l))) ./ ...
%                 sind(psiFit(l)));
%         end
%     end
% 
%     % Spannungsfaktoren auf dichtem Gitter
%     sf11fit  = HS2 .* cosd(phiFit).^2 .* sind(psiFit).^2 + S1;
%     sf22fit  = HS2 .* sind(phiFit).^2 .* sind(psiFit).^2 + S1;
%     sf13fit  = HS2 .* cosd(phiFit) .* 2 .* sqrt(sind(psiFit).^2 .* (1-sind(psiFit).^2));
%     sf23fit  = HS2 .* sind(phiFit) .* 2 .* sqrt(sind(psiFit).^2 .* (1-sind(psiFit).^2));
%     sfparfit = HS2 .* sind(psiFit).^2 + 2.*S1;
% 
%     switch spannkomp
%         case 11
%             epsFit = sfparfit * result.sigma;
%         case 1122
%             epsFit = sf11fit*result.sigma(1) + sf22fit*result.sigma(2);
%         case 112213
%             epsFit = sf11fit*result.sigma(1) + sf22fit*result.sigma(2) + ...
%                      sf13fit*result.sigma(3);
%         case 112223
%             epsFit = sf11fit*result.sigma(1) + sf22fit*result.sigma(2) + ...
%                      sf23fit*result.sigma(3);
%         case 11221323
%             epsFit = sf11fit*result.sigma(1) + sf22fit*result.sigma(2) + ...
%                      sf13fit*result.sigma(3) + sf23fit*result.sigma(4);
%     end
% 
%     % Glatte Kurve als [gamma, epsilon]-Matrix
%     result.epsgammaergfunc      = epsFit;           % überschreibt die diskrete Version
%     result.epsgammaergfunc_x    = gammaFit;         % x-Achse der glatten Kurve
%     result.epsgammaergfunc_disc = result.epsgammaergfunc; % diskrete Version als Backup
% 
% end