function exportAxesAsTif(ax, tifPath, resolution, keepPeakLines)

if nargin < 3, resolution    = 300;  end
if nargin < 4, keepPeakLines = true; end

try
    fig_tmp         = figure('Visible', 'off', 'Color', 'k');
    ax_tmp          = copyobj(ax, fig_tmp);
    ax_tmp.Units    = 'normalized';
    ax_tmp.Position = [0.08 0.08 0.86 0.86];

    if ~keepPeakLines
        ch = ax_tmp.Children;
        for ci = 1:numel(ch)
            obj = ch(ci);
            if ~isvalid(obj), continue; end
            if isa(obj, 'matlab.graphics.chart.decoration.ConstantLine')
                delete(obj);
            end
            if isa(obj, 'matlab.graphics.primitive.Line') && ...
               strcmp(get(obj, 'LineStyle'), '--')
                delete(obj);
            end
            if isa(obj, 'matlab.graphics.primitive.Text')
                delete(obj);
            end
        end
        drawnow;
    end

    exportgraphics(fig_tmp, tifPath, ...
        'Resolution',  resolution, ...
        'ContentType', 'image');
    close(fig_tmp);
    fprintf('TIF gespeichert: %s\n', tifPath);
catch ME
    warning('[exportAxesAsTif] %s', ME.message);
    try, close(fig_tmp); catch, end
end
end