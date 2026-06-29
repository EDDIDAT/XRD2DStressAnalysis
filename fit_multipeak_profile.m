function res = fit_multipeak_profile(x, y, peakDef, opts)
%FIT_MULTIPEAK_PROFILE
% Generischer Multi-Peak-Fit für 1..N Peaks mit Gauß oder pseudo-Voigt.
%
% INPUT
%   x       : x-Achse (z.B. 2theta)
%   y       : Intensität
%   peakDef : Struktur mit Peakdefinition
%   opts    : Optionen
%
% peakDef Felder:
%   peakDef.shape            = "gauss" | "pvoigt"
%   peakDef.nPeaks           = Anzahl Peaks
%   peakDef.peakGuessDeg     = [mu1 mu2 ... muN]
%   peakDef.fitRange         = [xmin xmax]   (optional)
%   peakDef.bgLeftRange      = [xmin xmax]   (optional)
%   peakDef.bgRightRange     = [xmin xmax]   (optional)
%   peakDef.backgroundModel  = "constant" | "linear"
%
% opts Felder:
%   opts.muBoundDeg          = 0.10
%   opts.fwhmMinDeg          = 0.01
%   opts.fwhmMaxDeg          = 0.80
%   opts.fixedEta            = [] oder z.B. 0.5
%   opts.maxIter             = 1000
%   opts.doPlot              = true
%
% OUTPUT
%   res.x
%   res.y
%   res.yfit
%   res.bg
%   res.peaks(k)
%   res.R2
%   res.ok

if nargin < 4 || isempty(opts)
    opts = struct();
end

opts = setd(opts, "muBoundDeg", 0.10);
opts = setd(opts, "fwhmMinDeg", 0.01);
opts = setd(opts, "fwhmMaxDeg", 0.80);
opts = setd(opts, "fixedEta", []);
opts = setd(opts, "maxIter", 1000);
opts = setd(opts, "doPlot", true);

x = x(:);
y = y(:);

assert(numel(x) == numel(y), "x und y müssen gleich lang sein.");

peakDef = setd(peakDef, "backgroundModel", "linear");

shape = lower(string(peakDef.shape));
nPeaks = peakDef.nPeaks;
muGuess = peakDef.peakGuessDeg(:).';

assert(numel(muGuess) == nPeaks, "peakGuessDeg muss nPeaks Elemente haben.");

% ---- Fitbereich wählen
fitMask = true(size(x));
if isfield(peakDef, "fitRange") && ~isempty(peakDef.fitRange)
    fitMask = x >= peakDef.fitRange(1) & x <= peakDef.fitRange(2);
end
xf = x(fitMask);
yf = y(fitMask);

assert(numel(xf) >= 10, "Fitbereich enthält zu wenige Punkte.");

% ---- Untergrund-Startwert aus BG-Fenstern
[bg0, bgType] = estimate_background_start(x, y, peakDef);

% ---- Peak-Startwerte
A0 = zeros(1, nPeaks);
fwhm0 = zeros(1, nPeaks);

for k = 1:nPeaks
    [A0(k), fwhm0(k)] = estimate_single_peak_start(xf, yf, muGuess(k), opts);
end

% ---- Parametervektor aufbauen
% constant bg: [c]
% linear bg:   [a b]
%
% gauss peak k:   [Ak muk sigmak]
% pvoigt peak k:  [Ak muk sigmak gammak] (+ eta global/fix)
%
% Wir nehmen pro Peak:
%   gauss:  A, mu, sigma
%   pvoigt: A, mu, sigma, gamma
% eta:
%   - fix, wenn opts.fixedEta gesetzt
%   - sonst globaler eta-Parameter für alle Peaks
%
% Das hält die Dimension moderat.

useFixedEta = ~isempty(opts.fixedEta);
if useFixedEta
    etaFix = min(max(opts.fixedEta, 0), 1);
else
    etaFix = [];
end

switch bgType
    case "constant"
        if bg0.isLinear
            p0_bg = bg0.b;
            lb_bg = -Inf;
            ub_bg = Inf;
        else
            p0_bg = bg0.c;
            lb_bg = -Inf;
            ub_bg = Inf;
        end
    case "linear"
        p0_bg = [bg0.a bg0.b];
        lb_bg = [-Inf -Inf];
        ub_bg = [ Inf  Inf];
    otherwise
        error("Unbekanntes backgroundModel.");
