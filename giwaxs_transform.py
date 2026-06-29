#!/usr/bin/env python3
"""
giwaxs_transform.py — GIWAXS-Transformation in Proben-Referenzsystem
Transformiert CBF-Bilder von Detektorkoordinaten in das Proben-Referenzsystem
(q, chi) analog zu INSIGHT.

Aufruf: python giwaxs_transform.py <job.json>

Job-JSON Felder:
    img_paths     : Liste der CBF-Dateipfade
    poni_paths    : Liste der PONI-Dateipfade (pro Bild)
    alpha_i_deg   : Liste der Einfallswinkel alpha_i in Grad (pro Bild)
    q_range       : [q_min, q_max] in Å^-1
    chi_range     : [chi_min, chi_max] in Grad
    npt_q         : Anzahl q-Punkte (Standard: 500)
    npt_chi       : Anzahl chi-Punkte (Standard: 360)
    out_mat       : Ausgabepfad für .mat-Datei
    out_npz       : Ausgabepfad für .npz-Datei
"""

import sys
import os
import json
import numpy as np
import fabio
import pyFAI
from pyFAI.azimuthalIntegrator import AzimuthalIntegrator
from scipy.io import savemat
from scipy.interpolate import RegularGridInterpolator

def load_job(job_path):
    with open(job_path, 'r') as f:
        return json.load(f)

def read_poni(poni_path):
    """Liest PONI-Datei und gibt Parameter-Dict zurück."""
    params = {}
    with open(poni_path, 'r') as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            if ':' in line:
                idx = line.index(':')
                key = line[:idx].strip()
                val = line[idx+1:].strip()
                try:
                    params[key] = float(val)
                except ValueError:
                    params[key] = val
    return params

def detector_to_reciprocal_space(img, ai, alpha_i_rad):
    wavelength_m = ai.wavelength
    wavelength_A = wavelength_m * 1e10
    k0 = 2 * np.pi / wavelength_A

    nrow, ncol = img.shape
    row_idx, col_idx = np.mgrid[0:nrow, 0:ncol]

    pixel1 = ai.detector.pixel1
    pixel2 = ai.detector.pixel2

    y_det = (row_idx * pixel1) - ai.poni1
    x_det = (col_idx * pixel2) - ai.poni2
    z_det = ai.dist

    # ── Detektorrotation ZUERST anwenden ─────────────────────────────
    rot1 = ai.rot1
    rot2 = ai.rot2
    rot3 = ai.rot3

    R1 = np.array([[1,           0,            0],
                   [0,  np.cos(rot1), np.sin(rot1)],
                   [0, -np.sin(rot1), np.cos(rot1)]])
    R2 = np.array([[ np.cos(rot2), 0, -np.sin(rot2)],
                   [0,             1,  0            ],
                   [ np.sin(rot2), 0,  np.cos(rot2)]])
    R3 = np.array([[ np.cos(rot3), np.sin(rot3), 0],
                   [-np.sin(rot3), np.cos(rot3), 0],
                   [0,             0,            1]])
    R = np.dot(R1, np.dot(R2, R3))

    det_vec = np.stack([x_det, y_det,
                        np.full_like(x_det, z_det)], axis=-1)
    det_rot  = np.einsum('ij,...j->...i', R, det_vec)
    x_det_r  = det_rot[..., 0]
    y_det_r  = det_rot[..., 1]
    z_det_r  = det_rot[..., 2]

    # ── Streuwinkel aus rotierten Koordinaten ─────────────────────────
    r_det   = np.sqrt(x_det_r**2 + y_det_r**2 + z_det_r**2)
    alpha_f = np.arcsin(-y_det_r / r_det)
    phi     = np.arctan2(x_det_r, z_det_r)

    # ── q-Vektoren im Proben-Referenzsystem ───────────────────────────
    cos_af  = np.cos(alpha_f)
    sin_af  = np.sin(alpha_f)
    cos_ai  = np.cos(alpha_i_rad)
    sin_ai  = np.sin(alpha_i_rad)
    cos_phi = np.cos(phi)
    sin_phi = np.sin(phi)

    qx = k0 * (cos_af * cos_phi - cos_ai)
    qy = k0 * (cos_af * sin_phi)
    qz = k0 * (sin_af + sin_ai)

    # ── qr und qz statt q und chi ─────────────────────────────────────────
    qr_map  = np.sqrt(qx**2 + qy**2)   # in-plane [Å^-1]
    qz_map  = qz                         # out-of-plane [Å^-1]

    # q_total für Referenz
    q_map   = np.sqrt(qx**2 + qy**2 + qz**2)

    # chi_map als qz für die Ausgabe verwenden
    chi_map = qz_map   # wird als "Y-Achse" interpretiert

    I_map = img.astype(np.float32)
    I_map[I_map < 0] = np.nan

    return q_map, chi_map, I_map


