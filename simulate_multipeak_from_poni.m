function [I_sim, maps, params, contours] = simulate_multipeak_from_poni(poniPath, imgSize, peaks, opts)
%SIMULATE_MULTIPEAK_FROM_PONI 2D-Ringsimulation aus PONI für beliebige Bildgrößen.
%
% imgSize = [nRows nCols] z.B. [1083 1021]
%
% peaks: struct-array. Je nach opts.domain:
%   "2theta": pos_deg, I, sigma_deg
%   "d"    : pos_A,   I, sigma_A
%   "q"    : pos_invA,I, sigma_invA
%
% opts:
%   pixel_size_m (default 172e-6)
%   domain       ("2theta"|"d"|"q"), default "2theta"
%   profile      ("gauss"|"pvoigt"), default "gauss"
%   eta          (0..1) for pvoigt, default 0.5
%   background   scalar, default 0
%   normalize    true/false, default true
%   makeContours true/false, default false
%   contourLevel value between 0..1 for each peak (default 0.5)
%
% Output:
%   I_sim: 2D image
%   maps : tth_rad, d_A, q_invA
%   params: geometry + beam center
%   contours: cell array of contour line coordinates (if enabled)

    arguments
        poniPath (1,:) char
        imgSize (1,2) double {mustBeInteger, mustBePositive}
        peaks (1,:) struct
        opts.pixel_size_m (1,1) double {mustBePositive} = 172e-6
        opts.domain (1,1) string {mustBeMember(opts.domain, ["2theta","d","q"])} = "2theta"
        opts.profile (1,1) string {mustBeMember(opts.profile, ["gauss","pvoigt"])} = "gauss"
        opts.eta (1,1) double {mustBeGreaterThanOrEqual(opts.eta,0), mustBeLessThanOrEqual(opts.eta,1)} = 0.5
        opts.background (1,1) double = 0
        opts.normalize (1,1) logical = true
        opts.makeContours (1,1) logical = false
        opts.contourLevel (1,1) double {mustBeGreaterThanOrEqual(opts.contourLevel,0), mustBeLessThanOrEqual(opts.contourLevel,1)} = 0.5
    end

    params = readPoniFile(poniPath);
    px = opts.pixel_size_m;

    nR = imgSize(1); nC = imgSize(2);
    [J, I] = meshgrid(0:nC-1, 0:nR-1);

    % Pixel centers in meters relative to PONI point
    x_d = (J + 0.5) * px - params.poni2; % axis2
    y_d = (I + 0.5) * px - params.poni1; % axis1
    z_d = params.dist * ones(size(x_d));

    % Rotation matrix (validate with overlay if needed)
    R = rotz(params.rot3) * roty(params.rot2) * rotx(params.rot1);

    V = [x_d(:).'; y_d(:).'; z_d(:).'];
    V2 = R * V;

    x = reshape(V2(1,:), nR, nC);
    y = reshape(V2(2,:), nR, nC);
    z = reshape(V2(3,:), nR, nC);

    tth = atan2(hypot(x,y), z); % 2theta rad

    lambda_A = params.wavelength * 1e10;
    theta = tth / 2;
    d_A = lambda_A ./ (2*sin(theta));
    q_invA = (4*pi*sin(theta)) ./ lambda_A;

    maps = struct("tth_rad", tth, "d_A", d_A, "q_invA", q_invA);

    I_sim = zeros(nR, nC, "double") + opts.background;

    % Also optionally store per-peak contribution (for contours)
    if opts.makeContours
        I_peaks = zeros(nR, nC, numel(peaks), "double");
    else
        I_peaks = [];
    end

    switch opts.domain
        case "2theta"
            xmap = tth; % rad
            for k = 1:numel(peaks)
                mu = deg2rad(peaks(k).pos_deg);
                sig = deg2rad(peaks(k).sigma_deg);
                amp = peaks(k).I;

                Ik = amp * peakProfile(xmap, mu, sig, opts.profile, opts.eta);
                I_sim = I_sim + Ik;
                if opts.makeContours, I_peaks(:,:,k) = Ik; end
            end

        case "d"
            xmap = d_A; % Å
            for k = 1:numel(peaks)
                mu = peaks(k).pos_A;
                sig = peaks(k).sigma_A;
                amp = peaks(k).I;

                Ik = amp * peakProfile(xmap, mu, sig, opts.profile, opts.eta);
                I_sim = I_sim + Ik;
                if opts.makeContours, I_peaks(:,:,k) = Ik; end
            end

        case "q"
            xmap = q_invA; % 1/Å
            for k = 1:numel(peaks)
                mu = peaks(k).pos_invA;
                sig = peaks(k).sigma_invA;
                amp = peaks(k).I;

                Ik = amp * peakProfile(xmap, mu, sig, opts.profile, opts.eta);
                I_sim = I_sim + Ik;
                if opts.makeContours, I_peaks(:,:,k) = Ik; end
            end
    end

    if opts.normalize
        mx = max(I_sim(:));
        if mx > 0, I_sim = I_sim ./ mx; end
    end

    params.pixel_size_m = px;
    params.lambda_A = lambda_A;
    params.beam_center_x_px = params.poni2 / px;
    params.beam_center_y_px = params.poni1 / px;

    % --- Optional: contour extraction per peak ---
    contours = {};
    if opts.makeContours
        contours = cell(numel(peaks),1);
        for k = 1:numel(peaks)
            Ik = I_peaks(:,:,k);
            if opts.normalize
                m = max(Ik(:));
                if m > 0, Ik = Ik./m; end
            end
            C = contourc(Ik, [opts.contourLevel opts.contourLevel]); % MATLAB contour format
            contours{k} = parseContourc(C);
        end
    end
end

% ---------- helpers ----------
function y = peakProfile(x, mu, sigma, profile, eta)
    switch profile
        case "gauss"
            y = exp(-0.5 * ((x - mu) ./ sigma).^2);
        case "pvoigt"
            g = exp(-0.5 * ((x - mu) ./ sigma).^2);
            l = 1 ./ (1 + ((x - mu) ./ sigma).^2);
            y = eta*l + (1-eta)*g;
    end
end

function params = readPoniFile(fp)
    txt = fileread(fp);
    lines = regexp(txt, '\r\n|\r|\n', 'split');

    params = struct('dist', NaN, 'poni1', NaN, 'poni2', NaN, ...
                    'rot1', 0, 'rot2', 0, 'rot3', 0, 'wavelength', NaN);

    for k = 1:numel(lines)
        line = strtrim(lines{k});
        if isempty(line) || startsWith(line, '#'), continue, end
        tok = regexp(line, '^([^:]+):\s*(.*)$', 'tokens', 'once');
        if isempty(tok), continue, end
        key = lower(strtrim(tok{1}));
        val = strtrim(tok{2});
        switch key
            case 'distance',   params.dist = str2double(val);
            case 'poni1',      params.poni1 = str2double(val);
            case 'poni2',      params.poni2 = str2double(val);
            case 'rot1',       params.rot1 = str2double(val);
            case 'rot2',       params.rot2 = str2double(val);
            case 'rot3',       params.rot3 = str2double(val);
            case 'wavelength', params.wavelength = str2double(val);
        end
    end
end

function R = rotx(a)
    ca = cos(a); sa = sin(a);
    R = [1 0 0; 0 ca -sa; 0 sa ca];
end
function R = roty(a)
    ca = cos(a); sa = sin(a);
    R = [ca 0 sa; 0 1 0; -sa 0 ca];
end
function R = rotz(a)
    ca = cos(a); sa = sin(a);
    R = [ca -sa 0; sa ca 0; 0 0 1];
end

function segs = parseContourc(C)
% Parse MATLAB contourc output into cell array of [x y] segments.
% Each segment is N-by-2 in matrix indices (col=x, row=y) coordinates.
    segs = {};
    idx = 1;
    while idx < size(C,2)
        level = C(1,idx); %#ok<NASGU>
        npts  = C(2,idx);
        pts = C(:, idx+1:idx+npts).';
        % pts(:,1)=x (col), pts(:,2)=y (row)
        segs{end+1} = pts; %#ok<AGROW>
        idx = idx + npts + 1;
    end
end