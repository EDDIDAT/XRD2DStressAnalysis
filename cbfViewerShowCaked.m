function showCaked = cbfViewerShowCaked(h)
% Gibt true zurück wenn "Caked" gewählt ist UND gecakte Daten vorhanden.
showCaked = false;
if ~isfield(h, 'CBFViewModeGroup') || ~isvalid(h.CBFViewModeGroup)
    return
end
if ~strcmp(get(h.CBFViewModeGroup, 'Visible'), 'on')
    return
end
selected = get(h.CBFViewModeGroup.SelectedObject, 'String');
showCaked = strcmp(selected, 'Caked');
end