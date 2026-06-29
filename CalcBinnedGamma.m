function [BinnedGamma] = CalcBinnedGamma(FileName, bins, imageheight)
%UNTITLED Summary of this function goes here
    % Import gamma data
    % GammaData = importdata(FileName);

    Gammatmp = FileName;

    % GammaData = importdata(FileName);
    % 
    % Gammatmp = GammaData(:,2);

    for k = 1:(imageheight/bins)-1
        BinData(:,k) = 1 + ((k-1)*bins) : 1 + ((k-1)*bins) + bins;
    end

    BinnedGammatmp = Gammatmp(BinData);
    BinnedGamma = mean(BinnedGammatmp,1);

    % Gammatmp = reshape(Gammatmp,bins,size(Gammatmp,1)/bins);
    % 
    % BinnedGamma = mean(Gammatmp,1);
    
%     % 
    % gammaminusrange = 1:GammaZero+bins/2;
    % gammaplusrange = GammaZero+bins/2+1:size(Gamma,1);
    % 
    % gammabinnedstepsminus = nan(bins,ceil(numel(gammaminusrange)./bins));
    % gammabinnedstepsminus(1:numel(gammaminusrange)) = flip(gammaminusrange);
    % gammabinnedstepsminus = flip(gammabinnedstepsminus,1);
    % gammabinnedstepsminus = flip(gammabinnedstepsminus,2);
    % 
    % gammabinnedstepsplus = nan(bins,ceil(numel(gammaplusrange)./bins));
    % gammabinnedstepsplus(1:numel(gammaplusrange)) = gammaplusrange;
    % 
    % gammabinnedsteps = [gammabinnedstepsminus gammabinnedstepsplus];
    % 
    % for k = 1:size(gammabinnedsteps,2)
    %     PixelNr = ~isnan(gammabinnedsteps(:,k));
    %     PixelBinLength = length(PixelNr(PixelNr==1)~=0);
    %     BinnedGamma(k,:) = mean(Gamma(gammabinnedsteps(~isnan(gammabinnedsteps(:,k)),k)));
    % end

end