end

dx = median(diff(xf), 'omitnan');
if ~isfinite(dx) || dx <= 0
    dx = 0.01;
end

p0_pk = [];
lb_pk = [];
ub_pk = [];

for k = 1:nPeaks
    mu0 = muGuess(k);
    fw0 = max(opts.fwhmMinDeg * 1.5, min(fwhm0(k), opts.fwhmMaxDeg));
    sig0 = max(fw0 / (2*sqrt(2*log(2))), dx/2);

    switch shape
        case "gauss"
            p0_pk = [p0_pk A0(k) mu0 sig0];
            lb_pk = [lb_pk 0      mu0-opts.muBoundDeg dx/10];
            ub_pk = [ub_pk Inf    mu0+opts.muBoundDeg opts.fwhmMaxDeg];
        case "pvoigt"
            gam0 = max(fw0/2, dx/2);
            p0_pk = [p0_pk A0(k) mu0 sig0 gam0];
            lb_pk = [lb_pk 0      mu0-opts.muBoundDeg dx/10 dx/10];
            ub_pk = [ub_pk Inf    mu0+opts.muBoundDeg opts.fwhmMaxDeg opts.fwhmMaxDeg];
        otherwise
            error("shape muss 'gauss' oder 'pvoigt' sein.");
    end
end

if shape == "pvoigt" && ~useFixedEta
    p0_eta = 0.5;
    lb_eta = 0;
    ub_eta = 1;
    p0 = [p0_bg p0_pk p0_eta];
    lb = [lb_bg lb_pk lb_eta];
    ub = [ub_bg ub_pk ub_eta];
else
    p0 = [p0_bg p0_pk];
    lb = [lb_bg lb_pk];
    ub = [ub_bg ub_pk];
end

% ---- Fit
lsqOpts = optimoptions('lsqcurvefit', ...
    'Display', 'off', ...
    'MaxIterations', opts.maxIter, ...
    'MaxFunctionEvaluations', 20000);

modelFun = @(p, xx) multipeak_model(xx, p, peakDef, opts, bgType, shape, nPeaks, useFixedEta, etaFix);

[pfit, ~, residual, ~, ~, ~, J] = lsqcurvefit(modelFun, p0, xf, yf, lb, ub, lsqOpts);

yfit = modelFun(pfit, xf);
R2 = calc_r2(yf, yfit);

% ---- Ergebnisse zerlegen
[bg, peaks, etaVal] = unpack_fit(xf, pfit, peakDef, opts, bgType, shape, nPeaks, useFixedEta, etaFix);

% Fehler der mu-Parameter
muErr = nan(1, nPeaks);
try
    Cov = covariance_from_jacobian(J, residual, numel(yf), numel(pfit));
    muIdx = get_mu_indices(bgType, shape, nPeaks);
    for k = 1:nPeaks
        if muIdx(k) <= size(Cov,1) && Cov(muIdx(k), muIdx(k)) > 0
            muErr(k) = sqrt(Cov(muIdx(k), muIdx(k)));
        end
    end
catch
end

for k = 1:nPeaks
    peaks(k).muErr = muErr(k); %#ok<AGROW>
end

res = struct();
res.x = xf;
res.y = yf;
res.yfit = yfit;
res.bg = bg;
res.peaks = peaks;
res.eta = etaVal;
res.R2 = R2;
res.ok = all(isfinite([peaks.mu])) && isfinite(R2);

if opts.doPlot
    figure;
    hold on; grid on;

    plot(xf, yf, 'k.-', 'DisplayName', 'data');
    plot(xf, yfit, 'r-', 'LineWidth', 1.5, 'DisplayName', 'global fit');
    plot(xf, bg.y, 'b--', 'LineWidth', 1.2, 'DisplayName', 'background');

    for k = 1:nPeaks
        plot(xf, peaks(k).yTotal, '-', 'LineWidth', 1.0, ...
            'DisplayName', sprintf('peak %d', k));
        xline(peaks(k).mu, ':', 'LineWidth', 1.0, ...
            'DisplayName', sprintf('\\mu_%d', k));
    end

    xlabel('2\theta');
    ylabel('Intensity');
    title(sprintf('Multi-Peak %s fit | N=%d | R^2=%.4f', shape, nPeaks, R2));
    legend('Location', 'best');
