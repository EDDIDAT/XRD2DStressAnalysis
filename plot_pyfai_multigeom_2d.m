function plot_pyfai_multigeom_2d(pyfaiMatPath, wavelength_m, opts)
%PLOT_PYFAI_MULTIGEOM_2D
% Visualize pyFAI MultiGeometry 2D output (2theta-chi and q-chi).
%
% Inputs:
%   pyfaiMatPath : .mat with fields I, radial, azimuthal
%   wavelength_m : wavelength in meters (for q conversion)
%   opts:
%     showAxis   : "tth" (default) or "q"
%     useLog     : true (default)
%     logStrength: 1 (default)
%     climPct    : [1 99] (default)
%
% Auto-detects orientation of I.

if nargin < 3, opts = struct(); end
% opts = applyDefaults(opts, struct( ...
%     "showAxis", "tth", ...
%     "useLog", true, ...
%     "logStrength", 1, ...
%     "climPct", [1 99] ...
% ));

opts = applyDefaults(opts, struct( ...
    "showAxis", "tth", ...
    "useLog", true, ...
    "logStrength", 1, ...
    "climPct", [1 99], ...
    "saveTif", true, ...
    "tifPath", "pyfai_multigeom_plot.tif", ...
    "resolution", 300 ...
));

% S = load(pyfaiMatPath);
% I = double(S.I);
% tth = double(S.radial(:));       % in your case: 2theta deg
% chi = double(S.azimuthal(:));     % [-180,180]

I = double(pyfaiMatPath.I);
tth = double(pyfaiMatPath.radial(:));       % in your case: 2theta deg
chi = double(pyfaiMatPath.azimuthal(:));     % [-180,180]

% I = double(pyfaiMatPath.I);
% tth = double(pyfaiMatPath.TTHcent(:));       % in your case: 2theta deg
% chi = double(pyfaiMatPath.CHIcent(:));     % [-180,180]

nRad = numel(tth); nChi = numel(chi);

% orient to [nRad x nChi]
if isequal(size(I), [nRad, nChi])
elseif isequal(size(I), [nChi, nRad])
    I = I.';
else
    error("Cannot infer I orientation. size(I)=[%d %d], nRad=%d, nChi=%d", size(I,1), size(I,2), nRad, nChi);
end

% choose y-axis
axisMode = lower(string(opts.showAxis));
if axisMode == "tth"
    y = tth;
    ylab = "2\theta (deg)";
elseif axisMode == "q"
    lambda_A = wavelength_m * 1e10;
    theta = (tth*pi/180)/2;
    y = (4*pi/lambda_A) * sin(theta); % 1/Å
    ylab = "q (1/\AA)";
else
    error("opts.showAxis must be 'tth' or 'q'");
end

Iplot = I;
if opts.useLog
    Iplot = log10(1 + opts.logStrength * max(Iplot,0));
end

v = Iplot(isfinite(Iplot));
if ~isempty(v)
    clim = prctile(v, opts.climPct);
else
    clim = [min(Iplot(:)) max(Iplot(:))];
end

% figure;
% imagesc(chi, y, Iplot);
fig = figure;
imagesc(chi, y, Iplot);
set(gca,'YDir','normal'); colorbar;
xlabel('\chi (deg)'); ylabel(ylab);
title(sprintf("pyFAI MultiGeometry: I(%s,\\chi)", ylab));
caxis(clim);

if opts.saveTif
    drawnow;  % stellt sicher, dass die Figure vollständig gerendert ist
    exportgraphics(fig, opts.tifPath, ...
        'Resolution', opts.resolution, ...
        'ContentType', 'image');
    fprintf("Saved figure to: %s\n", opts.tifPath);
end

fprintf("I oriented to [%d x %d] (radial x chi)\n", size(I,1), size(I,2));
fprintf("radial (2theta) range: %.4f .. %.4f deg\n", min(tth), max(tth));
fprintf("chi range: %.1f .. %.1f deg\n", min(chi), max(chi));

end

function opts = applyDefaults(opts, def)
f = fieldnames(def);
for i=1:numel(f)
    if ~isfield(opts,f{i}) || isempty(opts.(f{i}))
        opts.(f{i}) = def.(f{i});
    end
end
end