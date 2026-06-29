function scroll_plot_ImageFitData(dataX,dataY,fitresults,meas)

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
h.x = dataX(:,1);
h.y = dataY{meas}(:,1);

h.dataX = dataX;
h.dataY = dataY;
h.datafitresults = fitresults;
h.meas = meas;
% Create plot
h.axesplotRawData = axes('Parent', h.fig, 'Position', [0.07 0.1125 0.9 0.85]);
hold(h.axesplotRawData,'on');

for k = 1:size(fitresults{meas},2)
    plot(h.axesplotRawData, fitresults{meas}{1,k},h.x(:,1),h.y);
end

% h.plotfits = plot(h.axesplotRawData, fitresults{1}{1,k},dataX(:,1),dataY{1}(:,25));

h.axesplotRawData.XLim = [0,Inf];
h.axesplotRawData.YLim = [-Inf,Inf];
h.axesplotRawData.YLimMode = 'auto';
grid on

set(h.Slider,'Min',1);
set(h.Slider,'Max',size(fitresults{meas},1));
set(h.Slider,'SliderStep',[1/(size(fitresults{meas},1)-1) 1/(size(fitresults{meas},1)-1)]);

guidata(h.fig, h);

function SliderCallbackPlotRawData(hObj, data)
% This callback handles the changes when the slider button is pushed.
h = guidata(hObj);
% Get slider value
value = get(hObj, 'Value');
value = round(value);
cla(h.axesplotRawData)
hold(h.axesplotRawData,'on');

for k = 1:size(h.datafitresults{h.meas},2)
    plot(h.axesplotRawData, h.datafitresults{h.meas}{value,k},h.dataX(:,1),h.dataY{h.meas}(:,value));
end

% % set(h.plotdata,'Xdata',h.data{value}(:,1))
% set(h.plotdata,'Ydata',h.dataY{1}(:,value))
% set(h.plotdata,'Ydata',h.dataY{1}(:,value))

guidata(hObj, h);


% for k = 1:size(fitresultexport{1},2)
%     plot(fitresultexport{1}{25,k},dataX(:,1),dataY{1}(:,25))
%     hold on
% end