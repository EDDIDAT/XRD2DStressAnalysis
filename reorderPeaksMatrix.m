function result = reorderPeaksMatrix(p)
    nPeaks = size(p,1)/2;
    half = nPeaks/2;
    result = [p(1:half,:) , p(nPeaks+1:nPeaks+half,:) ;
              p(half+1:nPeaks,:) , p(nPeaks+half+1:end,:)];
end