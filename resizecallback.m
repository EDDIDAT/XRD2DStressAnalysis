function resizecallback(hObj, ~)
h = guidata(hObj);
if isempty(h), return; end

fp  = get(hObj, 'Position');
fs  = max(8, min(11, round(fp(4) / 95)));

kids = findall(hObj, 'Type', 'uicontrol');
for k = 1:numel(kids)
    try
        set(kids(k), 'FontSize', fs);
    catch
    end
end
end