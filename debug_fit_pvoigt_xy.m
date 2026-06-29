function out = debug_fit_pvoigt_xy(x, y, muExpected, opts)
%DEBUG_FIT_PVOIGT_XY
% Fit eines einfachen x/y-Datensatzes mit derselben pseudo-Voigt-Funktion
% wie in pyfai_peak_tracking_compare_methods.m
%
% INPUT
%   x          : x-Achse
%   y          : y-Daten
%   muExpected : erwartete Peaklage
%   opts:
%       .fixedEta        = [] oder z.B. 0.5
%       .muBoundDeg      = 0.15
%       .plotFit         = true
%       .verbose         = true
%       .maxIter         = 800
%       .maxFunEvals     = 8000
%
% OUTPUT
%   out.fit
%       .A, .mu, .sigma, .gamma, .eta, .c, .fwhm
%   out.yfit
%   out.R2
%   out.muErr
%   out.ok
%   out.debug
%       .hasJacobian
%       .nObs
%       .nPar
%       .dof
%       .mse
%       .rcondJTJ
%       .covComputed
%       .muAtLowerBound
%       .muAtUpperBound
%       .sigmaAtLowerBound
%       .gammaAtLowerBound
%       .etaAtLowerBound
%       .etaAtUpperBound
%       .reasonMuErrNaN
%
% BEISPIEL
%   out = debug_fit_pvoigt_xy(x, y, 29.52);

if nargin < 4 || isempty(opts)
    opts = struct();
end

opts = setd(opts, "fixedEta", []);
opts = setd(opts, "muBoundDeg", 0.15);
opts = setd(opts, "plotFit", true);
opts = setd(opts, "verbose", true);
opts = setd(opts, "maxIter", 800);
opts = setd(opts, "maxFunEvals", 8000);

x = x(:);
y = y(:);

assert(numel(x) == numel(y), "x und y müssen gleich lang sein.");

if numel(x) >= 2 && x(2) < x(1)
    x = flipud(x);
    y = flipud(y);
end

out = struct();
out.fit = struct("A",nan,"mu",nan,"sigma",nan,"gamma",nan,"eta",nan,"c",nan,"fwhm",nan);
out.yfit = nan(size(y));
out.R2 = nan;
out.muErr = nan;
out.ok = false;
out.debug = struct();

