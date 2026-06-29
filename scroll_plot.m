function scroll_plot(x,y)

h.fig = figure('Name','Scroll Plot','NumberTitle','off','units', 'normalized','Position', [0.05 0.1 .4 .8]); %[0.05 0.05 .92 .85] [0.05 0.05 .4 .8]

% Slider erzeugen
h.Slider = uicontrol(...
'Style','slider',...
'Tag','Slider',...
'Parent', h.fig,...
'Units','normalized',...
'Position', [0.46 0.015 0.1 0.025],...
'Min',0,...
'Max', 1,...
'Value',1,...
'Callback',{@SliderCallbackPlotRawData});

% empty data for plot
h.x = x';
h.y = y{1};
% Create plot
h.axesplotRawData = axes('Parent', h.fig, 'Position', [0.07 0.1125 0.9 0.85]);
h.plotdata = plot(h.axesplotRawData, h.x(:,1),h.y(:,1)); hold on;

h.axesplotRawData.XLim = [0,60];
h.axesplotRawData.YLim = [0,Inf];
h.axesplotRawData.YLimMode = 'auto';
grid on

set(h.Slider,'Min',1);
set(h.Slider,'Max',size(h.y,2));
set(h.Slider,'SliderStep',[1/(size(h.y,2)-1) 1/(size(h.y,2)-1)]);

guidata(h.fig, h);

function SliderCallbackPlotRawData(hObj, x, y)
% This callback handles the changes when the slider button is pushed.
h = guidata(hObj);
% Get slider value
value = get(hObj, 'Value');
value = round(value)

% set(h.plotdata,'xdata',h.x(:,value))
set(h.plotdata,'ydata',h.y(:,value))

guidata(hObj, h);