end

end

% =========================================================
% model
% =========================================================

function y = multipeak_model(x, p, peakDef, opts, bgType, shape, nPeaks, useFixedEta, etaFix)
[bg, peaks, ~] = unpack_fit(x, p, peakDef, opts, bgType, shape, nPeaks, useFixedEta, etaFix);

y = bg.y;
for k = 1:nPeaks
    y = y + peaks(k).y;
end
end

function [bg, peaks, etaVal] = unpack_fit(x, p, peakDef, opts, bgType, shape, nPeaks, useFixedEta, etaFix)
idx = 1;

switch bgType
    case "constant"
        c = p(idx); idx = idx + 1;
        bg.a = 0;
        bg.b = c;
        bg.y = c + 0*x;
    case "linear"
        a = p(idx); b = p(idx+1); idx = idx + 2;
        bg.a = a;
        bg.b = b;
        bg.y = a*x + b;
    otherwise
        error("Unbekanntes backgroundModel.");
end

peaks = struct([]);

switch shape
    case "gauss"
        for k = 1:nPeaks
            A = p(idx); mu = p(idx+1); sigma = abs(p(idx+2)); idx = idx + 3;
            yk = A * exp(-(x-mu).^2 ./ (2*sigma^2));

            peaks(k).A = A; %#ok<AGROW>
            peaks(k).mu = mu;
            peaks(k).sigma = sigma;
            peaks(k).gamma = nan;
            peaks(k).eta = nan;
            peaks(k).fwhm = 2*sqrt(2*log(2))*sigma;
            peaks(k).y = yk;
            peaks(k).yTotal = bg.y + yk;
        end
        etaVal = nan;

    case "pvoigt"
        if useFixedEta
            etaVal = etaFix;
        else
            etaVal = p(end);
        end

        for k = 1:nPeaks
            A = p(idx); mu = p(idx+1); sigma = abs(p(idx+2)); gamma = abs(p(idx+3)); idx = idx + 4;

            G = exp(-0.5 * ((x-mu)./sigma).^2);
            L = 1 ./ (1 + ((x-mu)./gamma).^2);
            yk = A * (etaVal * L + (1-etaVal) * G);

            fwhmG = 2*sqrt(2*log(2))*sigma;
            fwhmL = 2*gamma;
            fwhm = etaVal * fwhmL + (1-etaVal) * fwhmG;

            peaks(k).A = A; %#ok<AGROW>
            peaks(k).mu = mu;
            peaks(k).sigma = sigma;
            peaks(k).gamma = gamma;
            peaks(k).eta = etaVal;
            peaks(k).fwhm = fwhm;
            peaks(k).y = yk;
            peaks(k).yTotal = bg.y + yk;
        end

    otherwise
        error("shape muss 'gauss' oder 'pvoigt' sein.");
end
end

% =========================================================
% helpers
% =========================================================

function [bg0, bgType] = estimate_background_start(x, y, peakDef)
bgType = lower(string(peakDef.backgroundModel));

leftMask = false(size(x));
rightMask = false(size(x));

if isfield(peakDef, "bgLeftRange") && ~isempty(peakDef.bgLeftRange)
    leftMask = x >= peakDef.bgLeftRange(1) & x <= peakDef.bgLeftRange(2);
end
if isfield(peakDef, "bgRightRange") && ~isempty(peakDef.bgRightRange)
    rightMask = x >= peakDef.bgRightRange(1) & x <= peakDef.bgRightRange(2);
end

bgMask = leftMask | rightMask;

if nnz(bgMask) < 2
    % Fallback
    bg0.a = 0;
    bg0.b = median(y, 'omitnan');
    bg0.c = bg0.b;
    bg0.isLinear = false;
    return;
end

xb = x(bgMask);
yb = y(bgMask);

