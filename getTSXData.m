function [xData, xLabel] = getTSXData(h, ds)
% Gibt x-Achse des aktuellen Time-Series-Profils zurück (q Å⁻¹ oder 2θ°)
if isempty(ds.q) || isempty(ds.I)
    xData = []; xLabel = ''; return
end

use2theta = isfield(h,'TimeSeriesXAxisGroup') && ...
            isvalid(h.TimeSeriesXAxisGroup) && ...
            strcmp(get(h.TimeSeriesXAxisGroup.SelectedObject,'String'),'2θ');

lambda_m = [];
if use2theta
    if isfield(h,'datasetLambda_m') && h.datasetLambda_m > 0
        lambda_m = h.datasetLambda_m;
    elseif isfield(h,'lambda_m') && h.lambda_m > 0
        lambda_m = h.lambda_m;
    end
    if isempty(lambda_m), use2theta = false; end
end

q_ang = double(ds.q(:)) / 10;   % nm⁻¹ → Å⁻¹
if use2theta
    lambda_nm = lambda_m * 1e9;
    sinVal    = q_ang * lambda_nm * 10 / (4*pi);   % Å⁻¹ × Å / (4π) = dimensionslos
    sinVal    = max(min(sinVal, 1), -1);
    xData     = 2 * rad2deg(asin(sinVal));
    xLabel    = '2\theta (°)';
else
    xData  = q_ang;
    xLabel = 'q (Å^{-1})';
end