function undostresscallback(hObj, ~)
h = guidata(hObj);

if ~isfield(h, 'undoState') || isempty(h.undoState)
    return
end

% --- Zustand wiederherstellen ---
h.FitDataMod         = h.undoState.FitDataMod;
h.FitDataModCentroid = h.undoState.FitDataModCentroid;
h.fitresultexport    = h.undoState.fitresultexport;
h.dataXcorr          = h.undoState.dataXcorr;
h.dataYcorr          = h.undoState.dataYcorr;
h.fitMethodUsed      = h.undoState.fitMethodUsed;
h.dataCentroidMu     = h.undoState.dataCentroidMu;
h.dataGaussFit       = h.undoState.dataGaussFit;
h.dataPVFitY         = h.undoState.dataPVFitY;
h.dataPVSuccess      = h.undoState.dataPVSuccess;

if isfield(h.undoState, 'epsfitdataexport')
    h.epsfitdataexport      = h.undoState.epsfitdataexport;
    h.epsgammaergfunc       = h.undoState.epsgammaergfunc;
    h.epssin2psifitdaten    = h.undoState.epssin2psifitdaten;
    h.sin2psifit            = h.undoState.sin2psifit;
    h.sin2psiregres         = h.undoState.sin2psiregres;
    h.tau                   = h.undoState.tau;
    h.taumean               = h.undoState.taumean;
    h.sigmaFinal            = h.undoState.sigmaFinal;
    h.sigmaerrFinal         = h.undoState.sigmaerrFinal;
    h.sigmasin2psiFinal     = h.undoState.sigmasin2psiFinal;
    h.deltasigmasin2psiFinal = h.undoState.deltasigmasin2psiFinal;
end

valueSlider = h.undoState.valueSlider;

% --- Plots wiederherstellen ---
h = updateStressPlots(h, valueSlider);

% ε(γ)-Plot wiederherstellen
if isfield(h,'epsfitdataexport') && ~isempty(h.epsfitdataexport)
    eps = h.epsfitdataexport{valueSlider};
    idxV = isfinite(eps(:,2));
    if isfield(h,'plotdata') && isvalid(h.plotdata)
        set(h.plotdata, ...
            'XData', eps(idxV,1), 'YData', eps(idxV,2), ...
            'YNegativeDelta', eps(idxV,3), 'YPositiveDelta', eps(idxV,3), ...
            'Visible', 'on');
    end
end

% Peak-Fit-Plot wiederherstellen
h = updateFittedPeakPlot(h, valueSlider, 1);

% Slider anpassen
nPts = size(h.FitDataMod{valueSlider}, 1);
set(h.SliderFittedPeaks, 'Max', max(nPts,2), 'Value', 1, ...
    'SliderStep', [1/max(nPts-1,1)  1/max(nPts-1,1)]);

% Undo-Button deaktivieren (nur ein Undo-Schritt)
set(hObj, 'Enable', 'off');

% Undo-State löschen
h.undoState = [];

guidata(hObj, h);
end