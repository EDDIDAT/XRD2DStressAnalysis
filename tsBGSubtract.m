function [Xcorr, Ycorr, Ybkg] = tsBGSubtract(x, I, bgIntervals)
% Untergrundkorrektur über den gesamten x-Bereich.
% bgIntervals: [N x 2] Matrix mit [x_links, x_rechts] pro Intervall
% Strategie: lineare Interpolation zwischen den Randpunkten aller
% BG-Intervalle, konstante Extrapolation außerhalb.

x    = x(:);
I    = double(I(:));
Ybkg = zeros(size(I));

% ── Stützpunkte sammeln: je ein Punkt pro Intervallgrenze ─────────────
xBG = [];
yBG = [];
nGroups = size(bgIntervals, 1);

for g = 1:nGroups
    xL = bgIntervals(g, 1);
    xR = bgIntervals(g, 2);

    [~, iL] = min(abs(x - xL));
    [~, iR] = min(abs(x - xR));
    iL = max(1, iL);
    iR = min(numel(x), iR);

    xBG = [xBG; x(iL); x(iR)];
    yBG = [yBG; I(iL); I(iR)];
end

% Stützpunkte sortieren und Duplikate entfernen
[xBG, sortIdx] = unique(xBG);
yBG = yBG(sortIdx);

if numel(xBG) < 2
    Xcorr = x;
    Ycorr = max(I, 0);
    return
end

% ── Untergrund über gesamten Bereich interpolieren/extrapolieren ──────
% Innerhalb: lineare Interpolation
% Außerhalb: konstante Extrapolation (erster/letzter BG-Wert)
Ybkg = interp1(xBG, yBG, x, 'linear', 'extrap');

% Konstante Extrapolation außerhalb der Stützpunkte
Ybkg(x < xBG(1))   = yBG(1);
Ybkg(x > xBG(end)) = yBG(end);

% ── Untergrund abziehen ───────────────────────────────────────────────
Ycorr = max(I - Ybkg, 0);
Xcorr = x;

end

% function [Xcorr, Ycorr, Ybkg] = tsBGSubtract(x, I, bgIntervals)
% % Untergrundkorrektur NUR innerhalb der definierten BG-Intervalle.
% % Außerhalb: Originalspektrum bleibt erhalten, Untergrund = 0.
% 
% x    = x(:);
% I    = double(I(:));
% Ybkg = zeros(size(I));   % Untergrund = 0 außerhalb der Intervalle
% 
% nGroups = size(bgIntervals, 1);
% 
% for g = 1:nGroups
%     xL = bgIntervals(g, 1);
%     xR = bgIntervals(g, 2);
% 
%     % Nächste Datenpunkte zu den geklickten BG-Grenzen
%     [~, iL] = min(abs(x - xL));
%     [~, iR] = min(abs(x - xR));
%     iL = max(1, iL);
%     iR = min(numel(x), iR);
% 
%     if iR <= iL, continue; end
% 
%     % Lineare Interpolation des Untergrunds zwischen den Randpunkten
%     yL = I(iL);
%     yR = I(iR);
%     xRange = x(iL:iR);
%     Ybkg(iL:iR) = yL + (yR - yL) * (xRange - x(iL)) / (x(iR) - x(iL));
% end
% 
% % Untergrund abziehen, Minimum = 0
% Ycorr = max(I - Ybkg, 0);
% Xcorr = x;
% 
% end

% function [Xcorr, Ycorr, Ybkg] = tsBGSubtract(x, I, bgIntervals)
% % Untergrundkorrektur für 1D Time-Series-Profile
% x = double(x(:)); I = double(I(:));
% nG = size(bgIntervals, 1);
% 
% % Adaptiver movmin-Untergrund
% winW = max(5, round(numel(x) / 80));
% if mod(winW,2)==0, winW = winW+1; end
% Ybkg = max(movmean(movmin(I, winW), winW), 0);
% 
% % Innerhalb der BG-Intervalle: lineare Interpolation zwischen Stützstellen
% bgXv = zeros(1, nG*2); bgYv = zeros(1, nG*2);
% for g = 1:nG
%     [~,iL] = min(abs(x - bgIntervals(g,1)));
%     [~,iR] = min(abs(x - bgIntervals(g,2)));
%     bgXv(2*g-1) = x(iL);    bgXv(2*g)   = x(iR);
%     bgYv(2*g-1) = Ybkg(iL); bgYv(2*g)   = Ybkg(iR);
% end
% [bgXs, si] = sort(bgXv);
% bgYs = bgYv(si);
% 
% for g = 1:nG
%     idxPk = (x >= bgIntervals(g,1)) & (x <= bgIntervals(g,2));
%     if any(idxPk)
%         Ybkg(idxPk) = interp1(bgXs, bgYs, x(idxPk), 'linear','extrap');
%     end
% end
% Ybkg  = max(Ybkg, 0);
% Ycorr = max(I - Ybkg, 0);
% Xcorr = x;