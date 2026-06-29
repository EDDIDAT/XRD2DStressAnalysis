function XRD2DStressAnalysis_modPV_pyFAI()

% ---- App-Root für kompilierte und unkompilierte Nutzung ----
if isdeployed
    [~, exeInfo] = system(['wmic process where processid="' ...
        num2str(feature('getpid')) ...
        '" get ExecutablePath /format:value']);
    exePath = strtrim(regexprep(exeInfo, 'ExecutablePath=', ''));
    appRoot = fileparts(exePath);
else
    appRoot = fileparts(mfilename('fullpath'));
end

% ---- Startgröße ermitteln ----
scr  = get(0,'ScreenSize');
figW = min(round(scr(3)*0.92), 2200);
figH = min(round(scr(4)*0.88), 1050);
figL = round((scr(3)-figW)/2);
figB = round((scr(4)-figH)/2);

h.myfig = figure(...
    'Name',           '2DXRD Stress Analysis', ...
    'MenuBar',        'none', ...
    'ToolBar',        'auto', ...
    'Units',          'pixels', ...
    'Position',       [figL figB figW figH], ...
    'SizeChangedFcn', @resizecallback, ...
    'CloseRequestFcn', @guiCloseCallback);

% ---- Layout-Konstanten (normiert) ----
% Linke Spalte: x = 0 .. LW
% Mittlerer Bereich (Tabs): x = LW+GAP .. LW+GAP+MW
% Rechter Bereich: x = LW+GAP+MW+GAP .. 1
LW  = 0.230;   % linke Spaltenbreite
MW  = 0.515;   % mittlere Bereichsbreite
GAP = 0.006;   % Abstand zwischen Bereichen
RX  = LW + GAP;           % Startx Mitte
RX2 = LW + GAP + MW + GAP;% Startx rechts
RW  = 1 - RX2 - GAP;      % Breite rechts
P   = 0.004;   % inneres Padding links

% Zeilenhöhen (normiert)
RH  = 0.032;   % Standard Button/Edit
RH2 = 0.026;   % Text-Labels

% =========================================================
% KOPFZEILE  y = 0.955..0.988
% =========================================================
Files = dir(fullfile(appRoot,'Data','Materials','*.mpd'));
MPDFileNameList = cell(size(Files,1),1);
for i = 1:size(Files,1)
    [~,MPDFileNameList{i},~] = fileparts(Files(i).name);
end
MPDFileNameList = MPDFileNameList';

h.SampleFormulaeEditField = uicontrol('parent',h.myfig,...
    'Style','edit','Units','normalized',...
    'Position',[P 0.957 LW*0.40 RH],...
    'String','Elemental formula','HorizontalAlignment','center',...
    'Enable','inactive','Tag','FilenameSample',...
    'ButtonDownFcn',{@clearbuttondown});

h.popupmenumpd1 = uicontrol('Parent',h.myfig,...
    'Style','popupmenu','Units','normalized',...
    'Position',[LW*0.42 0.957 LW*0.32 RH],...
    'Tag','popupmenumpd1','String',MPDFileNameList,...
    'Value',1,'Callback',{@popupmenuCallback});

h.CreateSampleButton = uicontrol(h.myfig,...
    'Style','Pushbutton','Units','normalized',...
    'Position',[LW*0.76 0.957 LW*0.22 RH],...
    'String','Create Sample','Callback',@createsamplecallback);


% Nach h.SampleFormulaeEditField / h.CreateSampleButton, vor Block 1:
h.InputModeGroup = uibuttongroup(h.myfig, ...
    'Units',               'normalized', ...
    'Position',            [P+0.13 0.918 LW-P 0.030], ...
    'BorderType',          'none', ...
    'SelectionChangedFcn', @inputModeChangedCallback);

h.rb_pyfai = uicontrol(h.InputModeGroup, 'Style','radiobutton', ...
    'Units','normalized', 'Position',[0.00 0 0.25 1], ...
    'String','pyFAI-Modus', 'Value', 1);

h.rb_legacyTIF = uicontrol(h.InputModeGroup, 'Style','radiobutton', ...
    'Units','normalized', 'Position',[0.25 0 0.25 1], ...
    'String','Legacy TIF');

% =========================================================
% BLOCK 1: Load 2D images   y=0.915..0.950
% =========================================================
h.LoadImageButton = uicontrol(h.myfig,...
    'Style','Pushbutton','Units','normalized',...
    'Position',[P 0.918 LW*0.52 RH],...
    'String','Load 2D image(s)','Callback',@openfilecallback);

h.FileNameEditField = uicontrol(h.myfig,...
    'Style','edit','Units','normalized',...
    'Position',[P 0.884 LW-P RH2],...
    'String','File Name','HorizontalAlignment','center',...
    'Tag','FilenameData');

% =========================================================
% BLOCK 2: Load PONI + Alpha   y=0.845..0.878
% =========================================================
h.LoadGammaDataButton = uicontrol(h.myfig,...
    'Style','Pushbutton','Units','normalized',...
    'Position',[P 0.848 LW*0.52 RH],...
    'String','Load PONI Files','Callback',@opengammafilecallback);

h.AlphaText1 = uicontrol(h.myfig,'Style','text','Units','normalized',...
    'Position',[LW*0.54 0.851 LW*0.06 RH2],'String',char(945));
h.AlphaText2 = uicontrol(h.myfig,'Style','text','Units','normalized',...
    'Position',[LW*0.60 0.851 LW*0.05 RH2],'String','=');
h.AlphaEditField = uicontrol(h.myfig,...
    'Style','edit','Units','normalized',...
    'Position',[LW*0.66 0.848 LW*0.32 RH2],...
    'String','alpha','HorizontalAlignment','center','Tag','AlphaEditField');

h.GammaFileNameEditField = uicontrol(h.myfig,...
    'Style','edit','Units','normalized',...
    'Position',[P 0.814 LW-P RH2],...
    'String','PONI File(s)','HorizontalAlignment','center','Tag','GammaFilename');

% =========================================================
% BLOCK 2b: Python-Konfiguration   y=0.748..0.808
% =========================================================
h.pythonExeText = uicontrol(h.myfig,'Style','text','Units','normalized',...
    'Position',[P 0.786 LW*0.24 RH2],...
    'HorizontalAlignment','left','String','Python exe');
h.pythonExeEdit = uicontrol(h.myfig,...
    'Style','edit','Units','normalized',...
    'Position',[LW*0.26 0.784 LW*0.72 RH2],...
    'String', "C:\Users\hrp\AppData\Local\Programs\Python\Python311\venv\Scripts\python.exe", ...
    'HorizontalAlignment','left','Tag','pythonExe');

h.scriptPathText = uicontrol(h.myfig,'Style','text','Units','normalized',...
    'Position',[P 0.754 LW*0.24 RH2],...
    'HorizontalAlignment','left','String','Script path');
h.scriptPathEdit = uicontrol(h.myfig,...
    'Style','edit','Units','normalized',...
    'Position',[LW*0.26 0.752 LW*0.72 RH2],...
    'String',fullfile(appRoot,'pyfai_multigeom_run.py'),...
    'HorizontalAlignment','left','Tag','scriptPath');

% =========================================================
% BLOCK 3: pyFAI / Binning Parameter   y=0.648..0.746
% =========================================================
h.PyFAIParamText = uicontrol(h.myfig,'Style','text','Units','normalized',...
    'Position',[P 0.722 LW-P RH2],...
    'HorizontalAlignment','left','FontWeight','bold',...
    'String','pyFAI / Binning Parameter');

% Zeile 1: chi-Range
h.trackChiRangeMinText = uicontrol(h.myfig,'Style','text','Units','normalized',...
    'Position',[P 0.694 LW*0.24 RH2],'HorizontalAlignment','left',...
    'String',[char(967),'-min']);
h.trackChiRangeMinEdit = uicontrol(h.myfig,'Style','edit','Units','normalized',...
    'Position',[LW*0.18 0.692 LW*0.20 RH2],...
    'String','-180','HorizontalAlignment','center','Tag','trackChiRangeMin');
h.trackChiRangeMaxText = uicontrol(h.myfig,'Style','text','Units','normalized',...
    'Position',[LW*0.41 0.694 LW*0.24 RH2],'HorizontalAlignment','left',...
    'String',[char(967),'-max']);
h.trackChiRangeMaxEdit = uicontrol(h.myfig,'Style','edit','Units','normalized',...
    'Position',[LW*0.58 0.692 LW*0.20 RH2],...
    'String','180','HorizontalAlignment','center','Tag','trackChiRangeMax');

% Zeile 2: Chi-Bin | Chi avg
h.trackChiBinText = uicontrol(h.myfig,'Style','text','Units','normalized',...
    'Position',[P 0.663 LW*0.24 RH2],'HorizontalAlignment','left',...
    'String','Chi-Bin step','Tooltip','trackChiBin: jeden n-ten chi-Bin verwenden');
h.trackChiBinEdit = uicontrol(h.myfig,'Style','edit','Units','normalized',...
    'Position',[LW*0.18 0.661 LW*0.20 RH2],...
    'String','4','HorizontalAlignment','center','Tag','trackChiBin');
h.trackChiAvgBinsText = uicontrol(h.myfig,'Style','text','Units','normalized',...
    'Position',[LW*0.41 0.663 LW*0.24 RH2],'HorizontalAlignment','left',...
    'String','Chi avg +/-','Tooltip','trackChiAvgBins: Mittelung +/- n chi-Bins');
h.trackChiAvgBinsEdit = uicontrol(h.myfig,'Style','edit','Units','normalized',...
    'Position',[LW*0.58 0.661 LW*0.20 RH2],...
    'String','4','HorizontalAlignment','center','Tag','trackChiAvgBins');

% Zeile 3: Smooth | Baseline
h.smoothPointsText = uicontrol(h.myfig,'Style','text','Units','normalized',...
    'Position',[P 0.632 LW*0.24 RH2],'HorizontalAlignment','left','String','Smooth pts');
h.smoothPointsEdit = uicontrol(h.myfig,'Style','edit','Units','normalized',...
    'Position',[LW*0.18 0.630 LW*0.20 RH2],...
    'String','5','HorizontalAlignment','center','Tag','smoothPoints');
h.baselineModeText = uicontrol(h.myfig,'Style','text','Units','normalized',...
    'Position',[LW*0.41 0.632 LW*0.22 RH2],'HorizontalAlignment','left','String','Baseline');
h.baselineModePopup = uicontrol(h.myfig,'Style','popupmenu','Units','normalized',...
    'Position',[LW*0.58 0.630 LW*0.20 RH2],...
    'String',{'none','movmin'},'Value',2,'Tag','baselineMode');

h.RebinButton = uicontrol(h.myfig, ...
    'Style',    'Pushbutton', ...
    'Units',    'normalized', ...
    'Position', [LW*0.795 0.6885 LW*0.22 RH], ...
    'String',   'Rebin Data', ...
    'Enable',   'off', ...        % erst aktiv nach Load PONI
    'Tooltip',  'Binning mit aktuellen chi-Parametern neu ausführen', ...
    'Callback', @rebindatacallback);

% =========================================================
% BLOCK 4: 2theta range   y=0.578..0.622
% =========================================================
h.ChangetwothetaText = uicontrol(h.myfig,'Style','text','Units','normalized',...
    'Position',[P 0.600 LW*0.46 RH2],...
    'String',['Select 2',char(952),' range']);
h.twothetaminEditField = uicontrol(h.myfig,'Style','edit','Units','normalized',...
    'Position',[P 0.572 LW*0.32 RH2],...
    'String',['2',char(952),' min'],'HorizontalAlignment','center',...
    'Enable','inactive','ButtonDownFcn',{@clearbuttondown},'Tag','twothetaminEditField');
h.twothetamaxEditField = uicontrol(h.myfig,'Style','edit','Units','normalized',...
    'Position',[LW*0.34 0.572 LW*0.32 RH2],...
    'String',['2',char(952),' max'],'HorizontalAlignment','center',...
    'Enable','inactive','ButtonDownFcn',{@clearbuttondown},'Tag','twothetamaxEditField');
h.ChangetwothetarangeButton = uicontrol(h.myfig,'Style','Pushbutton','Units','normalized',...
    'Position',[LW*0.68 0.570 LW*0.30 RH],...
    'String',['Change 2',char(952),' range'],'Callback',@changetwothetarangecallback);

% =========================================================
% BLOCK 5: Peak search options   y=0.422..0.562
% =========================================================
h.PeakSearchOptionsText = uicontrol(h.myfig,'Style','text','Units','normalized',...
    'Position',[P 0.540 LW*0.60 RH2],'String','Peak search options');

% Prominence
h.PeakProminenceText1 = uicontrol(h.myfig,'Style','text','Units','normalized',...
    'Position',[P 0.511 LW*0.50 RH2],'HorizontalAlignment','left',...
    'String','Prominence threshold',...
    'Tooltip','Peak prominence relative to surroundings');
h.PeakProminenceEditField = uicontrol(h.myfig,'Style','edit','Units','normalized',...
    'Position',[LW*0.52 0.509 LW*0.18 RH2],...
    'String','0.2','HorizontalAlignment','center','Tag','PeakProminenceEditField');
h.DefinePeaksButton = uicontrol(h.myfig,'Style','Pushbutton','Units','normalized',...
    'Position',[LW*0.72 0.507 LW*0.26 RH],...
    'String','1. Define BG',...
    'Tooltip','Untergrundpunkte definieren und Untergrund korrigieren',...
    'Callback',@definebgcallback);

h.DefinePeakPosButton = uicontrol(h.myfig,'Style','Pushbutton','Units','normalized',...
    'Position',[LW*0.72 0.470 LW*0.26 RH],...
    'String','2. Define Peaks',...
    'Tooltip','Peakpositionen im korrigierten Spektrum definieren',...
    'Enable','off',...   % erst aktiv nach BG-Korrektur
    'Callback',@definepeakscallback);



% Peak window
h.PeakWindowText1 = uicontrol(h.myfig,'Style','text','Units','normalized',...
    'Position',[P 0.480 LW*0.50 RH2],'HorizontalAlignment','left',...
    'String','Peak window',...
    'Tooltip','Interval around peak for data collection');
h.PeakWindowEditField = uicontrol(h.myfig,'Style','edit','Units','normalized',...
    'Position',[LW*0.52 0.478 LW*0.18 RH2],...
    'String','1','HorizontalAlignment','center','Tag','PeakWindowEditField');

% Min height
h.PeakHeightText = uicontrol(h.myfig,'Style','text','Units','normalized',...
    'Position',[P 0.449 LW*0.50 RH2],'HorizontalAlignment','left',...
    'String','Min peak height');
h.PeakMinHeightEditField = uicontrol(h.myfig,'Style','edit','Units','normalized',...
    'Position',[LW*0.52 0.447 LW*0.18 RH2],...
    'String','3','HorizontalAlignment','center','Tag','PeakMinHeight');

% =========================================================
% BLOCK 6: User-defined peaks table   y=0.262..0.440
% =========================================================
datatmpUP = zeros(8,2);
% h.tableUserDefinedPeaks = uitable(h.myfig,...
%     'Units','normalized',...
%     'Position',[P 0.262 LW-P 0.178],...
%     'ColumnName',{'EPos-User','Peak count','Use'},...
%     'Data',[num2cell(datatmpUP),num2cell(datatmpUP(:,1)>0)],...
%     'Tag','tableUserDefinedPeaks',...
%     'ColumnFormat',{'numeric','numeric','logical'},...
%     'ColumnEditable',[false false true],...
%     'ColumnWidth',{100 100 55});

h.tableUserDefinedPeaks = uitable(h.myfig,...
    'Units','normalized',...
    'Position',[P 0.262 LW-P 0.178],...
    'ColumnName',{'EPos-User','Peak count','Use','BG links','BG rechts'},...
    'Data',[num2cell(datatmpUP), num2cell(datatmpUP(:,1)>0), ...
            num2cell(NaN(8,1)), num2cell(NaN(8,1))],...
    'Tag','tableUserDefinedPeaks',...
    'ColumnFormat',{'numeric','numeric','logical','numeric','numeric'},...
    'ColumnEditable',[false false true true true],...
    'ColumnWidth',{80 75 40 70 70},...
    'CellEditCallback', @bgregioneditcallback);

% =========================================================
% BLOCK 7: Load DEC + Fit Peaks   y=0.226..0.258
% =========================================================
h.LoadDECdataButton = uicontrol(h.myfig,...
    'Style','Pushbutton','Units','normalized',...
    'Position',[P 0.228 LW*0.46 RH],...
    'String','Load DEC data','Tooltip','Load DEC data manually.',...
    'Callback',@loadDECdatacallback);
h.FitPeaksButton = uicontrol(h.myfig,...
    'Style','Pushbutton','Units','normalized',...
    'Position',[LW*0.49 0.228 LW*0.49 RH],...
    'String','Start','Tooltip','Start fitting of found peaks.',...
    'Callback',@fitpeakscallback);

% NEU: Filter-Button
h.FilterPeaksButton = uicontrol(h.myfig,...
    'Style','Pushbutton','Units','normalized',...
    'Position',[LW*0.48 0.1864 LW*0.22 RH],...
    'String','Filter Peaks ...',...
    'Enable','off',...        % erst aktiv nach Track & Fit
    'FontSize', 9,...
    'Tooltip','Peaks nach R², Fehler und SNR filtern',...
    'Callback',@filterpeakscallback);


% =========================================================
% BLOCK 8: Absorption + Stress + Buttons   y=0.002..0.096
% =========================================================
h.AbscoeffText1 = uicontrol(h.myfig,'Style','text','Units','normalized',...
    'Position',[P 0.068 LW*0.32 RH2],'HorizontalAlignment','left',...
    'String','Abs. coeff.');
h.AbscoeffText2 = uicontrol(h.myfig,'Style','text','Units','normalized',...
    'Position',[LW*0.34 0.071 LW*0.07 RH2],'String',char(956));
h.AbscoeffText3 = uicontrol(h.myfig,'Style','text','Units','normalized',...
    'Position',[LW*0.41 0.071 LW*0.06 RH2],'String','=');
h.AbscoeffEditField = uicontrol(h.myfig,'Style','edit','Units','normalized',...
    'Position',[LW*0.48 0.066 LW*0.22 RH2],...
    'String','0','HorizontalAlignment','center','Tag','AbscoeffEditField');

h.ModDataButton = uicontrol(h.myfig,'Style','Pushbutton','Units','normalized',...
    'Position',[LW*0.72 0.1864 LW*0.26 RH],...
    'String','Modify Data','Callback',@moddatacallback);

h.SpannKompText1 = uicontrol(h.myfig,'Style','text','Units','normalized',...
    'Position',[P 0.034 LW*0.46 RH2],'HorizontalAlignment','left',...
    'String','Stress components');
h.SpannKompEditField = uicontrol(h.myfig,'Style','edit','Units','normalized',...
    'Position',[LW*0.48 0.032 LW*0.22 RH2],...
    'String','1122','HorizontalAlignment','center','Tag','SpannKompEditField');

% Auswahl Peaklage für Stressfit
h.peakMethodGroup = uibuttongroup(h.myfig, ...
    'Units','normalized', ...
    'BorderType','none', ...
    'Position',[P 0.19 LW-P-0.13 0.028]);

h.rb_fitpv = uicontrol(h.peakMethodGroup, 'Style','radiobutton', ...
    'Units','normalized', ...
    'Position',[0.0 0.5 0.5 0.5], ...
    'String','fitPseudoVoigt', 'Value', 1);
h.rb_centroid = uicontrol(h.peakMethodGroup, 'Style','radiobutton', ...
    'Units','normalized', ...
    'Position',[0.5 0.5 0.5 0.5], ...
    'String','fitCentroid');

h.cb_showCentroid = uicontrol(h.myfig, ...
    'Style',    'checkbox', ...
    'Units',    'normalized', ...
    'Position', [P 0.17 LW-P-0.13 0.022], ...
    'String',   'Show fitCentroid', ...
    'Value',    0, ...                  % standardmäßig aus
    'FontSize', 8, ...
    'Callback', @showcentroidcallback);



h.peakMaskThreshEditText = uicontrol(h.myfig, 'Style', 'text', ...
    'Units', 'normalized', ...
    'Position', [LW*0.02 0.13 LW*0.22 RH], ...   % Ihre Koordinaten anpassen
    'String', 'Peak Mask Threshold:', ...
    'HorizontalAlignment', 'left', ...
    'FontSize', 8);

h.peakMaskThreshEdit = uicontrol(h.myfig, 'Style', 'edit', ...
    'Units', 'normalized', ...
    'Position', [LW*0.02 0.1202 LW*0.22 RH2], ...   % Ihre Koordinaten anpassen
    'String', '0.99', ...
    'FontSize', 8, ...
    'Tooltip',['Define threshold for minimum of valid pixel of gamma bin at ',['2',char(952),'°'],' position'], ...
    'Tag', 'peakMaskThreshEdit');

h.peakMaskTthWinEditText = uicontrol(h.myfig, 'Style', 'text', ...
    'Units', 'normalized', ...
    'Position', [LW*0.25 0.13 LW*0.25 RH], ...   % Ihre Koordinaten anpassen
    'String', ['Peak Mask ',['2',char(952),'°'], ' window:'], ...
    'HorizontalAlignment', 'left', ...
    'FontSize', 8);

h.peakMaskTthWinEdit = uicontrol(h.myfig, 'Style', 'edit', ...
    'Units', 'normalized', ...
    'Position', [LW*0.25 0.1202 LW*0.22 RH2], ...   % Ihre Koordinaten anpassen
    'String', '0.3', ...
    'FontSize', 8, ...
    'Tooltip',['Define ',['2',char(952),'°'], ' window around peak where detector mask is evaluated'], ...
    'Tag', 'peakMaskTthWinEdit');

h.ApplyMaskButton = uicontrol(h.myfig, 'Style', 'pushbutton', ...
    'Units', 'normalized', ...
    'Position', [LW*0.48 0.1202 LW*0.22 RH], ...   % Ihre Koordinaten
    'String', 'Apply Detector Mask', ...
    'FontSize', 8, ...
    'Tooltip',['Delete ',['2',char(952),'°'],' values from detector mask areas'], ...
    'Callback', @applyDetectorMaskToFitData);

h.FitStessDataButton = uicontrol(h.myfig,'Style','Pushbutton','Units','normalized',...
    'Position',[LW*0.72 0.1532 LW*0.26 RH],...
    'String','Fit Stress Data','Callback',@fitstressdatacallback);

h.ModStessDataButton = uicontrol(h.myfig,'Style','Pushbutton','Units','normalized',...
    'Position',[LW*0.72 0.1202 LW*0.26 RH], ...  % war 0.002, jetzt 0.032
    'String','Modify Stress Data','Callback',@modstressdatacallback);

h.UndoStressButton = uicontrol(h.myfig, 'Style','Pushbutton', ...
    'Units','normalized', ...
    'Position',[LW*0.48 0.1525 LW*0.22 RH], ...
    'String','↩ Undo', ...
    'Enable','off', ...          % erst aktiv nach erstem Löschen
    'Tooltip','Letzten Löschvorgang rückgängig machen', ...
    'Callback', @undostresscallback);

% =========================================================
% MITTLERER BEREICH: Plot-Tabs   y=0.13..0.97
% =========================================================
h.plottab = uitabgroup(h.myfig,...
    'Units','normalized',...
    'Position',[RX 0.13 MW 0.84]);

h.plottab4 = uitab(h.plottab,'Title','Plot intensity data');
h.plottab1 = uitab(h.plottab,'Title','Stress factor method');
h.plottab2 = uitab(h.plottab,'Title','sin²psi method');
h.plottab3 = uitab(h.plottab,'Title','DEC data for fitted peaks');
h.plottab5 = uitab(h.plottab,'Title','Caked 2D Image');
h.plottab6 = uitab(h.plottab, 'Title', 'Ring Image (merged)');
h.plottab7 = uitab(h.plottab, 'Title', 'Raw 2D Image');

% h.axes = uiaxes(h.plottab1,'Units','normalized','Position',[0.01 0.01 0.98 0.97]);
h.axes = uiaxes(h.plottab1, 'Units', 'normalized', 'Position', [0.01 0.01 0.98 0.97]);

% NEU: wissenschaftliches Styling
h.axes.Color          = [1 1 1];
h.axes.Box            = 'on';
h.axes.LineWidth      = 0.8;
h.axes.FontSize       = 11;
h.axes.XColor         = [0.3 0.3 0.3];
h.axes.YColor         = [0.3 0.3 0.3];
h.axes.GridColor      = [0 0 0];
h.axes.GridAlpha      = 0.08;
h.axes.GridLineStyle  = '-';
h.axes.MinorGridAlpha = 0.05;

h.axes.XLim = [-90,90]; h.axes.YLim = [-Inf,Inf];
h.axes.YLabel.String = [char(949),'(',char(947),')']; h.axes.YLabel.FontSize = 14;
h.axes.XLabel.String = [char(947),' [°]']; h.axes.XLabel.FontSize = 14;
grid(h.axes,'on'); box(h.axes,'on');

h.axessin2psi = uiaxes(h.plottab2,'Units','normalized','Position',[0.01 0.01 0.98 0.97]);
h.axessin2psi.XLim = [0 1]; h.axessin2psi.YLim = [0,Inf]; h.axessin2psi.YLimMode = 'auto';
h.axessin2psi.YLabel.String = [char(949),'(',char(947),')']; h.axessin2psi.YLabel.FontSize = 14;
h.axessin2psi.XLabel.String = ['sin²',char(968)]; h.axessin2psi.XLabel.FontSize = 14;
grid(h.axessin2psi,'on'); box(h.axessin2psi,'on');

datatmp  = zeros(5,8);
datatmp1 = zeros(5,6);

h.tableDECFittedPeaks = uitable(h.plottab3,...
    'Units','normalized','Position',[0.01 0.01 0.54 0.97],...
    'ColumnName',{'E-fitted','E-theo','h','k','l','S1','1/2 S2',char(945)},...
    'Data',datatmp,'Tag','tableDECFittedPeaks',...
    'ColumnFormat',{'numeric',(cellfun(@num2str,num2cell(datatmp(:,4)),'UniformOutput',false))','numeric','numeric','numeric','numeric','numeric','numeric'},...
    'ColumnEditable',[false,true,false,false,false,true,true,false],...
    'ColumnWidth',{65 65 22 22 22 80 80 30},...
    'CellEditCallback',@celleditcallback);

h.plottabEtheo  = uitabgroup(h.plottab3,'Units','normalized','Position',[0.56 0.01 0.43 0.97]);
h.plottabEtheo1 = uitab(h.plottabEtheo,'Title','Ga k-alpha');
h.plottabEtheo2 = uitab(h.plottabEtheo,'Title','In k-alpha');
h.plottabEtheo3 = uitab(h.plottabEtheo,'Title','In k-beta');

tabHandles = {h.plottabEtheo1, h.plottabEtheo2, h.plottabEtheo3};
tabNames   = {'dekdataGaKalpha','dekdataInKalpha','dekdataInKbeta'};
for ti = 1:3
    h.(tabNames{ti}) = uitable(tabHandles{ti},...
        'Units','normalized','Position',[0.01 0.01 0.98 0.97],...
        'ColumnName',{'h','k','l','E-theo','S1','1/2 S2'},...
        'Data',datatmp1(:,1:6),'Tag','dekdata',...
        'ColumnFormat',{'numeric','numeric','numeric','numeric','numeric','numeric'},...
        'ColumnEditable',[false,false,false,false,true,true],...
        'ColumnWidth',{22 22 22 58 75 75},...
        'CellEditCallback',@celleditcallback);
end

h.axesPlotIntensityData = uiaxes(h.plottab4,'Units','normalized','Position',[0.01 0.01 0.98 0.97]);
h.axesPlotIntensityData.XLim = [0,60]; h.axesPlotIntensityData.YLimMode = 'auto';
h.axesPlotIntensityData.YLabel.String = 'Intensity [a.u.]'; h.axesPlotIntensityData.YLabel.FontSize = 14;
h.axesPlotIntensityData.XLabel.String = ['2',char(952),' °']; h.axesPlotIntensityData.XLabel.FontSize = 14;
grid(h.axesPlotIntensityData,'off'); box(h.axesPlotIntensityData,'on');
hold(h.axesPlotIntensityData,'on');

h.axesCaked2D = uiaxes(h.plottab5, 'Units','normalized', 'Position',[0.01 0.055 0.98 0.930]);
h.axesCaked2D.XLabel.String = '\chi (deg)';
h.axesCaked2D.YLabel.String = ['2',char(952),' °'];
h.axesCaked2D.YDir = 'normal';
box(h.axesCaked2D, 'on');

h.SliderCakedImages = uicontrol(h.plottab5, ...
    'Style',      'slider', ...
    'Units',      'normalized', ...
    'Position',   [0.01 0.005 0.98 0.040], ...
    'Min',        1, 'Max', 2, 'Value', 1, ...
    'SliderStep', [1 1], ...
    'Enable',     'off', ...
    'Callback',   @SliderCallbackCakedImage);

h.axesCaked2D.XLabel.String = '\chi (deg)';
h.axesCaked2D.YLabel.String = ['2',char(952),' °'];
h.axesCaked2D.YDir = 'normal';
box(h.axesCaked2D, 'on');

h.axesRingDet = uiaxes(h.plottab6, 'Units','normalized', 'Position',[0.01 0.01 0.98 0.97]);
h.axesRingDet.XLabel.String = 'x_{lab} (mm)';
h.axesRingDet.YLabel.String = 'y_{lab} (mm)';
h.axesRingDet.YDir = 'normal';
box(h.axesRingDet, 'on');

h.axesRawImage = uiaxes(h.plottab7, 'Units','normalized', 'Position',[0.01 0.06 0.98 0.93]);
h.axesRawImage.XLabel.String = 'x [px]';
h.axesRawImage.YLabel.String = 'y [px]';
h.axesRawImage.YDir = 'normal';
box(h.axesRawImage, 'on');

% Slider für Raw Image Tab (unter den Axes im Tab)
h.SliderRawImages = uicontrol(h.plottab7, ...
    'Style',      'slider', ...
    'Units',      'normalized', ...
    'Position',   [0.01 0.005 0.98 0.045], ...
    'Min',        1, ...
    'Max',        2, ...
    'Value',      1, ...
    'SliderStep', [1 1], ...
    'Enable',     'off', ...
    'Callback',   @SliderCallbackRawImage);

% =========================================================
% NEUER TAB 8: Time Series / Dataset
% =========================================================
h.plottab8 = uitab(h.plottab, 'Title', 'Time Series / Dataset');

% ── Zeile 1 (y=0.958..0.998): Load-Button + Status ───────
h.LoadDatasetButton = uicontrol(h.plottab8, ...
    'Style',      'Pushbutton', ...
    'Units',      'normalized', ...
    'Position',   [0.01 0.960 0.16 0.036], ...
    'String',     'Load Dataset Folder', ...
    'FontWeight', 'bold', ...
    'Tooltip',    'Messordner laden (CBF + DAT + LOG)', ...
    'Callback',   @loaddatasetcallback);

h.DatasetStatusText = uicontrol(h.plottab8, ...
    'Style',    'text', ...
    'Units',    'normalized', ...
    'Position', [0.18 0.960 0.81 0.036], ...
    'String',   '— kein Dataset geladen —', ...
    'HorizontalAlignment', 'left', ...
    'FontSize',  9);

h.ReintegratePONIButton = uicontrol(h.plottab8, ...
    'Style',    'Pushbutton', ...
    'Units',    'normalized', ...
    'Position', [0.18 0.960 0.16 0.036], ...
    'String',   'Reintegrate with PONI', ...
    'FontWeight', 'normal', ...
    'Enable',   'off', ...   % erst aktiv nach Dataset-Load
    'Tooltip',  'Neue PONI-Datei wählen und CBF-Bilder neu integrieren', ...
    'Callback', @reintegratePONICallback);

% ── Zeile 2 (y=0.918..0.954): Modus-RadioButtons ─────────
% Volle Breite — kein Platzproblem mehr mit X-Achse
h.TimeSeriesModeGroup = uibuttongroup(h.plottab8, ...
    'Units',               'normalized', ...
    'Position',            [0.01 0.920 0.98 0.036], ...
    'BorderType',          'none', ...
    'SelectionChangedFcn', @TimeSeriesModeCallback);

h.rb_ts_waterfall = uicontrol(h.TimeSeriesModeGroup, ...
    'Style', 'radiobutton', 'Units', 'normalized', ...
    'Position', [0.00 0 0.18 1], 'String', 'Waterfall', 'Value', 1);

h.rb_ts_heatmap = uicontrol(h.TimeSeriesModeGroup, ...
    'Style', 'radiobutton', 'Units', 'normalized', ...
    'Position', [0.09 0 0.18 1], 'String', 'Heatmap');

h.rb_ts_singleprofile = uicontrol(h.TimeSeriesModeGroup, ...
    'Style', 'radiobutton', 'Units', 'normalized', ...
    'Position', [0.18 0 0.20 1], 'String', 'Single Profile');

h.rb_ts_cbfviewer = uicontrol(h.TimeSeriesModeGroup, ...
    'Style', 'radiobutton', 'Units', 'normalized', ...
    'Position', [0.27 0 0.18 1], 'String', 'CBF Viewer');

% ── CBF-Viewer Anzeigemodus: Raw vs. Caked ────────────────────────────
% Nur sichtbar wenn CBF Viewer aktiv — wird per tabSelectionChangedCallback
% und TimeSeriesModeCallback ein-/ausgeblendet
h.CBFViewModeGroup = uibuttongroup(h.plottab8, ...
    'Units',               'normalized', ...
    'Position',            [0.15 0.852 0.20 0.034], ...
    'BorderType',          'none', ...
    'Visible',             'off', ...
    'SelectionChangedFcn', @CBFViewModeCallback);

h.rb_cbf_raw = uicontrol(h.CBFViewModeGroup, ...
    'Style',    'radiobutton', ...
    'Units',    'normalized', ...
    'Position', [0.00 0 0.48 1], ...
    'String',   'CBF Raw', ...
    'Value',    1);

h.rb_cbf_caked = uicontrol(h.CBFViewModeGroup, ...
    'Style',    'radiobutton', ...
    'Units',    'normalized', ...
    'Position', [0.50 0 0.48 1], ...
    'String',   'Caked');

% ── Zeile 3 (y=0.880..0.916): X-Achse + Y-Achse ──────────
h.TimeSeriesXAxisText = uicontrol(h.plottab8, ...
    'Style',    'text', 'Units', 'normalized', ...
    'Position', [0.015 0.872 0.08 0.032], ...
    'String',   'X-Achse:', ...
    'HorizontalAlignment', 'left', 'FontSize', 8);

h.TimeSeriesXAxisGroup = uibuttongroup(h.plottab8, ...
    'Units',               'normalized', ...
    'Position',            [0.08 0.880 0.20 0.034], ...
    'BorderType',          'none', ...
    'SelectionChangedFcn', @TimeSeriesXAxisModeCallback);

h.rb_xaxis_q = uicontrol(h.TimeSeriesXAxisGroup, ...
    'Style', 'radiobutton', 'Units', 'normalized', ...
    'Position', [0.0 0 0.40 1], 'String', 'q', 'Value', 1);

h.rb_xaxis_tth = uicontrol(h.TimeSeriesXAxisGroup, ...
    'Style', 'radiobutton', 'Units', 'normalized', ...
    'Position', [0.22 0 0.58 1], 'String', '2θ');

h.TimeSeriesYAxisText = uicontrol(h.plottab8, ...
    'Style',    'text', 'Units', 'normalized', ...
    'Position', [0.165 0.872 0.06 0.032], ...
    'String',   'Y-Achse:', ...
    'HorizontalAlignment', 'right', 'FontSize', 8);

h.TimeSeriesYAxisPopup = uicontrol(h.plottab8, ...
    'Style',    'popupmenu', 'Units', 'normalized', ...
    'Position', [0.24 0.876 0.15 0.034], ...
    'String',   {'Zeit (min)', 'Index'}, ...
    'Callback', @TimeSeriesYAxisCallback);

% % ── Ausschlusszone: störenden Reflex maskieren ────────────
% % Position + Breite in der aktuellen X-Achsen-Einheit (q Å⁻¹ oder 2θ°)
% h.cbExclude = uicontrol(h.plottab8, ...
%     'Style',    'checkbox', 'Units', 'normalized', ...
%     'Position', [0.435 0.884 0.030 0.028], ...
%     'Value',    0, 'FontSize', 8, ...
%     'TooltipString', 'Ausschlusszone aktivieren', ...
%     'Callback', @ExcludeZoneCallback);
% 
% uicontrol(h.plottab8, 'Style','text','Units','normalized', ...
%     'Position', [0.465 0.881 0.030 0.024], ...
%     'String','Excl.','FontSize',7,'HorizontalAlignment','left');
% 
% h.editExcludeCenter = uicontrol(h.plottab8, ...
%     'Style',               'edit', 'Units', 'normalized', ...
%     'Position',            [0.497 0.884 0.060 0.028], ...
%     'String',              '0.0', ...
%     'HorizontalAlignment', 'center', 'FontSize', 8, ...
%     'TooltipString',       'Zentrum der Ausschlusszone (q Å⁻¹ oder 2θ°)');
% 
% uicontrol(h.plottab8, 'Style','text','Units','normalized', ...
%     'Position', [0.558 0.886 0.008 0.024], ...
%     'String','\','FontSize',8,'HorizontalAlignment','center');
% 
% h.editExcludeWidth = uicontrol(h.plottab8, ...
%     'Style',               'edit', 'Units', 'normalized', ...
%     'Position',            [0.569 0.884 0.040 0.028], ...
%     'String',              '0.05', ...
%     'HorizontalAlignment', 'center', 'FontSize', 8, ...
%     'TooltipString',       'Halbbreite der Ausschlusszone');

% ── Kontrast-Slider für Heatmap ──────────────────────────
uicontrol(h.plottab8, 'Style','text','Units','normalized', ...
    'Position', [0.43 0.881 0.06 0.024], ...
    'String','Kontrast:','FontSize',7,'HorizontalAlignment','right');

h.HeatmapContrastSlider = uicontrol(h.plottab8, ...
    'Style',    'slider', 'Units', 'normalized', ...
    'Position', [0.50 0.884 0.15 0.024], ...
    'Min', 50, 'Max', 100, 'Value', 98, ...
    'SliderStep', [1/50 5/50], ...
    'Callback', @HeatmapContrastCallback);

h.HeatmapContrastLabel = uicontrol(h.plottab8, ...
    'Style','text','Units','normalized', ...
    'Position', [0.655 0.881 0.06 0.024], ...
    'String','98%','FontSize',7,'HorizontalAlignment','left');

% ── Plot-Bereich: Axes ────────────────────────────────────
% BOT_FULL = 0.115 (mit Slider+Tabelle) oder 0.040 (ohne)
% applyTimeSeriesLayout setzt die genauen Positionen dynamisch.

% Oberes Axes (Waterfall / Heatmap / CBF-Bild)
h.axesTimeSeries = uiaxes(h.plottab8, ...
    'Units',    'normalized', ...
    'Position', [0.01 0.040 0.97 0.835]);   % Startlayout: voll (ohne Slider)
h.axesTimeSeries.XLabel.String = 'q (Å^{-1})';
h.axesTimeSeries.YLabel.String = 'Zeit (min)';
h.axesTimeSeries.Title.String  = 'Dataset laden um Plot zu sehen';
box(h.axesTimeSeries, 'on');

% Unteres Axes (Single Profile / unteres CBF-Profil)
h.axesTimeProfile = uiaxes(h.plottab8, ...
    'Units',    'normalized', ...
    'Position', [0.01 -2.0 0.97 0.835]);    % initial außerhalb → unsichtbar
h.axesTimeProfile.XLabel.String = 'q (Å^{-1})';
h.axesTimeProfile.YLabel.String = 'Intensität';
h.axesTimeProfile.Title.String  = 'Einzelprofil';
box(h.axesTimeProfile, 'on');
hold(h.axesTimeProfile, 'on');

% ── Slider (nur Single Profile / CBF Viewer) ──────────────
% Initial unsichtbar — wird per applyTimeSeriesLayout ein/ausgeblendet
h.SliderTimeSeries = uicontrol(h.plottab8, ...
    'Style',      'slider', ...
    'Units',      'normalized', ...
    'Position',   [0.01 -0.08 0.78 0.028], ...  % initial außerhalb
    'Min',        1, 'Max', 2, 'Value', 1, ...
    'SliderStep', [1 1], ...
    'Enable',     'off', ...
    'Callback',   @SliderCallbackTimeSeries);

h.TimeSeriesInfoText = uicontrol(h.plottab8, ...
    'Style',    'text', 'Units', 'normalized', ...
    'Position', [0.80 -0.08 0.19 0.028], ...    % initial außerhalb
    'String',   't = --', ...
    'HorizontalAlignment', 'left', 'FontSize', 9);

% ── Motor-Info Tabelle (nur Single Profile / CBF Viewer) ──
h.TimeSeriesMotorTable = uitable(h.plottab8, ...
    'Units',       'normalized', ...
    'Position',    [0.01 -0.15 0.98 0.072], ... % initial außerhalb
    'ColumnName',  {'Parameter', 'Wert'}, ...
    'Data',        {'—', '—'}, ...
    'ColumnWidth', {200, 120}, ...
    'RowName',     [], ...
    'FontSize',    8);

% ── Heater-Plot: in h.myfig, an Stelle von axesPlottauData ──────────
% Positionen angelehnt an axesPlottauData + Slider (RX=0.236, MW=0.515)
% Sichtbar nur wenn Dataset-Tab aktiv + CSV geladen
% Initial unsichtbar (Visible='off' reicht hier da es in h.myfig ist)
RX_h = 0.236;   % = LW + GAP aus Haupt-GUI
MW_h = 0.515;   % mittlere Bereichsbreite

% axesHeater: Position wird nach dem Einblenden automatisch an
% axesTimeSeries angeglichen (in updateHeaterPlot via TightInset).
% Hier nur Startwerte — die genaue Ausrichtung erfolgt dynamisch.
h.axesHeater = uiaxes(h.myfig, ...
    'Units',    'normalized', ...
    'Position', [RX_h  0.002  MW_h*0.91  0.120], ...
    'Visible',  'off');
h.axesHeater.XLabel.String = 'Zeit (min)';
h.axesHeater.YLabel.String = 'T (°C)';
box(h.axesHeater, 'on');

% Dropdown rechts vom Tab-Bereich
POPUP_X = RX_h + MW_h * 0.91 + MW_h * 0.09 + 0.006;
POPUP_W = 1 - POPUP_X - 0.005;

h.HeaterColText = uicontrol(h.myfig, ...
    'Style',    'text', 'Units', 'normalized', ...
    'Position', [POPUP_X-0.045  0.096  POPUP_W  0.026], ...
    'String',   'Heater property:', ...
    'HorizontalAlignment', 'left', 'FontSize', 8, ...
    'Visible',  'off');

h.HeaterColPopup = uicontrol(h.myfig, ...
    'Style',    'popupmenu', 'Units', 'normalized', ...
    'Position', [POPUP_X-0.045  0.07  POPUP_W-0.16  0.030], ...
    'String',   {'— kein CSV —'}, ...
    'Visible',  'off', ...
    'Callback', @HeaterColCallback);

% Checkbox: T_max-Linie in Heatmap anzeigen
% Checkbox direkt unter dem Label-Text (y=0.082-0.030-0.004 = 0.048
% belegt Popup, also Checkbox darunter bei y=0.014)
% → Checkbox oberhalb des Popups: y = 0.082 + 0.026 + 0.004 = 0.112
h.cbTmaxLine = uicontrol(h.myfig, ...
    'Style',    'checkbox', 'Units', 'normalized', ...
    'Position', [POPUP_X-0.045 0.046  POPUP_W  0.026], ...
    'String',   'T_max-Linie', ...
    'Value',    0, ...
    'FontSize', 8, ...
    'Visible',  'off', ...
    'Callback', @TmaxLineCallback);

% ── Phasen-Panel: theoretische Linienlagen ───────────────
% 3 Phasen, je eine Zeile mit: Checkbox | Name-Edit | MPD-Popup | Berechnen-Button
% Farben
PHASE_COLORS = {[1.0 0.85 0.0], [0.15 0.85 0.15], [1.0 0.50 0.0]};
h.phaseColors = PHASE_COLORS;
h.phaseData   = cell(3,1);

% MPD-Dateiliste (dieselbe wie im Haupt-GUI)
MPD_Files_ph  = dir(fullfile(appRoot,'Data','Materials','*.mpd'));
MPD_List_ph   = cell(size(MPD_Files_ph,1),1);
for kk = 1:size(MPD_Files_ph,1)
    [~, MPD_List_ph{kk}, ~] = fileparts(MPD_Files_ph(kk).name);
end
if isempty(MPD_List_ph), MPD_List_ph = {'— keine MPD —'}; end

% Header-Zeile
uicontrol(h.plottab8, 'Style','text','Units','normalized', ...
    'Position',[0.70 0.952 0.270 0.020], ...
    'String','Phase    Name                             MPD-Datei', ...
    'HorizontalAlignment','left','FontSize',7,'FontAngle','italic');

for ph = 1:3
    col  = PHASE_COLORS{ph};
    PH_Y = 0.93 - (ph-1)*0.028;   % y-Start der Zeile

    % Checkbox (farbig)
    h.cbPhase(ph) = uicontrol(h.plottab8, ...
        'Style',           'checkbox', ...
        'Units',           'normalized', ...
        'Position',        [0.7  PH_Y  0.030  0.028], ...
        'Value',           0, ...
        'BackgroundColor', col, ...
        'TooltipString',   sprintf('Phase %d ein-/ausblenden', ph), ...
        'UserData',        ph, ...
        'Callback',        @phaseLineCallback);

    % Phasenname (editierbar)
    h.editPhaseName(ph) = uicontrol(h.plottab8, ...
        'Style',               'edit', ...
        'Units',               'normalized', ...
        'Position',            [0.732  PH_Y  0.100  0.028], ...
        'String',              sprintf('Phase %d', ph), ...
        'HorizontalAlignment', 'left', ...
        'FontSize',            8, ...
        'UserData',            ph);

    % MPD-Dropdown
    h.popupPhaseMPD(ph) = uicontrol(h.plottab8, ...
        'Style',    'popupmenu', ...
        'Units',    'normalized', ...
        'Position', [0.834  PH_Y  0.100  0.028], ...
        'String',   MPD_List_ph, ...
        'Value',    1, ...
        'FontSize', 7, ...
        'UserData', ph);

    % Berechnen-Button (farbig, kompakt)
    h.btnSetPhase(ph) = uicontrol(h.plottab8, ...
        'Style',           'pushbutton', ...
        'Units',           'normalized', ...
        'Position',        [0.94  PH_Y  0.030  0.028], ...
        'String',          char(8635), ...   % ↻ Refresh-Symbol
        'BackgroundColor', col, ...
        'FontWeight',      'bold', ...
        'FontSize',        9, ...
        'TooltipString',   sprintf('Reflexe für Phase %d berechnen', ph), ...
        'UserData',        ph, ...
        'Callback',        @setPhaseCallback);
end

% =========================================================
% TIME SERIES: Peak-Fit Controls (rechte Spalte, h.myfig)
% Sichtbar nur wenn Time-Series-Tab aktiv.
% Nutzt denselben Bereich wie Stress-Axes (die dann hidden sind).
% =========================================================

% Header
h.TSPFHeader = uicontrol(h.myfig, 'Style','text', 'Units','normalized', ...
    'Position',[RX2  0.932  RW  0.024], ...
    'String','── Peak-Fit  (Time Series) ──', ...
    'FontSize',9, 'FontAngle','italic', ...
    'HorizontalAlignment','center', 'Visible','off');

% ── x-Bereich (2θ/q) ─────────────────────────────────────
h.TSXRangeLbl = uicontrol(h.myfig, 'Style','text', 'Units','normalized', ...
    'Position',[RX2  0.906  RW*0.06  0.024], ...
    'String','x:', 'FontSize',8, 'FontWeight','bold', ...
    'HorizontalAlignment','right', 'Visible','off');

h.TSXRangeMinEdit = uicontrol(h.myfig, 'Style','edit', 'Units','normalized', ...
    'Position',[RX2+RW*0.07  0.906  RW*0.12  0.026], ...
    'String','', 'FontSize',8, 'HorizontalAlignment','center', ...
    'Tooltip','x-Minimum (2θ/q, leer = alles)', ...
    'Tag','TSXRangeMin', 'Visible','off');

h.TSXRangeDash = uicontrol(h.myfig, 'Style','text', 'Units','normalized', ...
    'Position',[RX2+RW*0.19  0.906  RW*0.03  0.024], ...
    'String','–', 'FontSize',9, 'HorizontalAlignment','center', 'Visible','off');

h.TSXRangeMaxEdit = uicontrol(h.myfig, 'Style','edit', 'Units','normalized', ...
    'Position',[RX2+RW*0.22  0.906  RW*0.12  0.026], ...
    'String','', 'FontSize',8, 'HorizontalAlignment','center', ...
    'Tooltip','x-Maximum (2θ/q, leer = alles)', ...
    'Tag','TSXRangeMax', 'Visible','off');

% ── t-Bereich (Zeit) ─────────────────────────────────────
h.TSTRangeLbl = uicontrol(h.myfig, 'Style','pushbutton', 'Units','normalized', ...
    'Position',[RX2+RW*0.37  0.906  RW*0.06  0.026], ...
    'String','t:', 'FontSize',8, 'FontWeight','bold', ...
    'Tooltip','t-Bereich in der Heatmap auswählen (2x klicken)', ...
    'Visible','off', 'Callback', @tsPickTRangeCallback);

h.TSTRangeMinEdit = uicontrol(h.myfig, 'Style','edit', 'Units','normalized', ...
    'Position',[RX2+RW*0.44  0.906  RW*0.10  0.026], ...
    'String','', 'FontSize',8, 'HorizontalAlignment','center', ...
    'Tooltip','t-Minimum in min (leer = alles)', 'Visible','off');

h.TSTRangeDash = uicontrol(h.myfig, 'Style','text', 'Units','normalized', ...
    'Position',[RX2+RW*0.54  0.906  RW*0.03  0.024], ...
    'String','–', 'FontSize',9, 'HorizontalAlignment','center', 'Visible','off');

h.TSTRangeMaxEdit = uicontrol(h.myfig, 'Style','edit', 'Units','normalized', ...
    'Position',[RX2+RW*0.57  0.906  RW*0.10  0.026], ...
    'String','', 'FontSize',8, 'HorizontalAlignment','center', ...
    'Tooltip','t-Maximum in min (leer = alles)', 'Visible','off');

% ── Apply + Reset (gemeinsam für x und t) ────────────────
h.TSXRangeApplyButton = uicontrol(h.myfig, 'Style','pushbutton', 'Units','normalized', ...
    'Position',[RX2+RW*0.69  0.906  RW*0.14  0.026], ...
    'String','Apply', 'FontSize',8, 'Visible','off', ...
    'Tooltip','x- und t-Bereich anwenden', ...
    'Callback', @tsXRangeApplyCallback);

h.TSXRangeResetButton = uicontrol(h.myfig, 'Style','pushbutton', 'Units','normalized', ...
    'Position',[RX2+RW*0.84  0.906  RW*0.10  0.026], ...
    'String','↺', 'FontSize',9, 'Visible','off', ...
    'Tooltip','x- und t-Bereich zurücksetzen', ...
    'Callback', @tsXRangeResetCallback);

% ── Buttons Zeile 1 ───────────────────────────────────────
h.TSDefineBGButton = uicontrol(h.myfig, 'Style','pushbutton', 'Units','normalized', ...
    'Position',[RX2+RW*0.475  0.874  RW*0.25  0.028], ...
    'String','1. Define BG', 'FontSize',8, ...
    'Enable','off', 'Visible','off', ...
    'Tooltip','Untergrundpunkte im aktuellen Profil definieren', ...
    'Callback', @tsDefineBGCallback);

h.TSDefinePeaksButton = uicontrol(h.myfig, 'Style','pushbutton', 'Units','normalized', ...
    'Position',[RX2+RW*0.73  0.874  RW*0.25  0.028], ...
    'String','2. Define Peaks', 'FontSize',8, ...
    'Enable','off', 'Visible','off', ...
    'Tooltip','Peaks im BG-korrigierten Profil definieren', ...
    'Callback', @tsDefinePeaksCallback);

h.TSPickPeaksHeatmapButton = uicontrol(h.myfig, 'Style','pushbutton', 'Units','normalized', ...
    'Position',[RX2  0.874  RW*0.3  0.028], ...
    'String','Pick Peaks (Heatmap)', 'FontSize',8, ...
    'Enable','off', 'Visible','off', ...
    'Tooltip','Peaks direkt in der Heatmap anklicken', ...
    'Callback', @tsPickPeaksHeatmapCallback);

h.TSAddPeakButton = uicontrol(h.myfig, 'Style','pushbutton', 'Units','normalized', ...
    'Position',[RX2+RW*0.3125  0.874  RW*0.15  0.028], ...
    'String','+ Peak', 'FontSize',8, ...
    'Enable','off', 'Visible','off', ...
    'Tooltip','Peak im 1D-Profil hinzufügen (Klick auf Position)', ...
    'Callback', @tsAddPeakCallback);

% ── Buttons Zeile 2 ───────────────────────────────────────
% Grenzen-Button (neu, links)
h.TSFitBoundsButton = uicontrol(h.myfig, 'Style','pushbutton', 'Units','normalized', ...
    'Position',[RX2,  0.842,  RW*0.29,  0.030], ...
    'String','Fit-Grenzen ...', 'FontSize',8, ...
    'Enable','off', 'Visible','off', ...
    'Tooltip','Untere und obere Grenzen für FWHM, Position und Amplitude definieren', ...
    'Callback', @tsOpenFitBoundsDialog);

% Fit-All-Button (verkleinert, nach rechts verschoben)
h.TSFitAllButton = uicontrol(h.myfig, 'Style','pushbutton', 'Units','normalized', ...
    'Position',[RX2 + RW*0.305,  0.842,  RW*0.310,  0.030], ...
    'String','3. Fit All Profiles', 'FontSize',8, 'FontWeight','bold', ...
    'Enable','off', 'Visible','off', ...
    'Tooltip','Pseudo-Voigt-Fit für alle N Profile starten', ...
    'Callback', @tsFitAllCallback);

% h.TSFitAllButton = uicontrol(h.myfig, 'Style','pushbutton', 'Units','normalized', ...
%     'Position',[RX2  0.842  RW*0.615  0.030], ...
%     'String','3. Fit All Profiles', 'FontSize',8, 'FontWeight','bold', ...
%     'Enable','off', 'Visible','off', ...
%     'Tooltip','Pseudo-Voigt-Fit für alle N Profile starten', ...
%     'Callback', @tsFitAllCallback);

h.TSFitExportButton = uicontrol(h.myfig, 'Style','pushbutton', 'Units','normalized', ...
    'Position',[RX2+RW*0.640  0.842  RW*0.345  0.030], ...
    'String','Export', 'FontSize',8, ...
    'Enable','off', 'Visible','off', ...
    'Tooltip','Fit-Ergebnisse als TXT exportieren', ...
    'Callback', @tsFitExportCallback);

% ── Status-Text ───────────────────────────────────────────
h.TSFitStatusText = uicontrol(h.myfig, 'Style','text', 'Units','normalized', ...
    'Position',[RX2  0.818  RW  0.020], ...
    'String','— kein Fit —', 'FontSize',8, ...
    'HorizontalAlignment','left', 'Visible','off');

% ── Zeige-Popup ───────────────────────────────────────────
h.TSFitZeigeLbl = uicontrol(h.myfig, 'Style','text', 'Units','normalized', ...
    'Position',[RX2  0.794  RW*0.28  0.022], ...
    'String','Zeige:', 'FontSize',8, ...
    'HorizontalAlignment','left', 'Visible','off');

h.TSFitResultPopup = uicontrol(h.myfig, 'Style','popupmenu', 'Units','normalized', ...
    'Position',[RX2+RW*0.1  0.791  RW*0.29  0.028], ...
    'String',{'Peak-Position','Amplitude','FWHM','R²'}, ...
    'FontSize',8, 'Enable','off', 'Visible','off', ...
    'Callback', @tsFitResultPopupCallback);

% ── Peak-Modell: Pseudo-Voigt vs. Split-Pseudo-Voigt ──────────────────
h.PeakModelGroup = uibuttongroup(h.myfig, ...
    'Units',               'normalized', ...
    'Position',            [RX2+RW*0.5  0.798  RW*0.45  0.022], ...
    'BorderType',          'none', ...
    'Visible',             'off', ...
    'SelectionChangedFcn', @peakModelChangedCallback);

h.rb_pv_sym    = uicontrol(h.PeakModelGroup, 'Style','radiobutton', ...
    'Units','normalized', 'Position',[0.0   0 0.44 1], ...
    'String','Pseudo-Voigt', 'Value', 1, 'FontSize', 8, ...
    'UserData', 'symmetric');

h.rb_pv_split  = uicontrol(h.PeakModelGroup, 'Style','radiobutton', ...
    'Units','normalized', 'Position',[0.4  0 0.3 1], ...
    'String','Split-PV', 'FontSize', 8, ...
    'UserData', 'asymmetric');

h.rb_pv_kalpha = uicontrol(h.PeakModelGroup, 'Style','radiobutton', ...
    'Units','normalized', 'Position',[0.7  0 0.3 1], ...
    'String','Kalpha1/2', 'FontSize', 8, ...
    'UserData', 'kalpha12');


% ── Ergebnis-Axes ─────────────────────────────────────────
h.axesTSFitResults = uiaxes(h.myfig, 'Units','normalized', ...
    'Position',[RX2  0.130  RW  0.656], 'Visible','off');
h.axesTSFitResults.XLabel.String = 'Zeit (min)';
h.axesTSFitResults.YLabel.String = 'Peak-Position';
h.axesTSFitResults.Title.String  = '— Fit-Ergebnisse —';
h.axesTSFitResults.FontSize      = 9;
box(h.axesTSFitResults,  'on');
grid(h.axesTSFitResults, 'on');

% ── Tab-Wechsel-Callback registrieren ────────────────────
% Muss im Haupt-GUI-Block gesetzt werden (nach Erstellung aller Elemente).
% In deiner GUI-Datei diese Zeile direkt VOR dem abschließenden guidata()
% einfügen — also z.B. direkt vor "guidata(h.myfig, h);"
%
%   h.plottab.SelectionChangedFcn = @tabSelectionChangedCallback;
%
% Der Callback selbst (tabSelectionChangedCallback) ist in Schritt B.

% Slider für Intensitäts-Tab (unter dem Tab)
h.Slider = uicontrol('Style','slider','Tag','Slider','Parent',h.myfig,...
    'Units','normalized',...
    'Position',[RX 0.095 MW*0.72 0.028],...
    'Min',1,'Max',2,'Value',1,'SliderStep',[1 1],...
    'Callback',{@SliderCallbackPlotRawData});

% Checkbox (rechts neben Slider)
h.checkboxplotall = uicontrol(h.myfig,'Style','checkbox','Units','normalized',...
    'Position',[RX+MW*0.74 0.097 MW*0.26 0.026],...
    'String','Plot all profiles','Callback',@plotallprofilescallback);

% Tau-Axes (unter Tab-Gruppe)
h.axesPlottauData = uiaxes(h.myfig,'Units','normalized',...
    'Position',[RX 0.002 MW 0.088]);
h.axesPlottauData.XLim = [-90,90]; h.axesPlottauData.YLimMode = 'auto';
h.axesPlottauData.YLabel.String = '\tau [µm]'; h.axesPlottauData.YLabel.FontSize = 12;
h.axesPlottauData.XLabel.String = [char(947),' °']; h.axesPlottauData.XLabel.FontSize = 12;
grid(h.axesPlottauData,'off'); box(h.axesPlottauData,'on');

% =========================================================
% RECHTER BEREICH
% =========================================================
% Wavelength radio buttons
h.radiobuttonwavelength = uibuttongroup(h.myfig,...
    'Units','normalized',...
    'BorderType','none',...
    'SelectionChangedFcn',@choosewavelengthcallback,...
    'Position',[RX2 0.88 RW 0.09]);
h.rb1 = uicontrol(h.radiobuttonwavelength,'Style','radiobutton','Units','normalized',...
    'Position',[0.02 0.65 0.96 0.30],'String','Ga K-alpha');
h.rb2 = uicontrol(h.radiobuttonwavelength,'Style','radiobutton','Units','normalized',...
    'Position',[0.02 0.33 0.96 0.30],'String','In K-alpha');
h.rb3 = uicontrol(h.radiobuttonwavelength,'Style','radiobutton','Units','normalized',...
    'Position',[0.02 0.02 0.96 0.30],'String','In K-beta');

% Stress-Axes oben rechts
h.axesStressData = uiaxes(h.myfig,'Units','normalized',...
    'Position',[RX2 0.50 RW 0.37]);
h.axesStressData.XLim = [0,Inf]; h.axesStressData.YLimMode = 'auto';
h.axesStressData.YLabel.String = [char(963),' [MPa]']; h.axesStressData.YLabel.FontSize = 14;
h.axesStressData.XLabel.String = [char(964),' [',char(956),'m]']; h.axesStressData.XLabel.FontSize = 14;
grid(h.axesStressData,'on'); box(h.axesStressData,'on');

% Export Buttons
h.ExportFitDataButton = uicontrol(h.myfig,'Style','Pushbutton','Units','normalized',...
    'Position',[RX2 0.458 RW*0.47 0.035],...
    'String','Export Fit Data','Callback',@exportfitdatacallback);
h.ExportStressDataButton = uicontrol(h.myfig,'Style','Pushbutton','Units','normalized',...
    'Position',[RX2+RW*0.50 0.458 RW*0.50 0.035],...
    'String','Export Stress Data','Callback',@exportstressdatacallback);

% FittedPeaks-Axes unten rechts
h.axesFittedPeaks = uiaxes(h.myfig,'Units','normalized',...
    'Position',[RX2 0.13 RW 0.32]);
h.axesFittedPeaks.YLimMode = 'auto'; h.axesFittedPeaks.XLimMode = 'auto';
h.axesFittedPeaks.YLabel.String = 'Intensity [a.u.]'; h.axesFittedPeaks.YLabel.FontSize = 14;
h.axesFittedPeaks.XLabel.String = ['2',char(952),' [°]']; h.axesFittedPeaks.XLabel.FontSize = 14;
box(h.axesFittedPeaks,'on');

% SliderFittedPeaks
h.SliderFittedPeaks = uicontrol('Style','slider','Tag','SliderFittedPeaks',...
    'Parent',h.myfig,'Units','normalized',...
    'Position',[RX2 0.092 RW 0.028],...
    'Min',1,'Max',2,'Value',1,'SliderStep',[1 1],...
    'Callback',{@SliderCallbackFittedPeaks});

% =========================================================
% Plot-Objekte initialisieren
% =========================================================
x = 0; y = 0; err = 0;

h.plotIntensityData     = plot(h.axesPlotIntensityData,x,y,'-','Color','blue','Visible','off');
% h.plotdata              = errorbar(h.axes,x,y,err,'s','Visible','off');
% 
% % fitCentroid Peaklagen (lila, Kreis)
% h.plotdataCentFit = errorbar(h.axes, 0, 0, 0, 'o', ...
%     'Color', [1 0 0], 'Visible', 'off');

% Summenspektrum der gefitteten Peaks
h.plotFitSum = plot(h.axesPlotIntensityData, NaN, NaN, '-', ...
    'Color',     [0.85 0.15 0.15], ...
    'LineWidth', 1.8, ...
    'Visible',   'off', ...
    'Tag',       'fitsumoverlay');

% Einzelne Peak-Komponenten — KEIN fill bei Initialisierung
% wird erst nach dem Fit angelegt
h.plotFitComponents = [];
compColors = lines(10);
for ci = 1:10
    h.plotFitComponents(ci) = fill(h.axesPlotIntensityData, NaN, NaN, ...
        compColors(ci,:), ...
        'FaceAlpha', 0.25, ...
        'EdgeColor', compColors(ci,:), ...
        'LineWidth', 1.2, ...
        'Visible',   'off', ...
        'Tag',       'fitsumoverlay');
end
h.compColors = compColors;

% NEU:
h.plotdata = errorbar(h.axes, x, y, err, 's', ...
    'MarkerSize',       4, ...
    'MarkerFaceColor',  [0.094 0.373 0.647], ...
    'MarkerEdgeColor',  [0.094 0.373 0.647], ...
    'Color',            [0.094 0.373 0.647], ...
    'LineWidth',        0.8, ...
    'Visible',          'off');

h.plotdataCentFit = errorbar(h.axes, 0, 0, 0, 'o', ...
    'MarkerSize',       4.5, ...
    'MarkerFaceColor',  'none', ...
    'MarkerEdgeColor',  [0.60 0.75 0.90], ...
    'Color',            [0.60 0.75 0.90], ...
    'LineWidth',        0.9, ...
    'Visible',          'off');

hold(h.axes,'on');
h.fitcurvestress        = plot(h.axes,0,0,'-','Visible','off');
h.plotdatasin2psi       = errorbar(h.axessin2psi,x,y,err,'s','Visible','off');
hold(h.axessin2psi,'on');
h.fitcurvestresssin2psi = plot(h.axessin2psi,0,0,'-','Visible','off');
h.plotstressdata        = errorbar(h.axesStressData,x,y,err,'s');
hold(h.axesStressData,'on');
h.plotsin2psistressdata = errorbar(h.axesStressData,x,y,err,'o');
h.highlightstressplot   = plot(h.axesStressData,x,y,'s','Color','g',...
    'MarkerFaceColor','g','Visible','off','MarkerSize',12);
h.highlightpeakdata     = plot(h.axes,x,y,'s','Color','g',...
    'MarkerFaceColor','g','Visible','off','MarkerSize',10);
h.plotRawData           = plot(h.axesFittedPeaks,x,y,'o','Color','black',...
    'MarkerFaceColor','black','MarkerSize',6,'Visible','off');
hold(h.axesFittedPeaks,'on');
h.plotFitData           = plot(h.axesFittedPeaks,x,y,'-','Color','red','Visible','off');
h.plottaudata           = plot(h.axesPlottauData,0,0,'s');
hold(h.axesPlottauData,'on');
h.plottaudatamean       = plot(h.axesPlottauData,0,0,'Color','r');

% Initialise default opts in guidata after guidata(h.myfig, h)
% -----------------------------------------------------------------------
% h.trackFitOpts = openTrackFitSettings();   % load defaults silently
% (If you want to pre-fill from a saved file, load it here instead.)

h.trackFitOpts = struct( ...
    'useGauss',                   false,                              ...
    'gaussMinR2',                 0.98,                               ...
    'gaussSigmaRangeDeg',         [0.10  0.80],                       ...
    'windowDeg',                  0.6,                                ...
    'pvoigtFixedEta',             0.5,                                ...
    'pvoigtFallbackToCentroid',   true,                               ...
    'pvoigtMinR2',                0.90,                               ...
    'pvMinR2Auto',                0.85,                               ... % 'Mindest-R² für automatischen Filter (0 = deaktiviert)'
    'pvoigtFwhmRangeDeg',         [0.10  0.80],                       ...
    'pvoigtMuBoundDeg',           0.10,                               ...
    'centroidKBins',              12,                                 ...
    'pvoigtAdaptiveWindow',       false,                              ...
    'pvoigtAdaptiveWindowFactor', 2.5,                                ...
    'pvoigtAdaptiveWindowMinDeg', 0.20,                               ...
    'pvoigtAdaptiveWindowMaxDeg', 0.80,                               ...
    'pvoigtAutoWindow',           false,                              ...
    'pvoigtWindowCandidates',     [0.30 0.35 0.40 0.50 0.55 0.60 0.65 0.70 0.75 0.80],   ...
    'pvoigtAutoWindowUseBestR2',  false                                ...
);

h.tsPeakModel = 'symmetric';   % Default: normale Pseudo-Voigt

% The call will open the dialog at startup – to AVOID that, initialise
% with the struct directly:
%
%   h.trackFitOpts = struct( ...
%       'profileChiRange',  [-150 -80], ...
%       'trackChiBin',      4,          ...
%       ...                             );
%
% Or simply call openTrackFitSettings with no display by reading the
% defaults from the function without showing the dialog (see STEP 4).


% ---- RECOMMENDED: silent default init --------------------------------
% Add this helper at the bottom of the main GUI function (before callbacks):

% h.trackFitOpts = getTrackFitDefaults();   % see STEP 4

h.plottab.SelectionChangedFcn = @tabSelectionChangedCallback;

guidata(h.myfig, h);

function popupmenuCallback(hObj,~)
% Callback for "pop up menu" in create sample panel
h = guidata(hObj);
% Determine the selected data set.
str = get(hObj, 'String');
val = get(hObj, 'Value');

h.PopupValueMpd = str{val};

guidata(hObj,h);

function createsamplecallback(hObj,~)
% Callback for "Open File" pushbutton
h = guidata(hObj);

if strcmp(get(h.SampleFormulaeEditField,'Value'),'Elemental formula')
    errordlg('Please enter formula','Warning');
else
    h.ElementalFormula = get(h.SampleFormulaeEditField,'String');
    h.MPDFileName = h.PopupValueMpd;
    % Set FileName to string and ExPath to UserData of Edit-Field
    [Sample,T] = CreateSampleGUI(h);
    h.T = T;
    h.Sample = Sample;
    
    msgbox({'Sample Created'});
end

% Calculate theoretical peak positions
h.PeaksTheo = CalcPeakPositions2DXRD(h.Sample.Materials.ElementalFormula,h.MPDFileName,'ETA3000',100);

assignin('base','PeaksTheo',h.PeaksTheo)
% Calculate absorption coefficient
Energy{1} = 9.251674; % Gallium k-alpha
Energy{2} = 24.2097; % Indium k-alpha
Energy{3} = 27.2759; % Indium k-beta

h.Energy = Energy;

for k = 1:size(Energy,2)
    h.abscoeff{k} = Sample.Materials.LAC(Energy{k})/10000;
end

set(h.AbscoeffEditField,"String",num2str(round(h.abscoeff{1},6)))

% Wellenlänge speichern (für pyFAI)
% Ga K-alpha: E = 9.2517 keV → λ = hc/E [m]
% hc_eVm = 1.23984193e-6;
% h.lambda_m = hc_eVm / (h.Energy{1} * 1000);  % Energy in keV → eV
h.lambda_m = 1.34143847484e-10;
% h.Energy{1} = 9.251674 keV

guidata(hObj, h);

function openfilecallback(hObj, ~)
h = guidata(hObj);

% --- Dateiauswahl: CBF und TIF unterstützen ---
[file, location] = uigetfile( ...
    {'*.cbf;*.tif;*.tiff', 'Detector images (*.cbf, *.tif)'; ...
     '*.cbf',              'CBF files (*.cbf)'; ...
     '*.tif;*.tiff',       'TIF files (*.tif, *.tiff)'}, ...
    'Select 2D XRD image(s)', ...
    'MultiSelect', 'on', ...
    fullfile(General.ProgramInfo.Path, 'Data', 'Measurements'));

if isequal(file, 0)
    disp('User selected Cancel');
    return
end

% Normalisieren auf Cell-Array
if ~iscell(file)
    file = {file};
end

% Button-Feedback
col = get(hObj, 'backg');
set(hObj, 'String', 'Loading images ...', 'backg', [1 .6 .6]);
pause(0.01);

total_images_selected = numel(file);

% Vollpfade speichern
imgPaths = cell(total_images_selected, 1);
for k = 1:total_images_selected
    imgPaths{k} = fullfile(location, file{k});
end

h.FileNameLoad = file;
h.imgPaths     = imgPaths;
h.imgLocation  = location;
h.BinSize      = str2double(get(h.trackChiBinEdit, 'String'));

set(h.FileNameEditField, 'String', strjoin(string(file), ', '));

% guidata speichern BEVOR SliderCallback aufgerufen wird
guidata(hObj, h);

% --- Slider konfigurieren ---
if total_images_selected > 1
    set(h.SliderRawImages, ...
        'Min',        1, ...
        'Max',        total_images_selected, ...
        'Value',      1, ...
        'SliderStep', [1/max(total_images_selected-1, 1) ...
                       1/max(total_images_selected-1, 1)], ...
        'Enable',     'on');
else
    set(h.SliderRawImages, ...
        'Min',        1, ...
        'Max',        2, ...
        'Value',      1, ...
        'SliderStep', [1 1], ...
        'Enable',     'off');
end

% --- Erstes Bild anzeigen (über SliderCallback) ---
set(h.SliderRawImages, 'Value', 1);
SliderCallbackRawImage(h.SliderRawImages, []);

% Tab aktivieren
h.plottab.SelectedTab = h.plottab7;

fprintf('Geladen: %d Bild(er) aus %s\n', total_images_selected, location);

% Button zurücksetzen
set(hObj, 'String', 'Load 2D image(s)', 'backg', col);

guidata(hObj, h);

function opengammafilecallback(hObj, ~)
h = guidata(hObj);

% =====================================================================
% Sicherheitscheck
% =====================================================================
if ~isfield(h, 'imgPaths') || isempty(h.imgPaths)
    errordlg('Please load 2D images first.', 'No images loaded');
    return
end

% =====================================================================
% PONI-Files auswählen
% =====================================================================
[poniFiles, poniLocation] = uigetfile('*.poni', ...
    'Select PONI files (same order as images)', ...
    'MultiSelect', 'on', ...
    fullfile(General.ProgramInfo.Path, 'Data', 'Measurements'));

if isequal(poniFiles, 0)
    disp('User selected Cancel');
    return
end
if ~iscell(poniFiles)
    poniFiles = {poniFiles};
end
if numel(poniFiles) ~= numel(h.imgPaths)
    errordlg(sprintf(...
        'Number of PONI files (%d) must match number of images (%d).', ...
        numel(poniFiles), numel(h.imgPaths)), 'Count mismatch');
    return
end

% Vollpfade PONI
poniPaths = cell(numel(poniFiles), 1);
for k = 1:numel(poniFiles)
    poniPaths{k} = fullfile(poniLocation, poniFiles{k});
end

% Alpha-Winkel aus Dateinamen parsen
alpha_tmp = zeros(1, numel(poniFiles));
for k = 1:numel(poniFiles)
    tok = regexp(poniFiles{k}, '(?<=alpha)([\d.+-]+)(?=.poni)', 'match');
    if ~isempty(tok)
        alpha_tmp(k) = str2double(tok{1});
    else
        alpha_tmp(k) = 0;
    end
end
h.alpha = unique(alpha_tmp);
set(h.AlphaEditField,        'String', strjoin(string(h.alpha),    ', '));
set(h.GammaFileNameEditField,'String', strjoin(string(poniFiles),  ', '));

% ── Zuordnung Bild → PONI → Alpha ausgeben ───────────────────────────
fprintf('\n── Bild → PONI Zuordnung ─────────────────────────────────────\n');
fprintf('%-5s  %-45s  %-45s  %s\n', 'Nr.', 'Bild', 'PONI', 'Alpha (°)');
fprintf('%s\n', repmat('-', 1, 105));
for k = 1:numel(h.imgPaths)
    [~, imgName, imgExt] = fileparts(h.imgPaths{k});
    [~, poniName, poniExt] = fileparts(poniPaths{k});
    fprintf('%-5d  %-45s  %-45s  %.2f\n', ...
        k, [imgName imgExt], [poniName poniExt], alpha_tmp(k));
end
fprintf('%s\n\n', repmat('-', 1, 105));

% Button-Feedback
col = get(hObj, 'backg');
set(hObj, 'String', 'Running pyFAI ...', 'backg', [1 .6 .6]);
pause(0.01);

% =====================================================================
% Wellenlänge
% =====================================================================
if isfield(h, 'lambda_m')
    lambda_m = h.lambda_m;
else
    hc_eVm   = 1.23984193e-6;
    lambda_m = hc_eVm / 9251.7;
end

% =====================================================================
% Wellenlängen-Index bestimmen
% =====================================================================
selectedWL = get(h.radiobuttonwavelength.SelectedObject, 'String');
if strcmp(selectedWL, 'Ga K-alpha'),     wlIdx = 1;
elseif strcmp(selectedWL, 'In K-alpha'), wlIdx = 2;
else,                                    wlIdx = 3;
end

% =====================================================================
% pyFAI Konfiguration
% =====================================================================
cfg = struct();
imgLoc = h.imgLocation;
if imgLoc(end) == filesep
    imgLoc = imgLoc(1:end-1);
end
[~, folderName, ~] = fileparts(imgLoc);

dateStr = char(datetime('now', 'Format', 'yyyyMMdd'));
runNum  = 1;
while exist(fullfile(h.imgLocation, ...
        sprintf('%s_pyfai_%s_%02d', dateStr, folderName, runNum)), 'dir') || ...
      ~isempty(dir(fullfile(h.imgLocation, ...
        sprintf('%s_pyfai_%s_%02d*', dateStr, folderName, runNum))))
    runNum = runNum + 1;
end
cfg.outBase          = fullfile(h.imgLocation, ...
    sprintf('%s_pyfai_%s_%02d', dateStr, folderName, runNum));
cfg.mode             = '2d';
cfg.unit             = '2th_deg';
cfg.npt_rad          = 3000;
cfg.npt_azim         = 360;
cfg.method           = 'csr';
cfg.pythonExe        = strtrim(get(h.pythonExeEdit,  'String'));
cfg.scriptPath       = strtrim(get(h.scriptPathEdit, 'String'));
cfg.mask_path        = '';
cfg.save_raw_stack   = false;
cfg.save_ring_image  = false;
cfg.save_ring_det    = false;
cfg.ring_npt_tth     = 1500;
cfg.ring_npt_chi     = 360;
cfg.ring_tth_max_deg = 60.0;
cfg.ring_chi_min_deg = -180.0;
cfg.ring_chi_max_deg =  180.0;
cfg.ring_output_size = 2000;

if isfield(h, 'PeakPos') && ~isempty(h.PeakPos)
    cfg.peak_pos_deg = h.PeakPos{wlIdx};
    cfg.peak_tol_deg = 0.05;
    fprintf('Peaklagen verfügbar: %d Peaks → Ring-Peaks werden berechnet.\n', ...
        numel(cfg.peak_pos_deg));
else
    cfg.peak_pos_deg = [];
    fprintf('Keine Peaklagen verfügbar – Ring-Peaks beim zweiten Durchlauf.\n');
end

% =====================================================================
% pyFAI MultiGeometry ausführen (kombiniert — für Ring-Bild etc.)
% =====================================================================
try
    out = run_pyfai_multigeometry_from_matlab(...
        h.imgPaths, poniPaths, lambda_m, cfg);
catch ME
    set(hObj, 'String', 'Load Gamma Data File', 'backg', col);
    errordlg(sprintf('pyFAI failed:\n%s', ME.message), 'pyFAI Error');
    return
end

% ── Temporäre Job-Datei löschen ──────────────────────────────────────
jobFile = [cfg.outBase '_job.json'];
if exist(jobFile, 'file')
    delete(jobFile);
end

h.pyfaiOut  = out;
h.poniPaths = poniPaths;
outBase     = cfg.outBase;

% =====================================================================
% Theoretische Peaks berechnen
% =====================================================================
if isfield(h, 'PeaksTheo')
    tthMin = double(min(out.radial));
    tthMax = double(max(out.radial));
    for k = 1:size(h.PeaksTheo, 2)
        PeakPostmp = mean(h.PeaksTheo{k}.Peaks(:, 5:6), 2)';
        idx        = (PeakPostmp >= tthMin) & (PeakPostmp <= tthMax);
        PeakPos{k} = PeakPostmp(idx);
        hkl{k}     = h.PeaksTheo{k}.Peaks(idx, 1:3);
        for i = 1:size(hkl{k}, 1)
            rowsAsStrings{k}{i} = strtrim(sprintf('%g %g %g', hkl{k}(i,:)));
        end
        hkltabledata{k} = [hkl{k} PeakPos{k}' zeros(length(PeakPos{k}), 2)];
    end
    h.PeakPos       = PeakPos;
    h.rowsAsStrings = rowsAsStrings;
end

% =====================================================================
% Rohbild-Median für Normierung
% =====================================================================
rawMedian = [];
try
    [~, ~, ext] = fileparts(h.imgPaths{1});
    pythonExe   = strtrim(get(h.pythonExeEdit, 'String'));
    if strcmpi(ext, '.cbf')
        img1 = loadCBF(h.imgPaths{1}, pythonExe);
    else
        img1 = double(imread(h.imgPaths{1}));
    end
    imgLog1   = log10(1 + max(img1, 0));
    rawMedian = median(imgLog1(isfinite(imgLog1) & imgLog1 > 0), 'all');
    fprintf('Raw image Median (log): %.4f\n', rawMedian);
catch ME
    warning('Rohbild-Normierung fehlgeschlagen: %s', strrep(ME.message,'%', '%%'));
end

% =====================================================================
% Variante 1: Rohdaten-Stapel
% =====================================================================
rawStackPath = [outBase '_raw_stack.mat'];
if cfg.save_raw_stack && exist(rawStackPath, 'file')
    try
        raw    = load(rawStackPath);
        imgLog = log10(1 + max(raw.imgs_mean, 0));
        v      = imgLog(isfinite(imgLog) & imgLog > 0);
        clims  = prctile(v, [1 99]);
        figure('Name', 'Raw Mean Image');
        imagesc(imgLog); clim(clims); colorbar;
        axis image; colormap(gca, 'hot');
        title('Raw mean image (log_{10}(1+I))');
    catch ME
        warning('[RawStack] %s', strrep(ME.message,'%', '%%'));
    end
end

% =====================================================================
% Variante 2: Reassembled Ringbild
% =====================================================================
ringPath = [outBase '_ring.mat'];
if cfg.save_ring_image && exist(ringPath, 'file')
    try
        ring   = load(ringPath);
        imgLog = log10(1 + max(ring.ring_mean, 0));
        v      = imgLog(isfinite(imgLog) & imgLog > 0);
        clims  = prctile(v, [1 99]);
        figure('Name', 'Ring Image (Reassembled)');
        imagesc(ring.tth_centers, ring.chi_centers, imgLog);
        clim(clims); set(gca, 'YDir', 'normal');
        colorbar; colormap(gca, 'hot');
        xlabel(['2',char(952),' °']); ylabel('\chi (deg)');
        title('Ring image – log_{10}(1+I)');
    catch ME
        warning('[RingImage] %s', strrep(ME.message,'%', '%%'));
    end
end

% =====================================================================
% Variante 3: Pixel-Ringbild (ring_det)
% =====================================================================
ringDetPath  = [outBase '_ring_det.mat'];
ringPeakPath = [outBase '_ring_peaks.mat'];
ringDet      = [];
ringDetOpts  = struct();

if exist(ringDetPath, 'file')
    try
        ringDet                       = load(ringDetPath);
        ringDetOpts.useLog            = true;
        ringDetOpts.logStrength       = 1;
        ringDetOpts.climPct           = [1 99];
        ringDetOpts.rawMedian         = rawMedian;
        ringDetOpts.useGeometricRings = false;

        if isfield(ringDet, 'sdd_mm')
            ringDetOpts.sdd_mm      = ringDet.sdd_mm;
            ringDetOpts.center_x_mm = ringDet.center_x_mm;
            ringDetOpts.center_y_mm = ringDet.center_y_mm;
        end
        if isfield(h, 'PeakPos') && ~isempty(h.PeakPos)
            ringDetOpts.peakPos    = h.PeakPos{wlIdx};
            ringDetOpts.peakLabels = h.rowsAsStrings{wlIdx};
        end
        if exist(ringPeakPath, 'file')
            ringDetOpts.ringPeakData = load(ringPeakPath);
            fprintf('Ring peak positions geladen: %s\n', ringPeakPath);
        else
            ringDetOpts.ringPeakData = [];
        end

        plotRingDetInAxes(h.axesRingDet, ringDet, ringDetOpts);
        h.plottab.SelectedTab = h.plottab6;
        fprintf('Ring detector image geladen: %s\n', ringDetPath);
    catch ME
        errordlg(sprintf('[RingDet] %s', ME.message), 'RingDet Error');
    end
end

% =====================================================================
% Ring-Peaks nachträglich berechnen
% =====================================================================
if cfg.save_ring_det && ~exist(ringPeakPath, 'file') && ...
   ~isempty(h.PeakPos) && ~isempty(ringDet)
    try
        fprintf('Berechne Ring-Peak-Positionen ...\n');
        pythonExe  = strtrim(get(h.pythonExeEdit, 'String'));
        scriptPath = strtrim(get(h.scriptPathEdit, 'String'));

        ringPeakJob              = struct();
        ringPeakJob.img_paths    = h.imgPaths;
        ringPeakJob.poni_paths   = poniPaths;
        ringPeakJob.wavelength_m = lambda_m;
        ringPeakJob.peak_pos_deg = h.PeakPos{wlIdx};
        ringPeakJob.peak_tol_deg = 0.05;
        ringPeakJob.out_mat      = [outBase '.mat'];
        ringPeakJob.out_npz      = [outBase '.npz'];

        jobPath = [outBase '_ring_peaks_job.json'];
        fid = fopen(jobPath, 'w');
        fprintf(fid, '%s', jsonencode(ringPeakJob));
        fclose(fid);

        cmd = sprintf('"%s" "%s" "%s" 2>&1', ...
            pythonExe, ...
            fullfile(fileparts(scriptPath), 'pyfai_ring_peaks_only.py'), ...
            jobPath);
        [status, cmdout] = system(cmd);

        if status ~= 0
            warning('[RingPeaks] %s', cmdout);
        else
            fprintf('Ring-Peaks berechnet: %s\n', ringPeakPath);
            if exist(ringPeakPath, 'file')
                ringDetOpts.ringPeakData = load(ringPeakPath);
                plotRingDetInAxes(h.axesRingDet, ringDet, ringDetOpts);
                fprintf('Ring-Plot aktualisiert.\n');
            end
        end
    catch ME
        warning('[RingPeaks] %s', strrep(ME.message,'%', '%%'));
    end
end

% =====================================================================
% Pro Alpha-Gruppe separat integrieren
% =====================================================================
uniqueAlpha      = unique(alpha_tmp);
nAlpha           = numel(uniqueAlpha);
pyfaiOutPerAlpha = cell(1, nAlpha);

for ka = 1:nAlpha
    alphaVal = uniqueAlpha(ka);
    idxGroup = find(alpha_tmp == alphaVal);
    fprintf('Alpha = %.2f°: %d Bild(er)\n', alphaVal, numel(idxGroup));

    cfgAlpha         = cfg;
    cfgAlpha.outBase = sprintf('%s_alpha%g', cfg.outBase, alphaVal);

    try
        outAlpha             = run_pyfai_multigeometry_from_matlab( ...
            h.imgPaths(idxGroup), poniPaths(idxGroup), lambda_m, cfgAlpha);
        pyfaiOutPerAlpha{ka} = outAlpha;
        fprintf('  → Integration OK\n');
        % ── Temporäre Job-Datei löschen ──────────────────────────────
        jobFile = [cfgAlpha.outBase '_job.json'];
        if exist(jobFile, 'file')
            delete(jobFile);
        end
    catch ME
        set(hObj, 'String', 'Load PONI Files', 'backg', col);
        errordlg(sprintf('pyFAI failed für alpha=%.2f:\n%s', ...
            alphaVal, ME.message), 'pyFAI Error');
        return
    end
end

% =====================================================================
% caked_mask pro Alpha-Gruppe übertragen
% Priorität: alpha-spezifische Maske > kombinierte Maske
% =====================================================================
% ── caked_mask pro Alpha-Gruppe übertragen ───────────────────────────
for ka = 1:nAlpha
    alphaVal = uniqueAlpha(ka);

    % Direkt aus pyfaiOutPerAlpha{ka} den matPath lesen
    % und daraus den caked_mask Pfad ableiten
    maskLoaded = false;

    if ~isempty(pyfaiOutPerAlpha{ka}) && ...
       isfield(pyfaiOutPerAlpha{ka}, 'matPath')
        matPathAlpha = pyfaiOutPerAlpha{ka}.matPath;
        maskFile     = strrep(matPathAlpha, '.mat', '_caked_mask.mat');

        if exist(maskFile, 'file')
            try
                maskData = load(maskFile);
                pyfaiOutPerAlpha{ka}.caked_mask     = maskData.caked_mask;
                pyfaiOutPerAlpha{ka}.valid_fraction = maskData.valid_fraction;
                fprintf('  Alpha %.1f°: caked_mask geladen: %s\n', ...
                    alphaVal, maskFile);
                maskLoaded = true;
            catch ME
                warning('caked_mask laden: %s', strrep(ME.message,'%', '%%'));
            end
        else
            fprintf('  Alpha %.1f°: caked_mask Datei nicht gefunden: %s\n', ...
                alphaVal, maskFile);
        end
    end

    % Fallback: kombinierte Maske
    if ~maskLoaded
        if isfield(out, 'caked_mask') && ~isempty(out.caked_mask)
            pyfaiOutPerAlpha{ka}.caked_mask     = out.caked_mask;
            pyfaiOutPerAlpha{ka}.valid_fraction = out.valid_fraction;
            fprintf('  Alpha %.1f°: Fallback auf kombinierte caked_mask\n', alphaVal);
        end
    end
end

% =====================================================================
% h-Felder setzen
% =====================================================================
h.pyfaiOut    = pyfaiOutPerAlpha;
h.alpha       = alpha_tmp;
h.uniqueAlpha = uniqueAlpha;
h.poniPaths   = poniPaths;

% =====================================================================
% Binning pro Alpha-Gruppe
% =====================================================================
h = runBinning(h, pyfaiOutPerAlpha);

fprintf('Nach runBinning: BinnedGammaValid hat %d Gruppen\n', ...
    numel(h.BinnedGammaValid));
for dbk = 1:numel(h.BinnedGammaValid)
    fprintf('  Gruppe %d: %d Bins, %d ungültig\n', ...
        dbk, numel(h.BinnedGammaValid{dbk}), ...
        sum(~h.BinnedGammaValid{dbk}));
end

if isfield(h,'RebinButton') && isvalid(h.RebinButton)
    set(h.RebinButton, 'Enable', 'on');
end

% =====================================================================
% Caked Images pro Alpha-Gruppe erzeugen
% =====================================================================
h.cakedImages = cell(1, nAlpha);

for ka = 1:nAlpha
    outAlpha_ck = pyfaiOutPerAlpha{ka};
    if isempty(outAlpha_ck), continue; end

    caked2dOpts             = struct();
    caked2dOpts.showAxis    = 'tth';
    caked2dOpts.useLog      = true;
    caked2dOpts.logStrength = 1;
    caked2dOpts.climPct     = [1 99];
    caked2dOpts.saveTif     = true;
    caked2dOpts.resolution  = 300;
    caked2dOpts.rawMedian   = rawMedian;

    if isfield(h, 'PeakPos') && ~isempty(h.PeakPos)
        caked2dOpts.peakPos    = h.PeakPos{wlIdx};
        caked2dOpts.peakLabels = h.rowsAsStrings{wlIdx};
    end

    alphaIdxGroup       = find(alpha_tmp == uniqueAlpha(ka), 1, 'first');
    [~, baseName_ck, ~] = fileparts(h.FileNameLoad{alphaIdxGroup});
    caked2dOpts.tifPath = fullfile(h.imgLocation, ...
        sprintf('%s_alpha%g_caked2D.tif', ...
        strrep(baseName_ck, ' ', '_'), uniqueAlpha(ka)));

    h.cakedImages{ka} = struct( ...
        'out',      outAlpha_ck, ...
        'opts',     caked2dOpts, ...
        'alphaVal', uniqueAlpha(ka));

    try
        plotCaked2DInAxes(h.axesCaked2D, outAlpha_ck, caked2dOpts);
    catch ME
        warning('[CakedImage] Alpha=%.2f: %s', ...
            uniqueAlpha(ka), strrep(ME.message, '%', '%%'));
    end
end

% Erstes Bild anzeigen
if ~isempty(h.cakedImages) && ~isempty(h.cakedImages{1})
    opts_display         = h.cakedImages{1}.opts;
    opts_display.saveTif = false;
    try
        plotCaked2DInAxes(h.axesCaked2D, h.cakedImages{1}.out, opts_display);
        h.axesCaked2D.Title.String = sprintf(...
            'Caked Image  –  \\alpha = %.1f°  (1/%d)', ...
            h.cakedImages{1}.alphaVal, nAlpha);
    catch
    end
end

if isfield(h,'SliderCakedImages') && isvalid(h.SliderCakedImages)
    if nAlpha > 1
        set(h.SliderCakedImages, ...
            'Min',        1, ...
            'Max',        nAlpha, ...
            'Value',      1, ...
            'SliderStep', [1/max(nAlpha-1,1)  1/max(nAlpha-1,1)], ...
            'Enable',     'on');
    else
        set(h.SliderCakedImages, 'Enable', 'off');
    end
end

h.plottab.SelectedTab = h.plottab5;

% =====================================================================
% Button zurücksetzen
% =====================================================================
set(hObj, 'String', 'Load Gamma Data File', 'backg', col);

% =====================================================================
% DEC-Daten laden
% =====================================================================
MatName  = h.Sample.Materials.Name;
FileName = ['DEKListe' MatName '.mat'];
Path     = fullfile(getAppRoot(), 'Data', 'Materials');
if exist([Path FileName], 'file')
    DEKMatFile    = load([Path FileName]);
    DEKdatatmp{1} = get(h.dekdataGaKalpha, 'data');
    DEKdatatmp{2} = get(h.dekdataInKalpha, 'data');
    DEKdatatmp{3} = get(h.dekdataInKbeta,  'data');

    for m = 1:size(DEKdatatmp, 2)
        hklDEKtmp = zeros(1, length(DEKdatatmp{m}(:,1)));
        for k = 1:length(DEKdatatmp{m}(:,1))
            hklDEKtmp(k) = DEKdatatmp{m}(k,1)*100 + ...
                           DEKdatatmp{m}(k,2)*10  + ...
                           DEKdatatmp{m}(k,3);
        end
        hklDEKtmp   = hklDEKtmp';
        IndexHittmp = cell(size(DEKMatFile.DEK,1), length(hklDEKtmp));
        for l = 1:length(hklDEKtmp)
            for k = 1:size(DEKMatFile.DEK, 1)
                IndexHittmp{k,l} = strcmp(num2str(hklDEKtmp(l,1)), ...
                                          num2str(DEKMatFile.DEK(k,1)));
            end
        end
        IndexHittmp = cell2mat(IndexHittmp);
        for k = 1:size(DEKdatatmp{m}, 1)
            if isempty(DEKMatFile.DEK(IndexHittmp(:,k), 2:3))
                DEKdatatmp{m}(k, 5:6) = [0 0];
            else
                DEKdatatmp{m}(k, 5:6) = DEKMatFile.DEK(IndexHittmp(:,k), 2:3);
            end
        end
    end
    set(h.dekdataGaKalpha, 'data', DEKdatatmp{1});
    set(h.dekdataInKalpha, 'data', DEKdatatmp{2});
    set(h.dekdataInKbeta,  'data', DEKdatatmp{3});
    uiwait(msgbox(sprintf('DEC data found and loaded. Check if data is correct.\n%s', '.')));
else
    uiwait(msgbox(sprintf('Warning: no DEC data found. Define manually.\n%s', '.'), ...
        'Warning', 'error'));
end

guidata(hObj, h);

function plotallprofilescallback(hObj,~)
% Callback for "pop up menu" in create sample panel
h = guidata(hObj);
% Determine the selected data set.
val = get(hObj, 'Value');

value = get(h.Slider,'value');
% assignin('base','h1',h)
if val == 1
    % ydata = h.dataY{:};
    % xdata = repmat(h.dataX{:},1,49);
    delete(h.plotIntensityData);
    h.plotIntensityData = plot(h.axesPlotIntensityData,h.dataXPlot,h.dataYPlot,'-','Color','blue','Visible','on');
    % set(h.plotIntensityData,'Xdata',h.dataXPlot)
    % set(h.plotIntensityData,'Ydata',h.dataYPlot)
elseif val == 0
    delete(h.plotIntensityData);
    h.plotIntensityData = plot(h.axesPlotIntensityData,h.dataXPlot(:,value),h.dataYPlot(:,value),'-','Color','blue','Visible','on');
    % set(h.plotIntensityData,'Xdata',h.dataXPlot(:,value))
    % set(h.plotIntensityData,'Ydata',h.dataYPlot(:,value))
end

guidata(hObj,h);

function changetwothetarangecallback(hObj,~)
h = guidata(hObj);

value = get(h.Slider,'value');

twothetamin = str2double(get(h.twothetaminEditField,'String'));
twothetamax = str2double(get(h.twothetamaxEditField,'String'));

% --- Eingabe validieren ---
if isnan(twothetamin) || isnan(twothetamax)
    errordlg('Bitte gültige Zahlenwerte für den 2theta-Bereich eingeben.','Eingabefehler');
    return
end
if twothetamin >= twothetamax
    errordlg('2theta min muss kleiner als 2theta max sein.','Eingabefehler');
    return
end

% ── Gemeinsamen 2theta-Bereich aller Alpha-Gruppen prüfen ─────────────
xMinPerGroup = cellfun(@(x) min(x), h.dataXBackup);
xMaxPerGroup = cellfun(@(x) max(x), h.dataXBackup);

commonMin = max(xMinPerGroup);   % größtes Minimum = gemeinsamer Startpunkt
commonMax = min(xMaxPerGroup);   % kleinstes Maximum = gemeinsamer Endpunkt

outsideMin = twothetamin < commonMin;
outsideMax = twothetamax > commonMax;

if outsideMin || outsideMax
    warnMsg = sprintf(['Der gewählte 2\x03B8-Bereich [%.3f°, %.3f°] liegt\n' ...
        'außerhalb des gemeinsamen Bereichs aller Alpha-Gruppen.\n\n' ...
        'Verfügbare Bereiche pro Gruppe:\n'], twothetamin, twothetamax);

    for kg = 1:numel(h.dataXBackup)
        warnMsg = [warnMsg, sprintf('  Alpha-Gruppe %d (α=%.1f°): %.3f° – %.3f°\n', ...
            kg, h.uniqueAlpha(kg), xMinPerGroup(kg), xMaxPerGroup(kg))]; %#ok<AGROW>
    end

    warnMsg = [warnMsg, sprintf(['\nEmpfohlener gemeinsamer Bereich:\n' ...
        '  2\x03B8-min \x2265 %.3f°\n  2\x03B8-max \x2264 %.3f°\n\n' ...
        'Trotzdem fortfahren?\n' ...
        '(Gruppen ohne Daten im gewählten Bereich werden übersprungen.)'], ...
        commonMin, commonMax)];

    answer = questdlg(warnMsg, ...
        '2\theta-Bereich außerhalb gemeinsamer Daten', ...
        'Fortfahren', 'Abbrechen', 'Empfohlenen Bereich verwenden', ...
        'Empfohlenen Bereich verwenden');

    switch answer
        case 'Abbrechen'
            return
        case 'Empfohlenen Bereich verwenden'
            twothetamin = commonMin;
            twothetamax = commonMax;
            set(h.twothetaminEditField, 'String', sprintf('%.3f', twothetamin));
            set(h.twothetamaxEditField, 'String', sprintf('%.3f', twothetamax));
        case 'Fortfahren'
            % weiter mit den eingegebenen Werten
        otherwise
            return
    end
end

dataXBackup = h.dataXBackup;

% NEU:
nGroups = numel(h.dataXBackup);
idxMin_perGroup = zeros(1, nGroups);
idxMax_perGroup = zeros(1, nGroups);

for kg = 1:nGroups
    xg = h.dataXBackup{kg};
    % Bereich auf tatsächlich vorhandene Daten einschränken
    tthMinClamped = max(twothetamin, min(xg));
    tthMaxClamped = min(twothetamax, max(xg));

    if tthMinClamped >= tthMaxClamped
        % Kein Überlapp — gesamten Bereich verwenden
        idxMin_perGroup(kg) = 1;
        idxMax_perGroup(kg) = numel(xg);
        fprintf('Warnung: Gruppe %d (α=%.1f°) hat keinen Überlapp mit [%.3f°, %.3f°] → voller Bereich.\n', ...
            kg, h.uniqueAlpha(kg), twothetamin, twothetamax);
    else
        idxMin_perGroup(kg) = Tools.Data.DataSetOperations.FindNearestIndex(xg, tthMinClamped);
        idxMax_perGroup(kg) = Tools.Data.DataSetOperations.FindNearestIndex(xg, tthMaxClamped);
        idxMin_perGroup(kg) = max(1, idxMin_perGroup(kg));
        idxMax_perGroup(kg) = min(numel(xg), idxMax_perGroup(kg));
    end
end

h.idxtwothetamin          = idxMin_perGroup(1);
h.idxtwothetamax          = idxMax_perGroup(1);
h.idxtwothetamin_perGroup = idxMin_perGroup;
h.idxtwothetamax_perGroup = idxMax_perGroup;

dataXmod = cell(1, nGroups);
dataYmod = cell(1, nGroups);
for kg = 1:nGroups
    iL = idxMin_perGroup(kg);
    iR = idxMax_perGroup(kg);
    dataXmod{kg} = h.dataXBackup{kg}(iL:iR, :);
    dataYmod{kg} = h.IntensityProfiles{kg}(iL:iR, :);
end

% dataXPlot / dataYPlot global zusammenführen
% Jede Gruppe kann unterschiedlich viele Zeilen haben → kleinsten gemeinsamen Bereich nehmen
nRowsPerGroup = cellfun(@(x) size(x,1), dataXmod);
nRowsMin      = min(nRowsPerGroup);

dataXmod_trimmed = cellfun(@(x) x(1:nRowsMin, :), dataXmod, 'UniformOutput', false);
dataYmod_trimmed = cellfun(@(x) x(1:nRowsMin, :), dataYmod, 'UniformOutput', false);

dataXplotmod = cell2mat(cellfun(@(x, y) repmat(x, 1, size(y,2)), ...
    dataXmod_trimmed, dataYmod_trimmed, 'UniformOutput', false));
dataYplotmod = cell2mat(dataYmod_trimmed);

% dataX / dataY mit getrimmten Versionen aktualisieren
dataXmod = dataXmod_trimmed;
dataYmod = dataYmod_trimmed;

h.dataX     = dataXmod;
h.dataXPlot = dataXplotmod;
h.dataY     = dataYmod;
h.dataYPlot = dataYplotmod;

delete(h.plotIntensityData);

% ── Slider-Wert auf gültige Spaltenanzahl begrenzen ──────────────────
nCols = size(dataXplotmod, 2);
value = max(1, min(round(value), nCols));
set(h.Slider, 'Value', value);

if get(h.checkboxplotall,'value') == 1
    h.plotIntensityData = plot(h.axesPlotIntensityData, dataXplotmod, dataYplotmod, '-', 'Color','blue','Visible','on');
else
    h.plotIntensityData = plot(h.axesPlotIntensityData, dataXplotmod(:,value), dataYplotmod(:,value), '-', 'Color','blue','Visible','on');
end

h.axesPlotIntensityData.XLim = [twothetamin twothetamax];

% -------------------------------------------------------
% BUG FIX: vorher war hier immer h.PeaksTheo{1} statt
% h.PeaksTheo{k} — dadurch wurden bei In K-alpha und
% In K-beta immer die falschen Peakpositionen angezeigt
% -------------------------------------------------------
for k = 1:size(h.PeaksTheo,2)
    PeakPostmp = h.PeaksTheo{k}.Peaks(:,5:6);
    PeakPostmp = mean(PeakPostmp,2)';
    idx = (PeakPostmp >= round(min(h.dataX{1}))) & ...
          (PeakPostmp <= round(max(h.dataX{1})));
    PeakPos{k} = PeakPostmp(idx);

    % rowsAsStringsFull nur beim ERSTEN Aufruf aufbauen
    if ~isfield(h,'rowsAsStringsFull') || numel(h.rowsAsStringsFull) < k
        % hkl-Strings aus PeaksTheo generieren — Spalten 1:3 sind h,k,l
        hklMat = h.PeaksTheo{k}.Peaks(:,1:3);
        fullStrings = cell(size(hklMat,1),1);
        for r = 1:size(hklMat,1)
            fullStrings{r} = sprintf('%d%d%d', ...
                hklMat(r,1), hklMat(r,2), hklMat(r,3));
        end
        h.rowsAsStringsFull{k} = fullStrings;
    end

    % Gefilterte hkl-Strings aus Full-Backup
    rowsAsStrings{k} = h.rowsAsStringsFull{k}(idx);
end

% rowsAsStrings aktualisieren — aber rowsAsStringsFull NICHT überschreiben
h.PeakPos       = PeakPos;
h.rowsAsStrings = rowsAsStrings;

delete(h.plotpeakstheo)

selectedWavelength = get(h.radiobuttonwavelength.SelectedObject,'String');

if strcmp(selectedWavelength,'Ga K-alpha')
    h.plotpeakstheo = xline(h.axesPlotIntensityData, PeakPos{1}, '--r', rowsAsStrings{1}, ...
        'LabelVerticalAlignment','middle','LabelHorizontalAlignment','left');
elseif strcmp(selectedWavelength,'In K-alpha')
    h.plotpeakstheo = xline(h.axesPlotIntensityData, PeakPos{2}, '--r', rowsAsStrings{2}, ...
        'LabelVerticalAlignment','middle','LabelHorizontalAlignment','left');
elseif strcmp(selectedWavelength,'In K-beta')
    h.plotpeakstheo = xline(h.axesPlotIntensityData, PeakPos{3}, '--r', rowsAsStrings{3}, ...
        'LabelVerticalAlignment','middle','LabelHorizontalAlignment','left');
end

% ── DEK-Tabellen auf neuen 2theta-Bereich einschränken ───────────────
dekHandles = {h.dekdataGaKalpha, h.dekdataInKalpha, h.dekdataInKbeta};
for ti = 1:3
    currentData = get(dekHandles{ti}, 'Data');
    if isempty(currentData), continue; end

    % E-theo Spalte (Spalte 4) gegen neuen 2theta-Bereich filtern
    if iscell(currentData)
        eTheoCol = cellfun(@(x) ...
            (isnumeric(x) && isscalar(x) && isfinite(x)) * x, ...
            currentData(:,4));
    else
        eTheoCol = currentData(:,4);
    end

    idxInRange = (eTheoCol >= twothetamin) & (eTheoCol <= twothetamax);

    % Nur wenn mindestens ein Peak im Bereich liegt
    if any(idxInRange)
        set(dekHandles{ti}, 'Data', currentData(idxInRange, :));
    end
end

% ── tableDECFittedPeaks ebenfalls filtern (falls bereits gefittet) ────
if isfield(h, 'DEKdataMatchedPeaks') && ~isempty(h.DEKdataMatchedPeaks)
    currentFitted = get(h.tableDECFittedPeaks, 'Data');
    if ~isempty(currentFitted)
        % Spalte 1 = E-fitted (gefittete Peakposition)
        if iscell(currentFitted)
            eFittedCol = cellfun(@(x) ...
                (isnumeric(x) && isscalar(x) && isfinite(x)) * x, ...
                currentFitted(:,1));
        else
            eFittedCol = currentFitted(:,1);
        end

        idxFitInRange = (eFittedCol >= twothetamin) & ...
                        (eFittedCol <= twothetamax);
        if any(idxFitInRange)
            set(h.tableDECFittedPeaks, 'Data', currentFitted(idxFitInRange,:));

            % DEKdataMatchedPeaks synchron halten
            h.DEKdataMatchedPeaks = h.DEKdataMatchedPeaks(idxFitInRange,:);
        end
    end
end

% ── Dropdown in tableDECFittedPeaks aktualisieren ─────────────────────
% Nur die E-theo Werte anbieten die im neuen 2theta-Bereich liegen
selectedWL = get(h.radiobuttonwavelength.SelectedObject,'String');
if strcmp(selectedWL,'Ga K-alpha'),     wlDek = get(h.dekdataGaKalpha,'Data');
elseif strcmp(selectedWL,'In K-alpha'), wlDek = get(h.dekdataInKalpha,'Data');
else,                                   wlDek = get(h.dekdataInKbeta, 'Data');
end

if ~isempty(wlDek)
    if iscell(wlDek)
        allEtheo = cellfun(@(x) ...
            (isnumeric(x) && isscalar(x) && isfinite(x)) * x, wlDek(:,4));
    else
        allEtheo = wlDek(:,4);
    end
    allEtheo = unique(allEtheo(allEtheo > 0));
    dropdownOptions = cellfun(@num2str, num2cell(allEtheo), 'UniformOutput',false);

    currentFmtData = get(h.tableDECFittedPeaks, 'Data');
    if ~isempty(currentFmtData)
        set(h.tableDECFittedPeaks, 'ColumnFormat', ...
            {'numeric', dropdownOptions', ...
             'numeric','numeric','numeric', ...
             'numeric','numeric','numeric'});
    end
end

guidata(hObj, h);

function loadDECdatacallback(hObj, ~)
h = guidata(hObj);

[baseFileName, folder] = uigetfile('*.mat','Load DEK data',[General.ProgramInfo.Path,'/Data/Materials/']);

% If user pressed cancel, abort saving process
if baseFileName == 0
  % user pressed cancel
  return
end

% Load user selected data
DEKDataFileName = fullfile(folder, baseFileName);
DEKdata = load(DEKDataFileName);

if strcmp(get(h.radiobuttonwavelength.SelectedObject,'String'),'Ga K-alpha')
    DEKdatatmp = get(h.dekdataGaKalpha,"data");
elseif strcmp(get(h.radiobuttonwavelength.SelectedObject,'String'),'In K-alpha')
    DEKdatatmp = get(h.dekdataInKalpha,"data");
elseif strcmp(get(h.radiobuttonwavelength.SelectedObject,'String'),'In K-beta')
    DEKdatatmp = get(h.dekdataInKbeta,"data");
end
% DEKdatatmp = get(h.dekdata,'data');
% assignin('base','DEKdatatmp',DEKdatatmp)
hklDEKtmp = zeros(1,length(DEKdatatmp(:,1)));
% Get hkl that were fitted
for k = 1:length(DEKdatatmp(:,1))
    if length(num2str(DEKdatatmp(k,1:3))) > 7
        hklDEKtmp(k) = DEKdatatmp(k,1)*1000 + DEKdatatmp(k,2)*100 + DEKdatatmp(k,3);
    else
        hklDEKtmp(k) = DEKdatatmp(k,1)*100 + DEKdatatmp(k,2)*10 + DEKdatatmp(k,3);
    end
end
% assignin('base','hklDEKtmp',hklDEKtmp)
hklDEKtmp = hklDEKtmp';
a = cell(size(DEKdata.DEK,1),length(hklDEKtmp));
% Find matches between fitted hkl and hkl in data file
for l = 1:length(hklDEKtmp)
    for k = 1:size(DEKdata.DEK,1)
		a{k,l} = strcmp(num2str(hklDEKtmp(l,1)),num2str(DEKdata.DEK(k,1)));
    end
end

IndexHittmp = cell2mat(a);
% If fitted hkl matches hkl from DEK data, add DEK or add zeros, which the 
% user has to change manually 
for k = 1:size(DEKdatatmp,1)
    if isempty(DEKdata.DEK(IndexHittmp(:,k),2:3))
        DEKdatatmp(k,5:6) = [0 0];
    else
        DEKdatatmp(k,5:6) = DEKdata.DEK(IndexHittmp(:,k),2:3);
    end
end

if strcmp(get(h.radiobuttonwavelength.SelectedObject,'String'),'Ga K-alpha')
    set(h.dekdataGaKalpha, 'data', DEKdatatmp);
elseif strcmp(get(h.radiobuttonwavelength.SelectedObject,'String'),'In K-alpha')
    set(h.dekdataInKalpha, 'data', DEKdatatmp);
elseif strcmp(get(h.radiobuttonwavelength.SelectedObject,'String'),'In K-beta')
    set(h.dekdataInKbeta, 'data', DEKdatatmp);
end

guidata(hObj, h);

function fitpeakscallback(hObj, ~)
h = guidata(hObj);

% clearFirst: true (default) = alte Marker löschen, false = nicht löschen

if nargin < 3, clearFirst = true; end

% ── Alte Marker löschen ───────────────────────────────────────────────
if clearFirst
    delete(findobj(h.axes, 'Tag', 'maskregion'));
    delete(findobj(h.axes, 'Tag', 'peakmask'));
end

col = get(hObj,'backg');
set(hObj,'String','Fitting peaks ...','backg',[1 .6 .6])
pause(.01)

% ── Fit-Felder zurücksetzen um Konflikte bei erneutem Fit zu vermeiden
resetFields = {'dataPVFitY','dataPVSuccess','datacentFitParams', ...
               'datacentFitErrors','datacentFitY','datacentFitSuccess', ...
               'dataPVFitMat','datacentFitMat','FitDataModCentroid', ...
               'fitMethodUsed','dataCentroidMu','dataGaussFit'};
for rf = 1:numel(resetFields)
    if isfield(h, resetFields{rf})
        h = rmfield(h, resetFields{rf});
    end
end

% UserPeaksdata = get(h.tableUserDefinedPeaks,'data');
% assignin('base','UserPeaksdata',UserPeaksdata)

% BgRegions aus Tabelle synchronisieren
tableData = get(h.tableUserDefinedPeaks, 'Data');
nPeaksTable = size(tableData, 1);
h.BgRegions = cell(nPeaksTable, 1);
for pk = 1:nPeaksTable
    bgL = tableData{pk, 4};
    bgR = tableData{pk, 5};
    if isnumeric(bgL) && isnumeric(bgR) && ...
       isfinite(bgL) && isfinite(bgR) && bgL < bgR
        h.BgRegions{pk} = [bgL, bgR];
    end
end

% ── Peaks direkt aus manueller Definition übernehmen ─────────────────
nAlphaFit = size(h.dataX, 2);

for k = 1:nAlphaFit
    h.UserPeaksCorr{k} = h.UserPeaks;

    nBinsAlpha = size(h.dataY{k}, 2);
    PeaksXCorr = cell(nBinsAlpha, 1);
    PeaksYCorr = cell(nBinsAlpha, 1);

    for l = 1:nBinsAlpha
        xBin   = h.dataX{k};
        yBin   = h.dataY{k}(:, l);
        nPks   = numel(h.UserPeaks);
        pkX    = zeros(nPks, 1);
        pkY    = zeros(nPks, 1);
        for pk = 1:nPks
            [~, idxPk] = min(abs(xBin - h.UserPeaks(pk)));
            pkX(pk) = xBin(idxPk);
            pkY(pk) = yBin(idxPk);
        end
        PeaksXCorr{l} = pkX;
        PeaksYCorr{l} = pkY;
    end

    h.Locations{k} = PeaksXCorr;
    h.Amplitude{k} = PeaksYCorr;
end

dataX = h.dataX;
dataY = h.dataY;

% Im manuellen Workflow: Locations enthält Vektoren, keine verschachtelten Cells
% idxempty daher direkt als logischer Vektor pro alpha
idxempty = cellfun(@(v) false(numel(v), 1), h.Locations, 'UniformOutput', false);
h.idxempty = idxempty;

% BinnedGamma vorbereiten
for k = 1:size(h.BinnedGamma, 2)
    BinnedGamma{k} = h.BinnedGamma{k};
end
h.BinnedGamma = BinnedGamma;

for k = 1:size(idxempty,2)
    % Keine leeren Einträge im manuellen Workflow → direkt übernehmen
    h.BinnedGammaFinal{k} = BinnedGamma{k};
end

% Pseudo-Voigt Gleichung
pVoigtEqn = @(p, xdata) p(1) .* ( ...
    p(4) .* (1 ./ (1 + ((xdata - p(2))./(p(3)/2)).^2)) + ...
    (1 - p(4)) .* exp(-log(2) .* ((xdata - p(2))./(p(3)/2)).^2));
h.gaussEqnFirst = pVoigtEqn;

% dataXcorr / dataYcorr initialisieren
h.dataXcorr = cell(1, size(dataY,2));
h.dataYcorr = cell(1, size(dataY,2));
h.YBkg      = cell(1, size(dataY,2));
for m = 1:size(dataY,2)
    nPeaksCurr = numel(h.UserPeaksCorr{m});
    h.dataXcorr{m} = cell(size(dataY{m},2), nPeaksCurr);
    h.dataYcorr{m} = cell(size(dataY{m},2), nPeaksCurr);
    h.YBkg{m}      = cell(size(dataY{m},2), nPeaksCurr);
end

% =====================================================================
% Haupt-Fit-Loop
% =====================================================================
for m = 1:size(dataY,2)

    dx            = mean(diff(dataX{m}));
    windowDeg     = str2double(get(h.PeakWindowEditField, 'String'));
    fitrangepixel = max(30, round(windowDeg / dx));

    PeakPosFiltered   = h.UserPeaksCorr{m};
    h.PeakPosFiltered = PeakPosFiltered;

    % Peaks gruppieren
    if isfield(h, 'BgRegions') && ~isempty(h.BgRegions) && ...
       any(~cellfun(@isempty, h.BgRegions))
        bgXall = [];
        for pk = 1:numel(h.BgRegions)
            if ~isempty(h.BgRegions{pk})
                bgXall = [bgXall, h.BgRegions{pk}(1), h.BgRegions{pk}(2)];
            end
        end
        bgXall     = unique(sort(bgXall(bgXall > 0)));
        nBgInt     = numel(bgXall) - 1;
        PeakGroups = cell(nBgInt, 1);
        for g = 1:nBgInt
            inInterval    = (PeakPosFiltered > bgXall(g)) & ...
                            (PeakPosFiltered < bgXall(g+1));
            PeakGroups{g} = find(inInterval);
        end
        PeakGroups = PeakGroups(~cellfun(@isempty, PeakGroups));
    else
        PeakGroups = num2cell((1:numel(PeakPosFiltered))');
    end

    fitresult = cell(size(dataY{m},2), length(PeakPosFiltered));
    PeakLocs  = zeros(size(dataY{m},2), length(PeakPosFiltered));
    PeakAmp   = zeros(size(dataY{m},2), length(PeakPosFiltered));
    PeakFWHM  = zeros(size(dataY{m},2), length(PeakPosFiltered));
    PeakEta   = zeros(size(dataY{m},2), length(PeakPosFiltered));
    StdError  = zeros(size(dataY{m},2), length(PeakPosFiltered));

    % Qualitätsschwellen auslesen (mit Fallback falls kein EditField vorhanden)
    if isfield(h,'minR2EditField') && isvalid(h.minR2EditField)
        minR2 = str2double(get(h.minR2EditField, 'String'));
    else
        minR2 = 0.5;
    end
    if isfield(h,'minAmpRelEditField') && isvalid(h.minAmpRelEditField)
        minAmpRel = str2double(get(h.minAmpRelEditField, 'String'));
    else
        minAmpRel = 5.0;
    end
    if isnan(minR2),     minR2     = 0.5; end
    if isnan(minAmpRel), minAmpRel = 3.0; end

    % Validitätsmaske für diese Alpha-Gruppe
    if isfield(h, 'BinnedGammaValid') && numel(h.BinnedGammaValid) >= m && ...
       ~isempty(h.BinnedGammaValid{m})
        validMask = h.BinnedGammaValid{m};
        if numel(validMask) < size(h.dataY{m}, 2)
            % Länge angleichen falls nötig
            validMask(end+1:size(h.dataY{m},2)) = false;
        end
    else
        validMask = true(1, size(h.dataY{m}, 2));
    end
    
    fprintf('Peak-Fit Alpha-Gruppe %d: %d/%d Bins werden gefittet.\n', ...
        m, sum(validMask), numel(validMask));

    for l = 1:size(dataY{m},2)
        
        % ── Bin überspringen wenn Maske ihn als ungültig markiert ────
        if ~validMask(l)
            for g = 1:numel(PeakGroups)
                for ki = 1:numel(PeakGroups{g})
                    pkIdx = PeakGroups{g}(ki);
                    fitresult{l,pkIdx} = [];
                    StdError(l,pkIdx)  = NaN;
                    PeakLocs(l,pkIdx)  = NaN;
                    PeakAmp(l,pkIdx)   = NaN;
                    PeakFWHM(l,pkIdx)  = NaN;
                    PeakEta(l,pkIdx)   = NaN;
                end
            end
            continue
        end

        % Untergrundkorrigierte Daten
        if isfield(h,'dataXcorrBg') && numel(h.dataXcorrBg) >= m && ...
           numel(h.dataXcorrBg{m}) >= l && ~isempty(h.dataXcorrBg{m}{l})
            XcorrBg   = h.dataXcorrBg{m}{l};
            YcorrBg   = h.dataYcorrBg{m}{l};
            useBgCorr = true;
        else
            useBgCorr = false;
        end

        for g = 1:numel(PeakGroups)
            pkIdxInGroup = PeakGroups{g};
            if isempty(pkIdxInGroup), continue; end
            nPkGroup = numel(pkIdxInGroup);
            pkFirst  = pkIdxInGroup(1);
            pkLast   = pkIdxInGroup(end);

            if useBgCorr && ~isempty(h.BgRegions{pkFirst})
                xBgLeft  = h.BgRegions{pkFirst}(1);
                xBgRight = h.BgRegions{pkLast}(2);

                idxWinL = Tools.Data.DataSetOperations.FindNearestIndex(XcorrBg, xBgLeft);
                idxWinR = Tools.Data.DataSetOperations.FindNearestIndex(XcorrBg, xBgRight);
                idxWinL = max(1, idxWinL);
                idxWinR = min(numel(XcorrBg), idxWinR);

                Xcorr = XcorrBg(idxWinL:idxWinR);
                Ycorr = YcorrBg(idxWinL:idxWinR);
                YBkg  = h.dataBkg{m}{l}(idxWinL:idxWinR);
            else
                posLeft  = PeakPosFiltered(pkFirst);
                posRight = PeakPosFiltered(pkLast);
                idxL = find(dataX{m} >= posLeft,  1, 'first');
                idxR = find(dataX{m} <= posRight, 1, 'last');
                if isempty(idxL), idxL = 1; end
                if isempty(idxR), idxR = numel(dataX{m}); end
                idxWinL = max(1,               idxL - fitrangepixel);
                idxWinR = min(numel(dataX{m}), idxR + fitrangepixel);
                X = dataX{m}(idxWinL:idxWinR);
                Y = dataY{m}(idxWinL:idxWinR, l);
                [~, Y_smoothed] = Tools.Data.Filtering.MinMaxLineMean(X, Y, 0.2, 5);
                Xleft  = X(2:6); Xright = X(end-6:end-1);
                idxLmt = ismembertol(Y(2:6),        mean(Y(2:6)),        0.1);
                idxRmt = ismembertol(Y(end-6:end-1),mean(Y(end-6:end-1)),0.1);
                if all(idxLmt==0), idxLmt = logical([0 1 0 0 0]); end
                if all(idxRmt==0), idxRmt = logical([0 1 0 0 0]); end
                PR  = [Xleft(find(idxLmt,1,'first')); Xright(find(idxRmt,1,'first'))];
                PRN = Tools.LogicalRegions(...
                    [Tools.Data.DataSetOperations.FindNearestIndex(X, PR(1)); ...
                     Tools.Data.DataSetOperations.FindNearestIndex(X, PR(2))], numel(X));
                [Xcorr, Ycorr, YBkg] = Tools.Data.Fitting.BackgroundReduction(...
                    X, Y, PRN, Y_smoothed);
            end

            % Startwerte
            p0 = zeros(1, 4*nPkGroup);
            lb = zeros(1, 4*nPkGroup);
            ub = zeros(1, 4*nPkGroup);

            for ki = 1:nPkGroup
                pkIdx  = pkIdxInGroup(ki);
                pos    = PeakPosFiltered(pkIdx);
                ampEst = max(Ycorr(abs(Xcorr - pos) <= 0.5), [], 'all');
                if isempty(ampEst) || ampEst <= 0
                    ampEst = max(Ycorr) * 0.5;
                end
                if nPkGroup > 1 && ki < nPkGroup
                    halfDist = (PeakPosFiltered(pkIdxInGroup(ki+1)) - pos) / 2;
                else
                    halfDist = 1.0;
                end
                if nPkGroup > 1 && ki > 1
                    halfDist = min(halfDist, ...
                        (pos - PeakPosFiltered(pkIdxInGroup(ki-1))) / 2);
                end
                idxPW = abs(Xcorr - pos) <= halfDist;
                Ypk   = max(Ycorr(idxPW) - min(Ycorr(idxPW)), 0);
                Xpk   = Xcorr(idxPW);
                abv   = Xpk(Ypk > max(Ypk)*0.5);
                if numel(abv) >= 2
                    fwhmEst = max(0.10, min(max(abv)-min(abv), 2.0));
                else
                    fwhmEst = 0.30;
                end
                p0(4*(ki-1)+1:4*(ki-1)+4) = [ampEst, pos,   fwhmEst, 0.5];
                lb(4*(ki-1)+1:4*(ki-1)+4) = [max(Ycorr)*0.01, pos-1, 0.05, 0];
                ub(4*(ki-1)+1:4*(ki-1)+4) = [Inf,     pos+1, 5.0,     1  ];
            end

            opts_pV = optimoptions('lsqcurvefit', ...
                'Display','off', 'MaxFunctionEvaluations',10000*nPkGroup, ...
                'MaxIterations',2000, 'FunctionTolerance',1e-12, ...
                'StepTolerance',1e-10);

            try
                [pFit,~,resid,~,~,~,jac] = lsqcurvefit(...
                    @multiPseudoVoigt, p0, Xcorr, Ycorr, lb, ub, opts_pV);
                [~,R]  = qr(jac,0);
                Rinv   = R\eye(size(R));
                diagI  = sum(Rinv.*Rinv,2);
                rmse   = norm(resid)/sqrt(max(numel(resid)-numel(pFit),1));
                SE_all = sqrt(diagI)*rmse;

                % ── Qualitätsprüfung: schlechte Fits ausfiltern ───────
                SStot = sum((Ycorr - mean(Ycorr)).^2);
                SSres = sum(resid.^2);
                Rsq   = 1 - SSres / max(SStot, eps);

                fitQualityOk = Rsq >= minR2;

                for ki = 1:nPkGroup
                    pkIdx   = pkIdxInGroup(ki);
                    iParams = 4*(ki-1)+1:4*(ki-1)+4;

                    ampFit  = pFit(iParams(1));
                    % muFit   = pFit(iParams(2));
                    fwhmFit = pFit(iParams(3));

                    % Amplitude relativ zum Maximum im Peak-Fenster prüfen
                    pos         = PeakPosFiltered(pkIdx);
                    idxPeakWin  = abs(Xcorr - pos) <= max(fwhmFit, 0.5);
                    if any(idxPeakWin)
                        localMax = max(Ycorr(idxPeakWin));
                    else
                        localMax = max(Ycorr);
                    end

                    % Globales Maximum im gesamten Fit-Fenster
                    globalMax = max(Ycorr);

                    % Peak ungültig wenn:
                    % 1. R² zu niedrig
                    % 2. Amplitude < minAmpRel% des globalen Maximums
                    % 3. Gefittete Amplitude viel größer als lokales Maximum
                    %    (Fit hat sich losgelöst von den Daten)
                    peakInvalid = ~fitQualityOk || ...
                                  ampFit < globalMax * (minAmpRel/100) || ...
                                  ampFit > localMax  * 3.0;

                    if peakInvalid
                        fitresult{l,pkIdx} = [];
                        StdError(l,pkIdx)  = NaN;
                        PeakLocs(l,pkIdx)  = NaN;
                        PeakAmp(l,pkIdx)   = NaN;
                        PeakFWHM(l,pkIdx)  = NaN;
                        PeakEta(l,pkIdx)   = NaN;
                        if isfield(h,'dataPVFitY') && numel(h.dataPVFitY) >= m
                            h.dataPVFitY{m}{l,pkIdx}        = [];
                            h.dataPVSuccess{m}(l,pkIdx)     = false;
                            h.datacentFitParams{m}{l,pkIdx} = [];
                            h.datacentFitY{m}{l,pkIdx}      = [];
                            h.datacentFitSuccess{m}(l,pkIdx)= false;
                        end
                        continue
                    end
                    h.dataXcorr{m}{l,pkIdx} = Xcorr;
                    h.dataYcorr{m}{l,pkIdx} = Ycorr;
                    h.YBkg{m}{l,pkIdx}      = YBkg;
                
                    fitresult{l,pkIdx}  = pFit(iParams);
                    StdError(l,pkIdx)   = SE_all(iParams(2));
                    PeakLocs(l,pkIdx)   = pFit(iParams(2));
                    PeakAmp(l,pkIdx)    = pFit(iParams(1));
                    PeakFWHM(l,pkIdx)   = pFit(iParams(3));
                    PeakEta(l,pkIdx)    = pFit(iParams(4));
                
                    % fitCentroid zusätzlich berechnen
                    pos     = PeakPosFiltered(pkIdx);
                    pvMu    = pFit(iParams(2));    % mu aus Pseudo-Voigt
                    pvFwhm  = pFit(iParams(3));    % fwhm aus Pseudo-Voigt
                    
                    try
                        cOpts.kBins        = 12;
                        cOpts.baselineMode = 'minval';
                        cOpts.nBootstrap   = 200;
                        cOpts.smoothPoints = 5;
                        cOpts.verbose      = false;
                    
                        % Fenster auf BgRegion einschränken — nicht enger
                        [centParams, centErrors, ycent] = ...
                            fitCentroid(Xcorr, Ycorr, pos, cOpts);
                    
                        % Plausibilitätsprüfung: centroid-Ergebnis nur verwenden wenn
                        % es nah am Pseudo-Voigt-Ergebnis liegt
                        if ~isempty(centParams) && isfield(centParams,'x0') && ...
                           isfinite(centParams.x0) && ...
                           abs(centParams.x0 - pvMu) <= pvFwhm
                            % Centroid plausibel
                            xc = Xcorr(:); yc = ycent(:);
                            centFitY_lk = @(xdata) interp1(xc, yc, xdata, 'linear', 0);
                            centSuccess = true;
                        else
                            % Centroid hat zum falschen Peak gewandert —
                            % Pseudo-Voigt-Ergebnis als Fallback verwenden
                            centParams        = struct('x0', pvMu);
                            centErrors        = struct('x0', SE_all(iParams(2)));
                            xc = Xcorr(:);
                            yc = multiPseudoVoigt(pFit(iParams), Xcorr);
                            yc = yc(:);
                            centFitY_lk = @(xdata) interp1(xc, yc, xdata, 'linear', 0);
                            centSuccess = true;  % als erfolgreich markieren mit PV-Werten
                        end
                    catch
                        centParams  = struct('x0', pvMu);
                        centErrors  = struct('x0', SE_all(iParams(2)));
                        xc = Xcorr(:);
                        yc = multiPseudoVoigt(pFit(iParams), Xcorr);
                        yc = yc(:);
                        centFitY_lk = @(xdata) interp1(xc, yc, xdata, 'linear', 0);
                        centSuccess = false;
                    end
                
                    % fitPseudoVoigt als anonyme Funktion (für updateFittedPeakPlot)
                    xpv = Xcorr(:);
                    ypv = multiPseudoVoigt(pFit(iParams), Xcorr);
                    ypv = ypv(:);
                    pvFitY_lk = @(xdata) interp1(xpv, ypv, xdata, 'linear', 'extrap');
                
                    % Felder befüllen die updateFittedPeakPlot erwartet
                    if ~isfield(h,'dataPVFitY') || numel(h.dataPVFitY) < m
                        h.dataPVFitY{m}     = cell(size(dataY{m},2), numel(PeakPosFiltered));
                        h.dataPVSuccess{m}  = false(size(dataY{m},2), numel(PeakPosFiltered));
                        h.datacentFitParams{m} = cell(size(dataY{m},2), numel(PeakPosFiltered));
                        h.datacentFitErrors{m} = cell(size(dataY{m},2), numel(PeakPosFiltered));
                        h.datacentFitY{m}      = cell(size(dataY{m},2), numel(PeakPosFiltered));
                        h.datacentFitSuccess{m} = false(size(dataY{m},2), numel(PeakPosFiltered));
                        h.dataPVFitMat{m}    = cell(size(dataY{m},2), numel(PeakPosFiltered));
                        h.datacentFitMat{m}  = cell(size(dataY{m},2), numel(PeakPosFiltered));
                    end
                
                    h.dataPVFitY{m}{l,pkIdx}    = pvFitY_lk;
                    h.dataPVSuccess{m}(l,pkIdx) = true;
                
                    h.datacentFitParams{m}{l,pkIdx}  = centParams;
                    h.datacentFitErrors{m}{l,pkIdx}  = centErrors;
                    h.datacentFitY{m}{l,pkIdx}       = centFitY_lk;
                    h.datacentFitSuccess{m}(l,pkIdx) = centSuccess;
                end
            catch ME
                warning('[Multi-Peak-Fit] Gruppe %d, Bin %d: %s', g, l, ME.message);
                for ki = 1:nPkGroup
                    pkIdx = pkIdxInGroup(ki);
                    fitresult{l,pkIdx} = [];
                    StdError(l,pkIdx)  = NaN;
                    PeakLocs(l,pkIdx)  = NaN;
                    PeakAmp(l,pkIdx)   = NaN;
                    PeakFWHM(l,pkIdx)  = NaN;
                    PeakEta(l,pkIdx)   = NaN;
                end
            end
        end % for g
    end % for l

    nanMask = isnan(PeakLocs) | isnan(StdError);
    PeakLocs(nanMask) = 0; PeakAmp(nanMask)  = 0;
    PeakFWHM(nanMask) = 0; PeakEta(nanMask)  = 0;
    StdError(nanMask) = 0;

    fitresultexport{m} = fitresult;

    BinnedGamma_m      = h.BinnedGammaFinal{m}';
    BinnedGammaSortMat = repmat(BinnedGamma_m, 1, length(PeakPosFiltered));

    FittedPeakPosSortMat    = zeros(size(dataY{m},2), length(PeakPosFiltered));
    FittedPeakPosErrSortMat = zeros(size(dataY{m},2), length(PeakPosFiltered));
    FittedPeakAmpSortMat    = zeros(size(dataY{m},2), length(PeakPosFiltered));
    FittedPeakWidthSortMat  = zeros(size(dataY{m},2), length(PeakPosFiltered));
    FittedPeakEtaSortMat    = zeros(size(dataY{m},2), length(PeakPosFiltered));

    for k = 1:size(PeakLocs,2)
        for l = 1:length(PeakPosFiltered)
            idx = find(ismembertol(PeakLocs(:,k), PeakPosFiltered(l), 0.03));
            if ~isempty(idx)
                FittedPeakPosSortMat(idx,l)    = PeakLocs(idx,k);
                FittedPeakPosErrSortMat(idx,l) = StdError(idx,k);
                FittedPeakAmpSortMat(idx,l)    = PeakAmp(idx,k);
                FittedPeakWidthSortMat(idx,l)  = PeakFWHM(idx,k);
                FittedPeakEtaSortMat(idx,l)    = PeakEta(idx,k);
            end
        end
    end

    FitDatatmp = [BinnedGammaSortMat(:) FittedPeakPosSortMat(:) ...
                  FittedPeakPosErrSortMat(:) FittedPeakAmpSortMat(:) ...
                  FittedPeakWidthSortMat(:)  FittedPeakEtaSortMat(:)];
    nCols   = size(FitDatatmp,2);
    nRows   = size(FitDatatmp,1) / length(PeakPosFiltered);
    FitData = mat2cell(FitDatatmp, nRows*ones(1,length(PeakPosFiltered)), nCols);
    h.FitDataRaw{m} = FitData;
end % for m

% Alpha-Wert hinzufügen
% for k = 1:size(h.FitDataRaw,2)
%     for l = 1:size(h.FitDataRaw{k},1)
%         h.FitDataRaw{k}{l} = horzcat(h.FitDataRaw{k}{l}, ...
%             repmat(h.alpha(min(k,numel(h.alpha))), size(h.FitDataRaw{k}{l},1), 1), ...
%             (1:size(h.FitDataRaw{k}{l},1))');
%     end
% end

for k = 1:size(h.FitDataRaw,2)
    for l = 1:size(h.FitDataRaw{k},1)
        h.FitDataRaw{k}{l} = horzcat(h.FitDataRaw{k}{l}, ...
            repmat(h.uniqueAlpha(k), ...          % <-- uniqueAlpha statt alpha
                size(h.FitDataRaw{k}{l},1), 1), ...
            (1:size(h.FitDataRaw{k}{l},1))');
    end
end

% assignin('base','FitDataRaw',h.FitDataRaw)

FitDataModtmp   = cat(1, h.FitDataRaw{:});
FitDataMod      = FitDataModtmp(~cellfun('isempty', FitDataModtmp));
h.FitDataModBkp = FitDataMod;

% fprintf('Alpha-Gruppe %d: validMask:\n', m);
% disp(validMask(:)');
% fprintf('BinnedGamma:\n');
% disp(h.BinnedGamma{m}(:)');

% =====================================================================
% Anzahl der Bilder pro Alpha-Gruppe bestimmen
% =====================================================================
[val, ~, idxalpha] = unique(h.alpha);
nUniqueAlpha  = numel(val);             % 6 Alpha-Gruppen
nImgsPerAlpha = numel(h.alpha) / nUniqueAlpha;  % 6 Bilder pro Gruppe
nPeaksPerGrp  = size(fitresultexport{1}, 2);    % 2 Peaks

isMultiImg = nImgsPerAlpha > 1;   % true wenn mehrere Bilder pro Alpha

fprintf('nUniqueAlpha=%d  nImgsPerAlpha=%d  nPeaksPerGrp=%d  isMultiImg=%d\n', ...
    nUniqueAlpha, nImgsPerAlpha, nPeaksPerGrp, isMultiImg);

% =====================================================================
% Umsortieren fitresultexport
% =====================================================================
N = numel(fitresultexport);
fitresultexportmod_tmp = cell(1, N * nPeaksPerGrp);
idx = 1;
for i = 1:N
    for j = 1:nPeaksPerGrp
        fitresultexportmod_tmp{idx} = fitresultexport{i}(:,j);
        idx = idx + 1;
    end
end

% if isMultiImg
    % Mehrere Bilder pro Alpha → nur nach Alpha-Gruppen umsortieren
    % fitresultexportmod_tmp hat N*nPeaksPerGrp = nUniqueAlpha*nPeaksPerGrp Einträge
    % h.fitresultexport = fitresultexportmod_tmp;
% else
    h.fitresultexport = fitresultexportmod_tmp;
% end

% =====================================================================
% Umsortieren dataXcorr
% =====================================================================
N          = numel(h.dataXcorr);
nPeaksCols = size(h.dataXcorr{1}, 2);
dataXcorr_tmp = cell(1, N * nPeaksCols);
idx = 1;
for i = 1:N
    for j = 1:nPeaksCols
        dataXcorr_tmp{idx} = h.dataXcorr{i}(:,j);
        idx = idx + 1;
    end
end
h.dataXcorr = dataXcorr_tmp;

% =====================================================================
% Umsortieren dataYcorr
% =====================================================================
N = numel(h.dataYcorr);
dataYcorr_tmp = cell(1, N * nPeaksCols);
idx = 1;
for i = 1:N
    for j = 1:nPeaksCols
        dataYcorr_tmp{idx} = h.dataYcorr{i}(:,j);
        idx = idx + 1;
    end
end
h.dataYcorr = dataYcorr_tmp;

% =====================================================================
% FitDataMod aufbauen
% Ziel: nUniqueAlpha × nPeaksPerGrp Einträge
% FitDataRaw{ka}{kp} = Daten für Alpha-Gruppe ka, Peak kp
% =====================================================================
if isMultiImg
    % Mehrere Bilder pro Alpha-Gruppe → direkt aus FitDataRaw aufbauen
    nAlphaGroups = numel(h.FitDataRaw);
    nPeaks_fdm   = numel(h.FitDataRaw{1});
    nTotal       = nAlphaGroups * nPeaks_fdm;

    FitDataMod_new = cell(nTotal, 1);
    entryIdx = 1;
    for ka = 1:nAlphaGroups
        for kp = 1:nPeaks_fdm
            FitDataMod_new{entryIdx} = h.FitDataRaw{ka}{kp};
            entryIdx = entryIdx + 1;
        end
    end
    h.FitDataMod = FitDataMod_new;

    fprintf('FitDataMod aufgebaut: %d Alpha × %d Peaks = %d Einträge\n', ...
        nAlphaGroups, nPeaks_fdm, nTotal);
else
    h.FitDataMod = FitDataMod;
end

% =====================================================================
% Nullzeilen entfernen
% =====================================================================
% for k = 1:size(h.FitDataMod, 1)
%     mat    = h.FitDataMod{k};
%     idxDel = (mat(:,2) == 0) & (mat(:,4) == 0);
%     if any(idxDel)
%         if numel(h.fitresultexport) >= k
%             h.fitresultexport{k}(idxDel) = {[]};
%             h.fitresultexport{k}(cellfun(@isempty, h.fitresultexport{k})) = [];
%         end
%         h.FitDataMod{k}(idxDel, :) = [];
%     end
% end

% ── Nullzeilen: 0 → NaN (NICHT löschen, Korrespondenz zu dataXcorr erhalten) ──
for k = 1:size(h.FitDataMod, 1)
    mat     = h.FitDataMod{k};
    idxZero = (mat(:,2) == 0) & (mat(:,4) == 0);
    if any(idxZero)
        % Spalten 2..end auf NaN — Spalte 1 (Gamma) bleibt erhalten
        h.FitDataMod{k}(idxZero, 2:end) = NaN;

        % fitresultexport: leere Zellen stehen lassen (Korrespondenz!)
        if numel(h.fitresultexport) >= k
            nFRE     = numel(h.fitresultexport{k});
            delValid = find(idxZero);
            delValid = delValid(delValid <= nFRE);
            if ~isempty(delValid)
                h.fitresultexport{k}(delValid) = {[]};
            end
        end
    end
end

% =====================================================================
% Umsortieren dataPVFitY / dataPVSuccess / datacentFit*
% =====================================================================
fieldPairs = {'dataPVFitY','dataPVSuccess','datacentFitParams', ...
              'datacentFitErrors','datacentFitY','datacentFitSuccess'};
for fp = 1:numel(fieldPairs)
    fn = fieldPairs{fp};
    if ~isfield(h, fn), continue; end
    src   = h.(fn);
    N_f   = numel(src);
    nC_src = size(src{1}, 2);
    if nC_src < 1, continue; end

    tmp = cell(1, N_f * nC_src);
    ii  = 1;
    for i = 1:N_f
        for j = 1:nC_src
            tmp{ii} = src{i}(:, j);
            ii = ii + 1;
        end
    end
    h.(fn) = tmp;
end

% =====================================================================
% dataPVFitMat und datacentFitMat aus FitDataMod ableiten
% =====================================================================
for k = 1:numel(h.FitDataMod)
    mat   = h.FitDataMod{k};
    matPV = mat;
    matPV(~isfinite(mat(:,2)), 2:3) = NaN;
    h.dataPVFitMat{k} = matPV;

    matCent = mat;
    if size(mat,2) >= 12
        matCent(:,2) = mat(:,11);
        matCent(:,3) = mat(:,12);
    end
    h.datacentFitMat{k} = matCent;
end

% =====================================================================
% Kompatibilitätsfelder
% =====================================================================
h.FitDataModCentroid = h.datacentFitMat;
for k = 1:numel(h.FitDataMod)
    h.fitMethodUsed{k}  = true(size(h.FitDataMod{k},1), 1);
    h.dataCentroidMu{k} = cell(size(h.FitDataMod{k},1), 1);
    h.dataGaussFit{k}   = cell(size(h.FitDataMod{k},1), 1);
end

fprintf('Finale FitDataMod: %d Einträge\n', numel(h.FitDataMod));
for k = 1:numel(h.FitDataMod)
    pv = h.FitDataMod{k};
    [~,~,idxFin_k] = getPlausibleCol(pv);
    fprintf('  Eintrag %d: %d Zeilen, %d plausibel, alpha=%.1f°\n', ...
        k, size(pv,1), sum(idxFin_k), ...
        pv(find(isfinite(pv(:,7)),1,'first'), 7));
end

% DEK Tabelle
if strcmp(get(h.radiobuttonwavelength.SelectedObject,'String'),'Ga K-alpha')
    DEK = get(h.dekdataGaKalpha,'data');
elseif strcmp(get(h.radiobuttonwavelength.SelectedObject,'String'),'In K-alpha')
    DEK = get(h.dekdataInKalpha,'data');
else
    DEK = get(h.dekdataInKbeta,'data');
end

% PeakPosData = cell2mat(cellfun(@(x) mean(x,1), h.FitDataMod, 'UniformOutput', false));
% NEU:
PeakPosData = cell2mat(cellfun(@(x) mean(x, 1, 'omitnan'), h.FitDataMod, 'UniformOutput', false));

if size(PeakPosData,2) < 2
    errordlg('FitDataMod hat unerwartetes Format.','Fehler');
    set(hObj,'String','Start Peak Fit','backg',col); return
end

Peaks = PeakPosData(:,2); PeaksTheo = DEK(:,4);
for k = 1:length(PeaksTheo)
    idxPeakHit(:,k) = ismembertol(Peaks, PeaksTheo(k), 0.02);
end
DEKdataMatchedPeaks = zeros(size(PeakPosData,1),6);
for k = 1:length(PeaksTheo)
    DEKdataMatchedPeaks = DEKdataMatchedPeaks + idxPeakHit(:,k).*DEK(k,:);
end

% ── FIX 1: Alpha korrekt aus Spalte 7 von FitDataMod lesen ───────────
% Spalte 7 = alpha, Spalte 8 = Peak-Index (laufende Nummer)
DEKdataMatchedPeaks(:,7) = PeakPosData(:,7);   % war fälschlich (:,6)
h.DEKdataMatchedPeaks = DEKdataMatchedPeaks;

% ── DEK-Tabelle befüllen + Dropdown korrekt setzen ───────────────────
% Dropdown muss alle verfügbaren E-theo Werte aus der DEK-Tabelle zeigen
% (nicht die gefitteten Peaks)
tableDataNew = [Peaks, DEKdataMatchedPeaks(:,4), DEKdataMatchedPeaks(:,1:3), ...
                DEKdataMatchedPeaks(:,5:7)];

% Dropdown-Optionen: ALLE theoretischen Peaks aus der DEK-Tabelle
% (nicht nur die gematchten) damit der User auch ummappen kann
allEtheo = DEK(:,4);
allEtheo = allEtheo(allEtheo > 0);   % Nullen rausfiltern
allEtheo = unique(allEtheo);          % Duplikate entfernen
dropdownOptions = cellfun(@num2str, num2cell(allEtheo), 'UniformOutput', false);

set(h.tableDECFittedPeaks, ...
    'Data',         tableDataNew, ...
    'ColumnFormat', {'numeric', dropdownOptions', ...
                     'numeric','numeric','numeric', ...
                     'numeric','numeric','numeric'});

% Slider
if size(h.FitDataMod,1) == 1
    set(h.Slider,'Min',0,'Max',1,'SliderStep',[1 1],'Value',1);
else
    set(h.Slider,'Max',size(h.FitDataMod,1), ...
        'SliderStep',[1/(size(h.FitDataMod,1)-1) 1/(size(h.FitDataMod,1)-1)], ...
        'Value',1);
end

% ── plotdata neu anlegen falls durch cla gelöscht ────────────────────
if ~isfield(h,'plotdata') || ~isvalid(h.plotdata)
    h.plotdata = errorbar(h.axes, NaN, NaN, NaN, 's', ...
        'MarkerSize',       4, ...
        'MarkerFaceColor',  [0.094 0.373 0.647], ...
        'MarkerEdgeColor',  [0.094 0.373 0.647], ...
        'Color',            [0.094 0.373 0.647], ...
        'LineWidth',        0.8, ...
        'Visible',          'off');
end
if ~isfield(h,'fitcurvestress') || ~isvalid(h.fitcurvestress)
    h.fitcurvestress = plot(h.axes, 0, 0, '-', 'Visible', 'off');
end
if ~isfield(h,'highlightpeakdata') || ~isvalid(h.highlightpeakdata)
    h.highlightpeakdata = plot(h.axes, 0, 0, 's', 'Color', 'g', ...
        'MarkerFaceColor', 'g', 'Visible', 'off', 'MarkerSize', 10);
end
if ~isfield(h,'plotdataCentFit') || ~isvalid(h.plotdataCentFit)
    h.plotdataCentFit = errorbar(h.axes, 0, 0, 0, 'o', ...
        'MarkerSize',       4.5, ...
        'MarkerFaceColor',  'none', ...
        'MarkerEdgeColor',  [0.60 0.75 0.90], ...
        'Color',            [0.60 0.75 0.90], ...
        'LineWidth',        0.9, ...
        'Visible',          'off');
end
% ─────────────────────────────────────────────────────────────────────

set(h.plotdata,'XData',h.FitDataMod{1}(:,1),'YData',h.FitDataMod{1}(:,2), ...
    'YNegativeDelta',h.FitDataMod{1}(:,3),'YPositiveDelta',h.FitDataMod{1}(:,3), ...
    'Visible','on')

% nPoints = size(h.FitDataMod{1},1);
% set(h.SliderFittedPeaks,'Max',max(nPoints,2), ...
%     'SliderStep',[1/max(nPoints-1,1) 1/max(nPoints-1,1)],'Value',1);

dc1    = h.dataXcorr{1};
nValid = sum(~cellfun(@isempty, dc1));
nValid = max(nValid, 1);
set(h.SliderFittedPeaks, ...
    'Min',        1, ...
    'Max',        max(nValid, 2), ...
    'Value',      1, ...
    'SliderStep', [1/max(nValid-1,1)  1/max(nValid-1,1)]);

% ── plotdata korrekt initialisieren ──────────────────────────────────
pv    = h.FitDataMod{1};
idxPV = isfinite(pv(:,2));
if any(idxPV)
    set(h.plotdata, ...
        'XData',          pv(idxPV,1), ...
        'YData',          pv(idxPV,2), ...
        'YNegativeDelta', pv(idxPV,3), ...
        'YPositiveDelta', pv(idxPV,3), ...
        'Visible',        'on');
end

% fitCentroid anzeigen falls Checkbox aktiv
if isfield(h,'datacentFitMat') && ~isempty(h.datacentFitMat) && ...
   isfield(h,'cb_showCentroid') && get(h.cb_showCentroid,'Value') == 1
    cf    = h.datacentFitMat{1};
    idxCF = isfinite(cf(:,2));
    if any(idxCF)
        set(h.plotdataCentFit, ...
            'XData',          cf(idxCF,1), ...
            'YData',          cf(idxCF,2), ...
            'YNegativeDelta', cf(idxCF,3), ...
            'YPositiveDelta', cf(idxCF,3), ...
            'Visible',        'on');
    end
end

% X-Achse anpassen
xData = pv(isfinite(pv(:,1)), 1);
if ~isempty(xData)
    margin = max(5, (max(xData)-min(xData)) * 0.05);
    h.axes.XLim = [min(xData)-margin, max(xData)+margin];
end

% ── Initialen Plot über updateFittedPeakPlot ─────────────────────────
set(h.Slider, 'Value', 1);
guidata(hObj, h);

% ── Ersten gültigen Bin über γ-Mapping finden ────────────────────────
firstBinIdx = 1;
if isfield(h,'FitDataMod') && ~isempty(h.FitDataMod) && ...
   isfield(h,'BinnedGamma') && ~isempty(h.BinnedGamma)

    pv1 = h.FitDataMod{1};
    yCol1 = 2;
    if size(pv1,2) >= 9 && any(isfinite(pv1(:,9)))
        yCol1 = 9;
    end
    firstValidRow = find(isfinite(pv1(:,yCol1)), 1, 'first');

    if ~isempty(firstValidRow)
        gammaFirst = pv1(firstValidRow, 1);   % +90° verschoben

        % Alpha-Gruppe für Peak 1
        if isfield(h,'DEKdataMatchedPeaks') && ...
           size(h.DEKdataMatchedPeaks,1) >= 1
            alphaVal_1 = h.DEKdataMatchedPeaks(1, 7);
            if isfield(h,'uniqueAlpha')
                [~, alphaGrpIdx_1] = min(abs(h.uniqueAlpha - alphaVal_1));
            else
                alphaGrpIdx_1 = 1;
            end
        else
            alphaGrpIdx_1 = 1;
        end

        % bg_1 = h.BinnedGamma{alphaGrpIdx_1};
        % [~, firstBinIdx] = min(abs(bg_1 - gammaFirst));

        % NEU:
        firstBinIdx = firstValidRow;
        firstBinIdx = max(1, min(firstBinIdx, numel(h.dataXcorr{1})));
    end
end

h = updateFittedPeakPlot(h, 1, firstBinIdx);

% plotRawData / plotFitData nicht mehr manuell setzen —
% updateFittedPeakPlot hat bereits alles gezeichnet
% Die alten Handles sind nach cla() ungültig, das ist korrekt so

% ── plotdata1 / plotdata2 für mehrere Detektorpositionen ─────────────
[val_init,~,idxalpha_init] = unique(h.alpha);
if length(val_init) ~= length(idxalpha_init)
    if ~isfield(h,'plotdata1') || ~isvalid(h.plotdata1)
        h.plotdata1 = errorbar(h.axes, NaN, NaN, NaN, 's', ...
            'MarkerSize',      4, ...
            'MarkerFaceColor', [0.094 0.373 0.647], ...
            'MarkerEdgeColor', [0.094 0.373 0.647], ...
            'Color',           [0.094 0.373 0.647], ...
            'LineWidth',       0.8, ...
            'Visible',         'off');
    end
    if ~isfield(h,'plotdata2') || ~isvalid(h.plotdata2)
        h.plotdata2 = errorbar(h.axes, NaN, NaN, NaN, 's', ...
            'MarkerSize',      4, ...
            'MarkerFaceColor', [0.85 0.33 0.10], ...
            'MarkerEdgeColor', [0.85 0.33 0.10], ...
            'Color',           [0.85 0.33 0.10], ...
            'LineWidth',       0.8, ...
            'Visible',         'off');
    end
end

set(hObj,'String','Start Peak Fit','backg',col)

h.plottab.SelectedTab = h.plottab1;
h.axes.YLabel.String  = ['2',char(952),' [°]'];

% Fit-Summe im Intensity-Tab
h = updateFitSumOverlay(h, 1);

% ── Detektormasken-Bereiche im initialen Plot markieren ──────────────
% YLim zuerst explizit setzen damit Patches korrekte Höhe haben
pv_init = h.FitDataMod{1};
[yCol_init, yErr_init, idxFin_init] = getPlausibleCol(pv_init);
if any(idxFin_init)
    yVals_init = pv_init(idxFin_init, yCol_init);
    yErrs_init = abs(pv_init(idxFin_init, yErr_init));
    yRange_init = max(max(yVals_init+yErrs_init) - min(yVals_init-yErrs_init), 0.02);
    h.axes.YLimMode = 'manual';
    h.axes.YLim     = [min(yVals_init-yErrs_init) - yRange_init*0.25, ...
                       max(yVals_init+yErrs_init) + yRange_init*0.25];
end
xData_init = pv_init(isfinite(pv_init(:,1)), 1);
if ~isempty(xData_init)
    margin_init = max(5, (max(xData_init)-min(xData_init))*0.05);
    h.axes.XLim = [min(xData_init)-margin_init, max(xData_init)+margin_init];
end
drawnow;

% Jetzt für alle Peaks die Masken zeichnen
% Ersten Peak mit clearFirst=true, alle weiteren mit clearFirst=false
h = markInvalidGammaRegions(h, 1, true);

% % In der MATLAB-Konsole nach dem Fit eingeben:
% fprintf('FitDataMod: %d Einträge\n', numel(h.FitDataMod));
% fprintf('FitDataRaw: %d Gruppen\n', numel(h.FitDataRaw));
% fprintf('uniqueAlpha: '); fprintf('%.1f°  ', h.uniqueAlpha); fprintf('\n');
% fprintf('alpha: '); fprintf('%.1f°  ', h.alpha); fprintf('\n');
% for k = 1:numel(h.FitDataMod)
%     pv = h.FitDataMod{k};
%     [~,~,idx] = getPlausibleCol(pv);
%     fprintf('Peak %d: %d Zeilen, %d plausibel, gamma=[%.1f°,%.1f°]\n', ...
%         k, size(pv,1), sum(idx), min(pv(:,1)), max(pv(:,1)));
% end

% ── Centroid-Peaklagen aus datacentFitParams in FitDataModCentroid ────
fprintf('── Centroid-Werte übertragen ────────────────────────────\n');
for k = 1:numel(h.FitDataMod)
    if ~isfield(h,'datacentFitParams') || numel(h.datacentFitParams) < k
        continue
    end
    cp  = h.datacentFitParams{k};   % cell-Array mit centroid-Ergebnissen
    mat = h.FitDataMod{k};          % Basis: gleiche Struktur
    
    % Kopie anlegen
    matCent = mat;
    
    nRows = size(mat, 1);
    nTransferred = 0;
    
    for ri = 1:nRows
        if ri > numel(cp) || isempty(cp{ri}), continue; end
        
        cParams = cp{ri};
        if ~isstruct(cParams) || ~isfield(cParams, 'x0'), continue; end
        if ~isfinite(cParams.x0), continue; end
        
        % x0 in Spalte 2 schreiben
        matCent(ri, 2) = cParams.x0;
        
        % Fehler in Spalte 3 schreiben falls vorhanden
        if isfield(h,'datacentFitErrors') && ...
           numel(h.datacentFitErrors) >= k && ...
           numel(h.datacentFitErrors{k}) >= ri && ...
           ~isempty(h.datacentFitErrors{k}{ri}) && ...
           isfield(h.datacentFitErrors{k}{ri}, 'x0') && ...
           isfinite(h.datacentFitErrors{k}{ri}.x0)
            matCent(ri, 3) = h.datacentFitErrors{k}{ri}.x0;
        end
        
        nTransferred = nTransferred + 1;
    end
    
    h.FitDataModCentroid{k} = matCent;
    h.datacentFitMat{k}     = matCent;
    
    fprintf('  Peak %d: %d Centroid-Werte übertragen\n', k, nTransferred);
end
fprintf('────────────────────────────────────────────────────────\n\n');

guidata(hObj, h);

function SliderCallbackPlotRawData(hObj, ~)
% This callback handles the changes when the slider button is pushed.
h = guidata(hObj);
% Get slider value
% value = get(hObj, 'Value');
% value = round(value);

% Prüfung:
if isfield(h, 'FitDataMod') && ~isempty(h.FitDataMod)
    pv_check = h.FitDataMod{1};
    if size(pv_check,2) >= 9
        nNaN = sum(~isfinite(pv_check(:,9)));
    else
        nNaN = sum(~isfinite(pv_check(:,2)));
    end
    fprintf('SliderCallback START: Peak 1 hat %d NaN-Zeilen in h.FitDataMod\n', nNaN);
end

try
    value = get(hObj, 'Value');
    value = round(value);

    % Maximalwert kontextabhängig bestimmen
    currentTab = h.plottab.SelectedTab.Title;
    if strcmp(currentTab, 'Plot intensity data')
        if isfield(h, 'IntensityProfiles') && ~isempty(h.IntensityProfiles)
            maxAllowed = size(h.IntensityProfiles, 2) * size(h.IntensityProfiles{1}, 2);
        else
            maxAllowed = 1;
        end
    else
        % Stress factor method / sin²psi method
        if isfield(h, 'FitDataMod') && ~isempty(h.FitDataMod)
            maxAllowed = size(h.FitDataMod, 1);
        else
            maxAllowed = 1;
        end
    end

    % Slider-Max anpassen falls nötig (verhindert das Zurückspringen)
    if get(hObj, 'Max') ~= max(maxAllowed, 2)
        set(hObj, ...
            'Max',        max(maxAllowed, 2), ...
            'SliderStep', [1/max(maxAllowed-1,1)  1/max(maxAllowed-1,1)]);
    end

    if value < 1 || value > maxAllowed
        value = max(1, min(value, maxAllowed));
        set(hObj, 'Value', value);
    end

catch ME
    warning('Slider:generalError', '[Slider] Fehler: %s', ME.message);
    return
end

assignin('base','hexport',h)
% DEK = get(h.dekdata,"data");
% Sicherheitsprüfung: alpha muss vorhanden sein
if ~isfield(h, 'alpha') || isempty(h.alpha)
    guidata(hObj, h);
    return
end
[val,~,idxalpha] = unique(h.alpha);

if strcmp(h.plottab.SelectedTab.Title,'Stress factor method')

    nFit = size(h.FitDataMod, 1);
    set(h.Slider, 'Max',        max(nFit, 2));
    set(h.Slider, 'SliderStep', [1/max(nFit-1,1)  1/max(nFit-1,1)]);

    % ── useEps VOR if/else definieren — gilt für gesamten Block ──────
    useEps = isfield(h,'epsfitdataexport') && ...
             numel(h.epsfitdataexport) >= value && ...
             ~isempty(h.epsfitdataexport{value}) && ...
             any(isfinite(h.epsfitdataexport{value}(:,2)));

    if length(val) ~= length(idxalpha)
        % ── Mehrere Detektorpositionen ────────────────────────────────
        if ~isfield(h,'plotdata1') || ~isvalid(h.plotdata1) || ...
           ~isfield(h,'plotdata2') || ~isvalid(h.plotdata2)
            guidata(hObj, h);
            return
        end

        set(h.plotdata, ...
            'XData',          h.FitDataMod{value}(:,1), ...
            'YData',          h.FitDataMod{value}(:,2), ...
            'YNegativeDelta', h.FitDataMod{value}(:,3), ...
            'YPositiveDelta', h.FitDataMod{value}(:,3));

        group   = h.FitDataMod{value}(:,8);
        classes = unique(group);
        idx1    = group == classes(1);
        set(h.plotdata1, ...
            'XData',          h.FitDataMod{value}(idx1,1), ...
            'YData',          h.FitDataMod{value}(idx1,2), ...
            'YNegativeDelta', h.FitDataMod{value}(idx1,3), ...
            'YPositiveDelta', h.FitDataMod{value}(idx1,3));
        idx2 = group == classes(2);
        set(h.plotdata2, ...
            'XData',          h.FitDataMod{value}(idx2,1), ...
            'YData',          h.FitDataMod{value}(idx2,2), ...
            'YNegativeDelta', h.FitDataMod{value}(idx2,3), ...
            'YPositiveDelta', h.FitDataMod{value}(idx2,3));

        % ── NEU: useEps auch im Mehrfachdetektor-Fall berücksichtigen ──
        if useEps
            eps    = h.epsfitdataexport{value};
            idxFin = isfinite(eps(:,2)) & isfinite(eps(:,3));
            if any(idxFin)
                set(h.plotdata, ...
                    'XData',          eps(idxFin, 1), ...
                    'YData',          eps(idxFin, 2), ...
                    'YNegativeDelta', abs(eps(idxFin, 3)), ...
                    'YPositiveDelta', abs(eps(idxFin, 3)), ...
                    'MarkerSize',       4, ...
                    'MarkerFaceColor',  [0.094 0.373 0.647], ...
                    'MarkerEdgeColor',  [0.094 0.373 0.647], ...
                    'Color',            [0.094 0.373 0.647], ...
                    'Visible', 'on');
            else
                set(h.plotdata, 'XData', NaN, 'YData', NaN, ...
                    'YNegativeDelta', NaN, 'YPositiveDelta', NaN, ...
                    'Visible', 'off');
            end

            % Fit-Kurve
            if isfield(h,'epsgammaergfunc_x') && ...
               numel(h.epsgammaergfunc_x) >= value && ...
               ~isempty(h.epsgammaergfunc_x{value}) && ...
               numel(h.epsgammaergfunc_x{value}) == numel(h.epsgammaergfunc{value})
                set(h.fitcurvestress, ...
                    'XData',   h.epsgammaergfunc_x{value}(:), ...
                    'YData',   h.epsgammaergfunc{value}(:), ...
                    'Color',   [0.85 0.33 0.10], ...
                    'Visible', 'on');
            else
                set(h.fitcurvestress, 'Visible', 'off');
            end

            % plotdata1 und plotdata2 ausblenden wenn eps-Modus aktiv
            set(h.plotdata1, 'Visible', 'off');
            set(h.plotdata2, 'Visible', 'off');
        end

    else
        % ── Einzeldetektor ────────────────────────────────────────────
        if useEps
            % Nach Stressfit: ε(γ)-Daten anzeigen
            eps    = h.epsfitdataexport{value};
            idxFin = isfinite(eps(:,2));
            if any(idxFin)
                set(h.plotdata, ...
                    'XData',          eps(idxFin,1), ...
                    'YData',          eps(idxFin,2), ...
                    'YNegativeDelta', abs(eps(idxFin,3)), ...
                    'YPositiveDelta', abs(eps(idxFin,3)), ...
                    'Visible', 'on');
            else
                set(h.plotdata, 'XData', NaN, 'YData', NaN, ...
                    'YNegativeDelta', NaN, 'YPositiveDelta', NaN, ...
                    'Visible', 'off');
            end

            % Fit-Kurve
            if isfield(h,'epsgammaergfunc_x') && ...
               numel(h.epsgammaergfunc_x) >= value && ...
               ~isempty(h.epsgammaergfunc_x{value}) && ...
               numel(h.epsgammaergfunc_x{value}) == numel(h.epsgammaergfunc{value})
                set(h.fitcurvestress, ...
                    'XData',   h.epsgammaergfunc_x{value}(:), ...
                    'YData',   h.epsgammaergfunc{value}(:), ...
                    'Visible', 'on');
            else
                ergVec = h.epsgammaergfunc{value}(:);
                if numel(ergVec) == size(eps,1)
                    set(h.fitcurvestress, ...
                        'XData',   eps(:,1), ...
                        'YData',   ergVec, ...
                        'Visible', 'on');
                else
                    set(h.fitcurvestress, 'Visible', 'off');
                end
            end

        else
            % Vor Stressfit: 2θ-Daten aus FitDataMod anzeigen
            pv = h.FitDataMod{value};
            if size(pv,2) >= 10 && any(isfinite(pv(:,9)))
                yColS    = 9;
                yErrColS = 10;
            else
                yColS    = 2;
                yErrColS = 3;
            end
            idxPV = isfinite(pv(:,yColS)) & isfinite(pv(:,yErrColS)) & ...
                    (pv(:,yColS) ~= 0);
            if any(idxPV)
                set(h.plotdata, ...
                    'XData',          pv(idxPV,1), ...
                    'YData',          pv(idxPV,yColS), ...
                    'YNegativeDelta', abs(pv(idxPV,yErrColS)), ...
                    'YPositiveDelta', abs(pv(idxPV,yErrColS)), ...
                    'Visible', 'on');
            else
                set(h.plotdata, 'XData', NaN, 'YData', NaN, ...
                    'YNegativeDelta', NaN, 'YPositiveDelta', NaN, ...
                    'Visible', 'off');
            end
            set(h.fitcurvestress, 'Visible', 'off');
        end

        % fitCentroid
        if isfield(h,'datacentFitMat') && numel(h.datacentFitMat) >= value
            if ~isfield(h,'plotdataCentFit') || ~isvalid(h.plotdataCentFit)
                h.plotdataCentFit = errorbar(h.axes, NaN, NaN, NaN, 'o', ...
                    'Color', [0.60 0.75 0.90], 'Visible', 'off');
            end
            cf       = h.datacentFitMat{value};
            idxCF    = isfinite(cf(:,2));
            showCent = isfield(h,'cb_showCentroid') && ...
                       get(h.cb_showCentroid,'Value') == 1;
            if any(idxCF) && showCent && ~useEps
                set(h.plotdataCentFit, ...
                    'XData',          cf(idxCF,1), ...
                    'YData',          cf(idxCF,2), ...
                    'YNegativeDelta', cf(idxCF,3), ...
                    'YPositiveDelta', cf(idxCF,3), ...
                    'Visible', 'on');
            else
                set(h.plotdataCentFit, 'Visible', 'off');
            end
        end

        set(h.plotdata, 'DisplayName', 'fitPseudoVoigt');
        if isfield(h,'plotdataCentFit') && isvalid(h.plotdataCentFit)
            set(h.plotdataCentFit, 'DisplayName', 'fitCentroid');
        end
        legend(h.axes, 'Location', 'best', 'FontSize', 9);
    end

    % ── Highlight im Spannungsplot ────────────────────────────────────
    if isfield(h,'taumean') && value <= numel(h.taumean)
        set(h.highlightstressplot, ...
            'XData',   h.taumean(value), ...
            'YData',   h.sigmaFinal(value,1), ...
            'Visible', 'on');
    end

    assignin('base','hfinal',h)

    % ── updateFittedPeakPlot mit erstem gültigem Bin ──────────────────
    % firstBinIdx = 1;
    % if isfield(h,'FitDataMod') && numel(h.FitDataMod) >= value && ...
    %    isfield(h,'BinnedGamma') && ~isempty(h.BinnedGamma)
    %     pv_val   = h.FitDataMod{value};
    %     yCol_val = 2;
    %     if size(pv_val,2) >= 9 && any(isfinite(pv_val(:,9)))
    %         yCol_val = 9;
    %     end
    %     firstValidRow = find(isfinite(pv_val(:,yCol_val)), 1, 'first');
    %     if ~isempty(firstValidRow)
    %         gammaFirst = pv_val(firstValidRow, 1);
    %         safeIdxVal = max(1, min(value, numel(h.BinnedGamma)));
    %         [~, firstBinIdx] = min(abs(h.BinnedGamma{safeIdxVal} - gammaFirst));
    %     end
    % end

    firstBinIdx = 1;
    if isfield(h,'FitDataMod') && numel(h.FitDataMod) >= value && ...
       isfield(h,'BinnedGamma') && ~isempty(h.BinnedGamma)
    
        pv_val = h.FitDataMod{value};
        yCol_val = 2;
        if size(pv_val,2) >= 9 && any(isfinite(pv_val(:,9)))
            yCol_val = 9;
        end
        firstValidRow = find(isfinite(pv_val(:,yCol_val)), 1, 'first');
    
        if ~isempty(firstValidRow)
            gammaFirst = pv_val(firstValidRow, 1);   % +90° verschoben
    
            % Alpha-Gruppe bestimmen
            if isfield(h,'DEKdataMatchedPeaks') && ...
               size(h.DEKdataMatchedPeaks,1) >= value
                alphaVal_v = h.DEKdataMatchedPeaks(value, 7);
                if isfield(h,'uniqueAlpha')
                    [~, alphaGrpIdx_v] = min(abs(h.uniqueAlpha - alphaVal_v));
                else
                    alphaGrpIdx_v = 1;
                end
            else
                alphaGrpIdx_v = 1;
            end
    
            % γ-Wert in BinnedGamma suchen
            bg_v = h.BinnedGamma{alphaGrpIdx_v};
            [~, firstBinIdx] = min(abs(bg_v - gammaFirst));
        end
    end

    h = updateFittedPeakPlot(h, value, firstBinIdx);

    % ── YLim setzen ───────────────────────────────────────────────────
    if useEps
        eps    = h.epsfitdataexport{value};
        idxFin = isfinite(eps(:,2)) & isfinite(eps(:,3));
        if any(idxFin)
            yLow   = eps(idxFin,2) - abs(eps(idxFin,3));
            yHigh  = eps(idxFin,2) + abs(eps(idxFin,3));
            yRange = max(max(yHigh)-min(yLow), 1e-6);
            h.axes.YLimMode = 'manual';
            h.axes.YLim     = [min(yLow)-yRange*0.20, max(yHigh)+yRange*0.20];
        else
            h.axes.YLimMode = 'auto';
        end
    else
        pv = h.FitDataMod{value};
        nCols = size(pv, 2);
        
        % Spalten 9+10 nur verwenden wenn BEIDE vorhanden und finite Werte haben
        if nCols >= 10 && any(isfinite(pv(:,9))) && any(isfinite(pv(:,10)))
            yCol    = 9;
            yErrCol = 10;
        elseif nCols >= 3 && any(isfinite(pv(:,2)))
            yCol    = 2;
            yErrCol = 3;
        else
            h.axes.YLimMode = 'auto';
            % weiter zum nächsten Block
            yCol    = 2;
            yErrCol = 3;
        end

        % Sicherheitscheck: Spaltenindex darf Array-Breite nicht überschreiten
        yCol    = min(yCol,    nCols);
        yErrCol = min(yErrCol, nCols);

        idxFin = isfinite(pv(:,yCol)) & (pv(:,yCol) ~= 0);
        if any(idxFin)
            yLow  = pv(idxFin,yCol) - abs(pv(idxFin,yErrCol));
            yHigh = pv(idxFin,yCol) + abs(pv(idxFin,yErrCol));
            yLow  = yLow(isfinite(yLow));
            yHigh = yHigh(isfinite(yHigh));
            if ~isempty(yLow) && ~isempty(yHigh)
                yMin   = min(yLow);
                yMax   = max(yHigh);
                yRange = max(yMax - yMin, 0.02);
                h.axes.YLimMode = 'manual';
                h.axes.YLim     = [yMin - yRange*0.25, yMax + yRange*0.25];
            end
        else
            h.axes.YLimMode = 'auto';
        end
    end

    % ── Detektormasken-Bereiche markieren ────────────────────────────
    h = markInvalidGammaRegions(h, value);
    % Patches nur anzeigen wenn noch kein Stressfit vorhanden
    % if ~isfield(h, 'epsfitdataexport') || isempty(h.epsfitdataexport)
    %     h = markInvalidGammaRegions(h, value);
    % end
    % delete(findobj(h.axes, 'Tag', 'maskregion'));
    % delete(findobj(h.axes, 'Tag', 'peakmask'));
    % ── Y-Achsenbeschriftung ──────────────────────────────────────────
    if useEps
        h.axes.YLabel.String = [char(949),'(',char(947),')'];
    else
        h.axes.YLabel.String = '2\theta [°]';
    end

    % % ── SliderFittedPeaks ─────────────────────────────────────────────
    % if isfield(h,'validBinIdxs') && numel(h.validBinIdxs) >= value && ...
    %    ~isempty(h.validBinIdxs{value})
    %     nValid = numel(h.validBinIdxs{value});
    % else
    %     if isfield(h,'dataXcorr') && numel(h.dataXcorr) >= value
    %         dc     = h.dataXcorr{value};
    %         nValid = sum(~cellfun(@isempty, dc));
    %     else
    %         nValid = size(h.FitDataMod{value}, 1);
    %     end
    % end
    % nValid = max(nValid, 1);
    % set(h.SliderFittedPeaks, ...
    %     'Min',        1, ...
    %     'Max',        max(nValid, 2), ...
    %     'Value',      max(1, min(round(get(h.SliderFittedPeaks,'Value')), nValid)), ...
    %     'SliderStep', [1/max(nValid-1,1)  1/max(nValid-1,1)]);

    % ── SliderFittedPeaks ─────────────────────────────────────────────
    if isfield(h,'FitDataMod') && numel(h.FitDataMod) >= value
        pv_sl = h.FitDataMod{value};
        [~, ~, idxPl_sl] = getPlausibleCol(pv_sl);
    
        safeIdx_sl = max(1, min(value, numel(h.dataXcorr)));
        nDC_sl     = numel(h.dataXcorr{safeIdx_sl});
        neDXC_sl   = false(size(pv_sl,1), 1);
        if nDC_sl > 0
            maxR_sl = min(nDC_sl, size(pv_sl,1));
            neDXC_sl(1:maxR_sl) = ~cellfun(@isempty, ...
                h.dataXcorr{safeIdx_sl}(1:maxR_sl));
        end
        nValid = sum(idxPl_sl & neDXC_sl);
    else
        nValid = 1;
    end
    
    nValid = max(nValid, 1);
    set(h.SliderFittedPeaks, ...
        'Min',        1, ...
        'Max',        max(nValid, 2), ...
        'Value',      max(1, min(round(get(h.SliderFittedPeaks,'Value')), nValid)), ...
        'SliderStep', [1/max(nValid-1,1)  1/max(nValid-1,1)]);

    % ── XLim anpassen ────────────────────────────────────────────────
    pv    = h.FitDataMod{value};
    xData = pv(isfinite(pv(:,1)), 1);
    if ~isempty(xData)
        xMin   = min(xData);
        xMax   = max(xData);
        margin = max(5, (xMax-xMin)*0.05);
        h.axes.XLim = [xMin-margin, xMax+margin];
    end

    set(h.SliderFittedPeaks,'Value',1);

    % ── highlightpeakdata ─────────────────────────────────────────────
    if ~useEps
        if isfield(h,'rb_fitpv') && get(h.rb_fitpv,'Value') == 1 && ...
           size(h.FitDataMod{value},2) >= 9 && isfinite(h.FitDataMod{value}(1,9))
            set(h.highlightpeakdata, ...
                'XData',   h.FitDataMod{value}(1,1), ...
                'YData',   h.FitDataMod{value}(1,9), ...
                'Visible', 'on');
        else
            set(h.highlightpeakdata, ...
                'XData',   h.FitDataMod{value}(1,1), ...
                'YData',   h.FitDataMod{value}(1,2), ...
                'Visible', 'on');
        end
    else
        set(h.highlightpeakdata, 'Visible', 'off');
    end

    % ── Tau-Plot ──────────────────────────────────────────────────────
    if isfield(h,'tau') && numel(h.tau) >= value && ~isempty(h.tau{value})
        tauVec = h.tau{value}(:);

        pv_tau = h.FitDataMod{value};
        if size(pv_tau,2) >= 9 && any(isfinite(pv_tau(:,9)) & pv_tau(:,9) > 1.0)
            idxTauValid = isfinite(pv_tau(:,9)) & (pv_tau(:,9) > 1.0);
        else
            idxTauValid = isfinite(pv_tau(:,2)) & (pv_tau(:,2) > 1.0);
        end
        xVec = pv_tau(idxTauValid, 1);

        if numel(tauVec) == numel(xVec)
            tauMin   = min(tauVec);
            tauMax   = max(tauVec);
            tauRange = max(tauMax - tauMin, 0.1);
            set(h.plottaudata,    'XData', xVec, 'YData', tauVec);
            set(h.plottaudatamean,'XData', xVec, ...
                'YData', repelem(mean(tauVec(isfinite(tauVec))), numel(xVec)));
            h.axesPlottauData.XLim = h.axes.XLim;
            h.axesPlottauData.YLim = [tauMin - tauRange*0.15, ...
                                       tauMax + tauRange*0.15];
        end
    end

    % ── sin²ψ synchronisieren ─────────────────────────────────────────
    if isfield(h,'epssin2psifitdaten') && numel(h.epssin2psifitdaten) >= value
        s2p = h.epssin2psifitdaten{value};
        set(h.plotdatasin2psi, ...
            'XData',          s2p(:,1), ...
            'YData',          s2p(:,2), ...
            'YNegativeDelta', abs(s2p(:,3)), ...
            'YPositiveDelta', abs(s2p(:,3)));
        reg = h.sin2psiregres{value};
        if numel(reg) == 21
            set(h.fitcurvestresssin2psi, 'YData', reg, 'Visible', 'on');
        else
            set(h.fitcurvestresssin2psi, 'Visible', 'off');
        end
    end
elseif strcmp(h.plottab.SelectedTab.Title,'sin²psi method')
    % set(h.Slider,'Max',size(h.FitDataMod,1));
    % set(h.Slider,'SliderStep',[1/(size(h.FitDataMod,1)-1) 1/(size(h.FitDataMod,1)-1)]);
    nFit = size(h.FitDataMod, 1);
    set(h.Slider, 'Max',        max(nFit, 2));
    set(h.Slider, 'SliderStep', [1/max(nFit-1,1)  1/max(nFit-1,1)]);
    if isfield(h,'epssin2psifitdaten')
        set(h.plotdatasin2psi,'Xdata',h.epssin2psifitdaten{value}(:,1))
        set(h.plotdatasin2psi,'Ydata',h.epssin2psifitdaten{value}(:,2))
        set(h.plotdatasin2psi,'YNegativeDelta',h.epssin2psifitdaten{value}(:,3))
        set(h.plotdatasin2psi,'YPositiveDelta',h.epssin2psifitdaten{value}(:,3))

        set(h.fitcurvestresssin2psi,'Ydata',h.sin2psiregres{value})
    end
    h.axessin2psi.XLim = [0,1];
    h.axessin2psi.YLim = [-Inf,Inf];

    % Set data for stress factor method
    % Set plot data
    if isfield(h,'epsfitdataexport')
        eps = h.epsfitdataexport{value};
        erg = h.epsgammaergfunc{value};

        idxFin = isfinite(eps(:,2));
        if any(idxFin)
            set(h.plotdata, ...
                'XData',          eps(idxFin,1), ...
                'YData',          eps(idxFin,2), ...
                'YNegativeDelta', abs(eps(idxFin,3)), ...
                'YPositiveDelta', abs(eps(idxFin,3)), ...
                'Visible', 'on');
        else
            set(h.plotdata, 'XData', NaN, 'YData', NaN, ...
                'YNegativeDelta', NaN, 'YPositiveDelta', NaN, 'Visible', 'off');
        end

        % Fit-Kurve nur setzen wenn Längen übereinstimmen
        ergVec = erg(:);
        if numel(ergVec) == size(eps,1)
            set(h.fitcurvestress, ...
                'XData',   eps(:,1), ...
                'YData',   ergVec, ...
                'Visible', 'on');
        else
            set(h.fitcurvestress, 'Visible', 'off');
        end
    end

    if isfield(h,'tau')
        tauVec = h.tau{value}(:);
        xVec   = h.FitDataMod{value}(:,1);
        if numel(tauVec) == numel(xVec)
            set(h.plottaudata,    'XData', xVec, 'YData', tauVec);
            set(h.plottaudatamean,'XData', xVec, ...
                'YData', repelem(mean(tauVec), numel(xVec)));
            h.axesPlottauData.XLim = h.axes.XLim;
            h.axesPlottauData.YLim = [0, round(max(tauVec))+1];
        end
    end

    if isfield(h,'taumean')
        set(h.highlightstressplot,'xdata',h.taumean(value))
        set(h.highlightstressplot,'ydata',h.sigmaFinal(value,1))
        set(h.highlightstressplot,'Visible','on')
    end

elseif strcmp(h.plottab.SelectedTab.Title,'Plot intensity data')
    
    nProf = sum(cellfun(@(y) size(y,2), h.IntensityProfiles));
    set(h.Slider, 'Max',        max(nProf, 2));
    set(h.Slider, 'SliderStep', [1/max(nProf-1,1)  1/max(nProf-1,1)]);

    % Globalen Slider-Index in Gruppe + lokalen Bin umrechnen
    [m_plot, localBin] = globalSliderToGroupBin(value, h.dataY);

    % plotIntensityData neu anlegen falls gelöscht
    if ~isfield(h,'plotIntensityData') || ~isvalid(h.plotIntensityData)
        hold(h.axesPlotIntensityData, 'on');
        h.plotIntensityData = plot(h.axesPlotIntensityData, ...
            h.dataXPlot(:,value), h.dataYPlot(:,value), '-', ...
            'Color', [0.75 0.75 0.75], 'LineWidth', 0.8);
    else
        set(h.plotIntensityData, 'XData', h.dataXPlot(:,value))
        set(h.plotIntensityData, 'YData', h.dataYPlot(:,value))
    end

    % Korrigiertes Spektrum aktualisieren
    delete(findobj(h.axesPlotIntensityData, 'Tag', 'bgcorrected'));
    if isfield(h,'dataXcorrBg') && numel(h.dataXcorrBg) >= m_plot && ...
       numel(h.dataXcorrBg{m_plot}) >= localBin && ...
       ~isempty(h.dataXcorrBg{m_plot}{localBin})
        hold(h.axesPlotIntensityData, 'on');
        plot(h.axesPlotIntensityData, ...
            h.dataXcorrBg{m_plot}{localBin}, ...
            h.dataYcorrBg{m_plot}{localBin}, '-', ...
            'Color', [0.094 0.373 0.647], 'LineWidth', 1.2, ...
            'Tag', 'bgcorrected');
    end

    % ── Detektorlücken aus valid_fraction im Intensity-Plot markieren ─────
    delete(findobj(h.axesPlotIntensityData, 'Tag', 'detmask'));
    
    if isfield(h, 'pyfaiOutPerAlpha') && ~isempty(h.pyfaiOutPerAlpha)
        [m_grp, localBin] = globalSliderToGroupBin(value, h.dataY);
    
        out_k = h.pyfaiOutPerAlpha{m_grp};
    
        % valid_fraction bevorzugen, Fallback auf caked_mask
        if isfield(out_k, 'valid_fraction') && ~isempty(out_k.valid_fraction)
            fracMat = double(out_k.valid_fraction);
        elseif isfield(out_k, 'caked_mask') && ~isempty(out_k.caked_mask)
            fracMat = double(out_k.caked_mask);
        else
            fracMat = [];
        end
    
        if ~isempty(fracMat)
            radialAll = double(out_k.radial(:));
            azimAll   = double(out_k.azimuthal(:));
            gamma_raw = h.BinnedGammaRaw{m_grp}(localBin);
    
            % chi-Index für diesen Bin
            [~, chiIdx] = min(abs(azimAll - gamma_raw));
    
            % Mitteln über halfWin Nachbarbins
            halfWin  = str2double(get(h.trackChiAvgBinsEdit, 'String'));
            if isnan(halfWin), halfWin = 4; end
            idxRange = max(1, chiIdx-halfWin) : min(numel(azimAll), chiIdx+halfWin);
            maskRow  = mean(fracMat(idxRange, :), 1);   % [1 x npt_rad]
    
            % Auf genutzten 2theta-Bereich einschränken
            TX      = h.dataX{m_grp};
            idxTth  = find(radialAll >= min(TX) & radialAll <= max(TX));
            maskROI = maskRow(idxTth);
            radROI  = radialAll(idxTth);
    
            % Schwellenwert aus GUI
            if isfield(h, 'peakMaskThreshEdit') && isvalid(h.peakMaskThreshEdit)
                maskThresh = str2double(get(h.peakMaskThreshEdit, 'String'));
                if isnan(maskThresh) || maskThresh <= 0 || maskThresh > 1
                    maskThresh = 0.99;
                end
            else
                maskThresh = 0.99;
            end
    
            % Zusammenhängende maskierte Bereiche finden
            isMasked = maskROI < maskThresh;
            if any(isMasked)
                changes  = diff([false, isMasked, false]);
                blkStart = find(changes ==  1);
                blkEnd   = find(changes == -1) - 1;
    
                yLims = h.axesPlotIntensityData.YLim;
                hold(h.axesPlotIntensityData, 'on');
    
                for bb = 1:numel(blkStart)
                    xL = radROI(blkStart(bb));
                    xR = radROI(blkEnd(bb));
    
                    patch(h.axesPlotIntensityData, ...
                        [xL xR xR xL], ...
                        [yLims(1) yLims(1) yLims(2) yLims(2)], ...
                        [0.7 0.7 0.7], ...
                        'FaceAlpha', 0.45, ...
                        'EdgeColor', [0.5 0.5 0.5], ...
                        'LineStyle', '--', ...
                        'LineWidth', 0.8, ...
                        'Tag',       'detmask');
    
                    uistack(findobj(h.axesPlotIntensityData, ...
                        'Tag', 'detmask'), 'bottom');
                end
            end
        end
    end

    % BG-Marker für aktuellen Bin neu berechnen
    delete(findobj(h.axesPlotIntensityData, 'Tag', 'bgmarker'));
    if isfield(h,'BgIntervals') && ~isempty(h.BgIntervals)
        TX      = h.dataX{m_plot};
        TY      = h.dataY{m_plot}(:, localBin);
        nGroups = size(h.BgIntervals, 1);
        bgXplot = zeros(1, nGroups*2);
        bgYplot = zeros(1, nGroups*2);
        for g = 1:nGroups
            idxL = Tools.Data.DataSetOperations.FindNearestIndex(...
                TX, h.BgIntervals(g,1));
            idxR = Tools.Data.DataSetOperations.FindNearestIndex(...
                TX, h.BgIntervals(g,2));
            bgXplot(2*g-1) = TX(idxL);
            bgXplot(2*g)   = TX(idxR);
            bgYplot(2*g-1) = TY(idxL);
            bgYplot(2*g)   = TY(idxR);
        end
        [bgXsort, sortIdx] = sort(bgXplot);
        bgYsort = bgYplot(sortIdx);
        xFull   = linspace(min(TX), max(TX), 500)';
        yBgFull = interp1(bgXsort, bgYsort, xFull, 'linear', 'extrap');
        yBgFull = max(yBgFull, 0);
        hold(h.axesPlotIntensityData, 'on');
        plot(h.axesPlotIntensityData, xFull, yBgFull, '--', ...
            'Color',     [0.8 0.4 0], ...
            'LineWidth', 1.2, ...
            'Tag',       'bgmarker');
        plot(h.axesPlotIntensityData, bgXsort, bgYsort, 'v', ...
            'Color',           [0.8 0.4 0], ...
            'MarkerFaceColor', [0.8 0.4 0], ...
            'MarkerSize',      8, ...
            'Tag',             'bgmarker');
    end

    % Peak-Marker aktualisieren
    delete(findobj(h.axesPlotIntensityData, 'Tag', 'peakmarker'));
    if isfield(h,'UserPeaks') && ~isempty(h.UserPeaks) && ...
       isfield(h,'dataXcorrBg') && numel(h.dataXcorrBg) >= m_plot && ...
       numel(h.dataXcorrBg{m_plot}) >= localBin && ...
       ~isempty(h.dataXcorrBg{m_plot}{localBin})
        hold(h.axesPlotIntensityData, 'on');
        for pk = 1:numel(h.UserPeaks)
            yPk = interp1(h.dataXcorrBg{m_plot}{localBin}, ...
                          h.dataYcorrBg{m_plot}{localBin}, ...
                          h.UserPeaks(pk), 'linear', 'extrap');
            plot(h.axesPlotIntensityData, h.UserPeaks(pk), yPk, '^', ...
                'Color', 'r', 'MarkerFaceColor', 'r', 'MarkerSize', 8, ...
                'Tag', 'peakmarker');
        end
    end

    % % Fit-Summe aktualisieren
    % if isfield(h,'FitDataMod') && ~isempty(h.FitDataMod)
    %     % Nur Peaks der aktuellen Alpha-Gruppe anzeigen
    %     [m_grp, ~] = globalSliderToGroupBin(value, h.dataY);
    % 
    %     % FitDataMod-Indizes die zu dieser Alpha-Gruppe gehören
    %     if isfield(h,'DEKdataMatchedPeaks') && ~isempty(h.DEKdataMatchedPeaks)
    %         alphaVal   = h.uniqueAlpha(m_grp);
    %         idxThisGrp = find(h.DEKdataMatchedPeaks(:,7) == alphaVal);
    %     else
    %         % Fallback: gleichmäßige Aufteilung
    %         nPeaksTotal  = numel(h.FitDataMod);
    %         nPeaksPerGrp = nPeaksTotal / numel(h.uniqueAlpha);
    %         idxThisGrp   = (m_grp-1)*nPeaksPerGrp+1 : m_grp*nPeaksPerGrp;
    %     end
    % 
    %     h = updateFitSumOverlay(h, value, idxThisGrp);
    %     set(findobj(h.axesPlotIntensityData, 'Tag', 'bgmarker'),    'Visible', 'off');
    %     set(findobj(h.axesPlotIntensityData, 'Tag', 'rawspectrum'), 'Visible', 'off');
    %     set(findobj(h.axesPlotIntensityData, 'Tag', 'peakmarker'),  'Visible', 'off');
    %     set(h.plotIntensityData, 'Visible', 'off');
    % end


    % Fit-Summe aktualisieren
    if isfield(h,'FitDataMod') && ~isempty(h.FitDataMod)
        [m_grp, localBin_s] = globalSliderToGroupBin(value, h.dataY);
    
        % FitDataMod-Indizes dieser Alpha-Gruppe
        % if isfield(h,'DEKdataMatchedPeaks') && ~isempty(h.DEKdataMatchedPeaks)
        %     alphaVal_s = h.uniqueAlpha(m_grp);
        %     idxThisGrp = find(h.DEKdataMatchedPeaks(:,7) == alphaVal_s);
        if isfield(h,'DEKdataMatchedPeaks') && ~isempty(h.DEKdataMatchedPeaks)
            alphaVal_s = h.uniqueAlpha(m_grp);
            idxThisGrp = find(abs(h.DEKdataMatchedPeaks(:,7) - alphaVal_s) < 0.1);    
        else
            nPeaksTotal  = numel(h.FitDataMod);
            nPeaksPerGrp = nPeaksTotal / numel(h.uniqueAlpha);
            idxThisGrp   = (m_grp-1)*nPeaksPerGrp+1 : m_grp*nPeaksPerGrp;
        end
    
        % Prüfen ob gammaCurrent im gefitteten γ-Bereich liegt
        if localBin_s <= numel(h.BinnedGamma{m_grp})
            gammaCurr_s = h.BinnedGamma{m_grp}(localBin_s);
        else
            gammaCurr_s = NaN;
        end
    
        inFitRange = false;
        if isfinite(gammaCurr_s)
            for pk_s = idxThisGrp(:)'
                if pk_s > numel(h.FitDataMod), continue; end
                mat_s    = h.FitDataMod{pk_s};
                [~,~,idxFin_s] = getPlausibleCol(mat_s);
                if ~any(idxFin_s), continue; end
                gammaMin = min(mat_s(idxFin_s, 1));
                gammaMax = max(mat_s(idxFin_s, 1));
                % Toleranz = 1.5x Schrittweite
                stepSize = median(abs(diff(sort(mat_s(idxFin_s,1)))));
                tol      = max(stepSize * 1.5, 3.0);
                if gammaCurr_s >= gammaMin - tol && ...
                   gammaCurr_s <= gammaMax + tol
                    inFitRange = true;
                    break
                end
            end
        end
    
        fprintf('inFitRange-Check: gammaCurr_s=%.2f°\n', gammaCurr_s);
            for pk_s = idxThisGrp(:)'
                if pk_s > numel(h.FitDataMod), continue; end
                mat_s = h.FitDataMod{pk_s};
                [~,~,idxFin_s] = getPlausibleCol(mat_s);
                if ~any(idxFin_s), continue; end
                gammaMin = min(mat_s(idxFin_s,1));
                gammaMax = max(mat_s(idxFin_s,1));
                stepSize = median(abs(diff(sort(mat_s(idxFin_s,1)))));
                tol = max(stepSize*1.5, 3.0);
                fprintf('  pk=%d  γ=[%.1f°,%.1f°]  tol=%.2f  inRange=%d\n', ...
                    pk_s, gammaMin, gammaMax, tol, ...
                    gammaCurr_s>=gammaMin-tol && gammaCurr_s<=gammaMax+tol);
            end
            fprintf('  inFitRange=%d\n', inFitRange);

        if inFitRange
            h = updateFitSumOverlay(h, value, idxThisGrp);
            set(findobj(h.axesPlotIntensityData, 'Tag', 'bgmarker'),    'Visible', 'off');
            set(findobj(h.axesPlotIntensityData, 'Tag', 'rawspectrum'), 'Visible', 'off');
            set(findobj(h.axesPlotIntensityData, 'Tag', 'peakmarker'),  'Visible', 'off');
            set(h.plotIntensityData, 'Visible', 'off');
        else
            % Außerhalb gefitteter Bereich → Overlays löschen, Rohspektrum zeigen
            delete(findobj(h.axesPlotIntensityData, 'Tag', 'fitsumoverlay'));
            if isfield(h,'plotIntensityData') && isvalid(h.plotIntensityData)
                set(h.plotIntensityData, 'Visible', 'on');
            end
        end
    end

    if isfield(h,'LocationsPlot')
        set(h.plotpeaklocations,'Xdata',h.LocationsPlot{value})
        set(h.plotpeaklocations,'Ydata',h.AmplitudePlot{value})
    end

    delete(h.plotpeakstheo)
    if strcmp(get(h.radiobuttonwavelength.SelectedObject,'String'),'Ga K-alpha')
        h.plotpeakstheo = xline(h.axesPlotIntensityData,h.PeakPos{1},'--r',h.rowsAsStrings{1}, ...
            'LabelVerticalAlignment','middle','LabelHorizontalAlignment','left');
    elseif strcmp(get(h.radiobuttonwavelength.SelectedObject,'String'),'In K-alpha')
        h.plotpeakstheo = xline(h.axesPlotIntensityData,h.PeakPos{2},'--r',h.rowsAsStrings{2}, ...
            'LabelVerticalAlignment','middle','LabelHorizontalAlignment','left');
    elseif strcmp(get(h.radiobuttonwavelength.SelectedObject,'String'),'In K-beta')
        h.plotpeakstheo = xline(h.axesPlotIntensityData,h.PeakPos{3},'--r',h.rowsAsStrings{3}, ...
            'LabelVerticalAlignment','middle','LabelHorizontalAlignment','left');
    end

    % Nach der Berechnung von maskRow:
    fprintf('Debug detmask: gamma_raw=%.2f°  chiIdx=%d\n', gamma_raw, chiIdx);
    fprintf('  azimAll(chiIdx)=%.2f°\n', azimAll(chiIdx));
    fprintf('  maskRow: %d von %d Kanäle maskiert\n', sum(maskROI < 0.5), numel(maskROI));
    fprintf('  isMasked Bereiche: %d\n', sum(diff([false, isMasked, false]) == 1));  
end

% ── Aktuellen γ-Wert anzeigen ─────────────────────────────────────────
if strcmp(h.plottab.SelectedTab.Title, 'Stress factor method') && ...
   isfield(h,'BinnedGamma') && ~isempty(h.BinnedGamma) && ...
   isfield(h,'FitDataMod')  && ~isempty(h.FitDataMod)  && ...
   value <= numel(h.FitDataMod)

    pv = h.FitDataMod{value};
    % if size(pv,2) >= 9 && any(isfinite(pv(:,9)))
    if size(pv,2) >= 10 && any(isfinite(pv(:,9))) && any(isfinite(pv(:,10)))
        yCol = 9;
    else
        yCol = 2;
    end
    idxFin = isfinite(pv(:,yCol));
    nValid = sum(idxFin);
    if nValid > 0
        gammaRange = [min(pv(idxFin,1)), max(pv(idxFin,1))];
        tthMean    = mean(pv(idxFin,yCol));
        if isfield(h,'DEKdataMatchedPeaks') && ...
           size(h.DEKdataMatchedPeaks,1) >= value
            hklStr   = sprintf('%d%d%d', ...
                h.DEKdataMatchedPeaks(value,1), ...
                h.DEKdataMatchedPeaks(value,2), ...
                h.DEKdataMatchedPeaks(value,3));
            alphaVal = h.DEKdataMatchedPeaks(value,7);
        else
            hklStr   = '???';
            alphaVal = NaN;
        end
        fprintf('Peak %d  |  hkl=%s  |  α=%.1f°  |  γ=[%.1f°, %.1f°]  |  2θ_mean=%.4f°  |  %d gültige Bins\n', ...
            value, hklStr, alphaVal, ...
            gammaRange(1), gammaRange(2), ...
            tthMean, nValid);
    else
        fprintf('Peak %d  |  keine gültigen Bins\n', value);
    end

elseif strcmp(h.plottab.SelectedTab.Title, 'Plot intensity data') && ...
       isfield(h,'BinnedGamma') && ~isempty(h.BinnedGamma)

    [m_grp, localBin] = globalSliderToGroupBin(value, h.dataY);
    gammaVal = h.BinnedGamma{m_grp}(localBin);
    fprintf('Slider=%d  →  Alpha-Gruppe=%d  Bin=%d  γ=%.2f°\n', ...
        value, m_grp, localBin, gammaVal);

end

guidata(hObj, h);


function SliderCallbackFittedPeaks(hObj, ~)
% Scrollt unabhängig durch die gefitteten Peaks (γ-Bins) des aktuell
% im Stress-Tab ausgewählten Peaks.
% Keine Kopplung mehr an h.Slider.

h = guidata(hObj);

% ── Slider-Wert lesen ────────────────────────────────────────────────
try
    binValue = round(get(hObj, 'Value'));
    maxVal   = round(get(hObj, 'Max'));
    binValue = max(1, min(binValue, maxVal));
catch ME
    warning('SliderFittedPeaks:generalError', '%s', ME.message);
    return
end

% ── Welcher Peak ist im Stress-Tab aktiv? ────────────────────────────
% h.Slider zeigt auf den aktuellen Peak-Index (FitDataMod-Eintrag)
peakIdx = max(1, min(round(get(h.Slider,'Value')), numel(h.FitDataMod)));

% ── Sicherheitsprüfungen ─────────────────────────────────────────────
if ~isfield(h,'FitDataMod') || isempty(h.FitDataMod) || ...
   peakIdx > numel(h.FitDataMod)
    guidata(hObj, h);
    return
end

% pv = h.FitDataMod{peakIdx};

% % ── Gültige Zeilen in FitDataMod bestimmen ───────────────────────────
% % FitDataMod kann NaN-Zeilen enthalten (gelöschte Punkte)
% % if size(pv,2) >= 9 && any(isfinite(pv(:,9)))
% if size(pv,2) >= 10 && any(isfinite(pv(:,9))) && any(isfinite(pv(:,10)))
%     yCol = 9;
% else
%     yCol = 2;
% end
% validRows = find(isfinite(pv(:,yCol)));
% 
% if isempty(validRows)
%     guidata(hObj, h);
%     return
% end
% 
% % binValue zeigt auf Index in validRows
% binValueClamped = max(1, min(binValue, numel(validRows)));
% fitDataRow      = validRows(binValueClamped);   % Zeile in FitDataMod
% gammaTarget     = pv(fitDataRow, 1);            % γ-Wert dieser Zeile
% 
% % ── Passenden Index in dataXcorr über γ-Wert finden ──────────────────
% % dataXcorr hat alle γ-Bins (inkl. leerer), FitDataMod nur die gefitteten
% safeIdx = max(1, min(peakIdx, numel(h.dataXcorr)));
% dc      = h.dataXcorr{safeIdx};
% 
% % γ-Wert → Index in BinnedGamma → Index in dataXcorr
% if isfield(h,'BinnedGamma') && numel(h.BinnedGamma) >= safeIdx && ...
%    ~isempty(h.BinnedGamma{safeIdx})
%     [~, gammaIdx] = min(abs(h.BinnedGamma{safeIdx} - gammaTarget));
% else
%     gammaIdx = fitDataRow;
% end
% gammaIdx = max(1, min(gammaIdx, numel(dc)));

% ── Gültige Zeilen in FitDataMod bestimmen ───────────────────────────
pv = h.FitDataMod{peakIdx};

if size(pv,2) >= 10 && any(isfinite(pv(:,9))) && any(isfinite(pv(:,10)))
    yCol = 9;
else
    yCol = 2;
end
% validRows = find(isfinite(pv(:,yCol)));

% NEU: plausible 2θ-Werte (> 1°) UND nicht-leere dataXcorr-Einträge
[~, ~, idxPlausible] = getPlausibleCol(pv);

safeIdx = max(1, min(peakIdx, numel(h.dataXcorr)));
nDC     = numel(h.dataXcorr{safeIdx});
nonEmptyDXC = false(size(pv,1), 1);
if nDC > 0
    maxR = min(nDC, size(pv,1));
    nonEmptyDXC(1:maxR) = ~cellfun(@isempty, h.dataXcorr{safeIdx}(1:maxR));
end

validRows = find(idxPlausible & nonEmptyDXC);

if isempty(validRows)
    guidata(hObj, h);
    return
end

% binValue zeigt auf Index in validRows
binValueClamped = max(1, min(binValue, numel(validRows)));
fitDataRow      = validRows(binValueClamped);
gammaTarget     = pv(fitDataRow, 1);   % γ-Wert dieser Zeile (+90° verschoben)

% ── Passenden Index in dataXcorr über γ-Wert in BinnedGamma finden ───
% WICHTIG: nicht fitDataRow direkt verwenden — BinnedGamma-Index suchen
% safeIdx = max(1, min(peakIdx, numel(h.dataXcorr)));
% 
% if isfield(h,'BinnedGamma') && numel(h.BinnedGamma) >= 1
%     % Alpha-Gruppe bestimmen
%     if isfield(h,'DEKdataMatchedPeaks') && ...
%        size(h.DEKdataMatchedPeaks,1) >= peakIdx
%         alphaVal = h.DEKdataMatchedPeaks(peakIdx, 7);
%         if isfield(h,'uniqueAlpha')
%             [~, alphaGrpIdx] = min(abs(h.uniqueAlpha - alphaVal));
%         else
%             alphaGrpIdx = 1;
%         end
%     else
%         alphaGrpIdx = 1;
%     end
% 
%     % γ-Wert in BinnedGamma suchen → das ist der korrekte Index in dataXcorr
%     bg = h.BinnedGamma{alphaGrpIdx};
%     [~, gammaIdx] = min(abs(bg - gammaTarget));
% else
%     gammaIdx = fitDataRow;
% end
% 
% gammaIdx = max(1, min(gammaIdx, numel(h.dataXcorr{safeIdx})));

% NEU – fitDataRow ist bereits der korrekte Index:
safeIdx  = max(1, min(peakIdx, numel(h.dataXcorr)));
gammaIdx = max(1, min(fitDataRow, numel(h.dataXcorr{safeIdx})));

% ── updateFittedPeakPlot mit korrektem Index aufrufen ────────────────
h = updateFittedPeakPlot(h, peakIdx, gammaIdx);

% ── YLim und XLim auf h.axes setzen ──────────────────────────────────
% Wenn Stress-Fit bereits durchgeführt wurde (epsfitdataexport vorhanden):
% → YLim aus ε-Daten berechnen, nicht aus 2θ-Werten
if isfield(h,'epsfitdataexport') && numel(h.epsfitdataexport) >= peakIdx && ...
   ~isempty(h.epsfitdataexport{peakIdx})
    eps     = h.epsfitdataexport{peakIdx};
    idxFinE = isfinite(eps(:,2)) & isfinite(eps(:,3));
    if any(idxFinE)
        yLowE   = eps(idxFinE,2) - abs(eps(idxFinE,3));
        yHighE  = eps(idxFinE,2) + abs(eps(idxFinE,3));
        yRangeE = max(max(yHighE)-min(yLowE), 1e-6);
        h.axes.YLimMode = 'manual';
        h.axes.YLim     = [min(yLowE)-yRangeE*0.20, max(yHighE)+yRangeE*0.20];
    end
    % XLim aus ε-Daten
    xMinE  = min(eps(idxFinE,1));
    xMaxE  = max(eps(idxFinE,1));
    if isfinite(xMinE) && isfinite(xMaxE)
        marginE = max(5, (xMaxE-xMinE)*0.05);
        h.axes.XLim = [xMinE-marginE, xMaxE+marginE];
    end
else
    % Vor Stress-Fit: YLim aus 2θ-Werten
    idxFin = isfinite(pv(:,yCol));
    if any(idxFin)
        yVals  = pv(idxFin, yCol);
        yRange = max(max(yVals)-min(yVals), 1e-6);
        h.axes.YLimMode = 'manual';
        h.axes.YLim     = [min(yVals)-yRange*0.20, max(yVals)+yRange*0.20];
    end
    xData = pv(isfinite(pv(:,1)), 1);
    if ~isempty(xData)
        xMin   = min(xData);
        xMax   = max(xData);
        margin = max(5, (xMax-xMin)*0.05);
        h.axes.XLim = [xMin-margin, xMax+margin];
    end
end

% ── Highlight im ε(γ)-Plot oder 2θ(γ)-Plot ───────────────────────────
if isfield(h,'epsfitdataexport') && numel(h.epsfitdataexport) >= peakIdx && ...
   ~isempty(h.epsfitdataexport{peakIdx})
    % Nach Stress-Fit: Highlight im ε(γ)-Plot
    eps = h.epsfitdataexport{peakIdx};
    if any(isfinite(eps(:,2)))
        [~, epsIdx] = min(abs(eps(:,1) - gammaTarget));
        if isfinite(eps(epsIdx,2))
            set(h.highlightpeakdata, ...
                'XData',   eps(epsIdx,1), ...
                'YData',   eps(epsIdx,2), ...
                'Visible', 'on');
        else
            set(h.highlightpeakdata, 'Visible', 'off');
        end
    else
        set(h.highlightpeakdata, 'Visible', 'off');
    end
else
    % Vor Stress-Fit: Highlight im 2θ(γ)-Plot
    if size(pv,1) >= fitDataRow && isfinite(pv(fitDataRow, yCol))
        set(h.highlightpeakdata, ...
            'XData',   gammaTarget, ...
            'YData',   pv(fitDataRow, yCol), ...
            'Visible', 'on');
    else
        set(h.highlightpeakdata, 'Visible', 'off');
    end
end

% % ── SliderFittedPeaks Grenzen aktualisieren ───────────────────────────
% % Max = Anzahl gültiger Zeilen in FitDataMod für diesen Peak
% nValid = numel(validRows);
% if get(hObj,'Max') ~= max(nValid,2)
%     set(hObj, ...
%         'Max',        max(nValid, 2), ...
%         'SliderStep', [1/max(nValid-1,1)  1/max(nValid-1,1)]);
% end

% ── SliderFittedPeaks Grenzen aktualisieren ───────────────────────────
nValid = numel(validRows);
if get(hObj,'Max') ~= max(nValid,2)
    set(hObj, ...
        'Max',        max(nValid, 2), ...
        'SliderStep', [1/max(nValid-1,1)  1/max(nValid-1,1)]);
end

guidata(hObj, h);

function SliderCallbackRawImage(hObj, ~)
h = guidata(hObj);

value = round(get(hObj, 'Value'));
value = max(1, min(value, numel(h.imgPaths)));

[~, ~, ext] = fileparts(h.imgPaths{value});
pythonExe   = strtrim(get(h.pythonExeEdit, 'String'));

try
    if strcmpi(ext, '.cbf')
        img = loadCBF(h.imgPaths{value}, pythonExe);
    else
        img = double(imread(h.imgPaths{value}));
    end

    imgLog = log10(1 + max(img, 0));
    v      = imgLog(isfinite(imgLog) & imgLog > 0);
    clims  = prctile(v, [1 99]);

    cla(h.axesRawImage);
    imagesc(h.axesRawImage, imgLog);
    clim(h.axesRawImage, clims);
    colormap(h.axesRawImage, 'hot');
    colorbar(h.axesRawImage);
    axis(h.axesRawImage, 'image');
    h.axesRawImage.YDir = 'reverse'; % normal
    h.axesRawImage.Title.String = sprintf('[%d/%d]  %s  [%d × %d px]', ...
        value, numel(h.imgPaths), h.FileNameLoad{value}, ...
        size(img,1), size(img,2));
catch ME
    warning('Slider:generalError', '[SliderRawImage] %s', ME.message);
end

guidata(hObj, h);

function SliderCallbackCakedImage(hObj, ~)
h = guidata(hObj);

if ~isfield(h, 'cakedImages') || isempty(h.cakedImages)
    guidata(hObj, h); return
end

value = max(1, min(round(get(hObj, 'Value')), numel(h.cakedImages)));
entry = h.cakedImages{value};
if isempty(entry), guidata(hObj, h); return; end

try
    % Beim Slider-Scrollen nicht erneut speichern
    opts = entry.opts;
    opts.saveTif = false;

    plotCaked2DInAxes(h.axesCaked2D, entry.out, opts);
    h.axesCaked2D.Title.String = sprintf(...
        'Caked Image  –  \\alpha = %.1f°  (%d/%d)', ...
        entry.alphaVal, value, numel(h.cakedImages));
catch ME
    warning('[SliderCakedImage] %s', strrep(ME.message, '%', '%%'));
end

guidata(hObj, h);

function celleditcallback(hObj, eventdata)
% Change entries for DEK data manually. User can also reallocate peaks if
% needed. Supports dropdown menu for E-theo column.
 
h = guidata(hObj);
h.SelectPeaktabledata = get(hObj, 'data');
 
if strcmp(get(hObj, 'Tag'), 'tableDECFittedPeaks')
 
    % --- Aktuelle DEK-Daten laden ---
    if strcmp(get(h.radiobuttonwavelength.SelectedObject, 'String'), 'Ga K-alpha')
        datadek = get(h.dekdataGaKalpha, 'data');
    elseif strcmp(get(h.radiobuttonwavelength.SelectedObject, 'String'), 'In K-alpha')
        datadek = get(h.dekdataInKalpha, 'data');
    else
        datadek = get(h.dekdataInKbeta, 'data');
    end
 
    % --- NewData auslesen: kann String (Dropdown) oder numeric sein ---
    newData = eventdata.NewData;
    if ischar(newData) || isstring(newData)
        newVal = str2double(newData);
    elseif isnumeric(newData)
        newVal = newData;
    else
        newVal = NaN;
    end
 
    % --- Ungültige Eingabe: alten Wert wiederherstellen ---
    if isempty(newVal) || ~isfinite(newVal) || newVal == 0
        prevData = eventdata.PreviousData;
        if isnumeric(prevData) && isfinite(prevData) && prevData ~= 0
            h.SelectPeaktabledata(eventdata.Indices(1), eventdata.Indices(2)) = prevData;
            set(hObj, 'data', h.SelectPeaktabledata);
        end
        guidata(hObj, h);
        return
    end
 
    % --- Index der geänderten Zeile ---
    idxdatanew = eventdata.Indices;
 
    % --- Passenden Peak in DEK-Tabelle suchen ---
    % num2str rundet auf 4-5 Stellen → Toleranz entsprechend großzügig
    idxchangedPeak = ismembertol(datadek(:,4), newVal, 0.001);
    if ~any(idxchangedPeak)
        idxchangedPeak = ismembertol(datadek(:,4), newVal, 0.05);
    end
    if ~any(idxchangedPeak)
        % Letzter Versuch: absoluter Abstand < 0.1°
        [minDist, minIdx] = min(abs(datadek(:,4) - newVal));
        if minDist < 0.1
            idxchangedPeak = false(size(datadek,1),1);
            idxchangedPeak(minIdx) = true;
        end
    end
    if ~any(idxchangedPeak)
        warning('celleditcallback: Kein passender Peak für E-theo=%.4f gefunden.', newVal);
        % Alten Wert wiederherstellen
        prevData = eventdata.PreviousData;
        if isnumeric(prevData) && isfinite(prevData)
            h.SelectPeaktabledata(idxdatanew(1), idxdatanew(2)) = prevData;
            set(hObj, 'data', h.SelectPeaktabledata);
        end
        guidata(hObj, h);
        return
    end
 
    % --- DEK-Werte übernehmen (nur ersten Treffer) ---
    idxRow = find(idxchangedPeak, 1, 'first');
    h.SelectPeaktabledata(idxdatanew(1), 3:7) = datadek(idxRow, [1:3, 5:6]);
    set(hObj, 'data', h.SelectPeaktabledata);
 
    % --- DEKdataMatchedPeaks aktualisieren ---
    h.DEKdataMatchedPeaks = [h.SelectPeaktabledata(:,3:5) ...
                              h.SelectPeaktabledata(:,2)   ...
                              h.SelectPeaktabledata(:,6:end)];
 
end
 
guidata(hObj, h);

function choosewavelengthcallback(hObj, eventdata)
% Change entries for DEK data manually. User can also reallocate peaks if
% needed.
h = guidata(hObj);

% disp("Previous: " + eventdata.OldValue.Text);
% disp("Current: " + eventdata.NewValue.Text);
delete(h.plotpeakstheo)

if strcmp(eventdata.NewValue.String,'Ga K-alpha')
    h.plotpeakstheo = xline(h.axesPlotIntensityData,h.PeakPos{1},'--r',h.rowsAsStrings{1}, 'LabelVerticalAlignment', 'middle', 'LabelHorizontalAlignment', 'left');
    % Set table data
    set(h.tableDECFittedPeaks,'ColumnFormat',{'numeric',(cellfun(@num2str,num2cell(h.PeakPos{1}'),'UniformOutput',false))','numeric','numeric','numeric','numeric','numeric','numeric'})
    set(h.AbscoeffEditField, "String", num2str(round(h.abscoeff{1}, 6)))
elseif strcmp(eventdata.NewValue.String,'In K-alpha')
    h.plotpeakstheo = xline(h.axesPlotIntensityData,h.PeakPos{2},'--r',h.rowsAsStrings{2}, 'LabelVerticalAlignment', 'middle', 'LabelHorizontalAlignment', 'left');
    % Set table data
    set(h.tableDECFittedPeaks,'ColumnFormat',{'numeric',(cellfun(@num2str,num2cell(h.PeakPos{2}'),'UniformOutput',false))','numeric','numeric','numeric','numeric','numeric','numeric'})
    set(h.AbscoeffEditField, "String", num2str(round(h.abscoeff{2}, 6)))
elseif strcmp(eventdata.NewValue.String,'In K-beta')
    h.plotpeakstheo = xline(h.axesPlotIntensityData,h.PeakPos{3},'--r',h.rowsAsStrings{3}, 'LabelVerticalAlignment', 'middle', 'LabelHorizontalAlignment', 'left');
    % Set table data
    set(h.tableDECFittedPeaks,'ColumnFormat',{'numeric',(cellfun(@num2str,num2cell(h.PeakPos{3}'),'UniformOutput',false))','numeric','numeric','numeric','numeric','numeric','numeric'})
    set(h.AbscoeffEditField, "String", num2str(round(h.abscoeff{3}, 6)))
end

guidata(hObj, h);

function fitstressdatacallback(hObj, ~)
h = guidata(hObj);

% ── Detektorlücken-Patches ausblenden ────────────────────────────────
delete(findobj(h.axes, 'Tag', 'maskregion'));
delete(findobj(h.axes, 'Tag', 'peakmask'));

% pVoigt-Tracking-Plot ausblenden
if isfield(h, 'plotdata') && isvalid(h.plotdata)
    set(h.plotdata, 'Visible', 'off');
end

% fitCentroid Peaklagen ausblenden
if isfield(h, 'plotdataCentFit') && isvalid(h.plotdataCentFit)
    set(h.plotdataCentFit, 'Visible', 'off');
end

% Highlight-Punkt ausblenden
if isfield(h, 'highlightpeakdata') && isvalid(h.highlightpeakdata)
    set(h.highlightpeakdata, 'Visible', 'off');
end

col = get(hObj,'backg');
set(hObj,'String','Fitting stress data ...','backg',[1 .6 .6])
pause(.01)

my         = str2double(get(h.AbscoeffEditField, "String"));
spannkomp  = str2double(get(h.SpannKompEditField, "String"));

% Peaklage-Quelle aus Radiobutton lesen
useFitPV    = true; %isfield(h, 'rb_fitpv')    && get(h.rb_fitpv,    'Value') == 1 ...
              %&& isfield(h, 'dataPVParams');
useCentroid = false; %isfield(h, 'rb_centroid') && get(h.rb_centroid, 'Value') == 1 ...
              %&& isfield(h, 'datacentFitParams');

FitDataMod = h.FitDataMod;

% Spalten 9+10: x0 und Fehler aus fitPseudoVoigt
for k = 1:numel(FitDataMod)
    mat = FitDataMod{k};
    if size(mat,2) >= 10
        idxValid = isfinite(mat(:,9));
        mat(idxValid, 2) = mat(idxValid, 9);
        mat(idxValid, 3) = mat(idxValid, 10);
    end
    FitDataMod{k} = mat;
end

DEK        = h.DEKdataMatchedPeaks;

% --- Stress für alle Peaks berechnen ---
for k = 1:size(FitDataMod, 1)
    % Zeilen mit NaN in Spalte 2 entfernen
    idxFinite     = isfinite(FitDataMod{k}(:,2));
    dataForCalc   = FitDataMod{k}(idxFinite, :);
    r = calcStress(dataForCalc, DEK(k,:), my, spannkomp);

    h.epsfitdataexport{k}   = r.epsfitdata;
    h.epsgammaergfunc{k}    = r.epsgammaergfunc;
    h.epsgammaergfunc_x{k}  = r.epsgammaergfunc_x;
    h.epssin2psifitdaten{k} = r.epssin2psifitdaten;
    h.sin2psifit{k}         = r.sin2psifit;
    h.sin2psiregres{k}      = r.sin2psiregres;
    h.tau{k}                = r.tau;
    h.psi{k}                = r.psi;
    h.phi{k}                = r.phi;

    sigma{k}           = r.sigma;
    sigmaerr{k}        = r.sigmaerr;
    sigmapardebye{k}   = r.sigmapardebye;
    deltasigmapardebye{k} = r.deltasigmapardebye;
    alphaexport{k}     = FitDataMod{k}(1,7);
end

% --- Ergebnisse in h speichern ---
% h.taumean               = cellfun(@mean, h.tau)';
h.taumean               = cellfun(@(t) mean(t(isfinite(t) & t > 0)), h.tau)';
h.sigmaFinal            = cell2mat(sigma)';
h.sigmaerrFinal         = cell2mat(sigmaerr)';
h.sigmasin2psiFinal     = cell2mat(sigmapardebye)';
h.deltasigmasin2psiFinal = cell2mat(deltasigmapardebye)';
h.alphaexport           = cell2mat(alphaexport)';

% Sicherstellen dass plotdata die ε(γ)-Werte zeigt, nicht die Peaklagen
% ── ε(γ)-Datenpunkte UND Fehlerbalken anzeigen ───────────────────────
if isfield(h, 'epsfitdataexport') && ~isempty(h.epsfitdataexport)
    eps1    = h.epsfitdataexport{1};
    idxFin1 = isfinite(eps1(:,2)) & isfinite(eps1(:,3));
    if any(idxFin1)
        set(h.plotdata, ...
            'XData',          eps1(idxFin1, 1), ...
            'YData',          eps1(idxFin1, 2), ...
            'YNegativeDelta', abs(eps1(idxFin1, 3)), ...
            'YPositiveDelta', abs(eps1(idxFin1, 3)), ...
            'MarkerSize',       4, ...
            'MarkerFaceColor',  [0.094 0.373 0.647], ...
            'MarkerEdgeColor',  [0.094 0.373 0.647], ...
            'Color',            [0.094 0.373 0.647], ...
            'Visible', 'on');
    end
end

% ── Fit-Kurve ─────────────────────────────────────────────────────────
if isfield(h,'epsgammaergfunc_x') && ~isempty(h.epsgammaergfunc_x{1}) && ...
   numel(h.epsgammaergfunc_x{1}) == numel(h.epsgammaergfunc{1})
    set(h.fitcurvestress, ...
        'XData',   h.epsgammaergfunc_x{1}(:), ...
        'YData',   h.epsgammaergfunc{1}(:), ...
        'Color',   [0.85 0.33 0.10], ...
        'Visible', 'on');
end

% --- Plot aktualisieren ---
h = updateStressPlots(h, 1);

% ── YLim und XLim auf ε(γ)-Skala setzen ─────────────────────────────
eps1     = h.epsfitdataexport{1};
idxFin1  = isfinite(eps1(:,2)) & isfinite(eps1(:,3));
if any(idxFin1)
    yLow1   = eps1(idxFin1,2) - abs(eps1(idxFin1,3));
    yHigh1  = eps1(idxFin1,2) + abs(eps1(idxFin1,3));
    yRange1 = max(max(yHigh1)-min(yLow1), 1e-6);
    h.axes.YLimMode = 'manual';
    h.axes.YLim     = [min(yLow1)-yRange1*0.20, max(yHigh1)+yRange1*0.20];
end

xMin1 = min(eps1(idxFin1,1));
xMax1 = max(eps1(idxFin1,1));
if isfinite(xMin1) && isfinite(xMax1)
    margin1 = max(5, (xMax1-xMin1)*0.05);
    h.axes.XLim = [xMin1-margin1, xMax1+margin1];
end

% fitcurvestress explizit setzen
if isfield(h,'epsgammaergfunc_x') && ~isempty(h.epsgammaergfunc_x{1})
    set(h.fitcurvestress, ...
        'XData',   h.epsgammaergfunc_x{1}(:), ...
        'YData',   h.epsgammaergfunc{1}(:), ...
        'Visible', 'on');
end

% YLim ist jetzt korrekt auf ε-Skala gesetzt — dann erst Gaps zeichnen:
h = markInvalidGammaRegions(h, 1);   % Peak 1 wird nach Stressfit angezeigt

h.axes.YLabel.String = [char(949),'(',char(947),')'];
drawnow;

assignin('base','hfitstress',h)

set(hObj,'String','Fit Stress Data','backg',col)
guidata(hObj, h);

% function fitstressdatacallback(hObj, ~)
% h = guidata(hObj);
% 
% % pVoigt-Tracking-Plot ausblenden
% if isfield(h, 'plotdata') && isvalid(h.plotdata)
%     set(h.plotdata, 'Visible', 'off');
% end
% if isfield(h, 'plotdataCentFit') && isvalid(h.plotdataCentFit)
%     set(h.plotdataCentFit, 'Visible', 'off');
% end
% if isfield(h, 'highlightpeakdata') && isvalid(h.highlightpeakdata)
%     set(h.highlightpeakdata, 'Visible', 'off');
% end
% 
% col = get(hObj,'backg');
% set(hObj,'String','Fitting stress data ...','backg',[1 .6 .6])
% pause(.01)
% 
% my        = str2double(get(h.AbscoeffEditField, "String"));
% spannkomp = str2double(get(h.SpannKompEditField, "String"));
% 
% FitDataMod = h.FitDataMod;
% 
% % Spalten 9+10: x0 und Fehler aus fitPseudoVoigt übernehmen
% for k = 1:numel(FitDataMod)
%     mat = FitDataMod{k};
%     if size(mat,2) >= 10
%         idxValid = isfinite(mat(:,9));
%         mat(idxValid, 2) = mat(idxValid, 9);
%         mat(idxValid, 3) = mat(idxValid, 10);
%     end
%     FitDataMod{k} = mat;
% end
% 
% DEK = h.DEKdataMatchedPeaks;
% 
% % ── Ausreißerfilter-Dialog ────────────────────────────────────────────
% filterOpts.sigmaThresh  = 3.0;
% filterOpts.windowSize   = 7;
% filterOpts.useErrWeight = true;
% 
% set(hObj,'String','Fit Stress Data','backg',col)
% 
% [acceptFilter, sigmaThresh, windowSize] = ...
%     showOutlierFilterDialog(h, FitDataMod, DEK, filterOpts);
% 
% filterOpts.sigmaThresh = sigmaThresh;
% filterOpts.windowSize  = windowSize;
% 
% set(hObj,'String','Fitting stress data ...','backg',[1 .6 .6])
% pause(.01)
% 
% % Ausreißerfilter auf FitDataMod anwenden falls akzeptiert
% if acceptFilter
%     for k = 1:size(FitDataMod, 1)
%         mat      = FitDataMod{k};
%         gamma_k  = mat(:, 1);
%         tth_k    = mat(:, 2);
%         tthErr_k = mat(:, 3);
% 
%         [~, outlMask] = filterOutliersByLocalTrend(...
%             gamma_k, tth_k, tthErr_k, filterOpts);
% 
%         mat(outlMask, 2:3)   = NaN;
%         mat(outlMask, 9:10)  = NaN;
%         if size(mat,2) >= 12
%             mat(outlMask, 11:12) = NaN;
%         end
%         FitDataMod{k}   = mat;
%         h.FitDataMod{k} = mat;
% 
%         fprintf('Peak %d: %d Ausreißer entfernt.\n', k, sum(outlMask));
%     end
% end
% 
% % ── Stress für alle Peaks berechnen ───────────────────────────────────
% for k = 1:size(FitDataMod, 1)
%     idxFinite   = isfinite(FitDataMod{k}(:,2));
%     dataForCalc = FitDataMod{k}(idxFinite, :);
%     r = calcStress(dataForCalc, DEK(k,:), my, spannkomp);
% 
%     h.epsfitdataexport{k}    = r.epsfitdata;
%     h.epsgammaergfunc{k}     = r.epsgammaergfunc;
%     h.epsgammaergfunc_x{k}   = r.epsgammaergfunc_x;
%     h.epssin2psifitdaten{k}  = r.epssin2psifitdaten;
%     h.sin2psifit{k}          = r.sin2psifit;
%     h.sin2psiregres{k}       = r.sin2psiregres;
%     h.tau{k}                 = r.tau;
%     h.psi{k}                 = r.psi;
%     h.phi{k}                 = r.phi;
% 
%     sigma{k}              = r.sigma;
%     sigmaerr{k}           = r.sigmaerr;
%     sigmapardebye{k}      = r.sigmapardebye;
%     deltasigmapardebye{k} = r.deltasigmapardebye;
%     alphaexport{k}        = FitDataMod{k}(1,7);
% end
% 
% % ── Ergebnisse speichern ──────────────────────────────────────────────
% h.taumean                = cellfun(@mean, h.tau)';
% h.sigmaFinal             = cell2mat(sigma)';
% h.sigmaerrFinal          = cell2mat(sigmaerr)';
% h.sigmasin2psiFinal      = cell2mat(sigmapardebye)';
% h.deltasigmasin2psiFinal = cell2mat(deltasigmapardebye)';
% h.alphaexport            = cell2mat(alphaexport)';
% 
% if isfield(h, 'epsfitdataexport') && ~isempty(h.epsfitdataexport)
%     set(h.plotdata, ...
%         'XData',          h.epsfitdataexport{1}(:,1), ...
%         'YData',          h.epsfitdataexport{1}(:,2), ...
%         'YNegativeDelta', h.epsfitdataexport{1}(:,3), ...
%         'YPositiveDelta', h.epsfitdataexport{1}(:,3), ...
%         'Visible', 'on');
% end
% 
% h = updateStressPlots(h, 1);
% 
% eps1    = h.epsfitdataexport{1};
% idxFin1 = isfinite(eps1(:,2)) & isfinite(eps1(:,3));
% if any(idxFin1)
%     yLow1   = eps1(idxFin1,2) - abs(eps1(idxFin1,3));
%     yHigh1  = eps1(idxFin1,2) + abs(eps1(idxFin1,3));
%     yRange1 = max(max(yHigh1)-min(yLow1), 1e-6);
%     h.axes.YLimMode = 'manual';
%     h.axes.YLim     = [min(yLow1)-yRange1*0.20, max(yHigh1)+yRange1*0.20];
% end
% 
% xMin1 = min(eps1(idxFin1,1));
% xMax1 = max(eps1(idxFin1,1));
% if isfinite(xMin1) && isfinite(xMax1)
%     margin1 = max(5, (xMax1-xMin1)*0.05);
%     h.axes.XLim = [xMin1-margin1, xMax1+margin1];
% end
% 
% if isfield(h,'epsgammaergfunc_x') && ~isempty(h.epsgammaergfunc_x{1})
%     set(h.fitcurvestress, ...
%         'XData',   h.epsgammaergfunc_x{1}(:), ...
%         'YData',   h.epsgammaergfunc{1}(:), ...
%         'Visible', 'on');
% end
% 
% h.axes.YLabel.String = [char(949),'(',char(947),')'];
% drawnow;
% 
% set(hObj,'String','Fit Stress Data','backg',col)
% guidata(hObj, h);

% function modstressdatacallback(hObj, ~)
% h = guidata(hObj);
% 
% valueSlider            = round(get(h.Slider,            'Value'));
% valueSliderFittedPeaks = round(get(h.SliderFittedPeaks, 'Value'));
% 
% % ── Prüfen ob Stressfit vorhanden ────────────────────────────────────
% if ~isfield(h, 'epsfitdataexport') || ...
%    numel(h.epsfitdataexport) < valueSlider || ...
%    isempty(h.epsfitdataexport{valueSlider})
%     errordlg(['Bitte zuerst "Fit Stress Data" ausführen, ' ...
%               'bevor Punkte manuell gelöscht werden.'], ...
%               'Kein Stressfit vorhanden');
%     return
% end
% 
% % ── Prüfen ob ε-Daten finite Werte enthalten ─────────────────────────
% eps_check = h.epsfitdataexport{valueSlider};
% if ~any(isfinite(eps_check(:,2)))
%     errordlg(['Keine gültigen ε(γ)-Daten für Peak ' num2str(valueSlider) ...
%               '. Bitte "Fit Stress Data" erneut ausführen.'], ...
%               'Keine gültigen Daten');
%     return
% end
% 
% % =====================================================================
% % Undo-State sichern
% % =====================================================================
% h.undoState.FitDataMod         = h.FitDataMod;
% h.undoState.FitDataModCentroid = h.FitDataModCentroid;
% h.undoState.fitresultexport    = h.fitresultexport;
% h.undoState.dataXcorr          = h.dataXcorr;
% h.undoState.dataYcorr          = h.dataYcorr;
% h.undoState.fitMethodUsed      = h.fitMethodUsed;
% h.undoState.dataCentroidMu     = h.dataCentroidMu;
% h.undoState.dataGaussFit       = h.dataGaussFit;
% h.undoState.dataPVFitY         = h.dataPVFitY;
% h.undoState.dataPVSuccess      = h.dataPVSuccess;
% if isfield(h, 'dataPVFitMat')
%     h.undoState.dataPVFitMat   = h.dataPVFitMat;
% end
% if isfield(h, 'datacentFitMat')
%     h.undoState.datacentFitMat = h.datacentFitMat;
% end
% if isfield(h, 'epsfitdataexport')
%     h.undoState.epsfitdataexport       = h.epsfitdataexport;
%     h.undoState.epsgammaergfunc        = h.epsgammaergfunc;
%     h.undoState.epsgammaergfunc_x      = h.epsgammaergfunc_x;
%     h.undoState.epssin2psifitdaten     = h.epssin2psifitdaten;
%     h.undoState.sin2psifit             = h.sin2psifit;
%     h.undoState.sin2psiregres          = h.sin2psiregres;
%     h.undoState.tau                    = h.tau;
%     h.undoState.taumean                = h.taumean;
%     h.undoState.sigmaFinal             = h.sigmaFinal;
%     h.undoState.sigmaerrFinal          = h.sigmaerrFinal;
%     h.undoState.sigmasin2psiFinal      = h.sigmasin2psiFinal;
%     h.undoState.deltasigmasin2psiFinal = h.deltasigmasin2psiFinal;
% end
% if isfield(h, 'validBinIdxs')
%     h.undoState.validBinIdxs = h.validBinIdxs;
% end
% h.undoState.valueSlider = valueSlider;
% 
% if isfield(h, 'UndoStressButton') && isvalid(h.UndoStressButton)
%     set(h.UndoStressButton, 'Enable', 'on');
% end
% 
% % =====================================================================
% % ε(γ)-Daten für Lasso vorbereiten
% % =====================================================================
% eps       = h.epsfitdataexport{valueSlider};
% idxFinEps = isfinite(eps(:,2)) & isfinite(eps(:,3));
% 
% % YLim VOR Lasso aus ε-Daten berechnen
% if any(idxFinEps)
%     yLowE   = eps(idxFinEps,2) - abs(eps(idxFinEps,3));
%     yHighE  = eps(idxFinEps,2) + abs(eps(idxFinEps,3));
%     yRangeE = max(max(yHighE) - min(yLowE), 1e-6);
%     ylimBeforeEdit = [min(yLowE) - yRangeE*0.20, ...
%                       max(yHighE) + yRangeE*0.20];
% else
%     ylimBeforeEdit = h.axes.YLim;
% end
% 
% % plotdata mit ε(γ)-Werten befüllen (nur finite Punkte für Lasso)
% if any(idxFinEps)
%     set(h.plotdata, ...
%         'XData',          eps(idxFinEps,1), ...
%         'YData',          eps(idxFinEps,2), ...
%         'YNegativeDelta', abs(eps(idxFinEps,3)), ...
%         'YPositiveDelta', abs(eps(idxFinEps,3)), ...
%         'Visible', 'on');
% else
%     set(h.plotdata, 'XData', NaN, 'YData', NaN, ...
%         'YNegativeDelta', NaN, 'YPositiveDelta', NaN, 'Visible', 'off');
% end
% 
% % Fit-Kurve ausblenden während Lasso
% for fn = {'fitcurvestress','plotdataCentFit','highlightpeakdata'}
%     if isfield(h, fn{1}) && isvalid(h.(fn{1}))
%         set(h.(fn{1}), 'Visible', 'off');
%     end
% end
% 
% % Achsen auf ε-Datenbereich setzen
% if any(idxFinEps)
%     xMinE  = min(eps(idxFinEps,1));
%     xMaxE  = max(eps(idxFinEps,1));
%     marginE = max(5, (xMaxE-xMinE)*0.05);
%     h.axes.XLim = [xMinE-marginE, xMaxE+marginE];
% end
% h.axes.YLimMode      = 'manual';
% h.axes.YLim          = ylimBeforeEdit;
% h.axes.YLabel.String = [char(949),'(',char(947),')'];
% drawnow;
% 
% % =====================================================================
% % Punkte per Lasso auswählen
% % pointslist = Indizes in plotdata.XData = Indizes in eps(idxFinEps,:)
% % =====================================================================
% pointslist = selectStressPoints(h.axes, h.plotdata);
% 
% if isempty(pointslist)
%     guidata(hObj, h);
%     return
% end
% 
% % =====================================================================
% % ε-Indizes auf FitDataMod-Zeilen mappen (über γ-Werte)
% % eps(idxFinEps,:) = kompaktes Array ohne NaN
% % FitDataMod       = vollständiges Array mit NaN-Zeilen
% % Mapping über γ-Spalte 1 (identisch in beiden)
% % =====================================================================
% pv       = h.FitDataMod{valueSlider};
% gammaEps = eps(idxFinEps, 1);   % γ der finiten ε-Punkte (kompakt)
% gammaPV  = pv(:, 1);             % γ aller FitDataMod-Zeilen (inkl. NaN)
% 
% mappedList = zeros(numel(pointslist), 1);
% for pi = 1:numel(pointslist)
%     gammaTarget        = gammaEps(pointslist(pi));
%     [~, mappedList(pi)] = min(abs(gammaPV - gammaTarget));
% end
% mappedList = unique(mappedList);
% 
% % =====================================================================
% % Datenpunkte NaN setzen (Zeilen bleiben erhalten)
% % =====================================================================
% h.FitDataMod{valueSlider}(mappedList, 2:3)   = NaN;
% h.FitDataMod{valueSlider}(mappedList, 9:10)  = NaN;
% h.FitDataMod{valueSlider}(mappedList, 11:12) = NaN;
% 
% if isfield(h,'dataPVFitMat') && numel(h.dataPVFitMat) >= valueSlider && ...
%    size(h.dataPVFitMat{valueSlider},1) >= max(mappedList)
%     h.dataPVFitMat{valueSlider}(mappedList, 2:3) = NaN;
% end
% if isfield(h,'datacentFitMat') && numel(h.datacentFitMat) >= valueSlider && ...
%    size(h.datacentFitMat{valueSlider},1) >= max(mappedList)
%     h.datacentFitMat{valueSlider}(mappedList, 2:3)   = NaN;
%     h.datacentFitMat{valueSlider}(mappedList, 11:12) = NaN;
% end
% if isfield(h,'FitDataModCentroid') && numel(h.FitDataModCentroid) >= valueSlider && ...
%    size(h.FitDataModCentroid{valueSlider},1) >= max(mappedList)
%     h.FitDataModCentroid{valueSlider}(mappedList, 2:3) = NaN;
% end
% 
% if numel(h.dataXcorr{valueSlider}) >= max(mappedList)
%     h.dataXcorr{valueSlider}(mappedList) = {[]};
% end
% if numel(h.dataYcorr{valueSlider}) >= max(mappedList)
%     h.dataYcorr{valueSlider}(mappedList) = {[]};
% end
% if numel(h.fitresultexport{valueSlider}) >= max(mappedList)
%     h.fitresultexport{valueSlider}(mappedList) = {[]};
% end
% if isfield(h,'dataPVFitY') && numel(h.dataPVFitY{valueSlider}) >= max(mappedList)
%     h.dataPVFitY{valueSlider}(mappedList) = {[]};
% end
% if isfield(h,'datacentFitParams') && numel(h.datacentFitParams{valueSlider}) >= max(mappedList)
%     h.datacentFitParams{valueSlider}(mappedList) = {[]};
% end
% 
% % =====================================================================
% % Stress neu berechnen
% % =====================================================================
% my        = str2double(get(h.AbscoeffEditField, 'String'));
% spannkomp = str2double(get(h.SpannKompEditField, 'String'));
% DEK       = h.DEKdataMatchedPeaks;
% 
% % dataForStress = h.FitDataMod{valueSlider};
% % if size(dataForStress,2) >= 10
% %     idxValid = isfinite(dataForStress(:,9));
% %     dataForStress(idxValid, 2) = dataForStress(idxValid, 9);
% %     dataForStress(idxValid, 3) = dataForStress(idxValid, 10);
% % end
% % dataForStress = dataForStress(isfinite(dataForStress(:,2)), :);
% 
% % dataForStress = h.FitDataMod{valueSlider};
% % if size(dataForStress,2) >= 10
% %     % Spalte 9 hat Priorität wenn finite — sonst Spalte 2 verwenden
% %     idxValid   = isfinite(dataForStress(:,9));
% %     idxInvalid = ~isfinite(dataForStress(:,9));
% % 
% %     % Valide: Spalte 9 → 2
% %     dataForStress(idxValid, 2) = dataForStress(idxValid, 9);
% %     dataForStress(idxValid, 3) = dataForStress(idxValid, 10);
% % 
% %     % Ungültig (NaN in Spalte 9): auch Spalte 2 auf NaN setzen
% %     dataForStress(idxInvalid, 2) = NaN;
% %     dataForStress(idxInvalid, 3) = NaN;
% % end
% % dataForStress = dataForStress(isfinite(dataForStress(:,2)), :);
% 
% dataForStress = h.FitDataMod{valueSlider};
% if size(dataForStress,2) >= 10
%     idxValid9 = isfinite(dataForStress(:,9)) & (dataForStress(:,9) ~= 0);
%     idxValid2 = isfinite(dataForStress(:,2)) & (dataForStress(:,2) ~= 0);
% 
%     % Spalte 9 in Spalte 2 kopieren wo Spalte 9 valide
%     dataForStress(idxValid9, 2) = dataForStress(idxValid9, 9);
%     dataForStress(idxValid9, 3) = dataForStress(idxValid9, 10);
% 
%     % Sofort prüfen ob Kopierung funktioniert hat:
%     fprintf('  Nach Kopierung: Sp.2 range: %.4f .. %.4f\n', ...
%         min(dataForStress(:,2)), max(dataForStress(:,2)));
%     fprintf('  Sp.9 sample: %.4f  Sp.2 sample: %.4f\n', ...
%         dataForStress(find(idxValid9,1), 9), ...
%         dataForStress(find(idxValid9,1), 2));
% 
%     % Zeilen auf NaN setzen wo WEDER Spalte 9 noch Spalte 2 valide
%     idxNeitherValid = ~idxValid9 & ~idxValid2;
%     dataForStress(idxNeitherValid, 2) = NaN;
%     dataForStress(idxNeitherValid, 3) = NaN;
% 
%     fprintf('  Sp.9 valide: %d  Sp.2 valide: %d  beide ungültig: %d\n', ...
%         sum(idxValid9), sum(idxValid2), sum(idxNeitherValid));
% 
%     fprintf('  Sp.9 Werte (erste 5): ');
%     fprintf('%.6f  ', dataForStress(1:min(5,end), 9));
%     fprintf('\n');
% end
% dataForStress = dataForStress(isfinite(dataForStress(:,2)) & ...
%                               (dataForStress(:,2) ~= 0), :);
% fprintf('  dataForStress nach Filter: %d Zeilen\n', size(dataForStress,1));
% 
% % Debug
% fprintf('dataForStress: %d Zeilen, %d finite in Spalte 2\n', ...
%     size(dataForStress,1), sum(isfinite(dataForStress(:,2))));
% fprintf('DEK Zeile %d: %s\n', valueSlider, mat2str(DEK(valueSlider,:)));
% 
% fprintf('dataForStress Spalten: %d\n', size(dataForStress,2));
% fprintf('  Spalte 1 (gamma): %.2f .. %.2f\n', min(dataForStress(:,1)), max(dataForStress(:,1)));
% fprintf('  Spalte 2 (2theta): %.4f .. %.4f\n', min(dataForStress(:,2)), max(dataForStress(:,2)));
% fprintf('  Spalte 9 original: ');
% pv_dbg = h.FitDataMod{valueSlider};
% fprintf('%d finite in Sp.9, %d finite in Sp.2\n', ...
%     sum(isfinite(pv_dbg(:,9))), sum(isfinite(pv_dbg(:,2))));
% 
% r = calcStress(dataForStress, DEK(valueSlider,:), my, spannkomp);
% 
% % ── Prüfung ob gültige Ergebnisse ────────────────────────────────────
% if isempty(r.epsfitdata) || ~any(isfinite(r.epsfitdata(:,2)))
%     fprintf('Warning: calcStress lieferte keine finiten ε-Werte für Peak %d\n', ...
%         valueSlider);
% 
%     % Alten ε-Daten behalten — nur gelöschte Punkte auf NaN
%     epsOld       = h.epsfitdataexport{valueSlider};
%     gammaDeleted = h.FitDataMod{valueSlider}(mappedList, 1);
%     for di = 1:numel(gammaDeleted)
%         [~, epsRow] = min(abs(epsOld(:,1) - gammaDeleted(di)));
%         epsOld(epsRow, 2:3) = NaN;
%     end
%     h.epsfitdataexport{valueSlider} = epsOld;
% 
%     idxFinOld = isfinite(epsOld(:,2)) & isfinite(epsOld(:,3));
%     if any(idxFinOld)
%         set(h.plotdata, ...
%             'XData',          epsOld(idxFinOld,1), ...
%             'YData',          epsOld(idxFinOld,2), ...
%             'YNegativeDelta', abs(epsOld(idxFinOld,3)), ...
%             'YPositiveDelta', abs(epsOld(idxFinOld,3)), ...
%             'Visible', 'on');
% 
%         yLowO   = epsOld(idxFinOld,2) - abs(epsOld(idxFinOld,3));
%         yHighO  = epsOld(idxFinOld,2) + abs(epsOld(idxFinOld,3));
%         yRangeO = max(max(yHighO)-min(yLowO), 1e-6);
%         h.axes.YLimMode      = 'manual';
%         h.axes.YLim          = [min(yLowO)-yRangeO*0.20, max(yHighO)+yRangeO*0.20];
%         h.axes.YLabel.String = [char(949),'(',char(947),')'];
%     end
% 
%     set(h.fitcurvestress, 'Visible', 'off');
%     h = markInvalidGammaRegions(h, valueSlider);
%     drawnow;
%     guidata(hObj, h);
%     return
% end
% 
% h.epsfitdataexport{valueSlider}       = r.epsfitdata;
% h.epsgammaergfunc{valueSlider}        = r.epsgammaergfunc;
% h.epsgammaergfunc_x{valueSlider}      = r.epsgammaergfunc_x;
% h.epssin2psifitdaten{valueSlider}     = r.epssin2psifitdaten;
% h.sin2psifit{valueSlider}             = r.sin2psifit;
% h.sin2psiregres{valueSlider}          = r.sin2psiregres;
% h.tau{valueSlider}                    = r.tau;
% h.taumean(valueSlider)                = mean(r.tau);
% h.sigmaFinal(valueSlider,:)           = r.sigma';
% h.sigmaerrFinal(valueSlider,:)        = r.sigmaerr';
% h.sigmasin2psiFinal(valueSlider)      = r.sigmapardebye;
% h.deltasigmasin2psiFinal(valueSlider) = r.deltasigmapardebye;
% 
% % =====================================================================
% % Plots aktualisieren
% % =====================================================================
% h = updateStressPlots(h, valueSlider);
% 
% % ── ε(γ)-Plot mit neuen Daten ─────────────────────────────────────────
% epsNew    = h.epsfitdataexport{valueSlider};
% ergNew    = h.epsgammaergfunc{valueSlider}(:);
% idxFinNew = isfinite(epsNew(:,2)) & isfinite(epsNew(:,3));
% 
% if any(idxFinNew)
%     set(h.plotdata, ...
%         'XData',          epsNew(idxFinNew,1), ...
%         'YData',          epsNew(idxFinNew,2), ...
%         'YNegativeDelta', abs(epsNew(idxFinNew,3)), ...
%         'YPositiveDelta', abs(epsNew(idxFinNew,3)), ...
%         'Visible', 'on');
%     if numel(ergNew) == size(epsNew,1)
%         set(h.fitcurvestress, ...
%             'XData',   epsNew(:,1), ...
%             'YData',   ergNew, ...
%             'Visible', 'on');
%     else
%         set(h.fitcurvestress, 'Visible', 'off');
%     end
% else
%     set(h.plotdata,       'XData', NaN, 'YData', NaN, ...
%         'YNegativeDelta', NaN, 'YPositiveDelta', NaN, 'Visible', 'off');
%     set(h.fitcurvestress, 'Visible', 'off');
% end
% 
% % ── YLim aus neuen ε-Daten ────────────────────────────────────────────
% if any(idxFinNew)
%     yLowN   = epsNew(idxFinNew,2) - abs(epsNew(idxFinNew,3));
%     yHighN  = epsNew(idxFinNew,2) + abs(epsNew(idxFinNew,3));
%     yRangeN = max(max(yHighN) - min(yLowN), 1e-6);
%     ylimTarget = [min(yLowN) - yRangeN*0.20, max(yHighN) + yRangeN*0.20];
% else
%     ylimTarget = ylimBeforeEdit;
% end
% 
% % highlightpeakdata und fitCentroid ausgeblendet lassen
% for fn = {'plotdataCentFit','highlightpeakdata'}
%     if isfield(h, fn{1}) && isvalid(h.(fn{1}))
%         set(h.(fn{1}), 'Visible', 'off');
%     end
% end
% 
% % =====================================================================
% % Slider anpassen
% % =====================================================================
% dc        = h.dataXcorr{valueSlider};
% validIdxs = find(~cellfun(@isempty, dc));
% nValid    = numel(validIdxs);
% h.validBinIdxs{valueSlider} = validIdxs;
% 
% if nValid < 1
%     set(h.SliderFittedPeaks, 'Min', 1, 'Max', 2, 'Value', 1, 'SliderStep', [1 1]);
%     h.axes.YLimMode = 'manual';
%     h.axes.YLim     = ylimTarget;
%     drawnow;
%     guidata(hObj, h);
%     return
% end
% 
% set(h.SliderFittedPeaks, ...
%     'Min',        1, ...
%     'Max',        max(nValid, 2), ...
%     'Value',      1, ...
%     'SliderStep', [1/max(nValid-1,1)  1/max(nValid-1,1)]);
% 
% % =====================================================================
% % Peak-Fit-Plot aktualisieren
% % =====================================================================
% firstAbsBin = validIdxs(1);
% h = updateFittedPeakPlot(h, valueSlider, firstAbsBin);
% 
% % highlightstressplot aktualisieren
% if isfield(h,'highlightstressplot') && isvalid(h.highlightstressplot) && ...
%    valueSlider <= numel(h.taumean)
%     set(h.highlightstressplot, ...
%         'XData',   h.taumean(valueSlider), ...
%         'YData',   h.sigmaFinal(valueSlider,1), ...
%         'Visible', 'on');
% end
% 
% % =====================================================================
% % YLim NACH updateFittedPeakPlot setzen
% % =====================================================================
% % h.axes.YLimMode = 'manual';
% % h.axes.YLim     = ylimTarget;
% % drawnow;
% % 
% % guidata(hObj, h);
% % ── Detektormasken-Bereiche neu markieren ────────────────────────────
% h = markInvalidGammaRegions(h, valueSlider);
% 
% % ── YLim nochmals explizit setzen (markInvalidGammaRegions ändert YLim nicht) ──
% h.axes.YLimMode = 'manual';
% h.axes.YLim     = ylimTarget;
% 
% % ── Y-Achsenbeschriftung ─────────────────────────────────────────────
% h.axes.YLabel.String = [char(949),'(',char(947),')'];
% 
% drawnow;
% guidata(hObj, h);

% function modstressdatacallback(hObj, ~)
% h = guidata(hObj);
% 
% valueSlider            = round(get(h.Slider,            'Value'));
% valueSliderFittedPeaks = round(get(h.SliderFittedPeaks, 'Value'));
% 
% % ── Prüfen ob Stressfit vorhanden ────────────────────────────────────
% if ~isfield(h, 'epsfitdataexport') || ...
%    numel(h.epsfitdataexport) < valueSlider || ...
%    isempty(h.epsfitdataexport{valueSlider}) || ...
%    ~any(isfinite(h.epsfitdataexport{valueSlider}(:,2)))
%     errordlg(['Bitte zuerst "Fit Stress Data" ausführen, ' ...
%               'bevor Punkte manuell gelöscht werden.'], ...
%               'Kein Stressfit vorhanden');
%     return
% end
% 
% % =====================================================================
% % Undo-State sichern
% % =====================================================================
% h.undoState.FitDataMod         = h.FitDataMod;
% h.undoState.FitDataModCentroid = h.FitDataModCentroid;
% h.undoState.fitresultexport    = h.fitresultexport;
% h.undoState.dataXcorr          = h.dataXcorr;
% h.undoState.dataYcorr          = h.dataYcorr;
% h.undoState.fitMethodUsed      = h.fitMethodUsed;
% h.undoState.dataCentroidMu     = h.dataCentroidMu;
% h.undoState.dataGaussFit       = h.dataGaussFit;
% h.undoState.dataPVFitY         = h.dataPVFitY;
% h.undoState.dataPVSuccess      = h.dataPVSuccess;
% if isfield(h, 'dataPVFitMat')
%     h.undoState.dataPVFitMat   = h.dataPVFitMat;
% end
% if isfield(h, 'datacentFitMat')
%     h.undoState.datacentFitMat = h.datacentFitMat;
% end
% if isfield(h, 'epsfitdataexport')
%     h.undoState.epsfitdataexport       = h.epsfitdataexport;
%     h.undoState.epsgammaergfunc        = h.epsgammaergfunc;
%     h.undoState.epsgammaergfunc_x      = h.epsgammaergfunc_x;
%     h.undoState.epssin2psifitdaten     = h.epssin2psifitdaten;
%     h.undoState.sin2psifit             = h.sin2psifit;
%     h.undoState.sin2psiregres          = h.sin2psiregres;
%     h.undoState.tau                    = h.tau;
%     h.undoState.taumean                = h.taumean;
%     h.undoState.sigmaFinal             = h.sigmaFinal;
%     h.undoState.sigmaerrFinal          = h.sigmaerrFinal;
%     h.undoState.sigmasin2psiFinal      = h.sigmasin2psiFinal;
%     h.undoState.deltasigmasin2psiFinal = h.deltasigmasin2psiFinal;
% end
% if isfield(h, 'validBinIdxs')
%     h.undoState.validBinIdxs = h.validBinIdxs;
% end
% h.undoState.valueSlider = valueSlider;
% 
% if isfield(h, 'UndoStressButton') && isvalid(h.UndoStressButton)
%     set(h.UndoStressButton, 'Enable', 'on');
% end
% 
% % =====================================================================
% % ε(γ)-Daten für Lasso vorbereiten
% % =====================================================================
% eps       = h.epsfitdataexport{valueSlider};
% idxFinEps = isfinite(eps(:,2)) & isfinite(eps(:,3));
% 
% % YLim VOR Lasso aus ε-Daten berechnen
% if any(idxFinEps)
%     yLowE   = eps(idxFinEps,2) - abs(eps(idxFinEps,3));
%     yHighE  = eps(idxFinEps,2) + abs(eps(idxFinEps,3));
%     yRangeE = max(max(yHighE) - min(yLowE), 1e-6);
%     ylimBeforeEdit = [min(yLowE) - yRangeE*0.20, ...
%                       max(yHighE) + yRangeE*0.20];
% else
%     ylimBeforeEdit = h.axes.YLim;
% end
% 
% % plotdata mit ε(γ)-Werten befüllen
% if any(idxFinEps)
%     set(h.plotdata, ...
%         'XData',          eps(idxFinEps,1), ...
%         'YData',          eps(idxFinEps,2), ...
%         'YNegativeDelta', abs(eps(idxFinEps,3)), ...
%         'YPositiveDelta', abs(eps(idxFinEps,3)), ...
%         'Visible', 'on');
% else
%     set(h.plotdata, 'XData', NaN, 'YData', NaN, ...
%         'YNegativeDelta', NaN, 'YPositiveDelta', NaN, 'Visible', 'off');
% end
% 
% % Fit-Kurve ausblenden während Lasso
% for fn = {'plotdataCentFit','highlightpeakdata'}
%     if isfield(h, fn{1}) && isvalid(h.(fn{1}))
%         set(h.(fn{1}), 'Visible', 'off');
%     end
% end
% 
% % Achsen auf ε-Datenbereich setzen
% if any(idxFinEps)
%     xMinE   = min(eps(idxFinEps,1));
%     xMaxE   = max(eps(idxFinEps,1));
%     marginE = max(5, (xMaxE-xMinE)*0.05);
%     h.axes.XLim = [xMinE-marginE, xMaxE+marginE];
% end
% h.axes.YLimMode      = 'manual';
% h.axes.YLim          = ylimBeforeEdit;
% h.axes.YLabel.String = [char(949),'(',char(947),')'];
% drawnow;
% 
% % =====================================================================
% % Punkte per Lasso auswählen
% % =====================================================================
% pointslist = selectStressPoints(h.axes, h.plotdata);
% 
% if isempty(pointslist)
%     guidata(hObj, h);
%     return
% end
% 
% % =====================================================================
% % ε-Indizes auf FitDataMod-Zeilen mappen (über γ-Werte)
% % =====================================================================
% pv       = h.FitDataMod{valueSlider};
% gammaEps = eps(idxFinEps, 1);
% gammaPV  = pv(:, 1);
% 
% mappedList = zeros(numel(pointslist), 1);
% for pi = 1:numel(pointslist)
%     gammaTarget         = gammaEps(pointslist(pi));
%     [~, mappedList(pi)] = min(abs(gammaPV - gammaTarget));
% end
% mappedList = unique(mappedList);
% 
% % =====================================================================
% % Datenpunkte NaN setzen (Zeilen bleiben erhalten)
% % =====================================================================
% h.FitDataMod{valueSlider}(mappedList, 2:3)   = NaN;
% h.FitDataMod{valueSlider}(mappedList, 9:10)  = NaN;
% if size(h.FitDataMod{valueSlider}, 2) >= 12
%     h.FitDataMod{valueSlider}(mappedList, 11:12) = NaN;
% end
% 
% if isfield(h,'dataPVFitMat') && numel(h.dataPVFitMat) >= valueSlider && ...
%    ~isempty(h.dataPVFitMat{valueSlider}) && ...
%    size(h.dataPVFitMat{valueSlider},1) >= max(mappedList)
%     h.dataPVFitMat{valueSlider}(mappedList, 2:3) = NaN;
% end
% if isfield(h,'datacentFitMat') && numel(h.datacentFitMat) >= valueSlider && ...
%    ~isempty(h.datacentFitMat{valueSlider}) && ...
%    size(h.datacentFitMat{valueSlider},1) >= max(mappedList)
%     h.datacentFitMat{valueSlider}(mappedList, 2:3)   = NaN;
%     h.datacentFitMat{valueSlider}(mappedList, 11:12) = NaN;
% end
% if isfield(h,'FitDataModCentroid') && numel(h.FitDataModCentroid) >= valueSlider && ...
%    ~isempty(h.FitDataModCentroid{valueSlider}) && ...
%    size(h.FitDataModCentroid{valueSlider},1) >= max(mappedList)
%     h.FitDataModCentroid{valueSlider}(mappedList, 2:3) = NaN;
% end
% 
% if numel(h.dataXcorr{valueSlider}) >= max(mappedList)
%     h.dataXcorr{valueSlider}(mappedList) = {[]};
% end
% if numel(h.dataYcorr{valueSlider}) >= max(mappedList)
%     h.dataYcorr{valueSlider}(mappedList) = {[]};
% end
% if numel(h.fitresultexport{valueSlider}) >= max(mappedList)
%     h.fitresultexport{valueSlider}(mappedList) = {[]};
% end
% if isfield(h,'dataPVFitY') && numel(h.dataPVFitY) >= valueSlider && ...
%    numel(h.dataPVFitY{valueSlider}) >= max(mappedList)
%     h.dataPVFitY{valueSlider}(mappedList) = {[]};
% end
% if isfield(h,'datacentFitParams') && numel(h.datacentFitParams) >= valueSlider && ...
%    numel(h.datacentFitParams{valueSlider}) >= max(mappedList)
%     h.datacentFitParams{valueSlider}(mappedList) = {[]};
% end
% 
% % =====================================================================
% % Stress neu berechnen — identisch mit fitstressdatacallback
% % =====================================================================
% my        = str2double(get(h.AbscoeffEditField, 'String'));
% spannkomp = str2double(get(h.SpannKompEditField, 'String'));
% DEK       = h.DEKdataMatchedPeaks;
% 
% mat = h.FitDataMod{valueSlider};
% 
% % Spalten 9+10 nur verwenden wenn vorhanden UND plausible 2theta-Werte
% if size(mat,2) >= 10 && any(mat(:,9) > 1.0, 'all')
%     idxValid = isfinite(mat(:,9)) & (mat(:,9) > 1.0);
%     mat(idxValid, 2) = mat(idxValid, 9);
%     mat(idxValid, 3) = mat(idxValid, 10);
% end
% 
% % Nur Zeilen mit plausiblen 2theta-Werten (>1°) verwenden
% dataForStress = mat(isfinite(mat(:,2)) & (mat(:,2) > 1.0), :);
% 
% fprintf('modstress: Peak %d — %d Zeilen, 2theta range: %.4f..%.4f\n', ...
%     valueSlider, size(dataForStress,1), ...
%     min(dataForStress(:,2)), max(dataForStress(:,2)));
% 
% % DEK-Werte prüfen
% if abs(DEK(valueSlider,5)) < 1e-10 && abs(DEK(valueSlider,6)) < 1e-10
%     warndlg(sprintf(['DEK-Werte für Peak %d sind null.\n' ...
%         'Bitte DEK-Werte in der Tabelle definieren.'], valueSlider), ...
%         'DEK fehlen');
%     guidata(hObj, h);
%     return
% end
% 
% if isempty(dataForStress) || size(dataForStress,1) < 3
%     warndlg(sprintf('Zu wenige Datenpunkte für Peak %d (%d Punkte).', ...
%         valueSlider, size(dataForStress,1)), 'Zu wenige Punkte');
%     guidata(hObj, h);
%     return
% end
% 
% assignin('base','hmodstress',h)
% 
% r = calcStress(dataForStress, DEK(valueSlider,:), my, spannkomp);
% 
% % ── Prüfung ob gültige Ergebnisse ────────────────────────────────────
% if isempty(r.epsfitdata) || ~any(isfinite(r.epsfitdata(:,2)))
%     fprintf('Warning: calcStress lieferte keine finiten ε-Werte für Peak %d\n', ...
%         valueSlider);
% 
%     % Alte ε-Daten behalten — nur gelöschte Punkte auf NaN setzen
%     epsOld       = h.epsfitdataexport{valueSlider};
%     gammaDeleted = h.FitDataMod{valueSlider}(mappedList, 1);
%     for di = 1:numel(gammaDeleted)
%         [~, epsRow] = min(abs(epsOld(:,1) - gammaDeleted(di)));
%         epsOld(epsRow, 2:3) = NaN;
%     end
%     h.epsfitdataexport{valueSlider} = epsOld;
% 
%     idxFinOld = isfinite(epsOld(:,2)) & isfinite(epsOld(:,3));
%     if any(idxFinOld)
%         set(h.plotdata, ...
%             'XData',          epsOld(idxFinOld,1), ...
%             'YData',          epsOld(idxFinOld,2), ...
%             'YNegativeDelta', abs(epsOld(idxFinOld,3)), ...
%             'YPositiveDelta', abs(epsOld(idxFinOld,3)), ...
%             'Visible', 'on');
% 
%         yLowO   = epsOld(idxFinOld,2) - abs(epsOld(idxFinOld,3));
%         yHighO  = epsOld(idxFinOld,2) + abs(epsOld(idxFinOld,3));
%         yRangeO = max(max(yHighO)-min(yLowO), 1e-6);
%         h.axes.YLimMode      = 'manual';
%         h.axes.YLim          = [min(yLowO)-yRangeO*0.20, ...
%                                  max(yHighO)+yRangeO*0.20];
%         h.axes.YLabel.String = [char(949),'(',char(947),')'];
%     end
% 
%     set(h.fitcurvestress, 'Visible', 'off');
%     h = markInvalidGammaRegions(h, valueSlider);
%     drawnow;
%     guidata(hObj, h);
%     return
% end
% 
% % ── Ergebnisse speichern ─────────────────────────────────────────────
% h.epsfitdataexport{valueSlider}       = r.epsfitdata;
% h.epsgammaergfunc{valueSlider}        = r.epsgammaergfunc;
% h.epsgammaergfunc_x{valueSlider}      = r.epsgammaergfunc_x;
% h.epssin2psifitdaten{valueSlider}     = r.epssin2psifitdaten;
% h.sin2psifit{valueSlider}             = r.sin2psifit;
% h.sin2psiregres{valueSlider}          = r.sin2psiregres;
% h.tau{valueSlider}                    = r.tau;
% h.taumean(valueSlider)                = mean(r.tau);
% h.sigmaFinal(valueSlider,:)           = r.sigma';
% h.sigmaerrFinal(valueSlider,:)        = r.sigmaerr';
% h.sigmasin2psiFinal(valueSlider)      = r.sigmapardebye;
% h.deltasigmasin2psiFinal(valueSlider) = r.deltasigmapardebye;
% 
% % =====================================================================
% % Plots aktualisieren
% % =====================================================================
% h = updateStressPlots(h, valueSlider);
% 
% % ── ε(γ)-Plot mit neuen Daten ─────────────────────────────────────────
% epsNew    = h.epsfitdataexport{valueSlider};
% idxFinNew = isfinite(epsNew(:,2)) & isfinite(epsNew(:,3));
% 
% if any(idxFinNew)
%     set(h.plotdata, ...
%         'XData',          epsNew(idxFinNew,1), ...
%         'YData',          epsNew(idxFinNew,2), ...
%         'YNegativeDelta', abs(epsNew(idxFinNew,3)), ...
%         'YPositiveDelta', abs(epsNew(idxFinNew,3)), ...
%         'Visible', 'on');
% 
%     % Fit-Kurve
%     if isfield(h,'epsgammaergfunc_x') && ...
%        numel(h.epsgammaergfunc_x) >= valueSlider && ...
%        ~isempty(h.epsgammaergfunc_x{valueSlider}) && ...
%        numel(h.epsgammaergfunc_x{valueSlider}) == ...
%        numel(h.epsgammaergfunc{valueSlider})
%         set(h.fitcurvestress, ...
%             'XData',   h.epsgammaergfunc_x{valueSlider}(:), ...
%             'YData',   h.epsgammaergfunc{valueSlider}(:), ...
%             'Visible', 'on');
%     else
%         set(h.fitcurvestress, 'Visible', 'off');
%     end
% else
%     set(h.plotdata,       'XData', NaN, 'YData', NaN, ...
%         'YNegativeDelta', NaN, 'YPositiveDelta', NaN, 'Visible', 'off');
%     set(h.fitcurvestress, 'Visible', 'off');
% end
% 
% % ── YLim aus neuen ε-Daten ────────────────────────────────────────────
% if any(idxFinNew)
%     yLowN   = epsNew(idxFinNew,2) - abs(epsNew(idxFinNew,3));
%     yHighN  = epsNew(idxFinNew,2) + abs(epsNew(idxFinNew,3));
%     yRangeN = max(max(yHighN) - min(yLowN), 1e-6);
%     ylimTarget = [min(yLowN) - yRangeN*0.20, max(yHighN) + yRangeN*0.20];
% else
%     ylimTarget = ylimBeforeEdit;
% end
% 
% % highlightpeakdata und fitCentroid ausblenden
% for fn = {'plotdataCentFit','highlightpeakdata'}
%     if isfield(h, fn{1}) && isvalid(h.(fn{1}))
%         set(h.(fn{1}), 'Visible', 'off');
%     end
% end
% 
% % =====================================================================
% % Slider anpassen
% % =====================================================================
% dc        = h.dataXcorr{valueSlider};
% validIdxs = find(~cellfun(@isempty, dc));
% nValid    = numel(validIdxs);
% h.validBinIdxs{valueSlider} = validIdxs;
% 
% if nValid < 1
%     set(h.SliderFittedPeaks, 'Min', 1, 'Max', 2, 'Value', 1, ...
%         'SliderStep', [1 1]);
%     h.axes.YLimMode = 'manual';
%     h.axes.YLim     = ylimTarget;
%     h.axes.YLabel.String = [char(949),'(',char(947),')'];
%     drawnow;
%     guidata(hObj, h);
%     return
% end
% 
% set(h.SliderFittedPeaks, ...
%     'Min',        1, ...
%     'Max',        max(nValid, 2), ...
%     'Value',      1, ...
%     'SliderStep', [1/max(nValid-1,1)  1/max(nValid-1,1)]);
% 
% % =====================================================================
% % Peak-Fit-Plot aktualisieren
% % =====================================================================
% firstAbsBin = validIdxs(1);
% h = updateFittedPeakPlot(h, valueSlider, firstAbsBin);
% 
% % highlightstressplot aktualisieren
% if isfield(h,'highlightstressplot') && isvalid(h.highlightstressplot) && ...
%    valueSlider <= numel(h.taumean)
%     set(h.highlightstressplot, ...
%         'XData',   h.taumean(valueSlider), ...
%         'YData',   h.sigmaFinal(valueSlider,1), ...
%         'Visible', 'on');
% end
% 
% % =====================================================================
% % YLim und Beschriftung final setzen
% % =====================================================================
% h = markInvalidGammaRegions(h, valueSlider);
% h.axes.YLimMode      = 'manual';
% h.axes.YLim          = ylimTarget;
% h.axes.YLabel.String = [char(949),'(',char(947),')'];
% 
% % ── Fit-Kurve explizit sichtbar machen ───────────────────────────────
% if isfield(h,'epsgammaergfunc_x') && ...
%    numel(h.epsgammaergfunc_x) >= valueSlider && ...
%    ~isempty(h.epsgammaergfunc_x{valueSlider}) && ...
%    numel(h.epsgammaergfunc_x{valueSlider}) == ...
%    numel(h.epsgammaergfunc{valueSlider})
%     set(h.fitcurvestress, ...
%         'XData',   h.epsgammaergfunc_x{valueSlider}(:), ...
%         'YData',   h.epsgammaergfunc{valueSlider}(:), ...
%         'Visible', 'on');
% end
% 
% % ── ε-Daten nochmals explizit setzen ─────────────────────────────────
% if any(idxFinNew)
%     set(h.plotdata, ...
%         'XData',          epsNew(idxFinNew,1), ...
%         'YData',          epsNew(idxFinNew,2), ...
%         'YNegativeDelta', abs(epsNew(idxFinNew,3)), ...
%         'YPositiveDelta', abs(epsNew(idxFinNew,3)), ...
%         'Visible', 'on');
% end
% 
% % ── Tau-Plot aktualisieren ────────────────────────────────────────────
% if isfield(h,'tau') && numel(h.tau) >= valueSlider && ...
%    ~isempty(h.tau{valueSlider})
%     tauVec = h.tau{valueSlider}(:);
% 
%     % gamma-Werte aus dataForStress — gleiche Länge wie tau
%     xVec = dataForStress(:,1);
% 
%     if numel(tauVec) == numel(xVec)
%         set(h.plottaudata, ...
%             'XData', xVec, ...
%             'YData', tauVec);
%         set(h.plottaudatamean, ...
%             'XData', xVec, ...
%             'YData', repelem(mean(tauVec), numel(xVec)));
% 
%         tauMin = min(tauVec);
%         tauMax = max(tauVec);
%         tauRange = max(tauMax - tauMin, 0.1);
%         h.axesPlottauData.XLim = h.axes.XLim;
%         h.axesPlottauData.YLim = [tauMin - tauRange*0.15, ...
%                                    tauMax + tauRange*0.15];
%     else
%         fprintf('Tau-Plot: Längen stimmen nicht überein (%d vs %d)\n', ...
%             numel(tauVec), numel(xVec));
%     end
% end
% 
% assignin('base','hmodstress',h)
% drawnow;
% guidata(hObj, h);

function modstressdatacallback(hObj, ~)
h = guidata(hObj);

valueSlider            = round(get(h.Slider,            'Value'));
valueSliderFittedPeaks = round(get(h.SliderFittedPeaks, 'Value'));

% ── safeSlider für dataXcorr-Zugriffe ────────────────────────────────
nXcorr     = numel(h.dataXcorr);
safeSlider = max(1, min(valueSlider, nXcorr));

% ── Prüfen ob Stressfit vorhanden ────────────────────────────────────
if ~isfield(h, 'epsfitdataexport') || ...
   numel(h.epsfitdataexport) < valueSlider || ...
   isempty(h.epsfitdataexport{valueSlider}) || ...
   ~any(isfinite(h.epsfitdataexport{valueSlider}(:,2)))
    errordlg(['Bitte zuerst "Fit Stress Data" ausführen, ' ...
              'bevor Punkte manuell gelöscht werden.'], ...
              'Kein Stressfit vorhanden');
    return
end

% =====================================================================
% Undo-State sichern
% =====================================================================
h.undoState.FitDataMod         = h.FitDataMod;
h.undoState.FitDataModCentroid = h.FitDataModCentroid;
h.undoState.fitresultexport    = h.fitresultexport;
h.undoState.dataXcorr          = h.dataXcorr;
h.undoState.dataYcorr          = h.dataYcorr;
h.undoState.fitMethodUsed      = h.fitMethodUsed;
h.undoState.dataCentroidMu     = h.dataCentroidMu;
h.undoState.dataGaussFit       = h.dataGaussFit;
h.undoState.dataPVFitY         = h.dataPVFitY;
h.undoState.dataPVSuccess      = h.dataPVSuccess;
if isfield(h, 'dataPVFitMat')
    h.undoState.dataPVFitMat   = h.dataPVFitMat;
end
if isfield(h, 'datacentFitMat')
    h.undoState.datacentFitMat = h.datacentFitMat;
end
if isfield(h, 'epsfitdataexport')
    h.undoState.epsfitdataexport       = h.epsfitdataexport;
    h.undoState.epsgammaergfunc        = h.epsgammaergfunc;
    h.undoState.epsgammaergfunc_x      = h.epsgammaergfunc_x;
    h.undoState.epssin2psifitdaten     = h.epssin2psifitdaten;
    h.undoState.sin2psifit             = h.sin2psifit;
    h.undoState.sin2psiregres          = h.sin2psiregres;
    h.undoState.tau                    = h.tau;
    h.undoState.taumean                = h.taumean;
    h.undoState.sigmaFinal             = h.sigmaFinal;
    h.undoState.sigmaerrFinal          = h.sigmaerrFinal;
    h.undoState.sigmasin2psiFinal      = h.sigmasin2psiFinal;
    h.undoState.deltasigmasin2psiFinal = h.deltasigmasin2psiFinal;
end
if isfield(h, 'validBinIdxs')
    h.undoState.validBinIdxs = h.validBinIdxs;
end
h.undoState.valueSlider = valueSlider;

if isfield(h, 'UndoStressButton') && isvalid(h.UndoStressButton)
    set(h.UndoStressButton, 'Enable', 'on');
end

% =====================================================================
% ε(γ)-Daten für Lasso vorbereiten
% =====================================================================
eps       = h.epsfitdataexport{valueSlider};
idxFinEps = isfinite(eps(:,2)) & isfinite(eps(:,3));

% YLim VOR Lasso aus ε-Daten berechnen
if any(idxFinEps)
    yLowE   = eps(idxFinEps,2) - abs(eps(idxFinEps,3));
    yHighE  = eps(idxFinEps,2) + abs(eps(idxFinEps,3));
    yRangeE = max(max(yHighE) - min(yLowE), 1e-6);
    ylimBeforeEdit = [min(yLowE) - yRangeE*0.20, ...
                      max(yHighE) + yRangeE*0.20];
else
    ylimBeforeEdit = h.axes.YLim;
end

% plotdata mit ε(γ)-Werten befüllen
if any(idxFinEps)
    set(h.plotdata, ...
        'XData',          eps(idxFinEps,1), ...
        'YData',          eps(idxFinEps,2), ...
        'YNegativeDelta', abs(eps(idxFinEps,3)), ...
        'YPositiveDelta', abs(eps(idxFinEps,3)), ...
        'MarkerSize',       4, ...
        'MarkerFaceColor',  [0.094 0.373 0.647], ...
        'MarkerEdgeColor',  [0.094 0.373 0.647], ...
        'Color',            [0.094 0.373 0.647], ...
        'Visible', 'on');
else
    set(h.plotdata, 'XData', NaN, 'YData', NaN, ...
        'YNegativeDelta', NaN, 'YPositiveDelta', NaN, 'Visible', 'off');
end

% Fit-Kurve und Highlights ausblenden während Lasso
for fn = {'plotdataCentFit','highlightpeakdata','highlightstressplot'}
    if isfield(h, fn{1}) && isvalid(h.(fn{1}))
        set(h.(fn{1}), 'Visible', 'off');
    end
end
delete(findobj(h.axes, 'Tag', 'invalidgamma'));

% Achsen auf ε-Datenbereich setzen
if any(idxFinEps)
    xMinE   = min(eps(idxFinEps,1));
    xMaxE   = max(eps(idxFinEps,1));
    marginE = max(5, (xMaxE-xMinE)*0.05);
    h.axes.XLim = [xMinE-marginE, xMaxE+marginE];
end
h.axes.YLimMode      = 'manual';
h.axes.YLim          = ylimBeforeEdit;
h.axes.YLabel.String = [char(949),'(',char(947),')'];
drawnow;

% =====================================================================
% Punkte per Lasso auswählen
% =====================================================================
pointslist = selectStressPoints(h.axes, h.plotdata);

if isempty(pointslist)
    guidata(hObj, h);
    return
end

% =====================================================================
% ε-Indizes auf FitDataMod-Zeilen mappen (über γ-Werte)
% =====================================================================
pv       = h.FitDataMod{valueSlider};
gammaEps = eps(idxFinEps, 1);
gammaPV  = pv(:, 1);

mappedList = zeros(numel(pointslist), 1);
for pi = 1:numel(pointslist)
    gammaTarget         = gammaEps(pointslist(pi));
    [~, mappedList(pi)] = min(abs(gammaPV - gammaTarget));
end
mappedList = unique(mappedList);

% =====================================================================
% Datenpunkte NaN setzen (Zeilen bleiben erhalten)
% =====================================================================
nColsFDM = size(h.FitDataMod{valueSlider}, 2);
h.FitDataMod{valueSlider}(mappedList, 2:3) = NaN;
if nColsFDM >= 10
    h.FitDataMod{valueSlider}(mappedList, 9:10)  = NaN;
end
if nColsFDM >= 12
    h.FitDataMod{valueSlider}(mappedList, 11:12) = NaN;
end

if isfield(h,'dataPVFitMat') && numel(h.dataPVFitMat) >= valueSlider && ...
   ~isempty(h.dataPVFitMat{valueSlider}) && ...
   size(h.dataPVFitMat{valueSlider},1) >= max(mappedList)
    h.dataPVFitMat{valueSlider}(mappedList, 2:3) = NaN;
end
if isfield(h,'datacentFitMat') && numel(h.datacentFitMat) >= valueSlider && ...
   ~isempty(h.datacentFitMat{valueSlider}) && ...
   size(h.datacentFitMat{valueSlider},1) >= max(mappedList)
    h.datacentFitMat{valueSlider}(mappedList, 2:3) = NaN;
    if size(h.datacentFitMat{valueSlider},2) >= 12
        h.datacentFitMat{valueSlider}(mappedList, 11:12) = NaN;
    end
end
if isfield(h,'FitDataModCentroid') && numel(h.FitDataModCentroid) >= valueSlider && ...
   ~isempty(h.FitDataModCentroid{valueSlider}) && ...
   size(h.FitDataModCentroid{valueSlider},1) >= max(mappedList)
    h.FitDataModCentroid{valueSlider}(mappedList, 2:3) = NaN;
end

% ── Cell-Arrays: Länge prüfen vor Zugriff ────────────────────────────
for cellField = {'dataXcorr','dataYcorr','fitresultexport','dataPVFitY','datacentFitParams'}
    fn = cellField{1};
    if isfield(h, fn) && numel(h.(fn)) >= safeSlider && ...
       ~isempty(h.(fn){safeSlider})
        nArr        = numel(h.(fn){safeSlider});
        validIdxDel = mappedList(mappedList <= nArr);
        if ~isempty(validIdxDel)
            h.(fn){safeSlider}(validIdxDel) = {[]};
        end
    end
end

% =====================================================================
% Stress neu berechnen
% =====================================================================
my        = str2double(get(h.AbscoeffEditField, 'String'));
spannkomp = str2double(get(h.SpannKompEditField, 'String'));
DEK       = h.DEKdataMatchedPeaks;

mat = h.FitDataMod{valueSlider};

% Spalten 9+10 nur verwenden wenn vorhanden UND plausible 2theta-Werte
[yColMat, yErrColMat, ~] = getPlausibleCol(mat);
if yColMat == 9
    idxValid = isfinite(mat(:,9)) & (mat(:,9) > 1.0) & ...
               (abs(mat(:,9) - round(mat(:,9))) > 1e-5);
    mat(idxValid, 2) = mat(idxValid, 9);
    mat(idxValid, 3) = mat(idxValid, 10);
end

% Nur Zeilen mit plausiblen 2theta-Werten verwenden
[~, ~, idxForStress] = getPlausibleCol(mat);
dataForStress = mat(idxForStress, :);

fprintf('modstress: Peak %d — %d Zeilen, 2theta range: %.4f..%.4f\n', ...
    valueSlider, size(dataForStress,1), ...
    min(dataForStress(:,2)), max(dataForStress(:,2)));

% DEK-Werte prüfen
if abs(DEK(valueSlider,5)) < 1e-10 && abs(DEK(valueSlider,6)) < 1e-10
    warndlg(sprintf(['DEK-Werte für Peak %d sind null.\n' ...
        'Bitte DEK-Werte in der Tabelle definieren.'], valueSlider), ...
        'DEK fehlen');
    guidata(hObj, h);
    return
end

if isempty(dataForStress) || size(dataForStress,1) < 3
    warndlg(sprintf('Zu wenige Datenpunkte für Peak %d (%d Punkte).', ...
        valueSlider, size(dataForStress,1)), 'Zu wenige Punkte');
    guidata(hObj, h);
    return
end

assignin('base','hmodstress',h)

r = calcStress(dataForStress, DEK(valueSlider,:), my, spannkomp);

% ── Prüfung ob gültige Ergebnisse ────────────────────────────────────
if isempty(r.epsfitdata) || ~any(isfinite(r.epsfitdata(:,2)))
    fprintf('Warning: calcStress lieferte keine finiten ε-Werte für Peak %d\n', ...
        valueSlider);

    epsOld       = h.epsfitdataexport{valueSlider};
    gammaDeleted = h.FitDataMod{valueSlider}(mappedList, 1);
    for di = 1:numel(gammaDeleted)
        [~, epsRow] = min(abs(epsOld(:,1) - gammaDeleted(di)));
        epsOld(epsRow, 2:3) = NaN;
    end
    h.epsfitdataexport{valueSlider} = epsOld;

    idxFinOld = isfinite(epsOld(:,2)) & isfinite(epsOld(:,3));
    if any(idxFinOld)
        set(h.plotdata, ...
            'XData',          epsOld(idxFinOld,1), ...
            'YData',          epsOld(idxFinOld,2), ...
            'YNegativeDelta', abs(epsOld(idxFinOld,3)), ...
            'YPositiveDelta', abs(epsOld(idxFinOld,3)), ...
            'MarkerSize',       4, ...
            'MarkerFaceColor',  [0.094 0.373 0.647], ...
            'MarkerEdgeColor',  [0.094 0.373 0.647], ...
            'Color',            [0.094 0.373 0.647], ...
            'Visible', 'on');

        yLowO   = epsOld(idxFinOld,2) - abs(epsOld(idxFinOld,3));
        yHighO  = epsOld(idxFinOld,2) + abs(epsOld(idxFinOld,3));
        yRangeO = max(max(yHighO)-min(yLowO), 1e-6);
        h.axes.YLimMode      = 'manual';
        h.axes.YLim          = [min(yLowO)-yRangeO*0.20, ...
                                 max(yHighO)+yRangeO*0.20];
        h.axes.YLabel.String = [char(949),'(',char(947),')'];
    end

    set(h.fitcurvestress, 'Visible', 'off');
    h = markInvalidGammaRegions(h, valueSlider);
    drawnow;
    guidata(hObj, h);
    return
end

% ── Ergebnisse speichern ─────────────────────────────────────────────
h.epsfitdataexport{valueSlider}       = r.epsfitdata;
h.epsgammaergfunc{valueSlider}        = r.epsgammaergfunc;
h.epsgammaergfunc_x{valueSlider}      = r.epsgammaergfunc_x;
h.epssin2psifitdaten{valueSlider}     = r.epssin2psifitdaten;
h.sin2psifit{valueSlider}             = r.sin2psifit;
h.sin2psiregres{valueSlider}          = r.sin2psiregres;
h.tau{valueSlider}                    = r.tau;
% h.taumean(valueSlider)                = mean(r.tau);
tauVec_k = r.tau(isfinite(r.tau) & r.tau > 0);
if isempty(tauVec_k)
    h.taumean(valueSlider) = NaN;
else
    h.taumean(valueSlider) = mean(tauVec_k);
end

h.sigmaFinal(valueSlider,:)           = r.sigma';
h.sigmaerrFinal(valueSlider,:)        = r.sigmaerr';
h.sigmasin2psiFinal(valueSlider)      = r.sigmapardebye;
h.deltasigmasin2psiFinal(valueSlider) = r.deltasigmapardebye;

% =====================================================================
% Plots aktualisieren
% =====================================================================
h = updateStressPlots(h, valueSlider);

% ── ε(γ)-Plot mit neuen Daten ─────────────────────────────────────────
epsNew    = h.epsfitdataexport{valueSlider};
idxFinNew = isfinite(epsNew(:,2)) & isfinite(epsNew(:,3));

if any(idxFinNew)
    set(h.plotdata, ...
        'XData',          epsNew(idxFinNew,1), ...
        'YData',          epsNew(idxFinNew,2), ...
        'YNegativeDelta', abs(epsNew(idxFinNew,3)), ...
        'YPositiveDelta', abs(epsNew(idxFinNew,3)), ...
        'MarkerSize',       4, ...
        'MarkerFaceColor',  [0.094 0.373 0.647], ...
        'MarkerEdgeColor',  [0.094 0.373 0.647], ...
        'Color',            [0.094 0.373 0.647], ...
        'Visible', 'on');

    % Fit-Kurve
    if isfield(h,'epsgammaergfunc_x') && ...
       numel(h.epsgammaergfunc_x) >= valueSlider && ...
       ~isempty(h.epsgammaergfunc_x{valueSlider}) && ...
       numel(h.epsgammaergfunc_x{valueSlider}) == ...
       numel(h.epsgammaergfunc{valueSlider})
        set(h.fitcurvestress, ...
            'XData',   h.epsgammaergfunc_x{valueSlider}(:), ...
            'YData',   h.epsgammaergfunc{valueSlider}(:), ...
            'Color',   [0.85 0.33 0.10], ...
            'Visible', 'on');
    else
        set(h.fitcurvestress, 'Visible', 'off');
    end
else
    set(h.plotdata, 'XData', NaN, 'YData', NaN, ...
        'YNegativeDelta', NaN, 'YPositiveDelta', NaN, 'Visible', 'off');
    set(h.fitcurvestress, 'Visible', 'off');
end

% ── YLim aus neuen ε-Daten ────────────────────────────────────────────
if any(idxFinNew)
    yLowN   = epsNew(idxFinNew,2) - abs(epsNew(idxFinNew,3));
    yHighN  = epsNew(idxFinNew,2) + abs(epsNew(idxFinNew,3));
    yRangeN = max(max(yHighN) - min(yLowN), 1e-6);
    ylimTarget = [min(yLowN) - yRangeN*0.20, max(yHighN) + yRangeN*0.20];
else
    ylimTarget = ylimBeforeEdit;
end

% highlightpeakdata und fitCentroid ausgeblendet lassen
for fn = {'plotdataCentFit','highlightpeakdata'}
    if isfield(h, fn{1}) && isvalid(h.(fn{1}))
        set(h.(fn{1}), 'Visible', 'off');
    end
end

% =====================================================================
% Slider anpassen — safeSlider verwenden
% =====================================================================
dc        = h.dataXcorr{safeSlider};
validIdxs = find(~cellfun(@isempty, dc));
nValid    = numel(validIdxs);
h.validBinIdxs{valueSlider} = validIdxs;

if nValid < 1
    set(h.SliderFittedPeaks, 'Min', 1, 'Max', 2, 'Value', 1, ...
        'SliderStep', [1 1]);
    h.axes.YLimMode      = 'manual';
    h.axes.YLim          = ylimTarget;
    h.axes.YLabel.String = [char(949),'(',char(947),')'];
    drawnow;
    guidata(hObj, h);
    return
end

set(h.SliderFittedPeaks, ...
    'Min',        1, ...
    'Max',        max(nValid, 2), ...
    'Value',      1, ...
    'SliderStep', [1/max(nValid-1,1)  1/max(nValid-1,1)]);

% =====================================================================
% Peak-Fit-Plot aktualisieren — safeSlider verwenden
% =====================================================================
firstAbsBin = validIdxs(1);

if isfield(h,'FitDataMod') && numel(h.FitDataMod) >= valueSlider && ...
   isfield(h,'BinnedGamma') && ~isempty(h.BinnedGamma)
    pv_vs = h.FitDataMod{valueSlider};
    [~, ~, idxVS] = getPlausibleCol(pv_vs);
    firstValidRow = find(idxVS, 1, 'first');
    if ~isempty(firstValidRow)
        firstAbsBin = firstValidRow;
        firstAbsBin = max(1, min(firstAbsBin, numel(h.dataXcorr{safeSlider})));
    end
end

h = updateFittedPeakPlot(h, safeSlider, firstAbsBin);

% highlightstressplot aktualisieren
if isfield(h,'highlightstressplot') && isvalid(h.highlightstressplot) && ...
   valueSlider <= numel(h.taumean)
    set(h.highlightstressplot, ...
        'XData',   h.taumean(valueSlider), ...
        'YData',   h.sigmaFinal(valueSlider,1), ...
        'Visible', 'on');
end

% =====================================================================
% YLim und Beschriftung final setzen — zweimal gegen Autoscaling
% =====================================================================
h.axes.YLimMode = 'manual';
h.axes.YLim     = ylimTarget;
h = markInvalidGammaRegions(h, valueSlider);   % patches mit korrektem ε-YLim
h.axes.YLabel.String = [char(949),'(',char(947),')'];
drawnow;
h.axes.YLimMode      = 'manual';
h.axes.YLim          = ylimTarget;

% ── ε-Daten nochmals explizit setzen ─────────────────────────────────
if any(idxFinNew)
    set(h.plotdata, ...
        'XData',          epsNew(idxFinNew,1), ...
        'YData',          epsNew(idxFinNew,2), ...
        'YNegativeDelta', abs(epsNew(idxFinNew,3)), ...
        'YPositiveDelta', abs(epsNew(idxFinNew,3)), ...
        'MarkerSize',       4, ...
        'MarkerFaceColor',  [0.094 0.373 0.647], ...
        'MarkerEdgeColor',  [0.094 0.373 0.647], ...
        'Color',            [0.094 0.373 0.647], ...
        'Visible', 'on');
end

% ── Tau-Plot aktualisieren ────────────────────────────────────────────
if isfield(h,'tau') && numel(h.tau) >= valueSlider && ...
   ~isempty(h.tau{valueSlider})
    tauVec = h.tau{valueSlider}(:);
    xVec   = dataForStress(:,1);
    if numel(tauVec) == numel(xVec)
        tauMin   = min(tauVec);
        tauMax   = max(tauVec);
        tauRange = max(tauMax - tauMin, 0.1);
        set(h.plottaudata, 'XData', xVec, 'YData', tauVec);
        set(h.plottaudatamean, 'XData', xVec, ...
            'YData', repelem(mean(tauVec), numel(xVec)));
        h.axesPlottauData.XLim = h.axes.XLim;
        h.axesPlottauData.YLim = [tauMin - tauRange*0.15, ...
                                   tauMax + tauRange*0.15];
    else
        fprintf('Tau-Plot: Längen stimmen nicht überein (%d vs %d)\n', ...
            numel(tauVec), numel(xVec));
    end
end

assignin('base','hmodstress',h)
drawnow;
guidata(hObj, h);

% function moddatacallback(hObj, ~)
% h = guidata(hObj);
% 
% valueSlider            = round(get(h.Slider,            'Value'));
% valueSliderFittedPeaks = round(get(h.SliderFittedPeaks, 'Value'));
% 
% % =====================================================================
% % Undo-State sichern
% % =====================================================================
% h.undoState.FitDataMod         = h.FitDataMod;
% h.undoState.FitDataModCentroid = h.FitDataModCentroid;
% h.undoState.fitresultexport    = h.fitresultexport;
% h.undoState.dataXcorr          = h.dataXcorr;
% h.undoState.dataYcorr          = h.dataYcorr;
% h.undoState.fitMethodUsed      = h.fitMethodUsed;
% h.undoState.dataCentroidMu     = h.dataCentroidMu;
% h.undoState.dataGaussFit       = h.dataGaussFit;
% h.undoState.dataPVFitY         = h.dataPVFitY;
% h.undoState.dataPVSuccess      = h.dataPVSuccess;
% if isfield(h, 'dataPVFitMat')
%     h.undoState.dataPVFitMat   = h.dataPVFitMat;
% end
% if isfield(h, 'datacentFitMat')
%     h.undoState.datacentFitMat = h.datacentFitMat;
% end
% if isfield(h, 'validBinIdxs')
%     h.undoState.validBinIdxs = h.validBinIdxs;
% end
% h.undoState.valueSlider = valueSlider;
% 
% if isfield(h, 'UndoStressButton') && isvalid(h.UndoStressButton)
%     set(h.UndoStressButton, 'Enable', 'on');
% end
% 
% % =====================================================================
% % YLim VOR Lasso aus aktuell gültigen Daten berechnen
% % =====================================================================
% % pvPre = h.FitDataMod{valueSlider};
% % if size(pvPre,2) >= 10 && any(isfinite(pvPre(:,9)))
% %     yColPre    = 9;
% %     yErrColPre = 10;
% % else
% %     yColPre    = 2;
% %     yErrColPre = 3;
% % end
% % idxPre = isfinite(pvPre(:,yColPre)) & isfinite(pvPre(:,yErrColPre));
% pvPre = h.FitDataMod{valueSlider};
% nColsPre = size(pvPre, 2);
% 
% % Plausibilitätscheck: nur Werte > 1° sind echte 2theta-Werte
% if nColsPre >= 10 && any(isfinite(pvPre(:,9)) & pvPre(:,9) > 1.0)
%     yColPre    = 9;
%     yErrColPre = 10;
% elseif any(isfinite(pvPre(:,2)) & pvPre(:,2) > 1.0)
%     yColPre    = 2;
%     yErrColPre = 3;
% else
%     yColPre    = 2;
%     yErrColPre = 3;
% end
% yColPre    = min(yColPre,    nColsPre);
% yErrColPre = min(yErrColPre, nColsPre);
% 
% idxPre = isfinite(pvPre(:,yColPre)) & isfinite(pvPre(:,yErrColPre)) & ...
%          (pvPre(:,yColPre) > 1.0);
% if any(idxPre)
%     yLowPre  = pvPre(idxPre, yColPre) - abs(pvPre(idxPre, yErrColPre));
%     yHighPre = pvPre(idxPre, yColPre) + abs(pvPre(idxPre, yErrColPre));
%     rangePre  = max(max(yHighPre) - min(yLowPre), 1e-6);
%     ylimBeforeEdit = [min(yLowPre) - rangePre*0.20, ...
%                       max(yHighPre) + rangePre*0.20];
% else
%     ylimBeforeEdit = h.axes.YLim;
% end
% 
% % =====================================================================
% % plotdata für Lasso-Selektion setzen (alle Zeilen inkl. NaN)
% % =====================================================================
% dataForPlot = h.FitDataMod{valueSlider};
% if size(dataForPlot, 2) >= 10
%     idxV = isfinite(dataForPlot(:,9));
%     dataForPlot(idxV, 2) = dataForPlot(idxV, 9);
%     dataForPlot(idxV, 3) = dataForPlot(idxV, 10);
% end
% 
% set(h.plotdata, ...
%     'XData',          dataForPlot(:,1), ...
%     'YData',          dataForPlot(:,2), ...
%     'YNegativeDelta', abs(dataForPlot(:,3)), ...
%     'YPositiveDelta', abs(dataForPlot(:,3)), ...
%     'Visible', 'on');
% 
% xMin = min(dataForPlot(:,1));
% xMax = max(dataForPlot(:,1));
% if isfinite(xMin) && isfinite(xMax)
%     h.axes.XLim = [xMin-5, xMax+5];
% end
% 
% % =====================================================================
% % Punkte per Lasso auswählen
% % =====================================================================
% pointslist = selectStressPoints(h.axes, h.plotdata);
% 
% if isempty(pointslist)
%     guidata(hObj, h);
%     return
% end
% 
% % % =====================================================================
% % % Datenpunkte NaN setzen (Zeilen bleiben erhalten)
% % % =====================================================================
% % h.FitDataMod{valueSlider}(pointslist, 2:3)   = NaN;
% % h.FitDataMod{valueSlider}(pointslist, 9:10)  = NaN;
% % h.FitDataMod{valueSlider}(pointslist, 11:12) = NaN;
% % 
% % if isfield(h,'dataPVFitMat') && numel(h.dataPVFitMat) >= valueSlider && ...
% %    size(h.dataPVFitMat{valueSlider},1) >= max(pointslist)
% %     h.dataPVFitMat{valueSlider}(pointslist, 2:3) = NaN;
% % end
% % if isfield(h,'datacentFitMat') && numel(h.datacentFitMat) >= valueSlider && ...
% %    size(h.datacentFitMat{valueSlider},1) >= max(pointslist)
% %     h.datacentFitMat{valueSlider}(pointslist, 2:3)   = NaN;
% %     h.datacentFitMat{valueSlider}(pointslist, 11:12) = NaN;
% % end
% % if isfield(h,'FitDataModCentroid') && numel(h.FitDataModCentroid) >= valueSlider && ...
% %    size(h.FitDataModCentroid{valueSlider},1) >= max(pointslist)
% %     h.FitDataModCentroid{valueSlider}(pointslist, 2:3) = NaN;
% % end
% % 
% % if numel(h.dataXcorr{valueSlider}) >= max(pointslist)
% %     h.dataXcorr{valueSlider}(pointslist) = {[]};
% % end
% % if numel(h.dataYcorr{valueSlider}) >= max(pointslist)
% %     h.dataYcorr{valueSlider}(pointslist) = {[]};
% % end
% % if numel(h.fitresultexport{valueSlider}) >= max(pointslist)
% %     h.fitresultexport{valueSlider}(pointslist) = {[]};
% % end
% % if isfield(h,'dataPVFitY') && numel(h.dataPVFitY{valueSlider}) >= max(pointslist)
% %     h.dataPVFitY{valueSlider}(pointslist) = {[]};
% % end
% % if isfield(h,'datacentFitParams') && numel(h.datacentFitParams{valueSlider}) >= max(pointslist)
% %     h.datacentFitParams{valueSlider}(pointslist) = {[]};
% % end
% 
% % =====================================================================
% % Datenpunkte NaN setzen (Zeilen bleiben erhalten)
% % =====================================================================
% h.FitDataMod{valueSlider}(pointslist, 2:3)   = NaN;
% 
% % Spalten 9:10 nur wenn vorhanden
% if size(h.FitDataMod{valueSlider}, 2) >= 10
%     h.FitDataMod{valueSlider}(pointslist, 9:10)  = NaN;
% end
% % Spalten 11:12 nur wenn vorhanden
% if size(h.FitDataMod{valueSlider}, 2) >= 12
%     h.FitDataMod{valueSlider}(pointslist, 11:12) = NaN;
% end
% 
% if isfield(h,'dataPVFitMat') && numel(h.dataPVFitMat) >= valueSlider && ...
%    ~isempty(h.dataPVFitMat{valueSlider}) && ...
%    size(h.dataPVFitMat{valueSlider},1) >= max(pointslist)
%     h.dataPVFitMat{valueSlider}(pointslist, 2:3) = NaN;
% end
% if isfield(h,'datacentFitMat') && numel(h.datacentFitMat) >= valueSlider && ...
%    ~isempty(h.datacentFitMat{valueSlider}) && ...
%    size(h.datacentFitMat{valueSlider},1) >= max(pointslist)
%     h.datacentFitMat{valueSlider}(pointslist, 2:3) = NaN;
%     if size(h.datacentFitMat{valueSlider},2) >= 12
%         h.datacentFitMat{valueSlider}(pointslist, 11:12) = NaN;
%     end
% end
% if isfield(h,'FitDataModCentroid') && numel(h.FitDataModCentroid) >= valueSlider && ...
%    ~isempty(h.FitDataModCentroid{valueSlider}) && ...
%    size(h.FitDataModCentroid{valueSlider},1) >= max(pointslist)
%     h.FitDataModCentroid{valueSlider}(pointslist, 2:3) = NaN;
% end
% 
% % ── dataXcorr / dataYcorr: Länge prüfen vor Zugriff ─────────────────
% if isfield(h,'dataXcorr') && numel(h.dataXcorr) >= valueSlider && ...
%    ~isempty(h.dataXcorr{valueSlider})
%     nXcorr = numel(h.dataXcorr{valueSlider});
%     validPoints = pointslist(pointslist <= nXcorr);
%     if ~isempty(validPoints)
%         h.dataXcorr{valueSlider}(validPoints) = {[]};
%     end
% end
% 
% if isfield(h,'dataYcorr') && numel(h.dataYcorr) >= valueSlider && ...
%    ~isempty(h.dataYcorr{valueSlider})
%     nYcorr = numel(h.dataYcorr{valueSlider});
%     validPoints = pointslist(pointslist <= nYcorr);
%     if ~isempty(validPoints)
%         h.dataYcorr{valueSlider}(validPoints) = {[]};
%     end
% end
% 
% if isfield(h,'fitresultexport') && numel(h.fitresultexport) >= valueSlider && ...
%    ~isempty(h.fitresultexport{valueSlider})
%     nFre = numel(h.fitresultexport{valueSlider});
%     validPoints = pointslist(pointslist <= nFre);
%     if ~isempty(validPoints)
%         h.fitresultexport{valueSlider}(validPoints) = {[]};
%     end
% end
% 
% if isfield(h,'dataPVFitY') && numel(h.dataPVFitY) >= valueSlider && ...
%    ~isempty(h.dataPVFitY{valueSlider})
%     nPVFY = numel(h.dataPVFitY{valueSlider});
%     validPoints = pointslist(pointslist <= nPVFY);
%     if ~isempty(validPoints)
%         h.dataPVFitY{valueSlider}(validPoints) = {[]};
%     end
% end
% 
% if isfield(h,'datacentFitParams') && numel(h.datacentFitParams) >= valueSlider && ...
%    ~isempty(h.datacentFitParams{valueSlider})
%     nCFP = numel(h.datacentFitParams{valueSlider});
%     validPoints = pointslist(pointslist <= nCFP);
%     if ~isempty(validPoints)
%         h.datacentFitParams{valueSlider}(validPoints) = {[]};
%     end
% end
% 
% % =====================================================================
% % Nullwerte in Peaklagen-Spalten ebenfalls auf NaN setzen
% % (Nullzeilen die nicht durch idxDel entfernt wurden)
% % =====================================================================
% for nanCol = [2, 9]
%     if size(h.FitDataMod{valueSlider}, 2) >= nanCol
%         zeroMask = (h.FitDataMod{valueSlider}(:, nanCol) == 0);
%         h.FitDataMod{valueSlider}(zeroMask, nanCol)   = NaN;
%         h.FitDataMod{valueSlider}(zeroMask, nanCol+1) = NaN;
%     end
% end
% 
% % % =====================================================================
% % % Plot aktualisieren + ylimTarget berechnen
% % % =====================================================================
% % pv = h.FitDataMod{valueSlider};
% % 
% % if size(pv,2) >= 10 && any(isfinite(pv(:,9)))
% %     yCol    = 9;
% %     yErrCol = 10;
% % else
% %     yCol    = 2;
% %     yErrCol = 3;
% % end
% % 
% % % idxFinY = isfinite(pv(:,yCol)) & isfinite(pv(:,yErrCol));
% % idxFinY = isfinite(pv(:,yCol)) & isfinite(pv(:,yErrCol)) & (pv(:,yCol) ~= 0);
% % 
% % if any(idxFinY)
% %     % Nur finite Punkte an plotdata übergeben — keine NaN-Zeilen
% %     % (NaN-Zeilen werden von MATLAB als y=0 gerendert → falsche Autoskalierung)
% %     set(h.plotdata, ...
% %         'XData',          pv(idxFinY, 1), ...
% %         'YData',          pv(idxFinY, yCol), ...
% %         'YNegativeDelta', abs(pv(idxFinY, yErrCol)), ...
% %         'YPositiveDelta', abs(pv(idxFinY, yErrCol)), ...
% %         'Visible', 'on');
% % 
% %     yLow    = pv(idxFinY, yCol) - abs(pv(idxFinY, yErrCol));
% %     yHigh   = pv(idxFinY, yCol) + abs(pv(idxFinY, yErrCol));
% %     yRange  = max(max(yHigh) - min(yLow), 1e-6);
% %     ylimTarget = [min(yLow) - yRange*0.20,  max(yHigh) + yRange*0.20];
% % else
% %     % Keine gültigen Punkte → plotdata auf NaN (nicht auf 0!)
% %     set(h.plotdata, ...
% %         'XData', NaN, 'YData', NaN, ...
% %         'YNegativeDelta', NaN, 'YPositiveDelta', NaN, ...
% %         'Visible', 'off');
% %     for fn = {'fitcurvestress', 'plotdataCentFit'}
% %         if isfield(h, fn{1}) && isvalid(h.(fn{1}))
% %             set(h.(fn{1}), 'Visible', 'off');
% %         end
% %     end
% %     ylimTarget = ylimBeforeEdit;
% % end
% 
% % =====================================================================
% % Plot aktualisieren + ylimTarget berechnen
% % =====================================================================
% pv = h.FitDataMod{valueSlider};
% 
% nCols = size(pv, 2);
% 
% % Spalten 9+10 nur wenn BEIDE vorhanden und plausible 2theta-Werte (>1°)
% if nCols >= 10 && any(isfinite(pv(:,9)) & pv(:,9) > 1.0)
%     yCol    = 9;
%     yErrCol = 10;
% elseif any(isfinite(pv(:,2)) & pv(:,2) > 1.0)
%     yCol    = 2;
%     yErrCol = 3;
% else
%     yCol    = 2;
%     yErrCol = 3;
% end
% 
% % Sicherheitscheck: Spaltenindex darf Array-Breite nicht überschreiten
% yCol    = min(yCol,    nCols);
% yErrCol = min(yErrCol, nCols);
% 
% % Nur Zeilen mit plausiblen 2theta-Werten (>1°) als gültig markieren
% idxFinY = isfinite(pv(:,yCol)) & isfinite(pv(:,yErrCol)) & (pv(:,yCol) > 1.0);
% 
% if any(idxFinY)
%     set(h.plotdata, ...
%         'XData',          pv(idxFinY, 1), ...
%         'YData',          pv(idxFinY, yCol), ...
%         'YNegativeDelta', abs(pv(idxFinY, yErrCol)), ...
%         'YPositiveDelta', abs(pv(idxFinY, yErrCol)), ...
%         'Visible', 'on');
% 
%     yLow    = pv(idxFinY, yCol) - abs(pv(idxFinY, yErrCol));
%     yHigh   = pv(idxFinY, yCol) + abs(pv(idxFinY, yErrCol));
%     yLow    = yLow(isfinite(yLow));
%     yHigh   = yHigh(isfinite(yHigh));
%     yRange  = max(max(yHigh) - min(yLow), 1e-6);
%     ylimTarget = [min(yLow) - yRange*0.20, max(yHigh) + yRange*0.20];
% else
%     set(h.plotdata, ...
%         'XData', NaN, 'YData', NaN, ...
%         'YNegativeDelta', NaN, 'YPositiveDelta', NaN, ...
%         'Visible', 'off');
%     for fn = {'fitcurvestress', 'plotdataCentFit'}
%         if isfield(h, fn{1}) && isvalid(h.(fn{1}))
%             set(h.(fn{1}), 'Visible', 'off');
%         end
%     end
%     ylimTarget = ylimBeforeEdit;
% end
% 
% % fitCentroid aktualisieren
% if isfield(h,'datacentFitMat') && numel(h.datacentFitMat) >= valueSlider
%     cf       = h.datacentFitMat{valueSlider};
%     idxCF    = isfinite(cf(:,2));
%     showCent = isfield(h,'cb_showCentroid') && get(h.cb_showCentroid,'Value') == 1;
%     if isfield(h,'plotdataCentFit') && isvalid(h.plotdataCentFit)
%         if any(idxCF) && showCent
%             set(h.plotdataCentFit, ...
%                 'XData',          cf(idxCF,1), ...
%                 'YData',          cf(idxCF,2), ...
%                 'YNegativeDelta', cf(idxCF,3), ...
%                 'YPositiveDelta', cf(idxCF,3), ...
%                 'Visible', 'on');
%         else
%             set(h.plotdataCentFit, 'Visible', 'off');
%         end
%     end
% end
% 
% % % =====================================================================
% % % Slider anpassen – validBinIdxs aktualisieren
% % % =====================================================================
% % dc        = h.dataXcorr{valueSlider};
% % validIdxs = find(~cellfun(@isempty, dc));
% % nValid    = numel(validIdxs);
% % h.validBinIdxs{valueSlider} = validIdxs;
% % 
% % if nValid < 1
% %     set(h.SliderFittedPeaks, 'Min', 1, 'Max', 2, 'Value', 1, 'SliderStep', [1 1]);
% %     h.axes.YLimMode = 'manual';
% %     h.axes.YLim     = ylimTarget;
% %     drawnow;
% %     guidata(hObj, h);
% %     return
% % end
% % 
% % set(h.SliderFittedPeaks, ...
% %     'Min',        1, ...
% %     'Max',        max(nValid, 2), ...
% %     'Value',      1, ...
% %     'SliderStep', [1/max(nValid-1,1)  1/max(nValid-1,1)]);
% % 
% % % =====================================================================
% % % Peak-Fit-Plot aktualisieren (zeichnet auf h.axesFittedPeaks, nicht h.axes)
% % % =====================================================================
% % % firstAbsBin = validIdxs(1);
% % % h = updateFittedPeakPlot(h, valueSlider, firstAbsBin);
% % % =====================================================================
% % % Peak-Fit-Plot aktualisieren
% % % Ersten gültigen Bin über γ-Mapping bestimmen
% % % =====================================================================
% % firstBinIdx = validIdxs(1);   % Index in dataXcorr (Fallback)
% % 
% % if isfield(h,'FitDataMod') && numel(h.FitDataMod) >= valueSlider && ...
% %    isfield(h,'BinnedGamma') && ~isempty(h.BinnedGamma)
% %     pv_vs = h.FitDataMod{valueSlider};
% %     yCol_vs = 2;
% %     if size(pv_vs,2) >= 9 && any(isfinite(pv_vs(:,9)))
% %         yCol_vs = 9;
% %     end
% %     firstValidRow = find(isfinite(pv_vs(:,yCol_vs)), 1, 'first');
% %     if ~isempty(firstValidRow)
% %         gammaFirst  = pv_vs(firstValidRow, 1);
% %         safeIdxVS   = max(1, min(valueSlider, numel(h.BinnedGamma)));
% %         [~, firstBinIdx] = min(abs(h.BinnedGamma{safeIdxVS} - gammaFirst));
% %     end
% % end
% % 
% % h = updateFittedPeakPlot(h, valueSlider, firstBinIdx);
% 
% % =====================================================================
% % Slider anpassen – validBinIdxs aktualisieren
% % =====================================================================
% 
% % dataXcorr-Index: bei mehreren Bildern unter gleichem Alpha kann
% % valueSlider > numel(dataXcorr) sein → auf gültigen Index begrenzen
% nXcorr     = numel(h.dataXcorr);
% safeSlider = max(1, min(valueSlider, nXcorr));
% 
% dc        = h.dataXcorr{safeSlider};
% validIdxs = find(~cellfun(@isempty, dc));
% nValid    = numel(validIdxs);
% h.validBinIdxs{valueSlider} = validIdxs;
% 
% if nValid < 1
%     set(h.SliderFittedPeaks, 'Min', 1, 'Max', 2, 'Value', 1, 'SliderStep', [1 1]);
%     h.axes.YLimMode = 'manual';
%     h.axes.YLim     = ylimTarget;
%     drawnow;
%     guidata(hObj, h);
%     return
% end
% 
% set(h.SliderFittedPeaks, ...
%     'Min',        1, ...
%     'Max',        max(nValid, 2), ...
%     'Value',      1, ...
%     'SliderStep', [1/max(nValid-1,1)  1/max(nValid-1,1)]);
% 
% % =====================================================================
% % Peak-Fit-Plot aktualisieren
% % =====================================================================
% firstBinIdx = validIdxs(1);
% 
% if isfield(h,'FitDataMod') && numel(h.FitDataMod) >= valueSlider && ...
%    isfield(h,'BinnedGamma') && ~isempty(h.BinnedGamma)
%     pv_vs = h.FitDataMod{valueSlider};
%     yCol_vs = 2;
%     if size(pv_vs,2) >= 9 && any(isfinite(pv_vs(:,9)) & pv_vs(:,9) > 1.0)
%         yCol_vs = 9;
%     end
%     firstValidRow = find(isfinite(pv_vs(:,yCol_vs)) & pv_vs(:,yCol_vs) > 1.0, 1, 'first');
%     if ~isempty(firstValidRow)
%         gammaFirst = pv_vs(firstValidRow, 1);
%         % BinnedGamma ebenfalls auf gültigen Index begrenzen
%         safeIdxBG  = max(1, min(valueSlider, numel(h.BinnedGamma)));
%         [~, firstBinIdx] = min(abs(h.BinnedGamma{safeIdxBG} - gammaFirst));
%     end
% end
% 
% % updateFittedPeakPlot mit safeSlider aufrufen
% h = updateFittedPeakPlot(h, safeSlider, firstBinIdx);
% 
% % highlightpeakdata ausblenden — Y-Skala von h.axes ist 2θ,
% % highlight würde bei falschem Y-Wert landen
% if isfield(h,'highlightpeakdata') && isvalid(h.highlightpeakdata)
%     set(h.highlightpeakdata, 'Visible', 'off');
% end
% 
% % =====================================================================
% % YLim NACH updateFittedPeakPlot setzen mit YLimMode='manual'
% % → verhindert dass MATLAB nach drawnow automatisch neu skaliert
% % =====================================================================
% h.axes.YLimMode = 'manual';
% h.axes.YLim     = ylimTarget;
% drawnow;
% 
% guidata(hObj, h);

function moddatacallback(hObj, ~)
h = guidata(hObj);

valueSlider            = round(get(h.Slider,            'Value'));
valueSliderFittedPeaks = round(get(h.SliderFittedPeaks, 'Value'));

% =====================================================================
% Undo-State sichern
% =====================================================================
h.undoState.FitDataMod         = h.FitDataMod;
h.undoState.FitDataModCentroid = h.FitDataModCentroid;
h.undoState.fitresultexport    = h.fitresultexport;
h.undoState.dataXcorr          = h.dataXcorr;
h.undoState.dataYcorr          = h.dataYcorr;
h.undoState.fitMethodUsed      = h.fitMethodUsed;
h.undoState.dataCentroidMu     = h.dataCentroidMu;
h.undoState.dataGaussFit       = h.dataGaussFit;
h.undoState.dataPVFitY         = h.dataPVFitY;
h.undoState.dataPVSuccess      = h.dataPVSuccess;
if isfield(h, 'dataPVFitMat')
    h.undoState.dataPVFitMat   = h.dataPVFitMat;
end
if isfield(h, 'datacentFitMat')
    h.undoState.datacentFitMat = h.datacentFitMat;
end
if isfield(h, 'validBinIdxs')
    h.undoState.validBinIdxs   = h.validBinIdxs;
end
h.undoState.valueSlider = valueSlider;

if isfield(h, 'UndoStressButton') && isvalid(h.UndoStressButton)
    set(h.UndoStressButton, 'Enable', 'on');
end

% =====================================================================
% YLim VOR Lasso aus aktuell gültigen Daten berechnen
% =====================================================================
pvPre = h.FitDataMod{valueSlider};
[yColPre, yErrColPre, idxPre] = getPlausibleCol(pvPre);

if any(idxPre)
    yLowPre  = pvPre(idxPre, yColPre) - abs(pvPre(idxPre, yErrColPre));
    yHighPre = pvPre(idxPre, yColPre) + abs(pvPre(idxPre, yErrColPre));
    yLowPre  = yLowPre(isfinite(yLowPre));
    yHighPre = yHighPre(isfinite(yHighPre));
    if ~isempty(yLowPre) && ~isempty(yHighPre)
        rangePre = max(max(yHighPre) - min(yLowPre), 0.02);
        ylimBeforeEdit = [min(yLowPre)  - rangePre*0.20, ...
                          max(yHighPre) + rangePre*0.20];
    else
        ylimBeforeEdit = h.axes.YLim;
    end
else
    ylimBeforeEdit = h.axes.YLim;
end

% =====================================================================
% Highlight und xlines VOR Lasso ausblenden
% =====================================================================
for fn = {'highlightpeakdata','highlightstressplot','plotdataCentFit'}
    if isfield(h, fn{1}) && isvalid(h.(fn{1}))
        set(h.(fn{1}), 'Visible', 'off');
    end
end
delete(findobj(h.axes, 'Tag', 'invalidgamma'));

% =====================================================================
% plotdata für Lasso-Selektion setzen (nur plausible Punkte)
% =====================================================================
dataForPlot = h.FitDataMod{valueSlider};
[yColP, yErrColP, idxPlot] = getPlausibleCol(dataForPlot);

if any(idxPlot)
    set(h.plotdata, ...
        'XData',          dataForPlot(idxPlot, 1), ...
        'YData',          dataForPlot(idxPlot, yColP), ...
        'YNegativeDelta', abs(dataForPlot(idxPlot, yErrColP)), ...
        'YPositiveDelta', abs(dataForPlot(idxPlot, yErrColP)), ...
        'Visible', 'on');
else
    set(h.plotdata, 'XData', NaN, 'YData', NaN, ...
        'YNegativeDelta', NaN, 'YPositiveDelta', NaN, 'Visible', 'off');
end

xData = dataForPlot(isfinite(dataForPlot(:,1)), 1);
if ~isempty(xData)
    xMin = min(xData); xMax = max(xData);
    if isfinite(xMin) && isfinite(xMax)
        h.axes.XLim = [xMin-5, xMax+5];
    end
end

% YLim vor Lasso explizit setzen
h.axes.YLimMode = 'manual';
h.axes.YLim     = ylimBeforeEdit;
drawnow;

% =====================================================================
% Punkte per Lasso auswählen
% =====================================================================
pointslist = selectStressPoints(h.axes, h.plotdata);

if isempty(pointslist)
    guidata(hObj, h);
    return
end

% pointslist bezieht sich auf idxPlot-Indizes → auf FitDataMod-Zeilen mappen
allRows    = find(idxPlot);
if max(pointslist) > numel(allRows)
    pointslist = pointslist(pointslist <= numel(allRows));
end
mappedRows = allRows(pointslist);

if isempty(mappedRows)
    guidata(hObj, h);
    return
end

% =====================================================================
% Datenpunkte NaN setzen (Zeilen bleiben erhalten)
% =====================================================================
nColsFDM = size(h.FitDataMod{valueSlider}, 2);
h.FitDataMod{valueSlider}(mappedRows, 2:3) = NaN;
if nColsFDM >= 10
    h.FitDataMod{valueSlider}(mappedRows, 9:10)  = NaN;
end
if nColsFDM >= 12
    h.FitDataMod{valueSlider}(mappedRows, 11:12) = NaN;
end

if isfield(h,'dataPVFitMat') && numel(h.dataPVFitMat) >= valueSlider && ...
   ~isempty(h.dataPVFitMat{valueSlider}) && ...
   size(h.dataPVFitMat{valueSlider},1) >= max(mappedRows)
    h.dataPVFitMat{valueSlider}(mappedRows, 2:3) = NaN;
end
if isfield(h,'datacentFitMat') && numel(h.datacentFitMat) >= valueSlider && ...
   ~isempty(h.datacentFitMat{valueSlider}) && ...
   size(h.datacentFitMat{valueSlider},1) >= max(mappedRows)
    h.datacentFitMat{valueSlider}(mappedRows, 2:3) = NaN;
    if size(h.datacentFitMat{valueSlider},2) >= 12
        h.datacentFitMat{valueSlider}(mappedRows, 11:12) = NaN;
    end
end
if isfield(h,'FitDataModCentroid') && numel(h.FitDataModCentroid) >= valueSlider && ...
   ~isempty(h.FitDataModCentroid{valueSlider}) && ...
   size(h.FitDataModCentroid{valueSlider},1) >= max(mappedRows)
    h.FitDataModCentroid{valueSlider}(mappedRows, 2:3) = NaN;
end

% dataXcorr / dataYcorr / fitresultexport / dataPVFitY / datacentFitParams
% → Länge prüfen, nur gültige Indizes verwenden
nXcorr = numel(h.dataXcorr);
safeSlider = max(1, min(valueSlider, nXcorr));

for cellField = {'dataXcorr','dataYcorr','fitresultexport','dataPVFitY','datacentFitParams'}
    fn = cellField{1};
    if isfield(h, fn) && numel(h.(fn)) >= safeSlider && ...
       ~isempty(h.(fn){safeSlider})
        nArr       = numel(h.(fn){safeSlider});
        validIdxDel = mappedRows(mappedRows <= nArr);
        if ~isempty(validIdxDel)
            h.(fn){safeSlider}(validIdxDel) = {[]};
        end
    end
end

% =====================================================================
% Plot aktualisieren + ylimTarget berechnen
% =====================================================================
pv = h.FitDataMod{valueSlider};
[yCol, yErrCol, idxFinY] = getPlausibleCol(pv);

if any(idxFinY)
    set(h.plotdata, ...
        'XData',          pv(idxFinY, 1), ...
        'YData',          pv(idxFinY, yCol), ...
        'YNegativeDelta', abs(pv(idxFinY, yErrCol)), ...
        'YPositiveDelta', abs(pv(idxFinY, yErrCol)), ...
        'Visible', 'on');

    yLow   = pv(idxFinY, yCol) - abs(pv(idxFinY, yErrCol));
    yHigh  = pv(idxFinY, yCol) + abs(pv(idxFinY, yErrCol));
    yLow   = yLow(isfinite(yLow));
    yHigh  = yHigh(isfinite(yHigh));
    if ~isempty(yLow) && ~isempty(yHigh)
        yRange     = max(max(yHigh) - min(yLow), 0.02);
        ylimTarget = [min(yLow) - yRange*0.20, max(yHigh) + yRange*0.20];
    else
        ylimTarget = ylimBeforeEdit;
    end
else
    set(h.plotdata, 'XData', NaN, 'YData', NaN, ...
        'YNegativeDelta', NaN, 'YPositiveDelta', NaN, 'Visible', 'off');
    for fn = {'fitcurvestress','plotdataCentFit'}
        if isfield(h, fn{1}) && isvalid(h.(fn{1}))
            set(h.(fn{1}), 'Visible', 'off');
        end
    end
    ylimTarget = ylimBeforeEdit;
end

% fitCentroid aktualisieren
if isfield(h,'datacentFitMat') && numel(h.datacentFitMat) >= valueSlider
    cf       = h.datacentFitMat{valueSlider};
    idxCF    = isfinite(cf(:,2));
    showCent = isfield(h,'cb_showCentroid') && get(h.cb_showCentroid,'Value') == 1;
    if isfield(h,'plotdataCentFit') && isvalid(h.plotdataCentFit)
        if any(idxCF) && showCent
            set(h.plotdataCentFit, ...
                'XData',          cf(idxCF,1), ...
                'YData',          cf(idxCF,2), ...
                'YNegativeDelta', cf(idxCF,3), ...
                'YPositiveDelta', cf(idxCF,3), ...
                'Visible', 'on');
        else
            set(h.plotdataCentFit, 'Visible', 'off');
        end
    end
end

% =====================================================================
% Slider anpassen – validBinIdxs aktualisieren
% =====================================================================
dc        = h.dataXcorr{safeSlider};
validIdxs = find(~cellfun(@isempty, dc));
nValid    = numel(validIdxs);
h.validBinIdxs{valueSlider} = validIdxs;

if nValid < 1
    set(h.SliderFittedPeaks, 'Min', 1, 'Max', 2, 'Value', 1, 'SliderStep', [1 1]);
    h.axes.YLimMode = 'manual';
    h.axes.YLim     = ylimTarget;
    drawnow;
    guidata(hObj, h);
    return
end

set(h.SliderFittedPeaks, ...
    'Min',        1, ...
    'Max',        max(nValid, 2), ...
    'Value',      1, ...
    'SliderStep', [1/max(nValid-1,1)  1/max(nValid-1,1)]);

% =====================================================================
% Peak-Fit-Plot aktualisieren
% =====================================================================
firstBinIdx = validIdxs(1);   % Fallback

if isfield(h,'FitDataMod') && numel(h.FitDataMod) >= valueSlider
    pv_vs = h.FitDataMod{valueSlider};
    [~, ~, idxVS] = getPlausibleCol(pv_vs);
    firstValidRow = find(idxVS, 1, 'first');
    if ~isempty(firstValidRow)
        firstBinIdx = max(1, min(firstValidRow, ...
                          numel(h.dataXcorr{safeSlider})));
    end
end

h = updateFittedPeakPlot(h, safeSlider, firstBinIdx);

% highlightpeakdata ausgeblendet lassen
if isfield(h,'highlightpeakdata') && isvalid(h.highlightpeakdata)
    set(h.highlightpeakdata, 'Visible', 'off');
end

% =====================================================================
% YLim final setzen — zweimal um MATLAB-Autoscaling zu verhindern
% =====================================================================
h = markInvalidGammaRegions(h, valueSlider);

h.axes.YLimMode = 'manual';
h.axes.YLim     = ylimTarget;
drawnow;
h.axes.YLimMode = 'manual';
h.axes.YLim     = ylimTarget;

% ── Tau-Plot aktualisieren ────────────────────────────────────────────
if isfield(h,'tau') && numel(h.tau) >= valueSlider && ...
   ~isempty(h.tau{valueSlider})
    tauVec = h.tau{valueSlider}(:);
    pv_tau = h.FitDataMod{valueSlider};
    [~, ~, idxTauV] = getPlausibleCol(pv_tau);
    xVec = pv_tau(idxTauV, 1);
    if numel(tauVec) == numel(xVec)
        tauMin   = min(tauVec);
        tauMax   = max(tauVec);
        tauRange = max(tauMax - tauMin, 0.1);
        set(h.plottaudata,    'XData', xVec, 'YData', tauVec);
        set(h.plottaudatamean,'XData', xVec, ...
            'YData', repelem(mean(tauVec(isfinite(tauVec))), numel(xVec)));
        h.axesPlottauData.XLim = h.axes.XLim;
        h.axesPlottauData.YLim = [tauMin - tauRange*0.15, ...
                                   tauMax + tauRange*0.15];
    end
end

guidata(hObj, h);

function exportfitdatacallback(hObj, ~)
h = guidata(hObj);

% Export stress reuslts in form of table
[FileName, PathName] = uiputfile('.txt','Save Fit data to file',[General.ProgramInfo.Path,'\Data\Results\Pilatus-2DXRD\']);

col = get(hObj,'backg');  % Get the background color of the figure.
set(hObj,'String','Exporting data ...','backg',[1 .6 .6]) % Change color of button. 
% The pause (or drawnow) is necessary to make button changes appear.
pause(.01)

PathNameExport = fullfile([PathName,['Bins_',num2str(h.BinSize)],'\']);

if exist(PathNameExport,'dir') ~= 7
    mkdir(PathNameExport);
end

if isequal(FileName, 0) || isequal(PathName, 0)
    disp('User canceled the save operation.')
else
    for k = 1:size(h.FitDataMod,1)
        FileNameExport = [FileName(1:end-4),'_Peak_',num2str(k),'.txt'];
        fullPath = fullfile(PathNameExport, FileNameExport);
    
        try
            fileID = fopen(fullPath, 'w');
            if fileID == -1
                error('Datei konnte nicht geöffnet werden: %s', fullPath);
            end
            fprintf(fileID,'%5s\t %7s\t %11s\t %9s\t %5s\t %5s\t %5s\t %10s\t \r\n',...
                'Gamma','2theta','2theta_err','Amplitude','FWHM','Eta','alpha','Peak count');
            fclose(fileID);
        catch ME
            if fileID ~= -1
                fclose(fileID);
            end
            errordlg(sprintf('Export fehlgeschlagen:\n%s', ME.message), 'Exportfehler');
            set(hObj, 'String', 'Export Fit Data', 'backg', col);
            return
        end
    
        writematrix(h.FitDataMod{k}, fullPath, 'Delimiter', 'tab', 'WriteMode', 'append');
    end
end

FileNameGraph = [FileName(1:end-4),'_Peak_',num2str(k)];

% Export fit of epsilon data (2theta vs gamma)
for k = 1:size(h.FitDataMod,1)

    pv_k    = h.FitDataMod{k};
    [~,~,idxFinK] = getPlausibleCol(pv_k);

    if ~any(idxFinK)
        fprintf('Peak %d: keine finiten 2θ-Werte — übersprungen\n', k);
        continue
    end

    figure
    fig = gcf;
    fig.PaperUnits = 'centimeters';
    fig.PaperPositionMode = 'manual';
    fig.PaperPosition = [0 0 18 12];
    ax = gca;
    ax.OuterPosition = [0 0 1.085 1.025];
    ax.TickDir = 'out';
    ax.YAxis.TickLabelFormat = '%,.4f';
    ax.Box = 'on';
    ax.XGrid = 'on';
    ax.YGrid = 'on';
    ax.GridLineStyle = '-';
    ax.GridColor = 'k';
    ax.GridAlpha = 0.3;
    ax.YLabel.String = ['2',char(952),' [°]'];
    ax.YLabel.FontSize = 12;
    ax.XLabel.String = [char(947),' [°]'];
    ax.XLabel.FontSize = 12;
    ax.LabelFontSizeMultiplier = 1;
    ax.LineWidth = 1.3;
    set(gca, 'FontSize', 12)
    hold on
    set(fig, 'Visible', 'off');

    % Datenpunkte
    errorbar(pv_k(idxFinK,1), pv_k(idxFinK,2), ...
        abs(pv_k(idxFinK,3)), 's', ...
        'MarkerSize', 5, ...
        'Color',          [0.094 0.373 0.647], ...
        'MarkerFaceColor',[0.094 0.373 0.647]);

    % XLim dynamisch
    x_min = min(pv_k(idxFinK,1));
    x_max = max(pv_k(idxFinK,1));
    x_margin = max(5, (x_max-x_min)*0.05);
    xlim([x_min-x_margin, x_max+x_margin]);

    % Tick-Schrittweite
    x_range = x_max - x_min;
    if x_range <= 30
        xticks(floor(x_min-x_margin):5:ceil(x_max+x_margin));
    elseif x_range <= 90
        xticks(floor(x_min-x_margin):10:ceil(x_max+x_margin));
    else
        xticks(floor(x_min-x_margin):20:ceil(x_max+x_margin));
    end

    % YLim
    y_min   = min(pv_k(idxFinK,2) - abs(pv_k(idxFinK,3)));
    y_max   = max(pv_k(idxFinK,2) + abs(pv_k(idxFinK,3)));
    y_range = max(y_max - y_min, 1e-4);
    margin  = 0.20 * y_range;

    yLimLow  = y_min - margin;
    yLimHigh = y_max + margin;

    if isfinite(yLimLow) && isfinite(yLimHigh) && yLimLow < yLimHigh
        ylim([yLimLow, yLimHigh]);
    else
        ylim('auto');
    end

    % Alpha-Wert
    if isfield(h,'alphaexport') && numel(h.alphaexport) >= k
        alphaVal = h.alphaexport(k);
    else
        alphaVal = h.DEKdataMatchedPeaks(k,7);
    end

    LegLabeldata = sprintf('%s  \\alpha=%.1f°', ...
        num2str(h.DEKdataMatchedPeaks(k,1:3)), alphaVal);

    l = legend(LegLabeldata);
    l.FontSize = 10;
    l.LineWidth = 0.5;
    l.Location = 'best';

    FileName1 = sprintf([strrep(h.FileNameLoad{1}(1:end-4),' ',''), '_', ...
        FileName(1:end-4), '_2thetafit_Peak_%d'], k);

    print(fig, [PathNameExport, FileName1], '-vector', '-dtiff', '-r300')
    close(fig);
end



% Reset the button color
set(hObj,'String','Export Fit Data','backg',col)  % Now reset the button features.

guidata(hObj, h);

function exportstressdatacallback(hObj, ~)
h = guidata(hObj);

spannkomp = str2double(get(h.SpannKompEditField, "String"));

if spannkomp == 1122
    StressResults = [h.taumean h.sigmaFinal(:,1) h.sigmaerrFinal(:,1) h.sigmaFinal(:,2) h.sigmaerrFinal(:,2) h.sigmasin2psiFinal h.deltasigmasin2psiFinal h.alphaexport];
elseif spannkomp == 112213
    StressResults = [h.taumean h.sigmaFinal(:,1) h.sigmaerrFinal(:,1) h.sigmaFinal(:,2) h.sigmaerrFinal(:,2) h.sigmaFinal(:,3) h.sigmaerrFinal(:,3) h.sigmasin2psiFinal h.deltasigmasin2psiFinal h.alphaexport];
end

% Export stress reuslts in form of table
[FileName, PathName] = uiputfile('*.txt','Save Stress data to file',[General.ProgramInfo.Path,'\Data\Results\Pilatus-2DXRD\']);

col = get(hObj,'backg');  % Get the background color of the figure.
set(hObj,'String','Exporting data ...','backg',[1 .6 .6]) % Change color of button. 
% The pause (or drawnow) is necessary to make button changes appear.
pause(.01)

PathNameExport = fullfile([PathName,['Bins_',num2str(h.BinSize)],'\']);

if exist(PathNameExport,'dir') ~= 7
    mkdir(PathNameExport);
end

if isequal(FileName, 0) || isequal(PathName, 0)
    disp('User canceled the save operation.')
else
    % Open the file for writing
    % fileID = fopen(fullfile([PathNameExport, FileName]), 'w');

    % NEU:
    try
        fileID = fopen(fullfile(PathNameExport, FileName), 'w');
        if fileID == -1
            error('Datei konnte nicht geöffnet werden: %s', fullfile(PathNameExport, FileName));
        end
        % Write the header
        if spannkomp == 1122
            fprintf(fileID,'%3s\t %7s\t %11s\t %7s\t %11s\t %15s\t %19s\t %5s\t %5s\t %5s\t %5s \r\n','tau','sigma11','sigma11_Err','sigma22','sigma22_Err','sigma11_sin2psi','sigma11_sin2psi_Err','alpha','h','k','l');
        elseif spannkomp == 112213
            fprintf(fileID,'%3s\t %7s\t %11s\t %7s\t %11s\t %7s\t %11s\t %15s\t %19s\t %5s \t %5s\t %5s\t %5s\r\n','tau','sigma11','sigma11_Err','sigma22','sigma22_Err','sigma13','sigma13_Err','sigma11_sin2psi','sigma11_sin2psi_Err','alpha','h','k','l');
        end
        fclose(fileID);
    catch ME
        if fileID ~= -1
            fclose(fileID);  % Datei auf jeden Fall schließen
        end
        errordlg(sprintf('Export fehlgeschlagen:\n%s', ME.message), 'Exportfehler');
        set(hObj, 'String', 'Export Fit Data', 'backg', col);
        return
    end
    
    if spannkomp == 1122
        writematrix([round(StressResults(:,1),4) round(StressResults(:,[2:7]),0) StressResults(:,8) h.DEKdataMatchedPeaks(:,1:3)],fullfile([PathNameExport, FileName]),'Delimiter','tab', 'WriteMode', 'append')
    elseif spannkomp == 112213
        writematrix([round(StressResults(:,1),4) round(StressResults(:,[2:9]),0) StressResults(:,10) h.DEKdataMatchedPeaks(:,1:3)],fullfile([PathNameExport, FileName]),'Delimiter','tab', 'WriteMode', 'append')
    end
end

assignin('base','sin2psiData',h.epssin2psifitdaten)
assignin('base','sin2psiRegressData',h.sin2psiregres)
assignin('base','SFFitData',h.epsfitdataexport)
assignin('base','SFFitRegressData',h.epsgammaergfunc)

h.FileNameLoad{1} = strrep(h.FileNameLoad{1},'.','-');

% Export fit of epsilon data
for k = 1:size(h.epsfitdataexport,2)

    % Daten prüfen
    if ~isfield(h,'epsfitdataexport') || numel(h.epsfitdataexport) < k || ...
       isempty(h.epsfitdataexport{k})
        fprintf('Peak %d: keine ε-Daten — übersprungen\n', k);
        continue
    end

    eps_k   = h.epsfitdataexport{k};
    idxFinK = isfinite(eps_k(:,2)) & isfinite(eps_k(:,3));

    if ~any(idxFinK)
        fprintf('Peak %d: keine finiten ε-Werte — übersprungen\n', k);
        continue
    end

    figure
    fig = gcf;
    fig.PaperUnits = 'centimeters';
    fig.PaperPositionMode = 'manual';
    fig.PaperPosition = [0 0 18 12];
    ax = gca;
    ax.OuterPosition = [0 0 1.085 1.025];
    ax.TickDir = 'out';
    ax.YAxis.TickLabelFormat = '%,.4f';
    ax.Box = 'on';
    ax.XGrid = 'on';
    ax.YGrid = 'on';
    ax.GridLineStyle = '-';
    ax.GridColor = 'k';
    ax.GridAlpha = 0.3;
    ax.YLabel.String = [char(949),'(',char(947),')'];
    ax.YLabel.FontSize = 12;
    ax.XLabel.String = [char(947),' [°]'];
    ax.XLabel.FontSize = 12;
    ax.LabelFontSizeMultiplier = 1;
    ax.LineWidth = 1.3;
    set(gca, 'FontSize', 12)
    hold on
    set(fig, 'Visible', 'off');

    % Datenpunkte
    errorbar(eps_k(idxFinK,1), eps_k(idxFinK,2), ...
        abs(eps_k(idxFinK,3)), 's', ...
        'MarkerSize', 5, ...
        'Color',          [0.094 0.373 0.647], ...
        'MarkerFaceColor',[0.094 0.373 0.647]);

    % Fit-Kurve
    if isfield(h,'epsgammaergfunc_x') && numel(h.epsgammaergfunc_x) >= k && ...
       ~isempty(h.epsgammaergfunc_x{k}) && ...
       numel(h.epsgammaergfunc_x{k}) == numel(h.epsgammaergfunc{k})
        plot(h.epsgammaergfunc_x{k}(:), h.epsgammaergfunc{k}(:), '-', ...
            'Color', [0.85 0.33 0.10], 'LineWidth', 1.5);
    else
        ergVec = h.epsgammaergfunc{k}(:);
        if numel(ergVec) == size(eps_k,1)
            plot(eps_k(:,1), ergVec, '-', ...
                'Color', [0.85 0.33 0.10], 'LineWidth', 1.5);
        end
    end

    % XLim dynamisch aus Daten
    x_min = min(eps_k(idxFinK,1));
    x_max = max(eps_k(idxFinK,1));
    x_margin = max(5, (x_max-x_min)*0.05);
    xlim([x_min-x_margin, x_max+x_margin]);

    % Tick-Schrittweite anpassen
    x_range = x_max - x_min;
    if x_range <= 30
        xticks(floor(x_min-x_margin):5:ceil(x_max+x_margin));
    elseif x_range <= 90
        xticks(floor(x_min-x_margin):10:ceil(x_max+x_margin));
    else
        xticks(floor(x_min-x_margin):20:ceil(x_max+x_margin));
    end

    % YLim
    y_min   = min(eps_k(idxFinK,2) - abs(eps_k(idxFinK,3)));
    y_max   = max(eps_k(idxFinK,2) + abs(eps_k(idxFinK,3)));
    y_range = max(y_max - y_min, 1e-6);
    margin  = 0.10 * y_range;

    yLimLow  = y_min - margin;
    yLimHigh = y_max + margin;

    if isfinite(yLimLow) && isfinite(yLimHigh) && yLimLow < yLimHigh
        ylim([yLimLow, yLimHigh]);
    else
        ylim('auto');
    end

    % Alpha-Wert
    if isfield(h,'alphaexport') && numel(h.alphaexport) >= k
        alphaVal = h.alphaexport(k);
    else
        alphaVal = h.DEKdataMatchedPeaks(k,7);
    end

    LegLabeldata = sprintf('%s  \\alpha=%.1f°', ...
        num2str(h.DEKdataMatchedPeaks(k,1:3)), alphaVal);

    l = legend(LegLabeldata);
    l.FontSize = 10;
    l.LineWidth = 0.5;
    l.Location = 'best';

    FileName1 = sprintf([strrep(h.FileNameLoad{1}(1:end-4),' ',''), '_', ...
        FileName(1:end-4), '_epsilonfit_Line_%d'], k);

    print(fig, [PathNameExport, FileName1], '-vector', '-dtiff', '-r300')
    close(fig);
end

% Export fit of sin2psi data
for k = 1:size(h.epsfitdataexport,2)
    figure
    fig = gcf;
    fig.PaperUnits = 'centimeters';
    fig.PaperPositionMode = 'manual';
    fig.PaperPosition = [0 0 18 12];
    ax = gca;
    ax.OuterPosition = [0 0 1.085 1.025];
    ax.TickDir = 'out';
    ax.YAxis.TickLabelFormat = '%,.4f';
    ax.Box = 'on';
    ax.XGrid = 'on';
    ax.YGrid = 'on';
    ax.GridLineStyle = '-';
    ax.GridColor = 'k';
    ax.GridAlpha = 0.3;
    ax.YLabel.String = [char(949),'(', char(947), ')'];
    ax.YLabel.FontSize = 12;
    ax.XLabel.String = ['sin²', char(968)];
    ax.XLabel.FontSize = 12;
    ax.XLim = [0 1];
    ax.LabelFontSizeMultiplier = 1;
    ax.LineWidth = 1.3;
    set(gca, 'FontSize', 12)
    hold on
    set(fig, 'Visible', 'off');

    % sin²ψ-Daten prüfen
    if ~isfield(h,'epssin2psifitdaten') || numel(h.epssin2psifitdaten) < k || ...
       isempty(h.epssin2psifitdaten{k})
        fprintf('Peak %d: keine sin²ψ-Daten — übersprungen\n', k);
        close(fig);
        continue
    end

    s2p_k   = h.epssin2psifitdaten{k};
    idxFinK = isfinite(s2p_k(:,1)) & isfinite(s2p_k(:,2));

    if ~any(idxFinK)
        fprintf('Peak %d: keine finiten sin²ψ-Werte — übersprungen\n', k);
        close(fig);
        continue
    end

    % Datenpunkte: sin²ψ vs ε
    errorbar(s2p_k(idxFinK,1), s2p_k(idxFinK,2), ...
        abs(s2p_k(idxFinK,3)), 's', ...
        'MarkerSize', 5, ...
        'Color', [0.094 0.373 0.647], ...
        'MarkerFaceColor', [0.094 0.373 0.647]);

    % Regressionsgerade
    if isfield(h,'sin2psiregres') && numel(h.sin2psiregres) >= k && ...
       ~isempty(h.sin2psiregres{k}) && numel(h.sin2psiregres{k}) == 21
        plot(0:0.05:1, h.sin2psiregres{k}, '-', ...
            'Color', [0.85 0.33 0.10], 'LineWidth', 1.5);
    end

    % YLim
    y_min   = min(s2p_k(idxFinK,2) - abs(s2p_k(idxFinK,3)));
    y_max   = max(s2p_k(idxFinK,2) + abs(s2p_k(idxFinK,3)));
    y_range = max(y_max - y_min, 1e-6);
    margin  = 0.10 * y_range;

    yLimLow  = y_min - margin;
    yLimHigh = y_max + margin;

    if isfinite(yLimLow) && isfinite(yLimHigh) && yLimLow < yLimHigh
        ylim([yLimLow, yLimHigh]);
    else
        ylim('auto');
    end

    % Alpha-Wert
    if isfield(h,'alphaexport') && numel(h.alphaexport) >= k
        alphaVal = h.alphaexport(k);
    else
        alphaVal = h.DEKdataMatchedPeaks(k,7);
    end

    % σ_sin²ψ in Legende
    if isfield(h,'sigmasin2psiFinal') && numel(h.sigmasin2psiFinal) >= k
        sigVal = h.sigmasin2psiFinal(k);
        LegLabeldata = sprintf('%s  \\alpha=%.1f°  \\sigma=%.0f MPa', ...
            num2str(h.DEKdataMatchedPeaks(k,1:3)), alphaVal, sigVal);
    else
        LegLabeldata = sprintf('%s  \\alpha=%.1f°', ...
            num2str(h.DEKdataMatchedPeaks(k,1:3)), alphaVal);
    end

    l = legend(LegLabeldata);
    l.FontSize = 10;
    l.LineWidth = 0.5;
    l.Location = 'best';

    FileName1 = sprintf([strrep(h.FileNameLoad{1}(1:end-4),' ',''), '_', ...
        FileName(1:end-4), '_sin2psifit_Line_%d'], k);

    print(fig, [PathNameExport, FileName1], '-vector', '-dtiff', '-r300')
    close(fig);
end

% Export plot of stress data
figure
fig = gcf;
fig.PaperUnits = 'centimeters';
fig.PaperPositionMode = 'manual';
fig.PaperPosition = [0 0 18 12];
ax = gca;
ax.OuterPosition = [0 0 1.085 1.025];
ax.TickDir = 'out';
ax.YAxis.TickLabelFormat = '%.0f';
ax.Box = 'on';
ax.XGrid = 'on';
ax.YGrid = 'on';
ax.GridLineStyle = '-';
ax.GridColor = 'k';
ax.GridAlpha = 0.3;
ax.YLabel.String = [char(963),' [MPa]'];
ax.YLabel.FontSize = 12;
ax.XLabel.String = [char(964),' [',char(956),'m]'];
ax.XLabel.FontSize = 12;

ax.XLim = [0 5];
% ax.YLim = [-Inf,Inf];

ax.LabelFontSizeMultiplier = 1;
ax.LineWidth = 1.3;
set(gca,'FontSize',12)
hold on
set(fig, 'Visible', 'off');

errorbar(h.taumean,h.sigmaFinal(:,1),h.sigmaerrFinal(:,1),'s');
errorbar(h.taumean,h.sigmasin2psiFinal,h.deltasigmasin2psiFinal,'o');

% --- Berechnung der Y-Grenzen ---
y_min = min(h.sigmaFinal(:,1) - h.sigmaerrFinal(:,1));
y_max = max(h.sigmaFinal(:,1) + h.sigmaerrFinal(:,1));

% Wertebereich bestimmen
range = y_max - y_min;

% --- Schrittweite automatisch bestimmen ---
% (Wenn Daten klein sind → 10er; mittel → 100er; groß → 1000er etc.)
if range < 100
    step = 10;
elseif range < 1000
    step = 100;
else
    step = 1000;
end

% --- Grenzen runden ---
y_lower = floor(y_min / step) * step;  % nach unten abrunden
y_upper = ceil(y_max / step) * step;   % nach oben aufrunden

% --- Neue Grenzen setzen ---
ylim([y_lower, y_upper]);


% --- Dynamische X-Achsenobergrenze ---
x_max_val = max(h.taumean);  % größter X-Wert

% Hier wird geprüft, in welchem Intervall x_max_val liegt:
if x_max_val <= 5
    x_upper = 5;
elseif x_max_val <= 10
    x_upper = 10;
elseif x_max_val <= 15
    x_upper = 15;
elseif x_max_val <= 20
    x_upper = 20;
elseif x_max_val <= 30
    x_upper = 30;
elseif x_max_val <= 50
    x_upper = 50;
else
    % falls größer, auf das nächste Vielfache von 10 runden
    x_upper = ceil(x_max_val/10)*10;
end

% Untere Grenze automatisch vom Minimum abhängig machen (optional)
% x_lower = min(x);
xlim([0, x_upper]);

LegLabeldata = {'Stressfactor-method','sin²psi-method'};
% Create legend
l = legend(LegLabeldata);
l.Location = 'northwest';

l.FontSize = 10;
l.LineWidth = 0.5;

FileName1 = sprintf([strrep(h.FileNameLoad{1}(1:end-4),' ',''),'_',FileName(1:end-4),'_stressdata']);

print(fig,[PathNameExport,FileName1],'-vector','-dtiff','-r300')


% Export plot of labeled stress data
figure
fig = gcf;
fig.PaperUnits = 'centimeters';
fig.PaperPositionMode = 'manual';
fig.PaperPosition = [0 0 18 12];
ax = gca;
ax.OuterPosition = [0 0 1.085 1.025];
ax.TickDir = 'out';
ax.YAxis.TickLabelFormat = '%.0f';
ax.Box = 'on';
ax.XGrid = 'on';
ax.YGrid = 'on';
ax.GridLineStyle = '-';
ax.GridColor = 'k';
ax.GridAlpha = 0.3;
ax.YLabel.String = [char(963),' [MPa]'];
ax.YLabel.FontSize = 12;
ax.XLabel.String = [char(964),' [',char(956),'m]'];
ax.XLabel.FontSize = 12;

ax.XLim = [0 5];
% ax.YLim = [-Inf,Inf];

ax.LabelFontSizeMultiplier = 1;
ax.LineWidth = 1.3;
set(gca,'FontSize',12)
hold on
set(fig, 'Visible', 'off');

errorbar(h.taumean,h.sigmaFinal(:,1),h.sigmaerrFinal(:,1),'s');
errorbar(h.taumean,h.sigmasin2psiFinal,h.deltasigmasin2psiFinal,'o');

% --- Berechnung der Y-Grenzen ---
y_min = min(h.sigmaFinal(:,1) - h.sigmaerrFinal(:,1));
y_max = max(h.sigmaFinal(:,1) + h.sigmaerrFinal(:,1));

% Wertebereich bestimmen
range = y_max - y_min;

% --- Schrittweite automatisch bestimmen ---
% (Wenn Daten klein sind → 10er; mittel → 100er; groß → 1000er etc.)
if range < 100
    step = 10;
elseif range < 1000
    step = 100;
else
    step = 1000;
end

% --- Grenzen runden ---
y_lower = floor(y_min / step) * step;  % nach unten abrunden
y_upper = ceil(y_max / step) * step;   % nach oben aufrunden

% --- Neue Grenzen setzen ---
ylim([y_lower, y_upper]);


% --- Dynamische X-Achsenobergrenze ---
x_max_val = max(h.taumean);  % größter X-Wert

% Hier wird geprüft, in welchem Intervall x_max_val liegt:
if x_max_val <= 5
    x_upper = 5;
elseif x_max_val <= 10
    x_upper = 10;
elseif x_max_val <= 15
    x_upper = 15;
elseif x_max_val <= 20
    x_upper = 20;
elseif x_max_val <= 30
    x_upper = 30;
elseif x_max_val <= 50
    x_upper = 50;
else
    % falls größer, auf das nächste Vielfache von 10 runden
    x_upper = ceil(x_max_val/10)*10;
end

% Untere Grenze automatisch vom Minimum abhängig machen (optional)
% x_lower = min(x);
xlim([0, x_upper]);

LegLabeldata = {'Stressfactor-method','sin²psi-method'};
% Create legend
l = legend(LegLabeldata);
l.Location = 'northwest';

l.FontSize = 10;
l.LineWidth = 0.5;

for k = 1:size(h.DEKdataMatchedPeaks,1)
   hkllabestressplot{k} = num2str(h.DEKdataMatchedPeaks(k,1:3));
end

% Label der Spannungswerte
hold on;

x = h.taumean(:,1);
y = h.sigmaFinal(:,1);
err = h.sigmaerrFinal(:,1);

base_dx = 0.075 * abs(abs(max(h.taumean(:,1))) - abs(min(h.taumean(:,1))));  % enger horizontaler Abstand
base_dy = 0.005 * abs(abs(max(h.sigmaFinal(:,1))) - abs(min(h.sigmaFinal(:,1))));   % kleiner vertikaler Schritt
min_dist = 0.025 * abs(abs(max(h.sigmaFinal(:,1))) - abs(min(h.sigmaFinal(:,1))));  % Mindestabstand zwischen Labels
max_iter = 150;

% --- Startpositionen ---
label_pos = zeros(length(x), 2);
for i = 1:length(x)
    side = (-1)^(i);  % abwechselnd rechts/links
    dx = side * base_dx * (1 + 0.3 * rand);
    label_pos(i,:) = [x(i) + dx, y(i)];
end

% --- Iterative Optimierung ---
for iter = 1:max_iter
    moved = false;
    for i = 1:length(x)
        % --- 1. Abstand zu anderen Labels prüfen ---
        for j = 1:length(x)
            if i == j, continue; end
            dist = sqrt((label_pos(i,1)-label_pos(j,1))^2 + (label_pos(i,2)-label_pos(j,2))^2);
            if dist < min_dist
                moved = true;
                % leicht vertikal verschieben, zufällige Richtung
                label_pos(i,2) = label_pos(i,2) + sign(rand-0.5) * base_dy;
            end
        end

        % --- 2. Vermeidung von Überdeckung mit Fehlerbalken ---
        for j = 1:length(x)
            y_low = y(j) - err(j);
            y_high = y(j) + err(j);

            if abs(label_pos(i,1) - x(j)) < 0.015 * abs(abs(max(h.taumean(:,1))) - abs(min(h.taumean(:,1))))
                if label_pos(i,2) > y_low && label_pos(i,2) < y_high
                    moved = true;
                    if label_pos(i,2) < y(j)
                        label_pos(i,2) = y_low - 0.3*base_dy;
                    else
                        label_pos(i,2) = y_high + 0.3*base_dy;
                    end
                end
            end
        end

        % --- 3. Vermeidung von Punktüberdeckung ---
        if abs(label_pos(i,2) - y(i)) < 0.3*base_dy
            label_pos(i,2) = y(i) + sign(rand-0.5)*base_dy;
        end
    end

    % Wenn in dieser Iteration keine Labels mehr verschoben wurden → fertig
    if ~moved
        break;
    end
end

% --- Zeichne Labels ---
for i = 1:length(x)
    halign = 'left';
    if label_pos(i,1) < x(i)
        halign = 'right';
    end
    text(label_pos(i,1), label_pos(i,2), hkllabestressplot{i}, ...
        'FontSize', 7, 'Color', 'b', ...
        'HorizontalAlignment', halign, ...
        'VerticalAlignment', 'middle', ...
        'BackgroundColor', 'w', 'Margin', 0.2);

    p = line([x(i), label_pos(i,1)], [y(i), label_pos(i,2)], 'Color','k', 'LineStyle','-', 'LineWidth',0.6);
    set(p, 'HandleVisibility', 'off');
end

hold off;

FileName1 = sprintf([strrep(h.FileNameLoad{1}(1:end-4),' ',''),'_',FileName(1:end-4),'_stressdatalabeled']);

print(fig,[PathNameExport,FileName1],'-vector','-dtiff','-r300')

% Reset the button color
set(hObj,'String','Export Stress Data','backg',col)  % Now reset the button features.

guidata(hObj, h);

function definebgcallback(hObj, ~)
h = guidata(hObj);

delete(findobj(h.axesPlotIntensityData, 'Tag', 'bgmarker'));
delete(findobj(h.axesPlotIntensityData, 'Tag', 'bgcorrected'));

% ── Schritt 1: BG-Intervalle definieren ──────────────────────────────
km = msgbox(sprintf(['Bitte Untergrundpunkte definieren.\n' ...
    'Pro Peak-Gruppe: 1 Punkt LINKS und 1 Punkt RECHTS.\n' ...
    'Bei mehreren Gruppen: alle Punkte nacheinander klicken.\n' ...
    'Enter nach jedem Punkt, am Ende Enter zum Bestätigen.']));
uiwait(km);

[bgXclick, ~] = getpts(h.axesPlotIntensityData);

if numel(bgXclick) < 2 || mod(numel(bgXclick), 2) ~= 0
    errordlg('Bitte eine gerade Anzahl von Punkten klicken (links+rechts pro Gruppe).', ...
        'Eingabefehler');
    return
end

bgXclick = sort(bgXclick);
nGroups  = numel(bgXclick) / 2;

% BG-Intervalle: [xLeft, xRight] pro Gruppe
h.BgIntervals = zeros(nGroups, 2);
for g = 1:nGroups
    h.BgIntervals(g, :) = [bgXclick(2*g-1), bgXclick(2*g)];
end

% ── Schritt 2: PeakRegions aufbauen (wie in BackgroundReductionGUI) ──
% PeakRegions{bin} = [xLeft_g1, xLeft_g2, ...; xRight_g1, xRight_g2, ...]
nBins = size(h.dataXPlot, 2);
PeakRegions = cell(1, nBins);
for bn = 1:nBins
    PeakRegions{bn} = h.BgIntervals';  % [2 × nGroups]: Zeile1=links, Zeile2=rechts
end
h.PeakRegionsBg = PeakRegions;

% ── Schritt 3: Untergrundkorrektur für alle Bins ──────────────────────
% SmootFilterWidth = 0.05;
% SmootStepSize    = 1;

nAlpha = size(h.dataX, 2);
h.dataXcorrBg = cell(1, nAlpha);
h.dataYcorrBg = cell(1, nAlpha);
h.dataBkg     = cell(1, nAlpha);

% Parameter für gleitenden Minimum-Filter
SmootFilterWidth = 0.05;   % in 2theta-Grad (wie alte GUI)
SmootStepSize    = 1;

for m = 1:nAlpha
    nBinsAlpha = size(h.dataY{m}, 2);
    h.dataXcorrBg{m} = cell(1, nBinsAlpha);
    h.dataYcorrBg{m} = cell(1, nBinsAlpha);
    h.dataBkg{m}     = cell(1, nBinsAlpha);

    TX = h.dataX{m};

    % Fenstergröße in Datenpunkten berechnen
    if numel(TX) >= 2
        dX = mean(diff(TX));
    else
        dX = 1;
    end
    windowWidth = max(3, round(SmootFilterWidth / dX));
    if mod(windowWidth, 2) == 0, windowWidth = windowWidth + 1; end

    for l = 1:nBinsAlpha
        TY = h.dataY{m}(:, l);

        % ── Schritt 1: Gleitender Minimum-Filter (wie MinMaxLineMean) ──
        % Schätzt den Untergrund unter allen Peaks
        TY_movmin = movmin(double(TY), windowWidth);

        % Glätten des gleitenden Minimums
        TY_background = movmean(TY_movmin, windowWidth * SmootStepSize);
        TY_background = max(TY_background, 0);

        % ── Schritt 2: BG-Punkte als Stützstellen verwenden ───────────
        % Die geklickten Punkte definieren den Untergrund in den
        % Peak-Regionen — außerhalb gilt der movmin-Untergrund
        bgXvals = zeros(1, nGroups*2);
        bgYvals = zeros(1, nGroups*2);

        for g = 1:nGroups
            idxL = Tools.Data.DataSetOperations.FindNearestIndex(TX, h.BgIntervals(g,1));
            idxR = Tools.Data.DataSetOperations.FindNearestIndex(TX, h.BgIntervals(g,2));
            bgXvals(2*g-1) = TX(idxL);
            bgXvals(2*g)   = TX(idxR);
            bgYvals(2*g-1) = TY_background(idxL);
            bgYvals(2*g)   = TY_background(idxR);
        end

        % ── Schritt 3: Innerhalb der Peak-Regionen linear interpolieren
        % Außerhalb: movmin-Untergrund verwenden
        [bgXsort, sortIdx] = sort(bgXvals);
        bgYsort = bgYvals(sortIdx);

        TY_bkg_final = TY_background;   % Basis: movmin-Untergrund

        % In den Peak-Regionen: lineare Interpolation zwischen BG-Punkten
        for g = 1:nGroups
            xL = h.BgIntervals(g,1);
            xR = h.BgIntervals(g,2);
            idxPeak = TX >= xL & TX <= xR;
            if any(idxPeak)
                TY_bkg_final(idxPeak) = interp1(bgXsort, bgYsort, ...
                    TX(idxPeak), 'linear', 'extrap');
            end
        end

        TY_bkg_final = max(TY_bkg_final, 0);

        % ── Schritt 4: Untergrund abziehen ────────────────────────────
        TY_corr = max(double(TY) - TY_bkg_final, 0);

        h.dataXcorrBg{m}{l} = TX;
        h.dataYcorrBg{m}{l} = TY_corr;
        h.dataBkg{m}{l}     = TY_bkg_final;
    end
end

% for m = 1:nAlpha
%     nBinsAlpha = size(h.dataY{m}, 2);
%     h.dataXcorrBg{m} = cell(1, nBinsAlpha);
%     h.dataYcorrBg{m} = cell(1, nBinsAlpha);
%     h.dataBkg{m}     = cell(1, nBinsAlpha);
% 
%     for l = 1:nBinsAlpha
%         TX = h.dataX{m};
%         TY = h.dataY{m}(:, l);
% 
%         % y-Werte der BG-Punkte direkt aus dem aktuellen Bin ablesen
%         bgXvals = zeros(1, nGroups*2);
%         bgYvals = zeros(1, nGroups*2);
%         for g = 1:nGroups
%             idxL = Tools.Data.DataSetOperations.FindNearestIndex(TX, h.BgIntervals(g,1));
%             idxR = Tools.Data.DataSetOperations.FindNearestIndex(TX, h.BgIntervals(g,2));
%             bgXvals(2*g-1) = TX(idxL);
%             bgXvals(2*g)   = TX(idxR);
%             bgYvals(2*g-1) = TY(idxL);   % ← y-Wert aus aktuellem Bin
%             bgYvals(2*g)   = TY(idxR);   % ← y-Wert aus aktuellem Bin
%         end
% 
%         % % Untergrundlinie: lineare Interpolation zwischen allen BG-Punkten
%         % % auf den gesamten x-Bereich
%         % [bgXsort, sortIdx] = sort(bgXvals);
%         % bgYsort = bgYvals(sortIdx);
%         % 
%         % TY_background = interp1(bgXsort, bgYsort, TX, 'linear', 'extrap');
%         % TY_background = max(TY_background, 0);
%         % 
%         % % Untergrund abziehen
%         % TY_corr = max(TY - TY_background, 0);
% 
%         % Untergrundlinie: lineare Interpolation zwischen allen BG-Punkten
%         [bgXsort, sortIdx] = sort(bgXvals);
%         bgYsort = bgYvals(sortIdx);
% 
%         % Nur innerhalb der definierten BG-Intervalle interpolieren
%         % Außerhalb: Untergrund = Spektrum selbst → korrigiertes Signal = 0
%         TY_background = zeros(size(TX));
%         xGlobalMin = min(bgXsort);
%         xGlobalMax = max(bgXsort);
% 
%         % Maske: Punkte innerhalb des gesamten BG-Bereichs
%         idxInRange = (TX >= xGlobalMin) & (TX <= xGlobalMax);
% 
%         if any(idxInRange)
%             TY_background(idxInRange) = interp1(bgXsort, bgYsort, ...
%                 TX(idxInRange), 'linear');
%         end
% 
%         % Außerhalb des definierten Bereichs: Untergrund = Spektrum
%         % → korrigiertes Signal wird 0
%         TY_background(~idxInRange) = TY(~idxInRange);
%         TY_background = max(TY_background, 0);
% 
%         % Untergrund abziehen — außerhalb der BG-Intervalle wird 0
%         TY_corr = max(TY - TY_background, 0);
% 
%         h.dataXcorrBg{m}{l} = TX;
%         h.dataYcorrBg{m}{l} = TY_corr;
%         h.dataBkg{m}{l}     = TY_background;
%     end
% end

% ── Schritt 4: Korrigiertes Spektrum anzeigen ─────────────────────────
% Aktuellen Bin aus Slider
% sliderVal = max(1, round(get(h.Slider, 'Value')));
% sliderVal = min(sliderVal, size(h.dataXPlot, 2));

% NEU: globalen Slider-Wert auf Alpha-Gruppe + lokalen Bin-Index umrechnen
sliderValGlobal = max(1, round(get(h.Slider, 'Value')));
[m_plot, sliderVal] = globalSliderToGroupBin(sliderValGlobal, h.dataY);

% Rohspektrum auf grau setzen (Referenz im Hintergrund)
if isfield(h,'plotIntensityData') && isvalid(h.plotIntensityData)
    set(h.plotIntensityData, ...
        'XData',     h.dataXPlot(:, sliderValGlobal), ...
        'YData',     h.dataYPlot(:, sliderValGlobal), ...
        'Color',     [0.75 0.75 0.75], ...
        'LineWidth', 0.8, ...
        'Tag',       'rawspectrum', ...
        'Visible',   'on');
end

% Alte BG-Overlays löschen und neu zeichnen
delete(findobj(h.axesPlotIntensityData, 'Tag', 'bgmarker'));
delete(findobj(h.axesPlotIntensityData, 'Tag', 'bgcorrected'));

hold(h.axesPlotIntensityData, 'on');

% BG-Marker auf Rohspektrum
xPlot = h.dataXPlot(:, sliderValGlobal);
yPlot = h.dataYPlot(:, sliderValGlobal);
for g = 1:nGroups
    bgX = h.BgIntervals(g, :);
    bgY = interp1(xPlot, yPlot, bgX, 'linear', 'extrap');
    plot(h.axesPlotIntensityData, bgX, bgY, 'v', ...
        'Color', [0.8 0.4 0], 'MarkerFaceColor', [0.8 0.4 0], ...
        'MarkerSize', 8, 'Tag', 'bgmarker');
    plot(h.axesPlotIntensityData, bgX, bgY, '--', ...
        'Color', [0.8 0.4 0], 'LineWidth', 1.2, 'Tag', 'bgmarker');
end

% Korrigiertes Spektrum (blau — konsistent mit Slider-Callback)
% m_plot = 1;
if ~isempty(h.dataYcorrBg{m_plot}{sliderVal})
    plot(h.axesPlotIntensityData, ...
        h.dataXcorrBg{m_plot}{sliderVal}, ...
        h.dataYcorrBg{m_plot}{sliderVal}, '-', ...
        'Color', [0.094 0.373 0.647], 'LineWidth', 1.2, ...
        'Tag', 'bgcorrected');
end

% ── Schritt 5: Define Peaks Button aktivieren ─────────────────────────
set(h.DefinePeakPosButton, 'Enable', 'on');

km = msgbox(sprintf(['Untergrundkorrektur abgeschlossen.\n' ...
    '%d Gruppe(n) korrigiert.\n' ...
    'Bitte nun "2. Define Peaks" klicken.'], nGroups));
uiwait(km);

guidata(hObj, h);

function definepeakscallback(hObj, ~)
h = guidata(hObj);

% Korrigiertes Spektrum temporär anzeigen für Peak-Klick
sliderValGlobal = max(1, round(get(h.Slider, 'Value')));
[m_plot, sliderVal] = globalSliderToGroupBin(sliderValGlobal, h.dataY);

if ~isfield(h, 'dataYcorrBg') || isempty(h.dataYcorrBg)
    errordlg('Bitte zuerst "1. Define BG" ausführen.', 'Fehler');
    return
end

% Nur bgcorrected aktualisieren — kein cla, damit andere Objekte erhalten bleiben
delete(findobj(h.axesPlotIntensityData, 'Tag', 'bgcorrected'));
hold(h.axesPlotIntensityData, 'on');

plot(h.axesPlotIntensityData, ...
    h.dataXcorrBg{m_plot}{sliderVal}, ...
    h.dataYcorrBg{m_plot}{sliderVal}, '-', ...
    'Color', [0.094 0.373 0.647], 'LineWidth', 1.2, ...
    'Tag', 'bgcorrected');

km = msgbox(sprintf(['Peakpositionen im korrigierten Spektrum anklicken.\n' ...
    'Alle Peaks die gefittet werden sollen anklicken.\n' ...
    'Enter nach jedem Klick, am Ende Enter zum Bestätigen.']));
uiwait(km);

[UP, ~] = getpts(h.axesPlotIntensityData);

if isempty(UP)
    errordlg('Keine Peaks definiert.', 'Fehler');
    return
end

UP       = sort(UP);
nPeaks   = length(UP);
h.UserPeaks = UP;

% Tabelle aktualisieren
UserPeaksdatanew = [num2cell(UP), num2cell(zeros(nPeaks,1)), ...
                    num2cell(true(nPeaks,1)), ...   % alle aktiviert
                    num2cell(NaN(nPeaks,1)), num2cell(NaN(nPeaks,1))];
set(h.tableUserDefinedPeaks, 'data', UserPeaksdatanew);

% BgRegions aus BgIntervals ableiten: pro Peak das passende Intervall
h.BgRegions = cell(nPeaks, 1);
for pk = 1:nPeaks
    pos = UP(pk);
    for g = 1:size(h.BgIntervals, 1)
        if pos > h.BgIntervals(g,1) && pos < h.BgIntervals(g,2)
            h.BgRegions{pk} = h.BgIntervals(g, :);
            % Tabelle aktualisieren
            tableData = get(h.tableUserDefinedPeaks, 'Data');
            tableData{pk, 4} = h.BgIntervals(g,1);
            tableData{pk, 5} = h.BgIntervals(g,2);
            set(h.tableUserDefinedPeaks, 'Data', tableData);
            break
        end
    end
end

% Nach Peak-Definition: korrigiertes Spektrum beibehalten
% KEIN cla — bestehende Objekte (xlines, BG-Marker) bleiben erhalten
delete(findobj(h.axesPlotIntensityData, 'Tag', 'bgcorrected'));
delete(findobj(h.axesPlotIntensityData, 'Tag', 'rawspectrum'));

hold(h.axesPlotIntensityData, 'on');

% plotIntensityData neu anlegen falls nötig
if ~isfield(h,'plotIntensityData') || ~isvalid(h.plotIntensityData)
    h.plotIntensityData = plot(h.axesPlotIntensityData, ...
        h.dataXPlot(:, sliderValGlobal), h.dataYPlot(:, sliderValGlobal), '-', ...
        'Color', [0.75 0.75 0.75], 'LineWidth', 0.8, ...
        'Tag', 'rawspectrum', 'Visible', 'off');
end

% Korrigiertes Spektrum
plot(h.axesPlotIntensityData, ...
    h.dataXcorrBg{m_plot}{sliderVal}, ...
    h.dataYcorrBg{m_plot}{sliderVal}, '-', ...
    'Color', [0.094 0.373 0.647], 'LineWidth', 1.2, ...
    'Tag', 'bgcorrected');

% BG-Marker
h = updateBgMarkers(h);

set(findobj(h.axesPlotIntensityData, 'Tag', 'bgmarker'), 'Visible', 'off');
set(findobj(h.axesPlotIntensityData, 'Tag', 'rawspectrum'), 'Visible', 'off');
% set(findobj(h.axesPlotIntensityData, 'Tag', 'peakmarker'), 'Visible', 'off');

% Peak-Marker
for pk = 1:nPeaks
    yPk = interp1(h.dataXcorrBg{m_plot}{sliderVal}, ...
                  h.dataYcorrBg{m_plot}{sliderVal}, UP(pk), 'linear', 'extrap');
    plot(h.axesPlotIntensityData, UP(pk), yPk, '^', ...
        'Color', 'r', 'MarkerFaceColor', 'r', 'MarkerSize', 8, ...
        'Tag', 'peakmarker', 'Visible', 'on');
end

km = msgbox(sprintf('%d Peak(s) definiert. Bereit zum Fitten.', nPeaks));
uiwait(km);

% ── Achsengrenzen auf Datenbreich setzen ─────────────────────────────
if isfield(h,'dataXcorrBg') && ~isempty(h.dataXcorrBg{m_plot}{sliderVal})
    xData = h.dataXcorrBg{m_plot}{sliderVal};
    xlim(h.axesPlotIntensityData, [min(xData) max(xData)]);
end
h.axesPlotIntensityData.YLimMode = 'auto';

guidata(hObj, h);

function bgregioneditcallback(hObj, eventdata)
h = guidata(hObj);

idx = eventdata.Indices;
pk  = idx(1);
col = idx(2);

% Nur Spalten 4 und 5 sind BG-relevant
if col < 4
    guidata(hObj, h);
    return
end

newVal = eventdata.NewData;

% Validierung
if isempty(newVal) || ~isnumeric(newVal) || ~isfinite(newVal)
    tableData = get(hObj, 'Data');
    tableData{pk, col} = eventdata.PreviousData;
    set(hObj, 'Data', tableData);
    guidata(hObj, h);
    return
end

% BgRegions synchronisieren
if ~isfield(h, 'BgRegions') || numel(h.BgRegions) < pk || isempty(h.BgRegions{pk})
    h.BgRegions{pk} = [NaN NaN];
end
h.BgRegions{pk}(col - 3) = newVal;  % col=4 → idx 1, col=5 → idx 2

% links < rechts prüfen
if all(isfinite(h.BgRegions{pk})) && h.BgRegions{pk}(1) >= h.BgRegions{pk}(2)
    warndlg(sprintf('BG links (%.3f) muss kleiner als BG rechts (%.3f) sein.', ...
        h.BgRegions{pk}(1), h.BgRegions{pk}(2)), 'Ungültige Eingabe');
    tableData = get(hObj, 'Data');
    tableData{pk, col} = eventdata.PreviousData;
    set(hObj, 'Data', tableData);
    h.BgRegions{pk}(col-3) = eventdata.PreviousData;
    guidata(hObj, h);
    return
end

% Marker aktualisieren
h = updateBgMarkers(h);
guidata(hObj, h);

function clearbuttondown(hObj,~)
set(hObj, 'String','','Enable','on');
uicontrol(hObj);

guidata(hObj);

function showcentroidcallback(hObj, ~)
h = guidata(hObj);

if ~isfield(h,'plotdataCentFit') || ~isvalid(h.plotdataCentFit)
    guidata(hObj, h);
    return
end

if get(hObj, 'Value') == 1
    % Centroid anzeigen falls Daten vorhanden
    valueSlider = round(get(h.Slider, 'Value'));
    showCent = isfield(h,'cb_showCentroid') && get(h.cb_showCentroid,'Value') == 1;
    if isfield(h,'datacentFitMat') && numel(h.datacentFitMat) >= valueSlider
        cf    = h.datacentFitMat{valueSlider};
        idxCF = isfinite(cf(:,2));
        if any(idxCF) && showCent
            set(h.plotdataCentFit, ...
                'XData',          cf(idxCF,1), ...
                'YData',          cf(idxCF,2), ...
                'YNegativeDelta', cf(idxCF,3), ...
                'YPositiveDelta', cf(idxCF,3), ...
                'Visible', 'on');
        end
    end
else
    set(h.plotdataCentFit, 'Visible', 'off');
end

guidata(hObj, h);


function tabSelectionChangedCallback(hObj, event)
h = guidata(hObj);
isDatasetTab   = strcmp(event.NewValue.Title, 'Time Series / Dataset');
isIntensityTab = strcmp(event.NewValue.Title, 'Plot intensity data');

% ── Globale Elemente ein-/ausblenden ─────────────────────────────────
elementsToToggle = {
    'Slider', 'checkboxplotall', 'axesPlottauData', 'plottaudata', ...
    'axesStressData', 'plotstressdata', 'plotsin2psistressdata', ...
    'highlightstressplot', 'axesFittedPeaks', 'SliderFittedPeaks', ...
    'radiobuttonwavelength', 'ExportFitDataButton', 'ExportStressDataButton'};
for k = 1:numel(elementsToToggle)
    fn = elementsToToggle{k};
    if isfield(h, fn) && isvalid(h.(fn))
        set(h.(fn), 'Visible', bool2vis(~isDatasetTab));
    end
end

% ── Slider-Grenzen je nach aktivem Tab setzen ─────────────────────────
if isIntensityTab && isfield(h, 'IntensityProfiles') && ~isempty(h.IntensityProfiles)
    nProf      = size(h.IntensityProfiles, 2) * size(h.IntensityProfiles{1}, 2);
    nProf      = max(nProf, 2);
    currentVal = max(1, min(round(get(h.Slider, 'Value')), nProf));
    set(h.Slider, ...
        'Min',        1, ...
        'Max',        nProf, ...
        'Value',      currentVal, ...
        'SliderStep', [1/max(nProf-1,1)  1/max(nProf-1,1)]);
elseif ~isIntensityTab && ~isDatasetTab && isfield(h, 'FitDataMod') && ~isempty(h.FitDataMod)
    nFit       = max(size(h.FitDataMod, 1), 2);
    currentVal = max(1, min(round(get(h.Slider, 'Value')), nFit));
    set(h.Slider, ...
        'Min',        1, ...
        'Max',        nFit, ...
        'Value',      currentVal, ...
        'SliderStep', [1/max(nFit-1,1)  1/max(nFit-1,1)]);
end

% ── Heater-Plot: nur bei Dataset-Tab + CSV ────────────────────────────
hasHeater   = isfield(h, 'heaterData') && ~isempty(h.heaterData);
heaterElems = {'axesHeater', 'HeaterColText', 'HeaterColPopup', 'cbTmaxLine'};
for k = 1:numel(heaterElems)
    fn = heaterElems{k};
    if isfield(h, fn) && isvalid(h.(fn))
        set(h.(fn), 'Visible', bool2vis(isDatasetTab && hasHeater));
    end
end

% ── TS-Fit-Elemente: nur bei Dataset-Tab ─────────────────────────────
tsFitElems = { ...
    'TSPFHeader',     'TSXRangeLbl',       'TSXRangeDash', ...
    'TSXRangeMinEdit','TSXRangeMaxEdit',   'TSXRangeResetButton', ...
    'TSTRangeLbl',    'TSTRangeDash',      'TSTRangeMinEdit', 'TSTRangeMaxEdit', ...
    'TSDefineBGButton','TSDefinePeaksButton','TSPickPeaksHeatmapButton','TSAddPeakButton', ...
    'TSFitAllButton', 'TSFitExportButton','TSFitBoundsButton', ...
    'TSFitStatusText','TSFitZeigeLbl','TSFitResultPopup', ...
    'axesTSFitResults','TSXRangeApplyButton','PeakModelGroup'};
for k = 1:numel(tsFitElems)
    fn = tsFitElems{k};
    if isfield(h, fn) && isvalid(h.(fn))
        set(h.(fn), 'Visible', bool2vis(isDatasetTab));
    end
end

% ── CBFViewModeGroup: nur bei Dataset-Tab + CBF Viewer aktiv ─────────
if isfield(h, 'CBFViewModeGroup') && isvalid(h.CBFViewModeGroup)
    isCBFViewer = isDatasetTab && ...
                  isfield(h, 'TimeSeriesModeGroup') && ...
                  isvalid(h.TimeSeriesModeGroup) && ...
                  strcmp(get(h.TimeSeriesModeGroup.SelectedObject, 'String'), ...
                         'CBF Viewer');
    set(h.CBFViewModeGroup, 'Visible', bool2vis(isCBFViewer));
end

guidata(hObj, h);


function loaddatasetcallback(hObj, ~)
h = guidata(hObj);

% Ordner wählen
dataDir = uigetdir(fullfile(General.ProgramInfo.Path, 'Data', 'Measurements'), 'Messordner wählen (CBF + DAT + LOG-Dateien)');
if isequal(dataDir, 0), return; end

% Python-Exe aus bestehendem Edit-Feld übernehmen
if isfield(h, 'pythonExeEdit') && isvalid(h.pythonExeEdit)
    pythonExe = strtrim(get(h.pythonExeEdit, 'String'));
else
    pythonExe = 'python';
end

col = get(hObj, 'backg');
set(hObj, 'String', 'Lade Dataset ...', 'backg', [1 .6 .6]);
pause(0.01);

try
    dataset = loadDataset(dataDir, pythonExe);
catch ME
    set(hObj, 'String', 'Load Dataset Folder', 'backg', col);
    errordlg(sprintf('loadDataset fehlgeschlagen:\n%s', ME.message), 'Fehler');
    return
end

h.dataset = dataset;
h.dataDir = dataDir;
N = numel(dataset);

% Status-Text aktualisieren
t0str = datestr(dataset(1).datetime,   'HH:MM:SS');
tEstr = datestr(dataset(end).datetime, 'HH:MM:SS');
set(h.DatasetStatusText, 'String', ...
    sprintf('%d Messungen  |  %s – %s  |  %s', ...
    N, t0str, tEstr, dataDir));

% TSDefineBGButton + TSPickPeaksHeatmapButton aktivieren sobald Daten vorhanden
if isfield(h,'TSDefineBGButton') && isvalid(h.TSDefineBGButton)
    set(h.TSDefineBGButton, 'Enable','on');
end
if isfield(h,'TSPickPeaksHeatmapButton') && isvalid(h.TSPickPeaksHeatmapButton)
    set(h.TSPickPeaksHeatmapButton, 'Enable','on');
end
if isfield(h,'TSAddPeakButton') && isvalid(h.TSAddPeakButton)
    set(h.TSAddPeakButton, 'Enable','on');
end

% Slider konfigurieren
set(h.SliderTimeSeries, ...
    'Min',        1, ...
    'Max',        max(N, 2), ...
    'Value',      1, ...
    'SliderStep', [1/max(N-1,1)  1/max(N-1,1)], ...
    'Enable',     'on');

% Y-Achsen-Popup mit numerischen meta-Feldern befüllen
if N > 0 && isfield(dataset(1), 'meta')
    metaFields = fieldnames(dataset(1).meta);
    numFields  = metaFields(cellfun(@(f) ...
        isnumeric(dataset(1).meta.(f)) && isscalar(dataset(1).meta.(f)), ...
        metaFields));
    axisOptions = [{'Zeit (min)'; 'Index'}; numFields];
    set(h.TimeSeriesYAxisPopup, 'String', axisOptions, 'Value', 1);
    h.datasetAxisOptions = axisOptions;
end

% ── Wellenlänge für 2θ-Konversion speichern ──────────────────────────
h.datasetLambda_m = [];

% Priorität 1: aus poni-Struct im Dataset
for ds_idx = 1:numel(dataset)
    p = dataset(ds_idx).poni;
    if isstruct(p) && isfield(p, 'wavelength') && ...
       isnumeric(p.wavelength) && p.wavelength > 0
        h.datasetLambda_m = p.wavelength;
        break
    end
end

% Priorität 2: direkt aus PONI-Datei lesen
if isempty(h.datasetLambda_m)
    poniFiles = dir(fullfile(dataDir, '*.poni'));
    if ~isempty(poniFiles)
        fid = fopen(fullfile(dataDir, poniFiles(1).name), 'r');
        while ~feof(fid)
            line = strtrim(fgetl(fid));
            if ~ischar(line), continue; end
            if strncmpi(line, 'Wavelength', 10)
                colonIdx = strfind(line, ':');
                if ~isempty(colonIdx)
                    val = str2double(strtrim(line(colonIdx(1)+1:end)));
                    if isfinite(val) && val > 0
                        h.datasetLambda_m = val;
                    end
                end
                break
            end
        end
        fclose(fid);
    end
end

% Priorität 3: h.lambda_m falls vorhanden
if isempty(h.datasetLambda_m) && isfield(h, 'lambda_m') && ...
   ~isempty(h.lambda_m) && h.lambda_m > 0
    h.datasetLambda_m = h.lambda_m;
end

if ~isempty(h.datasetLambda_m)
    fprintf('loaddatasetcallback: Wellenlänge = %.6e m  (%.4f Å)\n', ...
        h.datasetLambda_m, h.datasetLambda_m * 1e10);
else
    warning('loaddatasetcallback: Wellenlänge nicht gefunden — 2θ-Modus nicht verfügbar.');
end

% ── CSV-Heizprotokoll laden (optional, inline) ───────────────────────
h.heaterData = [];
csvFiles = dir(fullfile(dataDir, '*.csv'));
if ~isempty(csvFiles)
    try
        csvPath   = fullfile(dataDir, csvFiles(1).name);
        t0_csv    = dataset(1).datetime;

        % Datum aus CSV-Header lesen (# Date: YYYY/MM/DD)
        % Fallback: Datum aus erster XRD-Messung
        dateStr = datestr(t0_csv, 'yyyy/mm/dd');
        fid_csv = fopen(csvPath, 'r');
        while ~feof(fid_csv)
            raw_csv = fgetl(fid_csv);
            if ~ischar(raw_csv), break; end
            tok = regexp(strtrim(raw_csv), ...
                '#\s*Date:\s*(\d{4}/\d{2}/\d{2})', 'tokens');
            if ~isempty(tok)
                dateStr = tok{1}{1};   % z.B. '2026/03/26'
                break;
            end
        end
        fclose(fid_csv);

        % Header überspringen, Spaltenzeile finden
        fid_csv = fopen(csvPath, 'r');
        headerLine_csv = '';
        while ~feof(fid_csv)
            raw_csv = fgetl(fid_csv);
            if ~ischar(raw_csv), break; end
            line_csv = strtrim(raw_csv);
            if startsWith(line_csv, '#') || isempty(line_csv), continue; end
            if count(line_csv, sprintf('	')) >= 2
                headerLine_csv = line_csv; break;
            end
        end
        % Datenzeilen einlesen
        csvRows = {};
        while ~feof(fid_csv)
            raw_csv = fgetl(fid_csv);
            if ischar(raw_csv) && ~isempty(strtrim(raw_csv))
                csvRows{end+1} = strtrim(raw_csv); %#ok<AGROW>
            end
        end
        fclose(fid_csv);

        if ~isempty(headerLine_csv) && ~isempty(csvRows)
            % Spaltennamen
            rawCols_csv   = strsplit(headerLine_csv, '	');
            rawCols_csv   = rawCols_csv(~cellfun(@(x) isempty(strtrim(x)), rawCols_csv));
            colFields_csv = matlab.lang.makeValidName(rawCols_csv);
            nCols_csv     = numel(colFields_csv);
            nRows_csv     = numel(csvRows);

            % Daten parsen
            data_csv = cell(nRows_csv, nCols_csv);
            for r_csv = 1:nRows_csv
                parts_csv = strsplit(csvRows{r_csv}, '	');
                for c_csv = 1:min(nCols_csv, numel(parts_csv))
                    data_csv{r_csv, c_csv} = strtrim(parts_csv{c_csv});
                end
            end

            % Datetime aus Spalte 1 (HH:MM:SS)
            dtArr_csv = NaT(nRows_csv, 1);
            for r_csv = 1:nRows_csv
                try
                    dtArr_csv(r_csv) = datetime( ...
                        [dateStr ' ' data_csv{r_csv,1}], ...
                        'InputFormat', 'yyyy/MM/dd HH:mm:ss');
                    if r_csv > 1 && dtArr_csv(r_csv) < dtArr_csv(r_csv-1)
                        dtArr_csv(r_csv) = dtArr_csv(r_csv) + days(1);
                    end
                catch
                    if r_csv > 1
                        dtArr_csv(r_csv) = dtArr_csv(r_csv-1) + seconds(5);
                    else
                        dtArr_csv(r_csv) = t0_csv;
                    end
                end
            end

            % Struct aufbauen
            hd.datetime  = dtArr_csv;
            hd.time_min  = seconds(dtArr_csv - t0_csv) / 60;
            hd.colNames  = rawCols_csv;
            for c_csv = 2:nCols_csv
                vals_csv = zeros(nRows_csv, 1);
                for r_csv = 1:nRows_csv
                    if c_csv <= size(data_csv,2) && ~isempty(data_csv{r_csv,c_csv})
                        vals_csv(r_csv) = str2double(data_csv{r_csv,c_csv});
                    else
                        vals_csv(r_csv) = NaN;
                    end
                end
                hd.(colFields_csv{c_csv}) = vals_csv;
            end
            h.heaterData = hd;

            % Y-Achsen-Popup um Heizspalten erweitern
            extraCols_hd = rawCols_csv(2:end);
            heaterOpts   = cellfun(@(c) ['Heater: ' c], extraCols_hd, ...
                'UniformOutput', false);
            currentOpts  = get(h.TimeSeriesYAxisPopup, 'String');
            currentOpts  = currentOpts(:);
            heaterOpts   = heaterOpts(:);
            set(h.TimeSeriesYAxisPopup, 'String', [currentOpts; heaterOpts]);

            % HeaterColPopup mit CSV-Spalten befüllen (ohne 'Time')
            colOpts = extraCols_hd(:);
            % Automatisch eine Temperaturspalte vorwaehlen
            defaultVal = 1;
            tempKeywords = {'TSample','T_actual','T_sample','Temperature','PV'};
            for tk = 1:numel(tempKeywords)
                idx_tk = find(contains(colOpts, tempKeywords{tk}, 'IgnoreCase', true), 1);
                if ~isempty(idx_tk)
                    defaultVal = idx_tk;
                    break
                end
            end
            set(h.HeaterColPopup, 'String', colOpts, 'Value', defaultVal);
        end
    catch ME
        warning('loaddatasetcallback: CSV-Fehler: %s', strrep(ME.message, '%', '%%'));
    end
end

% Initial plotten
guidata(hObj, h);
h = updateTimeSeriesPlot(h);

% Tab aktivieren + globale Elemente ausblenden
h.plottab.SelectedTab = h.plottab8;

% Beim programmatischen Tab-Wechsel feuert SelectionChangedFcn nicht →
% globale Elemente manuell ausblenden
% elementsToHide = {'Slider', 'checkboxplotall', 'axesPlottauData', 'plottaudata'};
elementsToHide = {
    'Slider', 'checkboxplotall', 'axesPlottauData', 'plottaudata', ...
    'axesStressData', 'plotstressdata', 'plotsin2psistressdata', ...
    'highlightstressplot', 'axesFittedPeaks', 'SliderFittedPeaks', ...
    'radiobuttonwavelength', 'ExportFitDataButton', 'ExportStressDataButton'};
for k = 1:numel(elementsToHide)
    fn = elementsToHide{k};
    if isfield(h, fn) && isvalid(h.(fn))
        set(h.(fn), 'Visible', 'off');
    end
end

% Heater-Elemente einblenden falls CSV geladen
if isfield(h, 'heaterData') && ~isempty(h.heaterData)
    heaterElems = {'axesHeater', 'HeaterColText', 'HeaterColPopup', 'cbTmaxLine'};
    for k = 1:numel(heaterElems)
        fn = heaterElems{k};
        if isfield(h, fn) && isvalid(h.(fn))
            set(h.(fn), 'Visible', 'on');
        end
    end
    % Heater-Plot initial zeichnen
    h = updateHeaterPlot(h);
end

if isfield(h,'ReintegratePONIButton') && isvalid(h.ReintegratePONIButton)
    set(h.ReintegratePONIButton, 'Enable', 'on');
end

set(hObj, 'String', 'Load Dataset Folder', 'backg', col);
guidata(hObj, h);


function SliderCallbackTimeSeries(hObj, ~)
h = guidata(hObj);

if ~isfield(h, 'dataset') || isempty(h.dataset), return; end

value = max(1, round(get(hObj, 'Value')));
value = min(value, numel(h.dataset));
ds    = h.dataset(value);

% Info-Text
set(h.TimeSeriesInfoText, 'String', ...
    sprintf('#%d  t=%.1fs  %s', ds.index, ds.time_s, ...
    datestr(ds.datetime, 'HH:MM:SS')));

% Motor-Tabelle befüllen (nur bei Single Profile / CBF Viewer sinnvoll,
% aber immer aktualisieren)
if isfield(ds, 'log') && ~isempty(fieldnames(ds.log))
    logFields = fieldnames(ds.log);
    tableData = cell(numel(logFields), 2);
    for fi = 1:numel(logFields)
        tableData{fi, 1} = logFields{fi};
        val = ds.log.(logFields{fi});
        if isnumeric(val)
            tableData{fi, 2} = num2str(val, '%.4g');
        else
            tableData{fi, 2} = char(val);
        end
    end
    set(h.TimeSeriesMotorTable, 'Data', tableData);
elseif isfield(ds, 'meta')
    metaFields = fieldnames(ds.meta);
    tableData  = cell(numel(metaFields), 2);
    for fi = 1:numel(metaFields)
        tableData{fi, 1} = metaFields{fi};
        val = ds.meta.(metaFields{fi});
        if isnumeric(val)
            tableData{fi, 2} = num2str(val, '%.4g');
        else
            tableData{fi, 2} = char(val);
        end
    end
    set(h.TimeSeriesMotorTable, 'Data', tableData);
end

% Modus bestimmen und Layout sofort anpassen
selectedMode = get(h.TimeSeriesModeGroup.SelectedObject, 'String');
switch selectedMode
    case 'Waterfall',      h = applyTimeSeriesLayout(h, 'full');
    case 'Heatmap',        h = applyTimeSeriesLayout(h, 'full');
    case 'Single Profile', h = applyTimeSeriesLayout(h, 'bottom');
    case 'CBF Viewer',     h = applyTimeSeriesLayout(h, 'split');
end

% X-Achsen-Konversion (q → 2theta) — analog zu updateTimeSeriesPlot
use2theta_sl = isfield(h, 'TimeSeriesXAxisGroup') && ...
               isvalid(h.TimeSeriesXAxisGroup) && ...
               strcmp(get(h.TimeSeriesXAxisGroup.SelectedObject, 'String'), '2θ');
lambda_m_sl = [];
if use2theta_sl
    % datasetLambda_m zuerst: konsistent mit pyFAI-q-Berechnung
    if isfield(h, 'datasetLambda_m') && ~isempty(h.datasetLambda_m) ...
           && h.datasetLambda_m > 0
        lambda_m_sl = h.datasetLambda_m;
    elseif isfield(h, 'lambda_m') && ~isempty(h.lambda_m) && h.lambda_m > 0
        lambda_m_sl = h.lambda_m;
    elseif isstruct(ds.poni) && isfield(ds.poni, 'wavelength') && ...
           isnumeric(ds.poni.wavelength) && ds.poni.wavelength > 0
        lambda_m_sl = ds.poni.wavelength;
    end
    if isempty(lambda_m_sl) || lambda_m_sl <= 0
        use2theta_sl = false;
    end
end
if use2theta_sl
    lambda_nm_sl  = lambda_m_sl * 1e9;
    q2tth_sl      = @(q) 2 * rad2deg(asin(max(min(q * lambda_nm_sl / (4*pi), 1), -1)));
    xLabel_sl     = '2θ (°)';
else
    q2tth_sl  = @(q) q / 10;            % nm^-1 → Å^-1
    xLabel_sl = 'q (Å^{-1})';
end

switch selectedMode

    case 'Single Profile'
        if ~isempty(ds.q) && ~isempty(ds.I)
            [q_ex, I_ex] = applyExcludeZone(h, ds.q, ds.I);
            xData = q2tth_sl(q_ex);
    
            cla(h.axesTimeProfile);
            hold(h.axesTimeProfile, 'on');
    
            % BG- und Peak-Status prüfen
            hasBG    = isfield(h, 'tsBgIntervals') && ~isempty(h.tsBgIntervals);
            hasPeaks = isfield(h, 'tsUserPeaks')   && ~isempty(h.tsUserPeaks);
            hasFit   = isfield(h, 'tsFitResults')   && ~isempty(h.tsFitResults) && hasPeaks;

            if hasFit && hasBG
                % BG-korrigierte Daten anzeigen (passend zu Fit-Kurven)
                [Xcorr, Ycorr, ~] = tsBGSubtract(xData, I_ex, h.tsBgIntervals);
                if numel(Xcorr) >= 2
                    plot(h.axesTimeProfile, Xcorr, Ycorr, '-', ...
                        'Color', [0.094 0.373 0.647], 'LineWidth', 1.0, ...
                        'DisplayName', 'BG-korrigiert');
                else
                    plot(h.axesTimeProfile, xData, I_ex, '-', ...
                        'Color', [0.094 0.373 0.647], 'LineWidth', 1.0);
                end
            else
                % Rohdaten anzeigen
                plot(h.axesTimeProfile, xData, I_ex, '-', ...
                    'Color', [0.094 0.373 0.647], 'LineWidth', 1.0);
            end

            if hasBG
                makeDraggableBGLines(h.axesTimeProfile, h.tsBgIntervals, h.myfig);
            end

            if hasPeaks
                makeDraggablePeakLines(h.axesTimeProfile, h.tsUserPeaks, h.myfig);
            end

            % ── Fit-Overlay falls vorhanden ───────────────────────────────
            if hasFit
                r          = h.tsFitResults;
                colors_fit = lines(numel(h.tsUserPeaks));
                for pk = 1:numel(h.tsUserPeaks)
                    if ~isfinite(r.peakPos(value,pk)), continue; end
                    mu  = r.peakPos(value,pk);
                    amp = r.amplitude(value,pk);
                    fw  = r.fwhm(value,pk);
                    eta = r.eta(value,pk);                              % NEU
                    xpv = linspace(mu - fw*3, mu + fw*3, 200);
                    ypv = amp * (eta ./ (1 + ((xpv-mu)/(fw/2)).^2) + ... % eta statt 0.5
                                 (1-eta) .* exp(-log(2)*((xpv-mu)/(fw/2)).^2)); % (1-eta) statt 0.5
                    plot(h.axesTimeProfile, xpv, ypv, '-', ...
                        'Color', colors_fit(pk,:), 'LineWidth', 1.5, ...
                        'DisplayName', sprintf('Peak %d  R²=%.2f', pk, ...
                        r.R2(value,pk)));
                    xline(h.axesTimeProfile, mu, '--', ...
                        'Color', colors_fit(pk,:), 'LineWidth', 0.8, 'Alpha', 0.6);
                end
                if numel(h.tsUserPeaks) > 1
                    legend(h.axesTimeProfile, 'Location', 'best', 'FontSize', 7);
                end
            end
    
            h.axesTimeProfile.XLabel.String = xLabel_sl;
            h.axesTimeProfile.YLabel.String = 'Intensität';
            h.axesTimeProfile.Title.String  = sprintf( ...
                'Profil #%d  –  t = %.1f s  –  %s', ...
                ds.index, ds.time_s, datestr(ds.datetime,'HH:MM:SS'));
    
            if isfield(h, 'tsXRange') && ~isempty(h.tsXRange)
                h.axesTimeProfile.XLim = h.tsXRange;
            else
                h.axesTimeProfile.XLimMode = 'auto';
            end
            h.axesTimeProfile.YLimMode = 'auto';
        end

    case 'CBF Viewer'
        titStr = sprintf('#%d  –  t = %.1f s  –  %s', ...
            ds.index, ds.time_s, datestr(ds.datetime,'HH:MM:SS'));
    
        % ── Linkes Axes: Raw oder Caked je nach Auswahl ───────────────────
        if cbfViewerShowCaked(h)

            % ── Caked-Daten lazy erzeugen, falls noch nicht vorhanden ─────
            if ~isCakedAvailable(ds)
                col = get(h.LoadDatasetButton, 'backg');
                set(h.LoadDatasetButton, 'String', 'Erzeuge Caked Image ...', ...
                    'backg', [1 .6 .6]);
                cla(h.axesTimeSeries);
                text(h.axesTimeSeries, 0.5, 0.5, ...
                    sprintf('Erzeuge Caked Image für #%d ...', ds.index), ...
                    'Units', 'normalized', 'HorizontalAlignment', 'center', ...
                    'FontSize', 12, 'Color', [0.3 0.3 0.3]);
                drawnow;

                h  = ensureCakedSingleAvailable(h, value);
                ds = h.dataset(value);

                set(h.LoadDatasetButton, 'String', 'Load Dataset Folder', 'backg', col);
                drawnow;
            end

            if isCakedAvailable(ds)
                % Ticks vom vorherigen CBF-Bild löschen
                h.axesTimeSeries.XTickMode      = 'auto';
                h.axesTimeSeries.YTickMode      = 'auto';
                h.axesTimeSeries.XTickLabelMode = 'auto';
                h.axesTimeSeries.YTickLabelMode = 'auto';
                h = plotCakedSingle(h, value);
            else
                cla(h.axesTimeSeries);
                text(h.axesTimeSeries, 0.5, 0.5, ...
                    sprintf('Kein gecaktes Bild für Messung #%d', ds.index), ...
                    'Units', 'normalized', 'HorizontalAlignment', 'center', ...
                    'FontSize', 11, 'Color', [0.5 0.5 0.5]);
            end
        else
            % CBF Raw — lazy laden
            h = resetAxesForCBFRaw(h);
            if ~h.dataset(value).imgLoaded && ~isempty(h.dataset(value).cbfPath)
                cla(h.axesTimeSeries);
                text(h.axesTimeSeries, 0.5, 0.5, ...
                    sprintf('Lade CBF #%d ...', ds.index), ...
                    'Units', 'normalized', 'HorizontalAlignment', 'center', ...
                    'FontSize', 12, 'Color', [0.3 0.3 0.3]);
                drawnow;
                pythonExe = strtrim(get(h.pythonExeEdit, 'String'));
                try
                    h.dataset(value).img       = loadCBF(h.dataset(value).cbfPath, pythonExe);
                    h.dataset(value).imgLoaded = true;
                catch ME
                    warning('CBFViewModeCallback: %s', strrep(ME.message,'%', '%%'));
                    h.dataset(value).img       = [];
                    h.dataset(value).imgLoaded = true;
                end
                ds = h.dataset(value);
            end
        
            cla(h.axesTimeSeries);
            if ~isempty(ds.img)
                imgLog = log10(1 + max(ds.img, 0));
                v      = imgLog(isfinite(imgLog) & imgLog > 0);
                clims  = prctile(v, [1 99]);
                imagesc(h.axesTimeSeries, imgLog);
                clim(h.axesTimeSeries, clims);
                colormap(h.axesTimeSeries, 'hot');
                colorbar(h.axesTimeSeries);
                axis(h.axesTimeSeries, 'image');
                h.axesTimeSeries.YDir          = 'reverse';
                h.axesTimeSeries.XLabel.String = 'x (px)';
                h.axesTimeSeries.YLabel.String = 'y (px)';
                h.axesTimeSeries.Title.String  = ['CBF Raw  ' titStr];
            else
                text(h.axesTimeSeries, 0.5, 0.5, ...
                    sprintf('CBF konnte nicht geladen werden (#%d)', ds.index), ...
                    'Units', 'normalized', 'HorizontalAlignment', 'center', ...
                    'FontSize', 11, 'Color', [0.5 0.5 0.5]);
            end
        end
    
        % ── Rechtes Axes: 1D-Profil ───────────────────────────────────────
        cla(h.axesTimeProfile);
        if ~isempty(ds.q) && ~isempty(ds.I)
            hold(h.axesTimeProfile, 'on');
            plot(h.axesTimeProfile, q2tth_sl(ds.q), ds.I, '-', ...
                'Color', [0.094 0.373 0.647], 'LineWidth', 1.0);
            h.axesTimeProfile.XLabel.String = xLabel_sl;
            h.axesTimeProfile.YLabel.String = 'Intensität';
            h.axesTimeProfile.XLim = [min(q2tth_sl(ds.q)) max(q2tth_sl(ds.q))];
            h.axesTimeProfile.YLim = [0  max(ds.I)*1.05];
            h.axesTimeProfile.Title.String = ['Profil  ' titStr];
        else
            text(h.axesTimeProfile, 0.5, 0.5, 'Kein 1D-Profil', ...
                'Units', 'normalized', 'HorizontalAlignment', 'center', ...
                'FontSize', 10, 'Color', [0.5 0.5 0.5]);
        end
end

% Phasenlinien nach jedem Slider-Schritt neu zeichnen
h = updatePhaseLines(h);

guidata(hObj, h);


function TimeSeriesModeCallback(hObj, ~)
h = guidata(hObj);

% CBF-Viewer-Umschalter ein-/ausblenden
isCBFViewer = strcmp(get(h.TimeSeriesModeGroup.SelectedObject,'String'), ...
                     'CBF Viewer');
if isfield(h,'CBFViewModeGroup') && isvalid(h.CBFViewModeGroup)
    set(h.CBFViewModeGroup, 'Visible', bool2vis(isCBFViewer));
end

if ~isfield(h,'dataset') || isempty(h.dataset), return; end
h = updateTimeSeriesPlot(h);
guidata(hObj, h);


function TimeSeriesYAxisCallback(hObj, ~)
h = guidata(hObj);
if ~isfield(h, 'dataset') || isempty(h.dataset), return; end
h = updateTimeSeriesPlot(h);
guidata(hObj, h);


function TimeSeriesXAxisModeCallback(hObj, ~)
h = guidata(hObj);
if ~isfield(h, 'dataset') || isempty(h.dataset), return; end
h = updateTimeSeriesPlot(h);
guidata(hObj, h);

function ExcludeZoneCallback(hObj, ~)
% Checkbox: Ausschlusszone aktivieren/deaktivieren → Plot neu zeichnen
h = guidata(hObj);
if ~isfield(h,'dataset') || isempty(h.dataset), return; end
h = updateTimeSeriesPlot(h);
guidata(hObj, h);

function HeaterColCallback(hObj, ~)
% Callback für Heater-Spalten-Popup
h = guidata(hObj);
if ~isfield(h, 'heaterData') || isempty(h.heaterData), return; end
h = updateHeaterPlot(h);
guidata(hObj, h);


function TmaxLineCallback(hObj, ~)
% Checkbox: T_max-Linie in Heatmap ein-/ausblenden
h = guidata(hObj);
h = updateTmaxLine(h);
guidata(hObj, h);


function setPhaseCallback(hObj, ~)
% Berechnet Reflexlagen für Phase ph aus dem gewählten MPD-File
h  = guidata(hObj);
ph = get(hObj, 'UserData');

% MPD-Dateiname aus Popup
mpdList = get(h.popupPhaseMPD(ph), 'String');
mpdVal  = get(h.popupPhaseMPD(ph), 'Value');
if iscell(mpdList)
    mpdName = mpdList{mpdVal};
else
    mpdName = mpdList;
end
if strcmp(mpdName, '— keine MPD —')
    errordlg('Keine MPD-Datei ausgewählt.', 'Fehler'); return
end

% Elementarformel aus Name-Feld als Sampleformel verwenden
phaseName = strtrim(get(h.editPhaseName(ph), 'String'));
if isempty(phaseName), phaseName = sprintf('Phase %d', ph); end

% Wellenlängenindex
if isfield(h, 'radiobuttonwavelength')
    selectedWL = get(h.radiobuttonwavelength.SelectedObject, 'String');
    if strcmp(selectedWL, 'Ga K-alpha'),     wlIdx = 1;
    elseif strcmp(selectedWL, 'In K-alpha'), wlIdx = 2;
    else,                                    wlIdx = 3;
    end
else
    wlIdx = 1;
end

% Reflexlagen berechnen
col = get(hObj, 'backg');
set(hObj, 'String', '...', 'BackgroundColor', [1 0.6 0.6]);
drawnow;
try
    PeaksTheo_ph = CalcPeakPositions2DXRD(phaseName, mpdName, 'ETA3000', 100);
    peaks = PeaksTheo_ph{wlIdx};
    if isstruct(peaks) && isfield(peaks, 'Peaks')
        peakMat = peaks.Peaks;
    else
        peakMat = peaks;
    end
    % Spalte 5 = Kα₁, Spalte 6 = Kα₂
    % PONI-Wellenlänge (1.340121 Å) entspricht Ga Kα₁ → Spalte 5 verwenden
    tth_pos = peakMat(:, 5);

    % Wellenlänge für q-Konversion.
    % WICHTIG: dieselbe Wellenlänge wie in CalcPeakPositions2DXRD verwenden
    % → h.lambda_m (Ga K-alpha, 1.34143847484e-10 m) hat Priorität,
    %   da CalcPeakPositions2DXRD mit genau dieser Wellenlänge rechnet.
    % Fallback: datasetLambda_m aus PONI-Header.
    lambda_m_ph = [];
    if isfield(h,'lambda_m') && ~isempty(h.lambda_m) && h.lambda_m > 0
        lambda_m_ph = h.lambda_m;           % konsistent mit CalcPeakPositions2DXRD
    elseif isfield(h,'datasetLambda_m') && ~isempty(h.datasetLambda_m) ...
            && h.datasetLambda_m > 0
        lambda_m_ph = h.datasetLambda_m;
    end

    % q direkt aus d-Abstand berechnen: q = 2π/d
    % Das ist wellenlängenunabhängig und damit auf beiden Skalen konsistent.
    % Spalte 4 von peakMat enthält d in nm.
    d_nm  = peakMat(:, 4);
    q_nm  = 2*pi ./ d_nm;      % nm⁻¹  (unabhängig von λ)
    q_ang = q_nm / 10;         % Å⁻¹

    % 2θ aus d mit der Wellenlänge aus dem PONI-File (datasetLambda_m):
    % 2θ = 2·arcsin(λ/2d)  — hier λ = datasetLambda_m für Konsistenz mit Messdaten
    if ~isempty(lambda_m_ph)
        lambda_nm_ph = lambda_m_ph * 1e9;   % m → nm
        % tth_pos wurde bereits oben gesetzt (Spalte 5 = Kα₁)
        % Für die q-Skala ist tth_pos irrelevant — q kommt aus d-Abstand
    else
        warning('setPhaseCallback: Keine Wellenlänge — 2θ-Modus ggf. ungenau.');
    end

    h.phaseData{ph} = struct( ...
        'tth',    tth_pos, ...
        'q_ang',  q_ang, ...
        'q_nm',   q_nm, ...
        'hkl',    peakMat(:,1:3), ...
        'name',   phaseName, ...
        'mpd',    mpdName, ...
        'wlIdx',  wlIdx);

    set(h.cbPhase(ph), 'Value', 1);
    h = updatePhaseLines(h);

    set(hObj, 'String', char(8635), 'BackgroundColor', h.phaseColors{ph});
    msgbox(sprintf('Phase %d: %d Reflexe  |  %s  |  %s', ...
        ph, numel(tth_pos), phaseName, mpdName), 'Reflexe berechnet');
catch ME
    set(hObj, 'String', char(8635), 'BackgroundColor', h.phaseColors{ph});
    errordlg(sprintf('Fehler: %s', ME.message), 'Phase konnte nicht berechnet werden');
end
guidata(hObj, h);


function phaseLineCallback(hObj, ~)
% Checkbox: Phasenlinien ein-/ausblenden
h = guidata(hObj);
h = updatePhaseLines(h);
guidata(hObj, h);


function openfilecallback_legacy(hObj, ~)
h = guidata(hObj);

% ── 1. TIF-Dateien auswählen ─────────────────────────────────────────
[file, location] = uigetfile( ...
    {'*.tif;*.tiff','Gecaked TIF (*.tif)'}, ...
    'Gecakte TIF-Dateien auswählen', 'MultiSelect','on', ...
    'D:\EDDIDAT_github\Data\Results\Pilatus-2DXRD\');

if isequal(file, 0), return; end
if ~iscell(file), file = {file}; end

total = numel(file);
h.FileNameLoad = file;
h.IntensityProfiles = cell(1, total);

% BinSize aus Edit-Feld (ist in neuer GUI als trackChiBinEdit vorhanden)
h.BinSize = str2double(get(h.trackChiBinEdit, 'String'));
set(h.FileNameEditField, 'String', strjoin(string(file), ', '));

% ── 2. Intensitätsprofile laden ──────────────────────────────────────
col = get(hObj, 'backg');
set(hObj, 'String', 'Lade TIF ...', 'backg', [1 .6 .6]); pause(0.01);

for k = 1:total
    try
        [h.IntensityProfiles{k}, Info] = ...
            Conversion_2D_XRD(fullfile(location, file{k}), h.BinSize);
    catch ME
        errordlg(sprintf('Fehler beim Laden:\n%s\n%s', file{k}, ME.message));
        set(hObj, 'String', 'Load 2D image(s)', 'backg', col); return
    end
end
h.ImageInfo = Info;

% ── 3. Alpha aus Dateinamen parsen ───────────────────────────────────
for k = 1:total
    tok = regexp(file{k}, '(?<=chi_)([\d.+-]+)(?=-caked\.tif)', 'match');
    if ~isempty(tok)
        h.alpha(k) = str2double(tok{1});
    else
        h.alpha(k) = 0;
    end
end
set(h.AlphaEditField, 'String', strjoin(string(h.alpha), ', '));

% ── 4. Gamma-TXT-Datei laden ─────────────────────────────────────────
set(hObj, 'String', 'Load 2D image(s)', 'backg', col);
guidata(hObj, h);
opengammafilecallback_legacy(hObj);  % direkt weiter zum Gamma-Schritt


function opengammafilecallback_legacy(hObj, ~)
h = guidata(hObj);

[file, location] = uigetfile('*.txt', ...
    'Gamma-TXT-Datei(en) auswählen', 'MultiSelect','on', ...
    'D:\EDDIDAT_github\Data\Results\Pilatus-2DXRD\');

if isequal(file, 0), return; end
if ~iscell(file), file = {file}; end

total = numel(file);
set(h.GammaFileNameEditField, 'String', strjoin(string(file), ', '));

data = cell(1, total);
for k = 1:total
    data{k} = readmatrix(fullfile(location, file{k}));
end

% ── Theta/Gamma aus Kalibrierungsdatei berechnen ─────────────────────
for k = 1:total
    h.pixelradial{k}   = unique(data{k}(:,1));
    pixeltheta         = h.pixelradial{k}(1) : h.pixelradial{k}(2);
    h.pixelazimuthal{k}= unique(data{k}(:,2));
    pixelgamma         = h.pixelazimuthal{k}(1) : h.pixelazimuthal{k}(2);
    h.theta{k}         = unique(data{k}(:,3));
    gammatmp           = unique(data{k}(:,4));
    gammafit           = polyfit(h.pixelazimuthal{k}, gammatmp, 1);
    h.gamma{k}         = gammafit(2) + gammafit(1)*pixelgamma;
    h.thetafit{k}      = polyfit(h.pixelradial{k}, h.theta{k}, 1);
end

% ── BinnedGamma berechnen ─────────────────────────────────────────────
for k = 1:numel(h.thetafit)
    h.BinnedGamma{k} = CalcBinnedGamma(h.gamma{k}, h.BinSize, h.ImageInfo.Height);
end

% ── dataX aus thetafit aufbauen ───────────────────────────────────────
dataXtmp = 0:999;
for k = 1:numel(h.thetafit)
    dataX{k} = (h.thetafit{k}(2) + h.thetafit{k}(1).*dataXtmp)';
end

% ── GEMEINSAME FELDER befüllen ────────────────────────────────────────
% (identisch mit dem pyFAI-Weg nach runBinning)
h.dataX         = dataX;
h.dataXBackup   = dataX;
h.dataY         = h.IntensityProfiles;

% dataXPlot / dataYPlot für Checkbox "Plot all profiles"
dataX_exp = cellfun(@(x, y) repmat(x, 1, size(y,2)), ...
    dataX, h.IntensityProfiles, 'UniformOutput', false);
h.dataXPlot       = cell2mat(dataX_exp);
h.dataXPlotBackup = h.dataXPlot;
h.dataYPlot       = cell2mat(h.IntensityProfiles);
h.dataYPlotBackup = h.dataYPlot;
h.IntensityProfiles = h.IntensityProfiles;  % schon gesetzt

% dataXBackup für changetwothetarangecallback
h.dataXBackup = dataX;

% ── Slider konfigurieren ─────────────────────────────────────────────
nProf = numel(h.IntensityProfiles) * size(h.IntensityProfiles{1}, 2);
set(h.Slider, 'Min', 1, 'Max', max(nProf,2), ...
    'SliderStep', [1/max(nProf-1,1) 1/max(nProf-1,1)], 'Value', 1);

% ── Plot initialisieren ───────────────────────────────────────────────
set(h.plotIntensityData, ...
    'XData', h.dataXPlot(:,1), 'YData', h.dataYPlot(:,1), 'Visible','on');
set(h.axesPlotIntensityData, 'XLimMode', 'auto');

% ── Theoretische Peaks (falls Sample bereits geladen) ────────────────
if isfield(h, 'PeaksTheo')
    wlIdx = 1;  % Ga K-alpha als Default
    for k = 1:size(h.PeaksTheo, 2)
        pm      = h.PeaksTheo{k}.Peaks(:,5:6);
        pm      = mean(pm, 2)';
        idx     = pm >= round(min(dataX{1})) & pm <= round(max(dataX{1}));
        PeakPos{k}       = pm(idx);
        hkl{k}           = h.PeaksTheo{k}.Peaks(idx, 1:3);
        rowsAsStrings{k} = arrayfun(@(r) strtrim(sprintf('%g %g %g', ...
            hkl{k}(r,:))), 1:size(hkl{k},1), 'UniformOutput',false);
        hkltabledata{k}  = [hkl{k} PeakPos{k}' zeros(numel(PeakPos{k}),2)];
    end
    h.PeakPos       = PeakPos;
    h.rowsAsStrings = rowsAsStrings;
    
    set(h.dekdataGaKalpha, 'data', hkltabledata{1});
    set(h.dekdataInKalpha, 'data', hkltabledata{2});
    set(h.dekdataInKbeta,  'data', hkltabledata{3});

    if isfield(h, 'plotpeakstheo') && ~isempty(h.plotpeakstheo) && all(isvalid(h.plotpeakstheo))
        delete(h.plotpeakstheo);
    end
    h.plotpeakstheo = xline(h.axesPlotIntensityData, PeakPos{1}, '--r', ...
        rowsAsStrings{1}, 'LabelVerticalAlignment','middle', ...
        'LabelHorizontalAlignment','left');
    set(h.tableDECFittedPeaks, 'ColumnFormat', ...
        {'numeric', (cellfun(@num2str,num2cell(PeakPos{1}'),'UniformOutput',false))', ...
         'numeric','numeric','numeric','numeric','numeric','numeric'});
end

% Rebin-Button aktivieren
set(h.RebinButton, 'Enable', 'on');

% Tab wechseln
h.plottab.SelectedTab = h.plottab4;

guidata(hObj, h);

function inputModeChangedCallback(hObj, ~)
h = guidata(hObj);

isPyFAI = get(h.rb_pyfai, 'Value') == 1;

% pyFAI-spezifische Elemente
pyFAI_elems = {'LoadGammaDataButton', 'pythonExeText', 'pythonExeEdit', ...
               'scriptPathText', 'scriptPathEdit', 'PyFAIParamText', ...
               'trackChiRangeMinText', 'trackChiRangeMinEdit', ...
               'trackChiRangeMaxText', 'trackChiRangeMaxEdit', ...
               'trackChiBinText', 'trackChiBinEdit', ...
               'trackChiAvgBinsText', 'trackChiAvgBinsEdit', ...
               'smoothPointsText', 'smoothPointsEdit', ...
               'baselineModeText', 'baselineModePopup', 'RebinButton'};
for k = 1:numel(pyFAI_elems)
    fn = pyFAI_elems{k};
    if isfield(h, fn) && isvalid(h.(fn))
        set(h.(fn), 'Visible', bool2vis(isPyFAI));
    end
end

% Im Legacy-Modus: LoadImageButton-Callback umschalten
if isPyFAI
    set(h.LoadImageButton,    'Callback', @openfilecallback);
    set(h.LoadGammaDataButton,'Callback', @opengammafilecallback);
    set(h.LoadGammaDataButton,'String',   'Load PONI Files');
    set(h.AlphaText1, 'String', char(945));  % α
else
    set(h.LoadImageButton,    'Callback', @openfilecallback_legacy);
    set(h.LoadGammaDataButton,'Callback', @opengammafilecallback_legacy);
    set(h.LoadGammaDataButton,'String',   'Load Gamma *.txt');
    set(h.AlphaText1, 'String', char(945));
end

guidata(hObj, h);

function tsDefineBGCallback(hObj, ~)
h = guidata(hObj);

if ~isfield(h,'dataset') || isempty(h.dataset)
    errordlg('Bitte zuerst ein Dataset laden.','Kein Dataset'); return
end

% Zum Single-Profile-Modus wechseln damit axesTimeProfile sichtbar ist
set(h.rb_ts_singleprofile, 'Value', 1);
h = applyTimeSeriesLayout(h, 'bottom');

% Aktuelles Referenzprofil holen
idx = max(1, round(get(h.SliderTimeSeries,'Value')));
idx = min(idx, numel(h.dataset));
ds  = h.dataset(idx);

[xData, xLabel] = getTSXData(h, ds);
if isempty(xData) || isempty(ds.I)
    errordlg('Kein Profil verfügbar.','Fehler'); return
end
I = double(ds.I(:));
x = xData(:);

% Rohspektrum zeigen
% x-Bereich einschränken
[xMin, xMax] = getTSXRange(h);
if isempty(xMin), xMin = min(x); end
if isempty(xMax), xMax = max(x); end

if xMin >= xMax
    errordlg('x-Minimum muss kleiner als x-Maximum sein.','Bereichsfehler');
    return
end

% Bereich auf verfügbare Daten klemmen
xMin = max(xMin, min(x));
xMax = min(xMax, max(x));

% Maske anwenden
idxRange = (x >= xMin) & (x <= xMax);
if sum(idxRange) < 10
    errordlg(sprintf('Zu wenige Datenpunkte im Bereich [%.4f, %.4f].', ...
        xMin, xMax), 'Bereichsfehler');
    return
end
xR = x(idxRange);
IR = I(idxRange);

% Bereich in h speichern für nachfolgende Schritte
h.tsXRange = [xMin, xMax];

% Rohspektrum zeigen — nur im gewählten Bereich
cla(h.axesTimeProfile);
hold(h.axesTimeProfile,'on');
plot(h.axesTimeProfile, xR, IR, '-', 'Color',[0.75 0.75 0.75], 'LineWidth',0.8);
h.axesTimeProfile.XLabel.String = xLabel;
h.axesTimeProfile.YLabel.String = 'Intensität';
h.axesTimeProfile.Title.String  = sprintf('Profil #%d  –  BG-Punkte klicken  [%.4f – %.4f]', ...
    ds.index, xMin, xMax);
h.axesTimeProfile.XLim = [xMin, xMax];
drawnow;

uiwait(msgbox(sprintf(['Untergrundpunkte definieren:\n' ...
    '  Pro Peak-Gruppe: 1 Punkt LINKS, 1 Punkt RECHTS.\n' ...
    'Enter nach jedem Klick. Doppelt-Enter zum Beenden.\n\n' ...
    'x-Bereich: %.4f – %.4f'], xMin, xMax)));

[bgX, ~] = getpts(h.axesTimeProfile);

if numel(bgX) < 2 || mod(numel(bgX),2) ~= 0
    errordlg('Gerade Anzahl Punkte klicken (links + rechts pro Gruppe).','Eingabefehler');
    return
end
bgX = sort(bgX);
nG  = numel(bgX) / 2;
h.tsBgIntervals = zeros(nG, 2);
for g = 1:nG
    h.tsBgIntervals(g,:) = [bgX(2*g-1), bgX(2*g)];
end

% BG-korrigiertes Spektrum berechnen (nur im eingeschränkten Bereich)
[Xcorr, Ycorr, Ybkg] = tsBGSubtract(xR, IR, h.tsBgIntervals);
h.tsXcorrExample = Xcorr;
h.tsYcorrExample = Ycorr;

% BG-Linie + korrigiertes Spektrum einzeichnen
plot(h.axesTimeProfile, xR, Ybkg, '--', 'Color',[0.8 0.4 0], 'LineWidth',1.2);
plot(h.axesTimeProfile, Xcorr, Ycorr, '-', 'Color',[0.094 0.373 0.647], 'LineWidth',1.2);
for g = 1:nG
    plot(h.axesTimeProfile, h.tsBgIntervals(g,:), ...
        interp1(xR, Ybkg, h.tsBgIntervals(g,:),'linear','extrap'), ...
        'v', 'Color',[0.8 0.4 0], 'MarkerFaceColor',[0.8 0.4 0], 'MarkerSize',8);
end
h.axesTimeProfile.Title.String = sprintf('BG definiert (%d Gruppe(n))  –  Profil #%d', nG, ds.index);

set(h.TSDefinePeaksButton, 'Enable','on');
set(h.TSPickPeaksHeatmapButton, 'Enable','on');
guidata(hObj, h);


function tsDefinePeaksCallback(hObj, ~)
h = guidata(hObj);

if ~isfield(h,'tsBgIntervals') || isempty(h.tsBgIntervals)
    errordlg('Bitte zuerst "1. Define BG" ausführen.','Fehler'); return
end

idx = max(1, round(get(h.SliderTimeSeries,'Value')));
idx = min(idx, numel(h.dataset));
ds  = h.dataset(idx);

[xData, xLabel] = getTSXData(h, ds);
if isempty(xData), return; end

% x-Bereich aus vorherigem Schritt übernehmen (oder Edit-Felder lesen)
if isfield(h,'tsXRange') && ~isempty(h.tsXRange)
    xMin = h.tsXRange(1);
    xMax = h.tsXRange(2);
else
    [xMin, xMax] = getTSXRange(h);
    if isempty(xMin), xMin = min(xData); end
    if isempty(xMax), xMax = max(xData); end
end

idxRange = (xData >= xMin) & (xData <= xMax);
xData    = xData(idxRange);
I_ds     = double(ds.I(idxRange));

[Xcorr, Ycorr, ~] = tsBGSubtract(xData, I_ds, h.tsBgIntervals);

% BG-korrigiertes Spektrum anzeigen
cla(h.axesTimeProfile);
hold(h.axesTimeProfile,'on');
plot(h.axesTimeProfile, Xcorr, Ycorr, '-', 'Color',[0.094 0.373 0.647], 'LineWidth',1.2);
h.axesTimeProfile.XLabel.String = xLabel;
h.axesTimeProfile.YLabel.String = 'Intensität (BG-korr.)';
h.axesTimeProfile.Title.String  = 'Peaks klicken – Enter zum Bestätigen';
drawnow;

uiwait(msgbox(['Alle Peakpositionen im BG-korrigierten Spektrum anklicken.' newline ...
    'Enter nach jedem Klick, Doppelt-Enter zum Beenden.']));

[UP, ~] = getpts(h.axesTimeProfile);
if isempty(UP)
    errordlg('Keine Peaks definiert.','Fehler'); return
end
UP = sort(UP);
h.tsUserPeaks = UP;

% BG-Regionen pro Peak ableiten
nPeaks = numel(UP);
h.tsBgRegions = cell(nPeaks,1);
for pk = 1:nPeaks
    for g = 1:size(h.tsBgIntervals,1)
        if UP(pk) > h.tsBgIntervals(g,1) && UP(pk) < h.tsBgIntervals(g,2)
            h.tsBgRegions{pk} = h.tsBgIntervals(g,:);
            break
        end
    end
end

% Peak-Marker zeichnen
for pk = 1:nPeaks
    yPk = interp1(Xcorr, Ycorr, UP(pk), 'linear', 'extrap');
    plot(h.axesTimeProfile, UP(pk), max(yPk,0), '^', ...
        'Color','r', 'MarkerFaceColor','r', 'MarkerSize',8);
end
h.axesTimeProfile.Title.String = sprintf('%d Peak(s) definiert  –  Profil #%d', nPeaks, ds.index);

set(h.TSFitAllButton, 'Enable','on');
set(h.TSFitBoundsButton, 'Enable','on');
guidata(hObj, h);


function tsPickPeaksHeatmapCallback(hObj, ~)
h = guidata(hObj);

% Prüfen ob Heatmap aktiv ist
selectedMode = get(h.TimeSeriesModeGroup.SelectedObject, 'String');
if ~strcmp(selectedMode, 'Heatmap')
    errordlg('Bitte zuerst in den Heatmap-Modus wechseln.', 'Fehler');
    return
end

% X-Achsen-Modus bestimmen (2theta oder q)
if isfield(h,'TimeSeriesXAxisGroup') && isvalid(h.TimeSeriesXAxisGroup)
    use2theta = strcmp(get(h.TimeSeriesXAxisGroup.SelectedObject,'String'), '2θ');
else
    use2theta = false;
end

if use2theta
    unitStr = '2θ (°)';
else
    unitStr = 'q (Å^{-1})';
end

h.axesTimeSeries.Title.String = ...
    sprintf('Peaks anklicken (%s) – Enter zum Beenden', unitStr);
drawnow;

% Horizontale Markierungslinien + Klick-Schleife
peakPositions = [];
hLines = [];
hold(h.axesTimeSeries, 'on');

while true
    try
        [~, yClick, button] = ginput(1);
    catch
        break
    end
    if isempty(button) || button == 27  % Enter oder Escape
        break
    end
    if button == 3  % Rechtsklick → letzte Linie entfernen
        if ~isempty(peakPositions)
            delete(hLines(end));
            hLines(end) = [];
            peakPositions(end) = [];
        end
        continue
    end

    peakPositions(end+1) = yClick; %#ok<AGROW>
    hL = yline(h.axesTimeSeries, yClick, 'r-', ...
        sprintf('%.3f', yClick), 'LineWidth', 1.5, ...
        'LabelHorizontalAlignment', 'left', 'FontSize', 8);
    hLines(end+1) = hL; %#ok<AGROW>
end

if isempty(peakPositions)
    h.axesTimeSeries.Title.String = 'Keine Peaks ausgewählt';
    guidata(hObj, h);
    return
end

% h neu laden, damit zwischenzeitliche Änderungen (z.B. tsXRange) erhalten bleiben
h = guidata(hObj);

peakPositions = sort(peakPositions);
h.tsUserPeaks = peakPositions(:);
nPeaks = numel(peakPositions);

% ── Automatische BG-Intervalle: ±0.7 um jeden Peak ──────────────────
BG_HALF_WIDTH = 1.2;
bgIntervals = zeros(nPeaks, 2);
for pk = 1:nPeaks
    bgIntervals(pk,:) = [peakPositions(pk) - BG_HALF_WIDTH, ...
                          peakPositions(pk) + BG_HALF_WIDTH];
end

% Überlappende Intervalle zusammenführen
merged = bgIntervals(1,:);
for pk = 2:nPeaks
    if bgIntervals(pk,1) <= merged(end,2)
        merged(end,2) = max(merged(end,2), bgIntervals(pk,2));
    else
        merged(end+1,:) = bgIntervals(pk,:); %#ok<AGROW>
    end
end
h.tsBgIntervals = merged;

% BG-Regionen pro Peak zuordnen
h.tsBgRegions = cell(nPeaks, 1);
for pk = 1:nPeaks
    for g = 1:size(merged, 1)
        if peakPositions(pk) >= merged(g,1) && peakPositions(pk) <= merged(g,2)
            h.tsBgRegions{pk} = merged(g,:);
            break
        end
    end
end

% x-Bereich NICHT automatisch einschränken — Benutzer kann manuell setzen

% ── Zum Single Profile wechseln und Markierungen anzeigen ────────────
set(h.rb_ts_singleprofile, 'Value', 1);
h = applyTimeSeriesLayout(h, 'bottom');

idx = max(1, round(get(h.SliderTimeSeries, 'Value')));
idx = min(idx, numel(h.dataset));
ds  = h.dataset(idx);

[xData, xLabel] = getTSXData(h, ds);
if ~isempty(xData) && ~isempty(ds.I)
    I = double(ds.I(:));
    x = xData(:);

    cla(h.axesTimeProfile);
    hold(h.axesTimeProfile, 'on');

    % Rohdaten plotten
    plot(h.axesTimeProfile, x, I, '-', 'Color', [0.094 0.373 0.647], 'LineWidth', 1.0);

    % BG-Grenzen als vertikale Linien markieren
    yLims = [min(I) max(I)];
    for g = 1:size(merged, 1)
        xline(h.axesTimeProfile, merged(g,1), '--', 'Color', [0.8 0.4 0], 'LineWidth', 1.0);
        xline(h.axesTimeProfile, merged(g,2), '--', 'Color', [0.8 0.4 0], 'LineWidth', 1.0);
    end

    % Peak-Positionen als vertikale Linien markieren
    for pk = 1:nPeaks
        xline(h.axesTimeProfile, peakPositions(pk), 'r-', ...
            sprintf('Peak %d', pk), 'LineWidth', 1.2, ...
            'LabelOrientation', 'horizontal', 'LabelVerticalAlignment', 'top');
    end

    h.axesTimeProfile.XLabel.String = xLabel;
    h.axesTimeProfile.YLabel.String = 'Intensität';
    h.axesTimeProfile.XLimMode = 'auto';
    h.axesTimeProfile.YLimMode = 'auto';
    h.axesTimeProfile.Title.String = ...
        sprintf('%d Peak(s) + auto-BG (±%.1f)  –  Profil #%d  –  BG/Peaks anpassbar', ...
        nPeaks, BG_HALF_WIDTH, ds.index);
end

% Titel der Heatmap aktualisieren
h.axesTimeSeries.Title.String = ...
    sprintf('Heatmap – %d Peak(s) definiert', nPeaks);

set(h.TSDefineBGButton, 'Enable', 'on');
set(h.TSDefinePeaksButton, 'Enable', 'on');
set(h.TSFitAllButton, 'Enable', 'on');
set(h.TSFitBoundsButton, 'Enable', 'on');
guidata(hObj, h);

fprintf('tsPickPeaksHeatmap: %d Peaks definiert (auto-BG ±%.1f):\n', nPeaks, BG_HALF_WIDTH);
for pk = 1:nPeaks
    fprintf('  Peak %d: %.4f %s  BG=[%.4f, %.4f]\n', ...
        pk, peakPositions(pk), unitStr, bgIntervals(pk,1), bgIntervals(pk,2));
end


function tsFitAllCallback(hObj, ~)
h = guidata(hObj);

if ~isfield(h,'tsUserPeaks') || isempty(h.tsUserPeaks)
    errordlg('Bitte zuerst Peaks definieren.','Keine Peaks'); return
end

N      = numel(h.dataset);
nPeaks = numel(h.tsUserPeaks);

% ── Peak-Modell bestimmen ─────────────────────────────────────────────
peakModel = 'symmetric';
if isfield(h,'tsPeakModel'), peakModel = h.tsPeakModel; end

switch peakModel
    case 'asymmetric'
        nParamsPerPeak = 5;
        fitFunc        = @multiPseudoVoigtAsym;
    case 'kalpha12'
        nParamsPerPeak = 4;
        fitFunc        = @multiPseudoVoigtKalpha12;
    otherwise
        nParamsPerPeak = 4;
        fitFunc        = @multiPseudoVoigt;
end
useAsym = strcmp(peakModel, 'asymmetric');

% ── Ergebnis-Struct initialisieren ────────────────────────────────────
r.time_min   = zeros(N,1);
r.peakPos    = NaN(N, nPeaks);
r.peakPosErr = NaN(N, nPeaks);
r.amplitude  = NaN(N, nPeaks);
r.fwhm       = NaN(N, nPeaks);
r.eta        = NaN(N, nPeaks);
r.R2         = NaN(N, nPeaks);
r.xUnit      = '';
r.peakModel  = h.tsPeakModel;
if useAsym
    r.fwhmL = NaN(N, nPeaks);
    r.fwhmR = NaN(N, nPeaks);
end

% ── Temperatur falls vorhanden ────────────────────────────────────────
r.temperature = NaN(N,1);
if isfield(h,'heaterData') && ~isempty(h.heaterData)
    hd = h.heaterData;
    colPopupStr = get(h.HeaterColPopup,'String');
    colVal      = get(h.HeaterColPopup,'Value');
    if iscell(colPopupStr) && colVal <= numel(colPopupStr)
        colFn = matlab.lang.makeValidName(colPopupStr{colVal});
        if isfield(hd, colFn)
            tempVec = hd.(colFn);
            for i = 1:N
                t_i = h.dataset(i).time_s / 60;
                [~,iT] = min(abs(hd.time_min - t_i));
                r.temperature(i) = tempVec(iT);
            end
        end
    end
end

col = get(hObj,'backg');
set(hObj,'String','Fit läuft ...','backg',[1 .6 .6]);
set(h.TSFitStatusText,'String','Initialisiere ...');
drawnow;

opts_pV = optimoptions('lsqcurvefit', 'Display','off', ...
    'MaxFunctionEvaluations', 5000, 'MaxIterations', 1000, ...
    'FunctionTolerance', 1e-10, 'StepTolerance', 1e-8);

% ── Peak-Gruppen aus BG-Intervallen ───────────────────────────────────
PeakPos    = h.tsUserPeaks(:);
bgXall     = sort(h.tsBgIntervals(:)');
PeakGroups = cell(0,1);
for g = 1:numel(bgXall)-1
    inInt = find((PeakPos > bgXall(g)) & (PeakPos < bgXall(g+1)));
    if ~isempty(inInt), PeakGroups{end+1} = inInt; end %#ok<AGROW>
end
if isempty(PeakGroups)
    PeakGroups = num2cell((1:nPeaks)');
end

% ── windowDeg und Fit-Grenzen vor dem Loop lesen ──────────────────────
windowDeg = str2double(get(h.PeakWindowEditField,'String'));
if isnan(windowDeg), windowDeg = 1.0; end

if isfield(h,'tsFitBounds') && ~isempty(h.tsFitBounds)
    fb = h.tsFitBounds;
else
    fb = struct();
end

% ── Haupt-Loop über alle Profile ──────────────────────────────────────
for i = 1:N
    ds = h.dataset(i);

    if isfield(ds,'time_s')
        r.time_min(i) = ds.time_s / 60;
    else
        r.time_min(i) = i;
    end

    % t-Bereich: Profil überspringen wenn außerhalb
    if isfield(h, 'tsTRange') && ~isempty(h.tsTRange)
        if r.time_min(i) < h.tsTRange(1) || r.time_min(i) > h.tsTRange(2)
            continue
        end
    end

    if isempty(ds.q) || isempty(ds.I), continue; end

    [xData, xUnit] = getTSXData(h, ds);
    r.xUnit = xUnit;
    if isempty(xData) || numel(xData) ~= numel(ds.I), continue; end

    % x-Bereich einschränken
    if isfield(h,'tsXRange') && ~isempty(h.tsXRange)
        idxFit = (xData >= h.tsXRange(1)) & (xData <= h.tsXRange(2));
        if sum(idxFit) < 5, continue; end
        xData = xData(idxFit);
        I     = double(ds.I(idxFit));
    else
        I = double(ds.I(:));
    end

    % Untergrundkorrektur
    [Xcorr, Ycorr, ~] = tsBGSubtract(xData(:), I, h.tsBgIntervals);
    if numel(Xcorr) < 5, continue; end

    dx      = mean(diff(Xcorr));
    halfWin = max(20, round(windowDeg / max(dx, 1e-6)));

    % ── Peak-Gruppen-Fit ──────────────────────────────────────────────
    for g = 1:numel(PeakGroups)
        pkIdxGrp = PeakGroups{g};
        nPkG     = numel(pkIdxGrp);
        pkFirst  = pkIdxGrp(1);
        pkLast   = pkIdxGrp(end);

        % Fit-Fenster bestimmen
        bgR = h.tsBgRegions{pkFirst};
        if ~isempty(bgR)
            [~,iL] = min(abs(Xcorr - bgR(1)));
            [~,iR] = min(abs(Xcorr - bgR(2)));
        else
            [~,iL] = min(abs(Xcorr - PeakPos(pkFirst)));
            [~,iR] = min(abs(Xcorr - PeakPos(pkLast)));
            iL = max(1, iL - halfWin);
            iR = min(numel(Xcorr), iR + halfWin);
        end
        iL = max(1, iL); iR = min(numel(Xcorr), iR);
        if iR - iL < 4, continue; end

        Xfit = Xcorr(iL:iR);
        Yfit = Ycorr(iL:iR);

        % ── Startwerte und Grenzen pro Peak ───────────────────────────
        p0 = zeros(1, nParamsPerPeak*nPkG);
        lb = zeros(1, nParamsPerPeak*nPkG);
        ub = zeros(1, nParamsPerPeak*nPkG);

        for ki = 1:nPkG
            pkIdx = pkIdxGrp(ki);
            pos   = PeakPos(pkIdx);

            % Amplitudenabschätzung
            win    = windowDeg * 0.5;
            ampEst = max(Yfit(abs(Xfit-pos) <= win), [], 'all');
            if isempty(ampEst) || ~isfinite(ampEst) || ampEst <= 0
                ampEst = max(Yfit) * 0.5;
            end

            % Per-Peak Grenzen aus tsFitBounds
            pk_amp_min  = getBound(fb, 'amp_min',  pkIdx, 0);
            pk_amp_max  = getBound(fb, 'amp_max',  pkIdx, Inf);
            pk_pos_lb   = getBound(fb, 'pos_lb',   pkIdx, 1.0);
            pk_pos_ub   = getBound(fb, 'pos_ub',   pkIdx, 1.0);
            pk_fwhm_min = getBound(fb, 'fwhm_min', pkIdx, 0.1);
            pk_fwhm_max = getBound(fb, 'fwhm_max', pkIdx, 1.5);

            idxRange = nParamsPerPeak*(ki-1)+1 : nParamsPerPeak*ki;

            if useAsym
                pk_fwhm_min_r = getBound(fb, 'fwhm_min_r', pkIdx, 0.1);
                pk_fwhm_max_r = getBound(fb, 'fwhm_max_r', pkIdx, 1.5);
                p0(idxRange)  = [ampEst,      pos,              0.10,         0.10,           0.5];
                lb(idxRange)  = [pk_amp_min,  pos-pk_pos_lb,   pk_fwhm_min,  pk_fwhm_min_r,  0  ];
                ub(idxRange)  = [pk_amp_max,  pos+pk_pos_ub,   pk_fwhm_max,  pk_fwhm_max_r,  1  ];
            else
                p0(idxRange)  = [ampEst,      pos,              0.10,         0.5];
                lb(idxRange)  = [pk_amp_min,  pos-pk_pos_lb,   pk_fwhm_min,  0  ];
                ub(idxRange)  = [pk_amp_max,  pos+pk_pos_ub,   pk_fwhm_max,  1  ];
            end
        end

        % ── Fit ausführen ─────────────────────────────────────────────
        try
            [pFit,~,resid,~,~,~,jac] = lsqcurvefit(...
                fitFunc, p0, Xfit, Yfit, lb, ub, opts_pV);

            SStot = sum((Yfit - mean(Yfit)).^2);
            Rsq   = 1 - sum(resid.^2) / max(SStot, eps);

            [~,R] = qr(jac,0);
            Rinv  = R \ eye(size(R));
            rmse  = norm(resid) / sqrt(max(numel(resid)-numel(pFit), 1));
            SE    = sqrt(sum(Rinv.*Rinv, 2)) * rmse;

            for ki = 1:nPkG
                pkIdx = pkIdxGrp(ki);
                iP    = nParamsPerPeak*(ki-1)+(1:nParamsPerPeak);
                r.peakPos(i,pkIdx)    = pFit(iP(2));
                r.peakPosErr(i,pkIdx) = SE(iP(2));
                r.amplitude(i,pkIdx)  = pFit(iP(1));
                if useAsym
                    r.fwhmL(i,pkIdx) = abs(pFit(iP(3)));
                    r.fwhmR(i,pkIdx) = abs(pFit(iP(4)));
                    r.fwhm(i,pkIdx)  = (abs(pFit(iP(3))) + abs(pFit(iP(4)))) / 2;
                    r.eta(i,pkIdx)   = pFit(iP(5));
                else
                    r.fwhm(i,pkIdx)  = abs(pFit(iP(3)));
                    r.eta(i,pkIdx)   = pFit(iP(4));
                end
                r.R2(i,pkIdx) = Rsq;
            end
        catch
            % Fit fehlgeschlagen → NaN bleibt
        end
    end

    if mod(i,20)==0 || i==N
        set(h.TSFitStatusText,'String',sprintf('%d / %d', i, N));
        drawnow;
    end
end

h.tsFitResults = r;

% ── Ergebnis darstellen ───────────────────────────────────────────────
h = applyTSResultsLayout(h, true);
h = updateTSFitResultsPlot(h);

set(h.TSFitResultPopup, 'Enable','on');
set(h.TSFitExportButton,'Enable','on');
set(hObj,'String','3. Fit All','backg',col);

switch peakModel
    case 'asymmetric', modelLabel = 'Split-PV';
    case 'kalpha12',   modelLabel = 'Kalpha1/2';
    otherwise,         modelLabel = 'Pseudo-Voigt';
end
set(h.TSFitStatusText,'String', ...
    sprintf('%d Profile | %d Peak(s) | %s | R²_min=%.2f', ...
    N, nPeaks, modelLabel, min(r.R2(isfinite(r.R2)))));

h = updateTimeSeriesPlot(h);
guidata(hObj, h);


function tsFitResultPopupCallback(hObj, ~)
h = guidata(hObj);
if ~isfield(h,'tsFitResults') || isempty(h.tsFitResults), return; end
h = updateTSFitResultsPlot(h);
guidata(hObj, h);

function tsFitExportCallback(hObj, ~)
h = guidata(hObj);
if ~isfield(h,'tsFitResults') || isempty(h.tsFitResults)
    errordlg('Keine Fit-Ergebnisse vorhanden.','Fehler'); return
end

[fn, pn] = uiputfile('*.txt','Fit-Ergebnisse exportieren',[General.ProgramInfo.Path,'Data\Results\Pilatus-2DXRD\']);
if isequal(fn,0), return; end

r       = h.tsFitResults;
nPeaks  = size(r.peakPos,2);
hasTemp = any(isfinite(r.temperature));

% Prüfen ob asymmetrische FWHM vorhanden
hasAsym = isfield(r,'fwhmL') && isfield(r,'fwhmR');

fid = fopen(fullfile(pn,fn),'w');

% Header
if hasTemp
    fprintf(fid,'%s\t%s\t', 'Zeit_min', 'T_deg');
else
    fprintf(fid,'%s\t', 'Zeit_min');
end
for pk = 1:nPeaks
    if hasAsym
        fprintf(fid, ...
            'Peak%d_Pos\tPeak%d_Err\tPeak%d_Amp\tPeak%d_FWHM_L\tPeak%d_FWHM_R\tPeak%d_Eta\tPeak%d_R2\t', ...
            pk,pk,pk,pk,pk,pk,pk);
    else
        fprintf(fid, ...
            'Peak%d_Pos\tPeak%d_Err\tPeak%d_Amp\tPeak%d_FWHM\tPeak%d_Eta\tPeak%d_R2\t', ...
            pk,pk,pk,pk,pk,pk);
    end
end
fprintf(fid,'\r\n');

% Daten
N = numel(r.time_min);
for i = 1:N
    if hasTemp
        fprintf(fid,'%.4f\t%.2f\t', r.time_min(i), r.temperature(i));
    else
        fprintf(fid,'%.4f\t', r.time_min(i));
    end
    for pk = 1:nPeaks
        if hasAsym
            fprintf(fid,'%.6f\t%.6f\t%.4f\t%.6f\t%.6f\t%.4f\t%.4f\t', ...
                r.peakPos(i,pk), r.peakPosErr(i,pk), r.amplitude(i,pk), ...
                r.fwhmL(i,pk), r.fwhmR(i,pk), r.eta(i,pk), r.R2(i,pk));
        else
            fprintf(fid,'%.6f\t%.6f\t%.4f\t%.6f\t%.4f\t%.4f\t', ...
                r.peakPos(i,pk), r.peakPosErr(i,pk), r.amplitude(i,pk), ...
                r.fwhm(i,pk), r.eta(i,pk), r.R2(i,pk));
    end
    end
    fprintf(fid,'\r\n');
end

fclose(fid);
msgbox(sprintf('Exportiert: %s', fullfile(pn,fn)));
guidata(hObj, h);

% function tsFitExportCallback(hObj, ~)
% h = guidata(hObj);
% if ~isfield(h,'tsFitResults') || isempty(h.tsFitResults)
%     errordlg('Keine Fit-Ergebnisse vorhanden.','Fehler'); return
% end
% 
% [fn, pn] = uiputfile('*.txt','Fit-Ergebnisse exportieren',[General.ProgramInfo.Path,'Data\Results\Pilatus-2DXRD\']);
% if isequal(fn,0), return; end
% 
% r       = h.tsFitResults;
% nPeaks  = size(r.peakPos,2);
% hasTemp = any(isfinite(r.temperature));
% 
% fid = fopen(fullfile(pn,fn),'w');
% 
% % Header
% if hasTemp
%     fmt_h = '%10s\t%12s\t';
% else
%     fmt_h = '%10s\t';
% end
% fprintf(fid, fmt_h, 'Zeit_min', 'T_deg');
% for pk = 1:nPeaks
%     fprintf(fid,'Peak%d_Pos\tPeak%d_Err\tPeak%d_Amp\tPeak%d_FWHM\tPeak%d_Eta\tPeak%d_R2\t', ...
%         pk,pk,pk,pk,pk,pk);
% end
% fprintf(fid,'\r\n');
% 
% % Daten
% N = numel(r.time_min);
% for i = 1:N
%     if hasTemp
%         fprintf(fid,'%.4f\t%.2f\t', r.time_min(i), r.temperature(i));
%     else
%         fprintf(fid,'%.4f\t', r.time_min(i));
%     end
%     for pk = 1:nPeaks
%         fprintf(fid,'%.6f\t%.6f\t%.4f\t%.6f\t%.4f\t%.4f\t', ...
%             r.peakPos(i,pk), r.peakPosErr(i,pk), ...
%             r.amplitude(i,pk), r.fwhm(i,pk), r.eta(i,pk), r.R2(i,pk));
%     end
%     fprintf(fid,'\r\n');
% end
% fclose(fid);
% msgbox(sprintf('Exportiert: %s', fullfile(pn,fn)));
% 
% guidata(hObj, h);

function tsXRangeApplyCallback(hObj, ~)
h = guidata(hObj);

if ~isfield(h,'dataset') || isempty(h.dataset)
    guidata(hObj, h); return
end

% Werte lesen
[xMin, xMax] = getTSXRange(h);

% Aktuelles Profil holen
idx = max(1, round(get(h.SliderTimeSeries,'Value')));
idx = min(idx, numel(h.dataset));
ds  = h.dataset(idx);

[xData, xLabel] = getTSXData(h, ds);
if isempty(xData) || isempty(ds.I)
    guidata(hObj, h); return
end

x = xData(:);
I = double(ds.I(:));

% Grenzen automatisch setzen falls leer
if isempty(xMin), xMin = min(x); end
if isempty(xMax), xMax = max(x); end

% Validierung
if xMin >= xMax
    errordlg('x-Minimum muss kleiner als x-Maximum sein.','Bereichsfehler');
    return
end
xMin = max(xMin, min(x));
xMax = min(xMax, max(x));

idxRange = (x >= xMin) & (x <= xMax);
if sum(idxRange) < 5
    errordlg(sprintf('Zu wenige Datenpunkte im Bereich [%.4f, %.4f].', ...
        xMin, xMax), 'Bereichsfehler');
    return
end

% Bereich speichern
h.tsXRange = [xMin, xMax];

% Edit-Felder auf geklemmte Werte aktualisieren
set(h.TSXRangeMinEdit, 'String', num2str(xMin, '%.4f'));
set(h.TSXRangeMaxEdit, 'String', num2str(xMax, '%.4f'));

% ── t-Bereich lesen und speichern ─────────────────────────────────────
tMin = str2double(get(h.TSTRangeMinEdit, 'String'));
tMax = str2double(get(h.TSTRangeMaxEdit, 'String'));
if isnan(tMin), tMin = []; end
if isnan(tMax), tMax = []; end

if ~isempty(tMin) && ~isempty(tMax) && tMin < tMax
    h.tsTRange = [tMin, tMax];
    set(h.TSTRangeMinEdit, 'String', num2str(tMin, '%.1f'));
    set(h.TSTRangeMaxEdit, 'String', num2str(tMax, '%.1f'));
elseif isempty(tMin) && isempty(tMax)
    h.tsTRange = [];
else
    h.tsTRange = [];
end

% Plot aktualisieren (respektiert den aktuellen Modus: Heatmap/Single Profile etc.)
h = updateTimeSeriesPlot(h);
guidata(hObj, h);

function tsXRangeResetCallback(hObj, ~)
h = guidata(hObj);

set(h.TSXRangeMinEdit, 'String', '');
set(h.TSXRangeMaxEdit, 'String', '');
set(h.TSTRangeMinEdit, 'String', '');
set(h.TSTRangeMaxEdit, 'String', '');
h.tsXRange = [];
h.tsTRange = [];

% Achsen sofort zurücksetzen
if isfield(h,'axesTimeProfile') && isvalid(h.axesTimeProfile)
    h.axesTimeProfile.XLimMode = 'auto';
end

guidata(hObj, h);
% Direkt Apply aufrufen um ganzes Spektrum zu zeigen
tsXRangeApplyCallback(hObj, []);

function reintegratePONICallback(hObj, ~)
h = guidata(hObj);

% ── Sicherheitscheck ─────────────────────────────────────────────────
if ~isfield(h,'dataset') || isempty(h.dataset)
    errordlg('Bitte zuerst ein Dataset laden.','Kein Dataset');
    return
end

% Prüfen ob CBF-Dateien vorhanden
cbfPaths = {h.dataset.cbfPath};
hasCBF   = ~cellfun(@isempty, cbfPaths);
if ~any(hasCBF)
    errordlg(sprintf(['Keine CBF-Dateien im geladenen Dataset gefunden.\n' ...
        'Ordner: %s'], h.dataDir), 'Keine CBF-Dateien');
    return
end

% ── PONI-Datei wählen ─────────────────────────────────────────────────
[poniFile, poniLoc] = uigetfile('*.poni', ...
    'Neue PONI-Datei für Reintegration wählen', h.dataDir);
if isequal(poniFile, 0), return; end
newPoniPath = fullfile(poniLoc, poniFile);

% ── Python-Pfade aus GUI ──────────────────────────────────────────────
pythonExe  = strtrim(get(h.pythonExeEdit,  'String'));
scriptPath = strtrim(get(h.scriptPathEdit, 'String'));

% ── Wellenlänge bestimmen ─────────────────────────────────────────────
if isfield(h,'lambda_m') && ~isempty(h.lambda_m) && h.lambda_m > 0
    lambda_m = h.lambda_m;
elseif isfield(h,'datasetLambda_m') && ~isempty(h.datasetLambda_m)
    lambda_m = h.datasetLambda_m;
else
    hc_eVm   = 1.23984193e-6;
    lambda_m = hc_eVm / 9251.7;   % Ga K-alpha Fallback
    warning('reintegratePONICallback: Wellenlänge unbekannt, verwende Ga K-alpha.');
end

% ── Output-Verzeichnis: Unterordner im Dataset-Ordner ─────────────────
[~, poniName, ~] = fileparts(poniFile);
outDir = fullfile(h.dataDir, ['reintegrated_' poniName]);
if ~exist(outDir, 'dir'), mkdir(outDir); end

% ── Feedback ──────────────────────────────────────────────────────────
col = get(hObj, 'backg');
set(hObj, 'String', 'Integriere ...', 'backg', [1 .6 .6]);
pause(0.01);

% ── Job-JSON für jedes CBF einzeln (1d_batch-Modus) ──────────────────
validCBF = cbfPaths(hasCBF);
idxValid = find(hasCBF);
N_cbf    = numel(validCBF);

job = struct();
job.img_paths    = validCBF(:);
job.poni_paths   = repmat({newPoniPath}, N_cbf, 1);
job.wavelength_m = lambda_m;
job.mode         = '1d_batch';
job.unit         = 'q_nm^-1';
job.npt_rad      = 1000;
job.method       = 'csr';
job.error_model  = 'poisson';

outBase      = fullfile(outDir, 'batch_result');
job.out_npz  = [outBase '.npz'];
job.out_mat  = [outBase '.mat'];
job.out_json = [outBase '_meta.json'];

jobJsonPath = fullfile(outDir, 'reintegrate_job.json');
fid = fopen(jobJsonPath, 'w');
fprintf(fid, '%s', jsonencode(job));
fclose(fid);

% ── Python aufrufen ───────────────────────────────────────────────────
cmd = sprintf('"%s" "%s" "%s" 2>&1', pythonExe, scriptPath, jobJsonPath);
[status, cmdout] = system(cmd);

if status ~= 0
    set(hObj, 'String', 'Reintegrate with PONI', 'backg', col);
    errordlg(sprintf('pyFAI fehlgeschlagen:\n%s', cmdout), 'Fehler');
    return
end

% ── Ergebnis laden ───────────────────────────────────────────────────
if ~exist(job.out_mat, 'file')
    set(hObj, 'String', 'Reintegrate with PONI', 'backg', col);
    errordlg(sprintf('Ausgabedatei nicht gefunden:\n%s', job.out_mat), 'Fehler');
    return
end

result = load(job.out_mat);   % enthält I [N_cbf x npt_rad] und radial [1 x npt_rad]

q_new = double(result.radial(:));   % [npt_rad x 1]
I_new = double(result.I);           % [N_cbf x npt_rad]

% Wellenlänge aus neuer PONI auslesen und speichern
try
    newPoni = parsePoniFile(newPoniPath);
    if isfield(newPoni,'wavelength') && newPoni.wavelength > 0
        h.datasetLambda_m = newPoni.wavelength;
        fprintf('Neue Wellenlänge aus PONI: %.6e m\n', newPoni.wavelength);
    end
catch
end

% ── h.dataset aktualisieren ───────────────────────────────────────────
for ii = 1:N_cbf
    idx_ds = idxValid(ii);
    h.dataset(idx_ds).q = q_new;
    h.dataset(idx_ds).I = I_new(ii, :)';
end

% Job-Datei aufräumen
delete(jobJsonPath);

fprintf('Reintegration abgeschlossen: %d Profile mit %s\n', N_cbf, poniFile);

% ── Plot aktualisieren ────────────────────────────────────────────────
h = updateTimeSeriesPlot(h);

set(hObj, 'String', 'Reintegrate with PONI', 'backg', col);
guidata(hObj, h);

function peakModelChangedCallback(hObj, ~)
h = guidata(hObj);
h.tsPeakModel = get(hObj.SelectedObject, 'UserData');
guidata(hObj, h);

function r = getAppRoot()
if isdeployed
    [~, exeInfo] = system(['wmic process where processid="' ...
        num2str(feature('getpid')) ...
        '" get ExecutablePath /format:value']);
    exePath = strtrim(regexprep(exeInfo, 'ExecutablePath=', ''));
    r = fileparts(exePath);
else
    r = fileparts(mfilename('fullpath'));
end

function updateBGFromDrag(figHandle, newBGIntervals)
h = guidata(figHandle);
h.tsBgIntervals = newBGIntervals;

% BG-Regionen pro Peak neu zuordnen
if isfield(h, 'tsUserPeaks') && ~isempty(h.tsUserPeaks)
    nPeaks = numel(h.tsUserPeaks);
    h.tsBgRegions = cell(nPeaks, 1);
    for pk = 1:nPeaks
        for g = 1:size(newBGIntervals, 1)
            if h.tsUserPeaks(pk) >= newBGIntervals(g,1) && ...
               h.tsUserPeaks(pk) <= newBGIntervals(g,2)
                h.tsBgRegions{pk} = newBGIntervals(g,:);
                break
            end
        end
    end
end
guidata(figHandle, h);

function updatePeaksFromDrag(figHandle, newPeakPositions)
h = guidata(figHandle);
h.tsUserPeaks = sort(newPeakPositions(:));
guidata(figHandle, h);

function tsAddPeakCallback(hObj, ~)
h = guidata(hObj);

if ~isfield(h,'dataset') || isempty(h.dataset)
    errordlg('Bitte zuerst ein Dataset laden.','Fehler'); return
end

% Sicherstellen dass axesTimeProfile sichtbar ist
selectedMode = get(h.TimeSeriesModeGroup.SelectedObject, 'String');
if ~strcmp(selectedMode, 'Single Profile')
    set(h.rb_ts_singleprofile, 'Value', 1);
    h = applyTimeSeriesLayout(h, 'bottom');
    h = updateTimeSeriesPlot(h);
end

BG_HALF_WIDTH = 1.2;

h.axesTimeProfile.Title.String = 'Peaks hinzufügen – Linksklick = Peak, Enter = Fertig';
drawnow;

hold(h.axesTimeProfile, 'on');
newPeaks = [];
newLines = [];

while true
    try
        [xClick, ~, button] = ginput(1);
    catch
        break
    end
    if isempty(button) || button == 27
        break
    end
    if button == 3 && ~isempty(newPeaks)
        delete(newLines(end));
        newLines(end) = [];
        newPeaks(end) = [];
        continue
    end
    if button == 1
        newPeaks(end+1) = xClick; %#ok<AGROW>
        hL = xline(h.axesTimeProfile, xClick, 'r-', ...
            sprintf('+P'), 'LineWidth', 1.2, ...
            'LabelOrientation', 'horizontal', 'LabelVerticalAlignment', 'top');
        newLines(end+1) = hL; %#ok<AGROW>
    end
end

if isempty(newPeaks)
    h.axesTimeProfile.Title.String = 'Keine neuen Peaks hinzugefügt';
    guidata(hObj, h);
    return
end

% Bestehende Peaks ergänzen
if isfield(h, 'tsUserPeaks') && ~isempty(h.tsUserPeaks)
    allPeaks = [h.tsUserPeaks(:); newPeaks(:)];
else
    allPeaks = newPeaks(:);
end
h.tsUserPeaks = sort(allPeaks);

% BG-Intervalle erweitern
nAll = numel(h.tsUserPeaks);
bgNew = zeros(nAll, 2);
for pk = 1:nAll
    bgNew(pk,:) = [h.tsUserPeaks(pk) - BG_HALF_WIDTH, ...
                   h.tsUserPeaks(pk) + BG_HALF_WIDTH];
end

% Überlappende Intervalle zusammenführen
merged = bgNew(1,:);
for pk = 2:nAll
    if bgNew(pk,1) <= merged(end,2)
        merged(end,2) = max(merged(end,2), bgNew(pk,2));
    else
        merged(end+1,:) = bgNew(pk,:); %#ok<AGROW>
    end
end
h.tsBgIntervals = merged;

% BG-Regionen pro Peak zuordnen
h.tsBgRegions = cell(nAll, 1);
for pk = 1:nAll
    for g = 1:size(merged, 1)
        if h.tsUserPeaks(pk) >= merged(g,1) && h.tsUserPeaks(pk) <= merged(g,2)
            h.tsBgRegions{pk} = merged(g,:);
            break
        end
    end
end

set(h.TSFitAllButton, 'Enable', 'on');
set(h.TSFitBoundsButton, 'Enable', 'on');

% Plot aktualisieren
h = updateTimeSeriesPlot(h);
guidata(hObj, h);

fprintf('tsAddPeak: %d neue Peaks hinzugefügt, insgesamt %d Peaks.\n', ...
    numel(newPeaks), nAll);


function tsPickTRangeCallback(hObj, ~)
h = guidata(hObj);

selectedMode = get(h.TimeSeriesModeGroup.SelectedObject, 'String');
if ~strcmp(selectedMode, 'Heatmap')
    errordlg('Bitte zuerst in den Heatmap-Modus wechseln.', 'Fehler');
    return
end

h.axesTimeSeries.Title.String = 't-Bereich: 2x klicken (t_min, t_max)';
drawnow;

hold(h.axesTimeSeries, 'on');
tClicks = [];
hLines = [];

for k = 1:2
    try
        [xClick, ~, button] = ginput(1);
    catch
        break
    end
    if isempty(button) || button == 27
        break
    end
    tClicks(end+1) = xClick; %#ok<AGROW>
    if k == 1
        hL = xline(h.axesTimeSeries, xClick, 'g-', 't_{min}', ...
            'LineWidth', 1.5, 'LabelVerticalAlignment', 'bottom');
    else
        hL = xline(h.axesTimeSeries, xClick, 'g-', 't_{max}', ...
            'LineWidth', 1.5, 'LabelVerticalAlignment', 'bottom');
    end
    hLines(end+1) = hL; %#ok<AGROW>
end

if numel(tClicks) == 2
    tMin = min(tClicks);
    tMax = max(tClicks);
    h.tsTRange = [tMin, tMax];
    set(h.TSTRangeMinEdit, 'String', num2str(tMin, '%.1f'));
    set(h.TSTRangeMaxEdit, 'String', num2str(tMax, '%.1f'));
    h.axesTimeSeries.XLim = [tMin, tMax];
    h.axesTimeSeries.Title.String = ...
        sprintf('Heatmap – t-Bereich: %.1f – %.1f min', tMin, tMax);
else
    h.axesTimeSeries.Title.String = 'Heatmap – t-Bereich nicht gesetzt';
end

% Temporäre Linien entfernen
for k = 1:numel(hLines)
    try delete(hLines(k)); catch, end
end

guidata(hObj, h);


function HeatmapContrastCallback(hObj, ~)
h = guidata(hObj);
val = round(get(hObj, 'Value'));
set(h.HeatmapContrastLabel, 'String', sprintf('%d%%', val));
selectedMode = get(h.TimeSeriesModeGroup.SelectedObject, 'String');
if strcmp(selectedMode, 'Heatmap') && isfield(h, 'dataset') && ~isempty(h.dataset)
    h = updateTimeSeriesPlot(h);
    guidata(hObj, h);
end

function guiCloseCallback(hObj, ~)
try
    [~, result] = system('tasklist /FI "IMAGENAME eq python.exe" /FO CSV /NH');
    if contains(result, 'python.exe')
        system('taskkill /f /im python.exe');
        fprintf('GUI geschlossen: Python-Prozesse beendet.\n');
    end
catch
end
delete(hObj);