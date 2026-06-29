function [params, errors, fitResult, r2] = fitPseudoVoigt(x, y, x0_init)
% FITPSEUDOVOIGT Fittet eine Pseudo-Voigt-Funktion an x,y-Daten
%
% Pseudo-Voigt: pV(x) = A * [eta * L(x) + (1-eta) * G(x)]
%
% EINGABE:
%   x        - x-Daten (Vektor)
%   y        - y-Daten (Vektor)
%   x0_init  - Startwert für Peaklage (wird mitgefittet)
%
% AUSGABE:
%   params   - Struktur mit Fitparametern
%   errors   - Struktur mit 1-sigma Fehlern aller Parameter
%   fitResult- gefittete y-Werte

    x = x(:); y = y(:);

    % --- Pseudo-Voigt Modellfunktion ---
    % p = [A, offset, fwhm, eta, x0]
    pVoigt = @(p, x) p(1) .* ( ...
        p(4) .* (1 ./ (1 + ((x - p(5))./(p(3)/2)).^2)) + ...
        (1 - p(4)) .* exp(-log(2) .* ((x - p(5))./(p(3)/2)).^2) ...
        ) + p(2);

    % --- Robuste Startwertschätzung aus den Daten ---
    [A_peak, idx_peak] = max(y);
    offset_init = min(y);
    A_init      = A_peak - offset_init;
    x0_auto     = x(idx_peak);          % Peak aus Daten schätzen

    % FWHM: Halbwertsbreite aus Daten schätzen
    half_max   = offset_init + A_init / 2;
    above_half = x(y >= half_max);
    if numel(above_half) >= 2
        fwhm_init = max(above_half) - min(above_half);
    else
        fwhm_init = (max(x) - min(x)) / 10;
    end

    eta_init = 0.5;

    % x0_init als Startwert, aber x0_auto als Fallback wenn weit entfernt
    if abs(x0_init - x0_auto) > (max(x) - min(x)) / 2
        warning('x0_init liegt weit vom Daten-Peak entfernt. Nutze automatischen Startwert: %.4f', x0_auto);
        x0_start = x0_auto;
    else
        x0_start = x0_init;
    end

    p0 = [A_init, offset_init, fwhm_init, eta_init, x0_start];

    % --- Grenzen ---
    x_range = max(x) - min(x);
    lb = [0,    -Inf, 1e-6, 0, min(x)];
    ub = [Inf,   Inf, Inf,  1, max(x)];

    % --- Fit ---
    opts = optimoptions('lsqcurvefit', ...
        'Display',                'off', ...
        'MaxFunctionEvaluations', 10000, ...
        'FunctionTolerance',      1e-10, ...
        'StepTolerance',          1e-10);

    [p_fit, resnorm, residuals, ~, ~, ~, J] = ...
        lsqcurvefit(pVoigt, p0, x, y, lb, ub, opts);

    % --- Fehlerberechnung: pinv statt inv (robust gegen Singularität) ---
    n   = numel(x);
    dof = n - numel(p_fit);
    s2  = resnorm / dof;
    J   = full(J);
    cov = s2 * pinv(J' * J);    % <-- pinv statt inv!
    se  = sqrt(diag(cov));

    % --- Ergebnisse verpacken ---
    params.A      = p_fit(1);
    params.offset = p_fit(2);
    params.fwhm   = p_fit(3);
    params.eta    = p_fit(4);
    params.x0     = p_fit(5);

    errors.A      = se(1);
    errors.offset = se(2);
    errors.fwhm   = se(3);
    errors.eta    = se(4);
    errors.x0     = se(5);

    fitResult = pVoigt(p_fit, x);
    ss_res = sum(residuals.^2);
    ss_tot = sum((y - mean(y)).^2);
    r2     = 1 - ss_res / ss_tot;

    % % --- Konsole ---
    % fprintf('\n===== Pseudo-Voigt Fit Ergebnisse =====\n');
    % fprintf('  Peaklage  x0 : %.4f  ± %.4f\n', params.x0,     errors.x0);
    % fprintf('  Amplitude  A : %.4f  ± %.4f\n', params.A,      errors.A);
    % fprintf('  Offset       : %.4f  ± %.4f\n', params.offset, errors.offset);
    % fprintf('  FWHM         : %.4f  ± %.4f\n', params.fwhm,   errors.fwhm);
    % fprintf('  Eta (Lorentz): %.4f  ± %.4f\n', params.eta,    errors.eta);
    % fprintf('  R² = %.6f\n', r2);
    % fprintf('=======================================\n\n');
end