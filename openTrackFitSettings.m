function opts = openTrackFitSettings(opts_in)
% OPENTRACKFITSETTINGS  Modal settings dialog for Track & Fit parameters.
%
%   opts = openTrackFitSettings()          – opens with built-in defaults
%   opts = openTrackFitSettings(opts_in)   – opens pre-filled with opts_in
%
%   Returns the updated opts struct on "Apply & Close".
%   Returns opts_in (or defaults) unchanged on "Cancel".

% ---- Defaults -------------------------------------------------------
def = struct( ...
    'windowDeg',                  0.60,                           ...
    'useGauss',                   false,                          ...
    'gaussMinR2',                 0.98,                           ...
    'gaussSigmaRangeDeg',         [0.10  0.80],                   ...
    'pvoigtFixedEta',             0.5,                            ...
    'pvoigtFallbackToCentroid',   true,                           ...
    'pvoigtMinR2',                0.90,                           ...
    'pvoigtFwhmRangeDeg',         [0.2  0.80],                   ...
    'pvoigtMuBoundDeg',           0.2,                           ...
    'centroidKBins',              12,                            ...
    'pvoigtAdaptiveWindow',       true,                           ...
    'pvoigtAdaptiveWindowFactor', 2.5,                            ...
    'pvoigtAdaptiveWindowMinDeg', 0.20,                           ...
    'pvoigtAdaptiveWindowMaxDeg', 0.80,                           ...
    'pvoigtAutoWindow',           false,                           ...
    'pvoigtWindowCandidates',     [0.30 0.35 0.40 0.50 0.55 0.60], ...
    'pvoigtAutoWindowUseBestR2',  false                            ...
);

% Merge caller values over defaults
if nargin < 1 || isempty(opts_in)
    cur = def;
else
    cur = opts_in;
    flds = fieldnames(def);
    for fi = 1:numel(flds)
        if ~isfield(cur, flds{fi})
            cur.(flds{fi}) = def.(flds{fi});
        end
    end
end

opts = cur;   % returned unchanged on Cancel; overwritten on Apply

% =====================================================================
% Row definitions (used to auto-calculate required height)
% =====================================================================
rows = {};

% ---- General --------------------------------------------------------
rows{end+1} = {'section', 'General'};
rows{end+1} = {'scalar', 'Window deg',             'windowDeg',  cur.windowDeg,  []};

% ---- Gauss Fit ------------------------------------------------------
rows{end+1} = {'section', 'Gauss Fit'};
rows{end+1} = {'bool',   'Use Gauss fit',           'useGauss',          cur.useGauss,          []};
rows{end+1} = {'scalar', 'Min R²',                  'gaussMinR2',        cur.gaussMinR2,        []};
rows{end+1} = {'range',  'Sigma range [°]',         'gaussSigmaRangeDeg',cur.gaussSigmaRangeDeg,[]};

% ---- pseudo-Voigt ---------------------------------------------------
rows{end+1} = {'section', 'pseudo-Voigt'};
rows{end+1} = {'scalar', 'Fixed eta  (empty = free)','pvoigtFixedEta',           cur.pvoigtFixedEta,          []};
rows{end+1} = {'bool',   'Fallback to centroid',     'pvoigtFallbackToCentroid', cur.pvoigtFallbackToCentroid,[]};
rows{end+1} = {'scalar', 'Min R²',                   'pvoigtMinR2',              cur.pvoigtMinR2,             []};
rows{end+1} = {'range',  'FWHM range [°]',           'pvoigtFwhmRangeDeg',       cur.pvoigtFwhmRangeDeg,      []};
rows{end+1} = {'scalar', 'Mu bound [°]',             'pvoigtMuBoundDeg',         cur.pvoigtMuBoundDeg,        []};

% ---- Window ---------------------------------------------------------
rows{end+1} = {'section', 'Window'};
rows{end+1} = {'bool',   'Adaptive window',           'pvoigtAdaptiveWindow',           cur.pvoigtAdaptiveWindow,          []};
rows{end+1} = {'scalar', 'Adaptive window factor',    'pvoigtAdaptiveWindowFactor',     cur.pvoigtAdaptiveWindowFactor,    []};
rows{end+1} = {'range',  'Adaptive window range [°]', 'pvoigtAdaptiveWindowRange',      [cur.pvoigtAdaptiveWindowMinDeg  cur.pvoigtAdaptiveWindowMaxDeg], []};
rows{end+1} = {'bool',   'Auto window',               'pvoigtAutoWindow',               cur.pvoigtAutoWindow,              []};
rows{end+1} = {'vecstr', 'Window candidates [°]',     'pvoigtWindowCandidates',         cur.pvoigtWindowCandidates,        []};
rows{end+1} = {'bool',   'Auto window: use best R²',  'pvoigtAutoWindowUseBestR2',      cur.pvoigtAutoWindowUseBestR2,     []};