try
    if numel(x) < 5 || max(y) <= 0 || all(~isfinite(y))
        out.debug.reasonMuErrNaN = "too_few_points_or_invalid_data";
        return;
    end

    % ----- Startwerte wie im Tracking-Skript
    c0 = max(0, min(y));
    y0 = y - c0;
    y0(y0 < 0) = 0;

    idxExp = nearest_index(x, muExpected);
    lo = max(1, idxExp-2);
    hi = min(numel(x), idxExp+2);
    [A0, im0] = max(y0(lo:hi));
    im0 = lo + im0 - 1;

    if ~isfinite(A0) || A0 <= 0
        [A0, im0] = max(y0);
        if ~isfinite(A0) || A0 <= 0
            out.debug.reasonMuErrNaN = "no_positive_peak_found";
            return;
        end
    end

    mu0 = x(im0);
    xSpan = max(x) - min(x);
    fwhm0 = max(xSpan/6, eps);
    sigma0 = max(fwhm0 / (2*sqrt(2*log(2))), eps);
    gamma0 = max(fwhm0 / 2, eps);

    muLo = max(min(x), muExpected - opts.muBoundDeg);
    muHi = min(max(x), muExpected + opts.muBoundDeg);

    lsqOpts = optimoptions('lsqcurvefit', ...
        'Display','off', ...
        'MaxIterations', opts.maxIter, ...
        'MaxFunctionEvaluations', opts.maxFunEvals);

    useFixedEta = ~isempty(opts.fixedEta);
    if useFixedEta
        etaFix = min(max(opts.fixedEta, 0), 1);
    else
        etaFix = [];
    end

    if ~useFixedEta
        % b = [A mu sigma gamma eta c]
        model = @(b,xx) b(6) + b(1) .* ...
            ( b(5) .* (1 ./ (1 + ((xx-b(2))./b(4)).^2)) + ...
             (1-b(5)) .* exp(-0.5 * ((xx-b(2))./b(3)).^2) );

        b0 = [A0, mu0, sigma0, gamma0, 0.5, c0];
        lb = [0, muLo, eps, eps, 0, 0];
        ub = [Inf, muHi, xSpan, xSpan, 1, Inf];

        [b,~,residual,~,~,~,J] = lsqcurvefit(model, b0, x, y, lb, ub, lsqOpts);

        A = b(1);
        mu = b(2);
        sigma = b(3);
        gamma = b(4);
        eta = b(5);
        c = b(6);

        yfit = model(b, x);
        nPar = numel(b);

        % Bound-Diagnostik
        dbg.muAtLowerBound = is_close(mu, lb(2));
        dbg.muAtUpperBound = is_close(mu, ub(2));
        dbg.sigmaAtLowerBound = is_close(sigma, lb(3));
        dbg.gammaAtLowerBound = is_close(gamma, lb(4));
        dbg.etaAtLowerBound = is_close(eta, lb(5));
        dbg.etaAtUpperBound = is_close(eta, ub(5));

    else
        % b = [A mu sigma gamma c], eta fix
        model = @(b,xx) b(5) + b(1) .* ...
            ( etaFix .* (1 ./ (1 + ((xx-b(2))./b(4)).^2)) + ...
             (1-etaFix) .* exp(-0.5 * ((xx-b(2))./b(3)).^2) );

        b0 = [A0, mu0, sigma0, gamma0, c0];
        lb = [0, muLo, eps, eps, 0];
        ub = [Inf, muHi, xSpan, xSpan, Inf];

        [b,~,residual,~,~,~,J] = lsqcurvefit(model, b0, x, y, lb, ub, lsqOpts);

        A = b(1);
        mu = b(2);
        sigma = b(3);
        gamma = b(4);
        eta = etaFix;
        c = b(5);

        yfit = model(b, x);
        nPar = numel(b);

        dbg.muAtLowerBound = is_close(mu, lb(2));
        dbg.muAtUpperBound = is_close(mu, ub(2));
        dbg.sigmaAtLowerBound = is_close(sigma, lb(3));
        dbg.gammaAtLowerBound = is_close(gamma, lb(4));
        dbg.etaAtLowerBound = false;
        dbg.etaAtUpperBound = false;
    end

    % ----- Ausgabeparameter
    fwhmG = 2 * sqrt(2*log(2)) * sigma;
    fwhmL = 2 * gamma;
    fwhm = eta * fwhmL + (1-eta) * fwhmG;

    R2 = calc_r2(y, yfit);
    ok = isfinite(mu) && isfinite(fwhm) && fwhm > 0;

    % ----- Fehlerabschätzung wie im Skript
    [muErr, debugCov] = stderr_from_jacobian_debug(J, residual, numel(y), nPar, 2);

    % ----- Outputs
    out.fit.A = A;
    out.fit.mu = mu;
    out.fit.sigma = sigma;
    out.fit.gamma = gamma;
    out.fit.eta = eta;
    out.fit.c = c;
    out.fit.fwhm = fwhm;

    out.yfit = yfit;
    out.R2 = R2;
    out.muErr = muErr;
    out.ok = ok;

    dbg.hasJacobian = ~isempty(J);
    dbg.nObs = numel(y);
    dbg.nPar = nPar;
    dbg.dof = max(numel(y)-nPar, 0);
    dbg.mse = debugCov.mse;
    dbg.rcondJTJ = debugCov.rcondJTJ;
    dbg.covComputed = debugCov.covComputed;
    dbg.reasonMuErrNaN = debugCov.reasonMuErrNaN;

    out.debug = dbg;

    % ----- Verbose
    if opts.verbose
        fprintf('\n=== pVoigt debug ===\n');
        fprintf('ok            : %d\n', ok);
        fprintf('mu            : %.8f\n', mu);
        fprintf('muErr         : %g\n', muErr);
        fprintf('R2            : %.6f\n', R2);
        fprintf('A             : %.6g\n', A);
        fprintf('sigma         : %.6g\n', sigma);
        fprintf('gamma         : %.6g\n', gamma);
        fprintf('eta           : %.6g\n', eta);
        fprintf('c             : %.6g\n', c);
        fprintf('fwhm          : %.6g\n', fwhm);
        fprintf('nObs          : %d\n', dbg.nObs);
        fprintf('nPar          : %d\n', dbg.nPar);
        fprintf('dof           : %d\n', dbg.dof);
        fprintf('rcond(JTJ)    : %g\n', dbg.rcondJTJ);
        fprintf('covComputed   : %d\n', dbg.covComputed);
        fprintf('mu@lowerBound : %d\n', dbg.muAtLowerBound);
        fprintf('mu@upperBound : %d\n', dbg.muAtUpperBound);
        fprintf('sigma@LB      : %d\n', dbg.sigmaAtLowerBound);
        fprintf('gamma@LB      : %d\n', dbg.gammaAtLowerBound);
        fprintf('eta@LB        : %d\n', dbg.etaAtLowerBound);
        fprintf('eta@UB        : %d\n', dbg.etaAtUpperBound);
        fprintf('reasonMuErrNaN: %s\n', dbg.reasonMuErrNaN);
    end

    % ----- Plot
    if opts.plotFit
        figure;
        hold on; grid on;
        plot(x, y, 'k.-', 'DisplayName', 'data');
        plot(x, yfit, 'r-', 'LineWidth', 1.5, 'DisplayName', 'pVoigt fit');
        xline(muExpected, '--', 'DisplayName', 'mu expected');
        xline(mu, ':', 'DisplayName', 'mu fit');
        xlabel('x');
        ylabel('y');
        title(sprintf('pVoigt fit | mu=%.6f | muErr=%g | R^2=%.5f', mu, muErr, R2));
        legend('Location', 'best');
    end

