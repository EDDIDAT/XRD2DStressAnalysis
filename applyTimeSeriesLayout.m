function h = applyTimeSeriesLayout(h, layoutMode)
% APPLYTIMESERIESLAYOUT  Passt Axes, Slider und Tabelle je nach Modus an.
%
%   layoutMode:
%     'full'   – nur oberes Axes, volle Höhe, KEIN Slider/Tabelle
%                (Waterfall, Heatmap)
%     'bottom' – nur unteres Axes, volle Höhe, MIT Slider/Tabelle
%                (Single Profile)
%     'split'  – beide Axes, MIT Slider/Tabelle
%                (CBF Viewer)
%
% Unsichtbare Elemente werden per Position aus dem Tab geschoben
% (y < 0), da uiaxes/uicontrol Visible='off' nicht immer respektieren.

LEFT        = 0.01;
WIDTH_FULL  = 0.91;  % schmaler als 0.97 → Platz für Colorbar rechts
WIDTH_OTHER = 0.97;  % ohne Colorbar volle Breite
TOP         = 0.875; % untere Kante der Steuerzeilen
HIDE        = -2.0;  % y außerhalb des Tabs

% ── Positionen MIT Slider + Tabelle (Single Profile, CBF Viewer) ──────
BOT_WITH    = 0.115;
MID_WITH    = 0.490;
GAP         = 0.008;

% ── Positionen OHNE Slider + Tabelle (Waterfall, Heatmap) ─────────────
BOT_WITHOUT = 0.008;

switch layoutMode

    case 'full'   % Waterfall / Heatmap — Axes volle Höhe im Tab
        % Heater-Plot ist in h.myfig → hier nur Tab-Axes positionieren
        h.axesTimeSeries.Position  = [LEFT  BOT_WITHOUT  WIDTH_FULL  TOP-BOT_WITHOUT];
        h.axesTimeProfile.Position(2)        = HIDE;
        h.SliderTimeSeries.Position(2)       = HIDE;
        h.TimeSeriesInfoText.Position(2)     = HIDE;
        h.TimeSeriesMotorTable.Position(2)   = HIDE;

    case 'bottom'   % Single Profile
        h.axesTimeSeries.Position  = [LEFT  HIDE      WIDTH_OTHER  TOP-BOT_WITH];
        h.axesTimeProfile.Position = [LEFT  BOT_WITH  WIDTH_OTHER  TOP-BOT_WITH];
        % Slider + Info einblenden
        h.SliderTimeSeries.Position  = [LEFT   0.080  0.78  0.028];
        h.TimeSeriesInfoText.Position = [0.80   0.080  0.19  0.028];
        % Tabelle einblenden
        h.TimeSeriesMotorTable.Position = [LEFT  0.004  0.98  0.068];

    case 'split'   % CBF Viewer: CBF-Bild links (groß), 1D-Profil rechts (schmal)
        CBF_W   = 0.66;   % Breite CBF-Bild
        PRO_W   = 0.31;   % Breite 1D-Profil
        PRO_X   = LEFT + CBF_W + GAP;   % X-Start Profil
        % CBF-Bild: links, volle Höhe
        h.axesTimeSeries.Position  = [LEFT   BOT_WITH  CBF_W  TOP-BOT_WITH];
        % 1D-Profil: rechts, volle Höhe
        h.axesTimeProfile.Position = [PRO_X  BOT_WITH  PRO_W  TOP-BOT_WITH];
        % Slider + Info einblenden
        h.SliderTimeSeries.Position   = [LEFT  0.080  0.78  0.028];
        h.TimeSeriesInfoText.Position  = [0.80  0.080  0.19  0.028];
        % Tabelle einblenden
        h.TimeSeriesMotorTable.Position = [LEFT  0.004  0.98  0.068];
end
end  % applyTimeSeriesLayout