% =====================================================================
% Layout constants
% =====================================================================
TITLE_H = 40;
BTN_BAR = 46;
EROW_H  = 22;
GAP     = 5;
SEC_GAP = 10;
SEC_H   = 18;
PAD_TOP = 6;
PAD_BOT = 6;
P_LEFT  = 16;
COL1_W  = 215;
COL2_X  = P_LEFT + COL1_W + 10;
COL2_W  = 105;

% Auto-calculate required content height
contentH = PAD_TOP;
for ri = 1:numel(rows)
    if strcmp(rows{ri}{1}, 'section')
        contentH = contentH + SEC_GAP + 2 + 4 + SEC_H + GAP;
    else
        contentH = contentH + EROW_H + GAP;
    end
end
contentH = contentH + PAD_BOT;

% Dialog height = content + title + button bar (no scroll needed)
dlgW  = 500;
dlgH  = contentH + TITLE_H + BTN_BAR;

% =====================================================================
% Figure
% =====================================================================
scr  = get(0, 'ScreenSize');
dlgL = round((scr(3) - dlgW) / 2);
dlgB = round((scr(4) - dlgH) / 2);

fig = figure( ...
    'Name',        'Track & Fit Settings', ...
    'NumberTitle', 'off', ...
    'MenuBar',     'none', ...
    'ToolBar',     'none', ...
    'Units',       'pixels', ...
    'Position',    [dlgL dlgB dlgW dlgH], ...
    'Resize',      'off', ...
    'WindowStyle', 'modal', ...
    'Color',       [0.94 0.94 0.94]);

% ---- Colours --------------------------------------------------------
CLR_HDR  = [0.20 0.35 0.55];
CLR_SEC  = [0.20 0.40 0.65];
CLR_LINE = [0.75 0.80 0.88];
CLR_BG   = [0.94 0.94 0.94];
CLR_EDIT = [1.00 1.00 1.00];
CLR_BTN  = [0.20 0.45 0.75];
CLR_BTNC = [0.75 0.20 0.20];

% ---- Title bar ------------------------------------------------------
uicontrol(fig, 'Style','text', 'Units','pixels', ...
    'Position',[0  dlgH-TITLE_H  dlgW  TITLE_H], ...
    'BackgroundColor',CLR_HDR, 'ForegroundColor',[1 1 1], ...
    'FontSize',11, 'FontWeight','bold', ...
    'String','   Track & Fit  –  Peak Fit Settings', ...
    'HorizontalAlignment','left');

% =====================================================================
% Content panel (no scroll — height is exactly right)
% =====================================================================
contentPanel = uipanel(fig, ...
    'Units','pixels', ...
    'Position',[0  BTN_BAR  dlgW  contentH], ...
    'BorderType','none', 'BackgroundColor',CLR_BG);

% =====================================================================
% Render rows
% =====================================================================
handles = struct();
curY    = contentH - PAD_TOP;

