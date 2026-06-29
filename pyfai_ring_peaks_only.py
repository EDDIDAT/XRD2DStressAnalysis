import json, sys, traceback
import numpy as np
import pyFAI
import fabio
from scipy.io import savemat

def main(job_path):
    with open(job_path) as f:
        job = json.load(f)

    img_paths    = job["img_paths"]
    poni_paths   = job["poni_paths"]
    wavelength_m = float(job["wavelength_m"])
    peak_pos_deg = job["peak_pos_deg"]
    peak_tol_deg = float(job.get("peak_tol_deg", 0.05))
    out_mat      = job["out_mat"]

    ais  = []
    for p in poni_paths:
        ai = pyFAI.load(p)
        ai.wavelength = wavelength_m
        ais.append(ai)

    imgs = [np.asarray(fabio.open(p).data, dtype=np.float32) for p in img_paths]

    ring_data = {}
    for tth_peak in peak_pos_deg:
        xp, yp = [], []
        for ai, img in zip(ais, imgs):
            try:
                tth_pix = np.degrees(
                    ai.center_array(img.shape, unit="2th_rad")).ravel()
                pos   = ai.position_array(img.shape, corners=False)
                x_lab = pos[..., 2].ravel() * 1000.0
                y_lab = pos[..., 1].ravel() * 1000.0
                mask  = np.abs(tth_pix - tth_peak) < peak_tol_deg
                if np.any(mask):
                    xp.append(x_lab[mask])
                    yp.append(y_lab[mask])
            except Exception as e:
                print(f"Warning {tth_peak:.3f}°: {e}")

        if xp:
            key = f"peak_{tth_peak:.4f}".replace('.', 'p')
            # Nur jeden n-ten Pixel speichern
            step = 5
            ring_data[key + "_x"] = np.concatenate(xp)[::step].astype(np.float16)
            ring_data[key + "_y"] = np.concatenate(yp)[::step].astype(np.float16)
            print(f"Ring {tth_peak:.3f}°: {len(ring_data[key+'_x'])} Pixel")

    if ring_data:
        out_peaks = out_mat.replace('.mat', '_ring_peaks.mat')
        savemat(out_peaks, ring_data)
        print(f"OK: {out_peaks}")

if __name__ == "__main__":
    main(sys.argv[1])