if bgType == "linear" && numel(xb) >= 3
    pp = polyfit(xb, yb, 1);
    bg0.a = pp(1);
    bg0.b = pp(2);
    bg0.c = median(yb, 'omitnan');
    bg0.isLinear = true;
else
    bg0.a = 0;
    bg0.b = median(yb, 'omitnan');
    bg0.c = bg0.b;
    bg0.isLinear = false;
end
end

function [A0, fwhm0] = estimate_single_peak_start(x, y, muGuess, opts)
[~, idx0] = min(abs(x - muGuess));

lo = max(1, idx0 - 5);
hi = min(numel(x), idx0 + 5);

[A0, im] = max(y(lo:hi));
im = lo + im - 1;

if ~isfinite(A0) || A0 <= 0
    A0 = max(y, [], 'omitnan');
end
if ~isfinite(A0) || A0 <= 0
    A0 = 1;
end

[fwhm0, ~, ok] = estimate_fwhm_local(x, y, x(im));
if ~ok
    fwhm0 = max(opts.fwhmMinDeg * 2, 0.10);
end
fwhm0 = min(max(fwhm0, opts.fwhmMinDeg), opts.fwhmMaxDeg);
end

function [fwhmEst, peakPos, ok] = estimate_fwhm_local(x, y, muGuess)
x = x(:);
y = y(:);
ok = false;
fwhmEst = nan;
peakPos = nan;

[~, idx0] = min(abs(x - muGuess));
lo = max(1, idx0 - 5);
hi = min(numel(x), idx0 + 5);

[amp, im] = max(y(lo:hi));
im = lo + im - 1;

if ~isfinite(amp) || amp <= 0
    return;
end

peakPos = x(im);
halfLevel = 0.5 * amp;

iL = im;
while iL > 1 && y(iL) > halfLevel
    iL = iL - 1;
end

iR = im;
while iR < numel(x) && y(iR) > halfLevel
    iR = iR + 1;
end

if iL == 1 || iR == numel(x) || iR <= iL
    return;
end

xL = interp_half(x(iL), y(iL), x(iL+1), y(iL+1), halfLevel);
xR = interp_half(x(iR-1), y(iR-1), x(iR), y(iR), halfLevel);

if ~isfinite(xL) || ~isfinite(xR) || xR <= xL
    return;
end

fwhmEst = xR - xL;
ok = isfinite(fwhmEst) && fwhmEst > 0;
end

function xh = interp_half(x1, y1, x2, y2, yh)
if ~isfinite(x1) || ~isfinite(x2) || ~isfinite(y1) || ~isfinite(y2) || y1 == y2
    xh = nan;
    return;
end
xh = x1 + (yh - y1) * (x2 - x1) / (y2 - y1);
end

function muIdx = get_mu_indices(bgType, shape, nPeaks)
switch bgType
    case "constant"
        bgN = 1;
    case "linear"
        bgN = 2;
    otherwise
        error("Unbekanntes backgroundModel.");
end

muIdx = zeros(1, nPeaks);

switch shape
    case "gauss"
        base = bgN;
        stride = 3;
        for k = 1:nPeaks
            muIdx(k) = base + (k-1)*stride + 2;
        end
    case "pvoigt"
        base = bgN;
        stride = 4;
        for k = 1:nPeaks
            muIdx(k) = base + (k-1)*stride + 2;
        end
    otherwise
        error("shape muss 'gauss' oder 'pvoigt' sein.");
end
end

function Cov = covariance_from_jacobian(J, residual, nObs, nPar)
mse = sum(residual.^2) / max(nObs - nPar, 1);
JTJ = J' * J;
if rcond(JTJ) < 1e-12
    error('Jacobian ist numerisch singulär.');
end
Cov = mse * inv(JTJ);
end

function R2 = calc_r2(y, yfit)
ssRes = sum((y - yfit).^2);
ssTot = sum((y - mean(y,'omitnan')).^2);
if ssTot <= 0
    R2 = nan;
else
    R2 = 1 - ssRes / ssTot;
end
end

function s = setd(s, f, v)
if ~isfield(s, f) || isempty(s.(f))
    s.(f) = v;
end
end