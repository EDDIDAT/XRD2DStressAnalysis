function [yproc, base] = baseline_remove(y, mode, win)
y = y(:);
switch lower(string(mode))
    case "none"
        base = zeros(size(y));
        yproc = y;
    case "movmin"
        win = max(5, round(win));
        if mod(win,2)==0, win = win + 1; end
        base = movmin(y, win);
        yproc = y - base;
        yproc(yproc < 0) = 0;
    otherwise
        error("Unknown baselineMode: %s", string(mode));
end
end