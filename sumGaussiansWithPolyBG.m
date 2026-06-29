function ysum = sumGaussiansWithPolyBG(x, p, peakPositions, bgOrder)
numPeaks = length(peakPositions);
ysum = zeros(size(x));
for k = 1:numPeaks
    a = p(k);
    b = peakPositions(k);
    c = p(numPeaks + k);
    ysum = ysum + a*exp(-(x-b).^2/(2*c^2));
end
bg_params = p(2*numPeaks + (1:(bgOrder+1)));
ysum = ysum + polyval(flip(bg_params), x);
end