def regrid_to_uniform(q_map, chi_map, I_map,
                      q_min, q_max, npt_q,
                      chi_min, chi_max, npt_chi):
    """
    Interpoliert die unregelmäßig verteilten (q, chi, I)-Werte
    auf ein gleichmäßiges rechteckiges Gitter.
    
    Rückgabe:
        q_axis   : 1D q-Achse [Å^-1]
        chi_axis : 1D chi-Achse [°]
        I_grid   : 2D Intensitätsgitter [npt_chi x npt_q]
    """
    q_axis   = np.linspace(q_min,   q_max,   npt_q)
    chi_axis = np.linspace(chi_min, chi_max, npt_chi)

    # Gitterpunkte
    Q_grid, CHI_grid = np.meshgrid(q_axis, chi_axis)

    # Flache Arrays der Eingangsdaten (nur gültige Pixel)
    mask = np.isfinite(I_map) & np.isfinite(q_map) & np.isfinite(chi_map)
    q_flat   = q_map[mask].ravel()
    chi_flat = chi_map[mask].ravel()
    I_flat   = I_map[mask].ravel()

    # Interpolation mit scipy.interpolate.griddata
    from scipy.interpolate import griddata
    points = np.column_stack([q_flat, chi_flat])
    I_grid = griddata(points, I_flat,
                  (Q_grid, CHI_grid),
                  method='nearest',    # statt 'linear'
                  fill_value=0.0)

    return q_axis, chi_axis, I_grid.astype(np.float32)


def main():
    if len(sys.argv) < 2:
        print("Verwendung: python giwaxs_transform.py <job.json>")
        sys.exit(1)

    job_path = sys.argv[1]
    job      = load_job(job_path)

    img_paths   = job['img_paths']
    poni_paths  = job['poni_paths']
    alpha_degs  = job['alpha_i_deg']   # Liste der Einfallswinkel [°]
    q_range     = job.get('q_range',   [0.5, 4.0])
    chi_range   = job.get('chi_range', [-90.0, 90.0])
    npt_q       = int(job.get('npt_q',   500))
    npt_chi     = int(job.get('npt_chi', 360))
    out_mat     = job.get('out_mat',  'giwaxs_result.mat')
    out_npz     = job.get('out_npz',  'giwaxs_result.npz')

    N = len(img_paths)
    print(f"GIWAXS-Transformation: {N} Bilder")

    # Ausgabe-Arrays
    I_stack   = np.zeros((N, npt_chi, npt_q), dtype=np.float32)
    q_axis    = np.linspace(q_range[0],   q_range[1],   npt_q)
    chi_axis  = np.linspace(chi_range[0], chi_range[1], npt_chi)

    for i, (img_path, poni_path, alpha_deg) in \
            enumerate(zip(img_paths, poni_paths, alpha_degs)):

        print(f"  {i+1}/{N}: {os.path.basename(img_path)}"
              f"  PONI={os.path.basename(poni_path)}"
              f"  alpha={alpha_deg:.1f}°")

        # Bild laden
        img_data = fabio.open(img_path).data.astype(np.float32)

        # AzimuthalIntegrator laden
        ai = pyFAI.load(poni_path)

        # Einfallswinkel
        alpha_i_rad = np.radians(float(alpha_deg))

        # Pixelweise Transformation in Proben-Referenzsystem
        q_map, chi_map, I_map = detector_to_reciprocal_space(
            img_data, ai, alpha_i_rad)

        print(f"    q:   {np.nanmin(q_map):.3f} – {np.nanmax(q_map):.3f} Å^-1")
        print(f"    chi: {np.nanmin(chi_map):.1f} – {np.nanmax(chi_map):.1f} °")

        # Auf gleichmäßiges Gitter interpolieren
        _, _, I_grid = regrid_to_uniform(
            q_map, chi_map, I_map,
            q_range[0], q_range[1], npt_q,
            chi_range[0], chi_range[1], npt_chi)

        I_stack[i] = I_grid

    # Speichern
    np.savez(out_npz,
             I=I_stack,
             q=q_axis,
             chi=chi_axis)

    savemat(out_mat, {
        'I':   I_stack,
        'q':   q_axis,
        'chi': chi_axis
    })

    print(f"OK: {out_mat}")
    print(f"    I_stack: {I_stack.shape}")
    print(f"    q:    {q_axis[0]:.3f} – {q_axis[-1]:.3f} Å^-1")
    print(f"    chi:  {chi_axis[0]:.1f} – {chi_axis[-1]:.1f} °")


if __name__ == '__main__':
    main()