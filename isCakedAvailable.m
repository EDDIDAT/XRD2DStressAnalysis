% =========================================================================
%  isCakedAvailable — prüft ob gecaktes Bild vorhanden
% =========================================================================
function tf = isCakedAvailable(ds)
tf = isfield(ds, 'cakedLoaded') && ds.cakedLoaded && ...
     isfield(ds, 'caked')       && isstruct(ds.caked) && ...
     isfield(ds.caked, 'I')     && ~isempty(ds.caked.I);
end