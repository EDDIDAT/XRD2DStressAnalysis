function scroll_plot_2D(data)

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
h.x = data{1}(:,1);
h.y = data{1}(:,2);
h.err = data{1}(:,3);
h.data = data;
% Create plot
h.axesplotRawData = axes('Parent', h.fig, 'Position', [0.07 0.1125 0.9 0.85]);
h.plotdata = errorbar(h.axesplotRawData, h.x,h.y,h.err,'s'); hold on;

h.axesplotRawData.XLim = [-90,20];
h.axesplotRawData.YLim = [0,Inf];
h.axesplotRawData.YLimMode = 'auto';
grid on

set(h.Slider,'Min',1);
set(h.Slider,'Max',size(data,1));
set(h.Slider,'SliderStep',[1/(size(data,1)-1) 1/(size(data,1)-1)]);

guidata(h.fig, h);

function SliderCallbackPlotRawData(hObj, data)
% This callback handles the changes when the slider button is pushed.
h = guidata(hObj);
% Get slider value
value = get(hObj, 'Value');
value = round(value);

set(h.plotdata,'Xdata',h.data{value}(:,1))
set(h.plotdata,'Ydata',h.data{value}(:,2))
set(h.plotdata,'YNegativeDelta',h.data{value}(:,3))
set(h.plotdata,'YPositiveDelta',h.data{value}(:,3))

guidata(hObj, h);