for ri = 1:numel(rows)
    row   = rows{ri};
    rtype = row{1};

    % ---- Section header -----------------------------------------
    if strcmp(rtype, 'section')
        curY = curY - SEC_GAP;
        uicontrol(contentPanel, 'Style','text', 'Units','pixels', ...
            'Position',[P_LEFT  curY-2  dlgW-2*P_LEFT  2], ...
            'BackgroundColor',CLR_LINE, 'String','');
        curY = curY - 4;
        uicontrol(contentPanel, 'Style','text', 'Units','pixels', ...
            'Position',[P_LEFT  curY-SEC_H  dlgW-2*P_LEFT  SEC_H], ...
            'BackgroundColor',CLR_BG, 'ForegroundColor',CLR_SEC, ...
            'FontWeight','bold', 'FontSize',9, ...
            'String',['  ' row{2}], 'HorizontalAlignment','left');
        curY = curY - SEC_H - GAP;
        continue
    end

    label  = row{2};
    tag    = row{3};
    defval = row{4};

    % Row label
    uicontrol(contentPanel, 'Style','text', 'Units','pixels', ...
        'Position',[P_LEFT  curY-EROW_H  COL1_W  EROW_H], ...
        'BackgroundColor',CLR_BG, 'ForegroundColor',[0.15 0.15 0.15], ...
        'FontSize',8, 'String',label, 'HorizontalAlignment','left');

    switch rtype

        case 'scalar'
            if isempty(defval) || (isnumeric(defval) && isscalar(defval) && isnan(defval))
                strval = '';
            else
                strval = num2str(defval);
            end
            h_ctrl = uicontrol(contentPanel, 'Style','edit', 'Units','pixels', ...
                'Position',[COL2_X  curY-EROW_H+2  COL2_W  EROW_H-2], ...
                'BackgroundColor',CLR_EDIT, 'FontSize',8, ...
                'String',strval, 'Tag',tag, 'HorizontalAlignment','center');
            handles.(tag) = h_ctrl;

        case 'range'
            uicontrol(contentPanel, 'Style','text', 'Units','pixels', ...
                'Position',[COL2_X  curY-EROW_H  24  EROW_H], ...
                'BackgroundColor',CLR_BG, 'FontSize',8, ...
                'String','min:', 'HorizontalAlignment','right');
            h1 = uicontrol(contentPanel, 'Style','edit', 'Units','pixels', ...
                'Position',[COL2_X+28  curY-EROW_H+2  46  EROW_H-2], ...
                'BackgroundColor',CLR_EDIT, 'FontSize',8, ...
                'String',num2str(defval(1)), 'Tag',[tag '_min'], ...
                'HorizontalAlignment','center');
            uicontrol(contentPanel, 'Style','text', 'Units','pixels', ...
                'Position',[COL2_X+78  curY-EROW_H  28  EROW_H], ...
                'BackgroundColor',CLR_BG, 'FontSize',8, ...
                'String','max:', 'HorizontalAlignment','right');
            h2 = uicontrol(contentPanel, 'Style','edit', 'Units','pixels', ...
                'Position',[COL2_X+110  curY-EROW_H+2  46  EROW_H-2], ...
                'BackgroundColor',CLR_EDIT, 'FontSize',8, ...
                'String',num2str(defval(2)), 'Tag',[tag '_max'], ...
                'HorizontalAlignment','center');
            handles.([tag '_min']) = h1;
            handles.([tag '_max']) = h2;

        case 'bool'
            h_ctrl = uicontrol(contentPanel, 'Style','checkbox', 'Units','pixels', ...
                'Position',[COL2_X  curY-EROW_H+3  COL2_W  EROW_H-2], ...
                'BackgroundColor',CLR_BG, 'FontSize',8, ...
                'Value',double(defval), 'Tag',tag, 'String','');
            handles.(tag) = h_ctrl;

        case 'vecstr'
            strval = strtrim(num2str(defval(:)', '%.4g  '));
            h_ctrl = uicontrol(contentPanel, 'Style','edit', 'Units','pixels', ...
                'Position',[COL2_X  curY-EROW_H+2  COL2_W+80  EROW_H-2], ...
                'BackgroundColor',CLR_EDIT, 'FontSize',8, ...
                'String',strval, 'Tag',tag, 'HorizontalAlignment','left');
            handles.(tag) = h_ctrl;
    end

    curY = curY - EROW_H - GAP;
end

% =====================================================================
% Button bar
% =====================================================================
BTN_W = 118;
BTN_H = 28;
BTN_Y = 9;

uicontrol(fig, 'Style','pushbutton', 'Units','pixels', ...
    'Position',[P_LEFT  BTN_Y  BTN_W  BTN_H], ...
    'String','Reset to defaults', 'FontSize',8, ...
    'BackgroundColor',[0.80 0.80 0.80], ...
    'Callback',@resetCallback);

uicontrol(fig, 'Style','pushbutton', 'Units','pixels', ...
    'Position',[dlgW-2*BTN_W-P_LEFT-6  BTN_Y  BTN_W  BTN_H], ...
    'String','Cancel', 'FontSize',9, 'FontWeight','bold', ...
    'BackgroundColor',CLR_BTNC, 'ForegroundColor',[1 1 1], ...
    'Callback',@cancelCallback);

uicontrol(fig, 'Style','pushbutton', 'Units','pixels', ...
    'Position',[dlgW-BTN_W-P_LEFT  BTN_Y  BTN_W  BTN_H], ...
    'String','Apply & Close', 'FontSize',9, 'FontWeight','bold', ...
    'BackgroundColor',CLR_BTN, 'ForegroundColor',[1 1 1], ...
    'Callback',@applyCallback);

% =====================================================================
% Wait for user
% =====================================================================
uiwait(fig);


% =====================================================================
% Nested callbacks
% =====================================================================
    function applyCallback(~,~)
        opts = readHandles(handles, cur);
        if isvalid(fig)
            uiresume(fig);
            delete(fig);
        end
    end

    function cancelCallback(~,~)
        if isvalid(fig)
            uiresume(fig);
            delete(fig);
        end
    end

    function resetCallback(~,~)
        populateHandles(handles, def);
    end

end  % openTrackFitSettings


% =========================================================================
% Local helper: populate controls from struct
% =========================================================================
function populateHandles(handles, s)
flds = fieldnames(handles);
for fi = 1:numel(flds)
    tag  = flds{fi};
    ctrl = handles.(tag);
    if ~isvalid(ctrl), continue; end
    style = lower(get(ctrl, 'Style'));

    if localEndsWith(tag, '_min') || localEndsWith(tag, '_max')
        baseTag = tag(1:end-4);
        if strcmp(baseTag, 'pvoigtAdaptiveWindowRange')
            if localEndsWith(tag, '_min') && isfield(s, 'pvoigtAdaptiveWindowMinDeg')
                set(ctrl, 'String', num2str(s.pvoigtAdaptiveWindowMinDeg));
            elseif isfield(s, 'pvoigtAdaptiveWindowMaxDeg')
                set(ctrl, 'String', num2str(s.pvoigtAdaptiveWindowMaxDeg));
            end
        elseif isfield(s, baseTag)
            v = s.(baseTag);
            if localEndsWith(tag, '_min'), set(ctrl, 'String', num2str(v(1)));
            else,                          set(ctrl, 'String', num2str(v(2)));
            end
        end
        continue
    end

    if ~isfield(s, tag), continue; end
    val = s.(tag);

    switch style
        case 'edit'
            if isnumeric(val)
                if isscalar(val)
                    set(ctrl, 'String', num2str(val));
                else
                    set(ctrl, 'String', strtrim(num2str(val(:)', '%.4g  ')));
                end
            else
                set(ctrl, 'String', char(val));
            end
        case 'checkbox'
            set(ctrl, 'Value', double(logical(val)));
    end
end
end


% =========================================================================
% Local helper: read controls into opts struct
% =========================================================================
function opts = readHandles(handles, cur)
opts = cur;
flds = fieldnames(handles);
for fi = 1:numel(flds)
    tag  = flds{fi};
    ctrl = handles.(tag);
    if ~isvalid(ctrl), continue; end
    style = lower(get(ctrl, 'Style'));

    if localEndsWith(tag, '_min')
        baseTag = tag(1:end-4);
        maxTag  = [baseTag '_max'];
        minVal  = str2double(strtrim(get(ctrl, 'String')));
        if isfield(handles, maxTag) && isvalid(handles.(maxTag))
            maxVal = str2double(strtrim(get(handles.(maxTag), 'String')));
        else
            maxVal = NaN;
        end
        if strcmp(baseTag, 'pvoigtAdaptiveWindowRange')
            if ~isnan(minVal), opts.pvoigtAdaptiveWindowMinDeg = minVal; end
            if ~isnan(maxVal), opts.pvoigtAdaptiveWindowMaxDeg = maxVal; end
        elseif isfield(opts, baseTag)
            v = opts.(baseTag);
            if ~isnan(minVal), v(1) = minVal; end
            if ~isnan(maxVal), v(2) = maxVal; end
            opts.(baseTag) = v;
        end
        continue
    end
    if localEndsWith(tag, '_max'), continue; end

    switch style
        case 'edit'
            if ~isfield(opts, tag), continue; end
            str      = strtrim(get(ctrl, 'String'));
            existing = opts.(tag);
            if isnumeric(existing)
                nums = str2num(str); %#ok<ST2NM>
                if ~isempty(nums)
                    opts.(tag) = nums;
                end
            else
                opts.(tag) = str;
            end
        case 'checkbox'
            if isfield(opts, tag)
                opts.(tag) = logical(get(ctrl, 'Value'));
            end
    end
end
end


% =========================================================================
% Local helper: string ends-with
% =========================================================================
function tf = localEndsWith(str, suffix)
tf = numel(str) >= numel(suffix) && ...
     strcmp(str(end-numel(suffix)+1:end), suffix);
end