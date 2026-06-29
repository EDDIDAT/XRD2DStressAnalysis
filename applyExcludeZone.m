%% =========================================================================
%  SCHRITT C — HILFSFUNKTIONEN
%  Diese Funktionen am Ende der Datei einfügen (nach allen Callbacks).
%  Sie sind eigenständige lokale Funktionen (kein 'end' am Schluss nötig,
%  wenn die Datei im klassischen MATLAB-Stil ohne 'end' geschrieben ist).
% =========================================================================

function [q_out, I_out] = applyExcludeZone(h, q_in, I_in)
% APPLYEXCLUDEZONE  Setzt Intensitätswerte im Ausschlussbereich auf NaN.
%
%   q_in   – q-Vektor in nm⁻¹ (Rohdaten aus DAT-File)
%   I_in   – Intensitätsvektor
%   Gibt modifizierte Vektoren zurück (NaN im Ausschlussbereich)

q_out = q_in;
I_out = I_in;

if ~isfield(h,'cbExclude') || ~isvalid(h.cbExclude), return; end
if get(h.cbExclude, 'Value') == 0, return; end

center_str = strtrim(get(h.editExcludeCenter, 'String'));
width_str  = strtrim(get(h.editExcludeWidth,  'String'));
center = str2double(center_str);
width  = str2double(width_str);
if isnan(center) || isnan(width) || width <= 0, return; end

% Ausschlussbereich in der aktuellen X-Achsen-Einheit
use2theta = isfield(h,'TimeSeriesXAxisGroup') && isvalid(h.TimeSeriesXAxisGroup) && ...
            strcmp(get(h.TimeSeriesXAxisGroup.SelectedObject,'String'),'2θ');

if use2theta
    % center ist in 2θ° → in q [nm⁻¹] umrechnen
    lambda_m = [];
    if isfield(h,'datasetLambda_m') && ~isempty(h.datasetLambda_m)
        lambda_m = h.datasetLambda_m;
    elseif isfield(h,'lambda_m') && ~isempty(h.lambda_m)
        lambda_m = h.lambda_m;
    end
    if ~isempty(lambda_m)
        lambda_nm = lambda_m * 1e9;
        % Grenzen in 2θ → q
        tth_lo = center - width;
        tth_hi = center + width;
        q_lo   = 4*pi / lambda_nm * sin(deg2rad(tth_lo/2));
        q_hi   = 4*pi / lambda_nm * sin(deg2rad(tth_hi/2));
    else
        return
    end
else
    % center ist in q [Å⁻¹] → in nm⁻¹
    q_lo = (center - width) * 10;
    q_hi = (center + width) * 10;
end

% Maske: Indizes im Ausschlussbereich
mask = q_in >= q_lo & q_in <= q_hi;
if ~any(mask), return; end

% Randpunkte links und rechts des Ausschlussbereichs für Interpolation
% Puffer: 50% der Ausschlussbreite auf jeder Seite
q_range  = q_hi - q_lo;
buf      = q_range * 0.5;
left_mask  = q_in >= (q_lo - buf) & q_in < q_lo;
right_mask = q_in >  q_hi         & q_in <= (q_hi + buf);

if sum(left_mask) >= 2 && sum(right_mask) >= 2
    % Genügend Nachbarpunkte → lineare Interpolation + leichtes Rauschen
    q_support = [q_in(left_mask);  q_in(right_mask)];
    I_support = [I_in(left_mask);  I_in(right_mask)];

    % Lineare Interpolation auf die maskierten q-Punkte
    I_interp = interp1(q_support, I_support, q_in(mask), 'linear', 'extrap');

    % Leichtes Gauß-Rauschen (Standardabweichung = 1% des lokalen Mittelwerts)
    I_local_mean = mean(I_support);
    noise_std    = max(I_local_mean * 0.01, 1e-6);
    rng_state    = rng;          % Zufallszustand merken (reproduzierbar)
    noise        = noise_std * randn(sum(mask), 1);
    rng(rng_state);

    I_out(mask) = I_interp + noise;
else
    % Zu wenig Nachbarpunkte → einfach NaN (sicherer Fallback)
    I_out(mask) = NaN;
end
end  % applyExcludeZone