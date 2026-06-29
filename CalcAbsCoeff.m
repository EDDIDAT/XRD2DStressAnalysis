function mu = CalcAbsCoeff(ElementalFormula,MPDFileName,Energy)
P.ElementalFormula = ElementalFormula;
P.MPDFileName = MPDFileName;
P.ShowSubstratePeaks = false;
T.Material = Sample.Material();
T.Material.ElementalFormula = P.ElementalFormula;
T.Material.GetElementsFromFormula();
% Import and read the mpd file.
T.MaterialInfo = T.Material.LoadFromMpdFile(P.MPDFileName);
% Assign the respective property of the material.
T.Material.MaterialDensity = T.MaterialInfo.MaterialDensity;
T.Material.LatticeParameter = T.MaterialInfo.LatticeParameter;
T.Material.CrystalStructure = T.MaterialInfo.CrystalStructure;
T.Material.MolecularWeight = T.MaterialInfo.MolecularWeight;
T.Material.HKLdspacing = T.MaterialInfo.HKLdspacing;
T.Material.ShowSubstratePeaks = P.ShowSubstratePeaks;
T.Material.Name = P.MPDFileName;
% Default value for maximum energy.
T.Material.EnergyMax = 100;
% SampleNeu = Sample.Sample();
% % Choose sample structre (not intended to be changed as yet).
% SampleNeu.Structure = 'PhaseMixture';
% % Assign the materials information to the sample object.
Sample.Materials = T.Material;
mu = Sample.Materials.LAC(Energy);
end