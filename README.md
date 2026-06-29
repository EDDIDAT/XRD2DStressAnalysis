# XRD2DStressAnalysis

A MATLAB/Python-based graphical analysis platform for determining residual stresses and microstructural parameters from 2D area-detector X-ray diffraction data.

## Features

- **Data import**: CBF and TIF detector images (Dectris Pilatus and others)
- **Azimuthal integration**: pyFAI-based multi-geometry caking with automatic detector gap mask computation
- **Dual peak fitting**: Parametric Pseudo-Voigt fit + intensity-weighted centroid with bootstrap error estimation
- **Stress computation**: Generalized stress factor method and classical sin²ψ method
- **Time series analysis**: Waterfall, heatmap, single-profile, and CBF viewer modes for in-situ experiments
- **Materials database**: 100+ pre-configured material phases with diffraction elastic constants (DEK/REK)
- **Interactive visualization**: Eight plot tabs including raw detector images, caked 2D images, ring projections, and stress-depth profiles

## Requirements

- MATLAB R2022b or later
- Python 3.11+ with virtual environment containing:
  - pyFAI >= 2023.9
  - fabio >= 2023.9
  - scipy >= 1.10
  - numpy >= 1.24

## Quick Start

1. Clone this repository
2. Set up a Python virtual environment with pyFAI:
   ```
   python -m venv venv
   venv\Scripts\pip install pyFAI fabio scipy numpy
   ```
3. Start MATLAB and navigate to the project folder
4. Run: `XRD2DStressAnalysis_modPV_pyFAI`
5. Adjust the Python path in the GUI if needed

## Documentation

- [User Manual (German)](Benutzerhandbuch_XRD2DStressAnalysis.docx)
- [Caked Mask Documentation](caked_mask_dokumentation.pdf)

## Workflow

1. Create Sample (define material, select MPD file)
2. Load 2D images (CBF/TIF)
3. Load PONI calibration files (triggers automatic pyFAI caking)
4. Adjust binning parameters (chi range, smoothing, baseline)
5. Select 2θ range
6. Define background (interactive)
7. Define peaks (interactive)
8. Run Track & Fit (parallel Pseudo-Voigt + Centroid fitting)
9. Apply detector mask
10. Compute stresses (stress factor method)
11. Export results

## License

[To be determined - Apache 2.0 planned]

## Citation

If you use this software in your research, please cite:

```
[Citation information to be added]
```

## Acknowledgments

Developed at the Helmholtz-Zentrum Berlin für Materialien und Energie (HZB).
