function [I_sim, tth_map, params] = simulate_ring_from_poni(poniPath, imgSize, twoTheta_deg, sigma_deg)
%SIMULATE_RING_FROM_PONI Simuliert einen Debye-Scherrer Ring im 2D-Detektorbild
% aus einem pyFAI .poni File (Forward-Modell: pro Pixel 2theta berechnen).
%
% Inputs:
%   poniPath      - Pfad zur .poni Datei
%   imgSize       - [nRows, nCols] des gewünschten Ausgabebildes
%   twoTheta_deg  - Ringlage als 2theta in Grad (z.B. 38.6)
%   sigma_deg     - "Ringbreite" als Sigma in Grad (z.B. 0.05). Für harte Maske klein machen.
%
% Outputs:
%   I_sim         - simuliertes 2D-Bild (double)
%   tth_map       - 2theta Map pro Pixel (rad)
%   params        - Struktur mit Geometrieparametern

    arguments
        poniPath (1,:) char
        imgSize (1,2) double {mustBeInteger, mustBePositive}
        twoTheta_deg (1,1) double
        sigma_deg (1,1) double {mustBePositive} = 0.05
    end

    % --- 1) PONI lesen ---
    params = readPoniFile(poniPath);

    % Pixelgröße Pilatus (von dir bestätigt)
    % Falls du es generisch halten willst, mach's als Argument.
    px = 172e-6;  % m

    % --- 2) Pixelgrid (Pixelzentren) ---
    nR = imgSize(1);
    nC = imgSize(2);

    % i = row index (0..nR-1), j = col index (0..nC-1)
    [J, I] = meshgrid(0:nC-1, 0:nR-1);

    % Pixelzentrum (+0.5)
    x_d = (J + 0.5) * px - params.poni2; % Achse2 (x)
    y_d = (I + 0.5) * px - params.poni1; % Achse1 (y)
    z_d = params.dist * ones(size(x_d));

    % --- 3) Rotation anwenden ---
    % Konvention hier: R = Rz(rot3)*Ry(rot2)*Rx(rot1)
    R = rotz(params.rot3) * roty(params.rot2) * rotx(params.rot1);

    % Vektoren stapeln: 3 x N
    X = x_d(:).';
    Y = y_d(:).';
    Z = z_d(:).';
    V = [X; Y; Z];

    V2 = R * V;

    x = reshape(V2(1,:), nR, nC);
    y = reshape(V2(2,:), nR, nC);
    z = reshape(V2(3,:), nR, nC);

    % --- 4) 2theta pro Pixel ---
    r = hypot(x, y);
    tth_map = atan2(r, z); % rad

    % --- 5) Ring simulieren ---
    tth0 = deg2rad(twoTheta_deg);
    sig  = deg2rad(sigma_deg);

    I_sim = exp(-0.5 * ((tth_map - tth0) ./ sig).^2);

    % Optional: auf 0..1 normieren
    I_sim = I_sim ./ max(I_sim(:));

    % --- 6) Zusatzinfos ---
    params.pixel_size_m = px;
    params.beam_center_x_px = params.poni2 / px;
    params.beam_center_y_px = params.poni1 / px;
end

% -------- Hilfsfunktionen --------

function params = readPoniFile(fp)
    % Minimaler PONI-Parser (pyFAI style)
    txt = fileread(fp);
    lines = regexp(txt, '\r\n|\r|\n', 'split');

    params = struct('dist', NaN, 'poni1', NaN, 'poni2', NaN, ...
                    'rot1', 0, 'rot2', 0, 'rot3', 0, 'wavelength', NaN);

    for k = 1:numel(lines)
        line = strtrim(lines{k});
        if isempty(line) || startsWith(line, '#')
            continue
        end

        % Key: value
        tok = regexp(line, '^([^:]+):\s*(.*)$', 'tokens', 'once');
        if isempty(tok), continue, end

        key = strtrim(tok{1});
        val = strtrim(tok{2});

        switch lower(key)
            case 'distance'
                params.dist = str2double(val);
            case 'poni1'
                params.poni1 = str2double(val);
            case 'poni2'
                params.poni2 = str2double(val);
            case 'rot1'
                params.rot1 = str2double(val);
            case 'rot2'
                params.rot2 = str2double(val);
            case 'rot3'
                params.rot3 = str2double(val);
            case 'wavelength'
                params.wavelength = str2double(val);
        end
    end

    % Simple checks
    mustHave = {'dist','poni1','poni2','rot1','rot2','rot3','wavelength'};
    for i = 1:numel(mustHave)
        if isnan(params.(mustHave{i}))
            warning('PONI: Parameter "%s" fehlt oder konnte nicht gelesen werden.', mustHave{i});
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