catch ME
    out.debug.reasonMuErrNaN = "exception";
    if opts.verbose
        fprintf('\nException in debug_fit_pvoigt_xy:\n%s\n', getReport(ME, 'basic'));
    end
end

end

% =========================================================
% helpers
% =========================================================

function idx = nearest_index(x, xq)
x = x(:);
[~, idx] = min(abs(x - xq));
end

function R2 = calc_r2(y, yfit)
y = y(:);
yfit = yfit(:);
ssRes = sum((y - yfit).^2);
ssTot = sum((y - mean(y,'omitnan')).^2);
if ssTot <= 0
    R2 = nan;
else
    R2 = 1 - ssRes / ssTot;
end
end

function [errParam, dbg] = stderr_from_jacobian_debug(J, residual, nObs, nPar, parIdx)
errParam = nan;
dbg = struct();
dbg.mse = nan;
dbg.rcondJTJ = nan;
dbg.covComputed = false;
dbg.reasonMuErrNaN = "unknown";

try
    if isempty(J)
        dbg.reasonMuErrNaN = "empty_jacobian";
        return;
    end

    if size(J,1) <= nPar
        dbg.reasonMuErrNaN = "not_enough_observations_for_covariance";
        return;
    end

    mse = sum(residual.^2) / max(nObs - nPar, 1);
    dbg.mse = mse;

    % JTJ = J' * J;
    JTJ = (pinv(J) * pinv(J)');
    rc = rcond(JTJ);
    dbg.rcondJTJ = rc;

    if ~isfinite(rc) || rc < 1e-12
        dbg.reasonMuErrNaN = "JTJ_ill_conditioned";
        return;
    end

    % Cov = mse * inv(JTJ);
    Cov = mse * (pinv(J) * pinv(J)');
    dbg.covComputed = true;

    if parIdx > size(Cov,1)
        dbg.reasonMuErrNaN = "parameter_index_out_of_range";
        return;
    end

    if ~isfinite(Cov(parIdx,parIdx)) || Cov(parIdx,parIdx) <= 0
        dbg.reasonMuErrNaN = "non_positive_or_invalid_variance";
        return;
    end

    errParam = sqrt(Cov(parIdx,parIdx));
    dbg.reasonMuErrNaN = "ok";

catch
    dbg.reasonMuErrNaN = "covariance_exception";
end
end

function tf = is_close(a, b)
scale = max([1, abs(a), abs(b)]);
tf = abs(a-b) <= 1e-8 * scale;
end

function s = setd(s, f, v)
if ~isfield(s, f) || isempty(s.(f))
    s.(f) = v;
end
end