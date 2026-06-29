import os
import json
import sys
import traceback
import numpy as np
import inspect

def _filtered_kwargs(func, d):
    sig = inspect.signature(func)
    allowed = set(sig.parameters.keys())
    return {k: v for k, v in d.items() if k in allowed}

def _call_integrate2d(mg, imgs, npt_rad, npt_azim, unit, method, error_model, base_kwargs):
    sig = inspect.signature(mg.integrate2d)
    params = set(sig.parameters.keys())
    kw = dict(base_kwargs)
    if "method" in params:      kw["method"]      = method
    if "error_model" in params: kw["error_model"] = error_model
    for uk in ["unit","rad_unit","radial_unit","radialUnit","radial_unit_name"]:
        if uk in params:
            kw[uk] = unit
            break
    return mg.integrate2d(imgs, npt_rad, npt_azim, **_filtered_kwargs(mg.integrate2d, kw))

def _call_integrate1d(mg, imgs, npt_rad, unit, method, error_model, base_kwargs):
    sig = inspect.signature(mg.integrate1d)
    params = set(sig.parameters.keys())
    kw = dict(base_kwargs)
    if "method" in params:      kw["method"]      = method
    if "error_model" in params: kw["error_model"] = error_model
    for uk in ["unit","rad_unit","radial_unit","radialUnit","radial_unit_name"]:
        if uk in params:
            kw[uk] = unit
            break
    return mg.integrate1d(imgs, npt_rad, **_filtered_kwargs(mg.integrate1d, kw))

def integrate2d_compat(mg, imgs, npt_rad, npt_azim, unit, method, error_model, kwargs):
    try:
        return _call_integrate2d(mg, imgs, npt_rad, npt_azim, unit, method, error_model, kwargs)
    except TypeError as e:
        raise TypeError(f"integrate2d failed. Sig: {inspect.signature(mg.integrate2d)}") from e

def integrate1d_compat(mg, imgs, npt_rad, unit, method, error_model, kwargs):
    try:
        return _call_integrate1d(mg, imgs, npt_rad, unit, method, error_model, kwargs)
    except TypeError as e:
        raise TypeError(f"integrate1d failed. Sig: {inspect.signature(mg.integrate1d)}") from e

def _maybe_add(kwargs, job, key, cast=float):
    if key in job:
        v = job[key]
        if isinstance(v, (int, float)) and not np.isnan(v):
            kwargs[key] = cast(v)

# =====================================================================
# Caked-Maske berechnen
# =====================================================================
def compute_caked_mask(ais, imgs, npt_rad, npt_azim, unit, method, kwargs,
                       out_mat_base):
    """
    Berechnet eine Maske für das gecakte 2D-Bild.
    Gibt (caked_mask, valid_fraction) zurück:
      caked_mask     [npt_azim x npt_rad] uint8: 0=maskiert, 1=valide
      valid_fraction [npt_azim x npt_rad] float32: Anteil valider Pixel
    """
    try:
        from scipy.io import savemat
        from pyFAI.multi_geometry import MultiGeometry

        print("  Berechne Caked-Maske aus Detektormaske ...")

        # Detektormaske aus erstem AI laden
        mask_pix = None
        for ai in ais:
            try:
                m = ai.detector.mask
                if m is not None:
                    mask_pix = m.astype(bool)
                    break
            except Exception:
                pass

        if mask_pix is None:
            print("  Keine Detektormaske gefunden — Caked-Maske = alle valide")
            caked_mask = np.ones((npt_azim, npt_rad), dtype=np.uint8)
            return caked_mask, np.ones((npt_azim, npt_rad), dtype=np.float32)

        print(f"  Detektormaske: {mask_pix.sum()} maskierte Pixel")

        # Synthetisches Bild: 1=valider Pixel, 0=maskierter Pixel
        synthetic_imgs = []
        for img in imgs:
            syn = np.ones(img.shape, dtype=np.float32)
            if mask_pix.shape == img.shape:
                syn[mask_pix] = 0.0
            synthetic_imgs.append(syn)

        # Integration des synthetischen Bildes OHNE Maske
        mg_mask = MultiGeometry(ais, chi_disc=180)
        kw_mask = {k: v for k, v in kwargs.items()
                   if k not in ('mask', 'dummy', 'delta_dummy')}

        res_mask = integrate2d_compat(mg_mask, synthetic_imgs,
                                      npt_rad, npt_azim,
                                      unit, method, None, kw_mask)

        if isinstance(res_mask, tuple):
            I_mask = res_mask[0]
        else:
            I_mask = res_mask.intensity

        I_mask     = np.asarray(I_mask, dtype=np.float32)
        
        # Echte Normierung: Anteil = synthetische Intensität / maximale mögliche Intensität
        # Die maximale Intensität wäre ein vollständig valides Bild (alle Pixel = 1)
        # → integriere ein Bild mit allen Pixeln = 1 (ohne Maske)
        synthetic_full = [np.ones(img.shape, dtype=np.float32) for img in imgs]

        res_full = integrate2d_compat(mg_mask, synthetic_full,
                                       npt_rad, npt_azim,
                                       unit, method, None, kw_mask)

        if isinstance(res_full, tuple):
            I_full = res_full[0]
        else:
            I_full = res_full.intensity

        I_full = np.asarray(I_full, dtype=np.float32)

        # Anteil valider Pixel = maskiertes Bild / volles Bild
        # Wo I_full = 0: kein Pixel → außerhalb Detektor → NaN → wird auf 0 gesetzt
        with np.errstate(divide='ignore', invalid='ignore'):
            valid_fraction = np.where(I_full > 0,
                                       I_mask / I_full,
                                       0.0).astype(np.float32)

        valid_fraction = np.clip(valid_fraction, 0.0, 1.0)

        print(f"  valid_fraction range: {valid_fraction.min():.4f} .. {valid_fraction.max():.4f}")
        print(f"  Bins mit frac < 0.99: {int((valid_fraction < 0.99).sum())}")
        
        print(f"  frac = 0:           {int((valid_fraction == 0).sum())}")
        print(f"  0 < frac < 0.5:     {int(((valid_fraction > 0) & (valid_fraction < 0.5)).sum())}")
        print(f"  0.5 <= frac < 0.99: {int(((valid_fraction >= 0.5) & (valid_fraction < 0.99)).sum())}")
        print(f"  frac >= 0.99:       {int((valid_fraction >= 0.99).sum())}")

        caked_mask = (valid_fraction > 0.001).astype(np.uint8)

        n_valid   = int(caked_mask.sum())
        n_total   = caked_mask.size
        n_invalid = n_total - n_valid
        print(f"  Caked-Maske: {n_valid}/{n_total} Bins valide "
              f"({n_invalid} maskiert, {100*n_invalid/max(n_total,1):.1f}%)")

        chi_valid_caked = (caked_mask.sum(axis=1) > 0).astype(np.uint8)
        n_chi_invalid   = int((chi_valid_caked == 0).sum())
        print(f"  Chi-Bins komplett maskiert: {n_chi_invalid}/{npt_azim}")

        # Sicherstellen dass out_mat_base sauber endet (kein _caked_mask im Namen)
        base = out_mat_base
        if base.endswith('_caked_mask.mat'):
            base = base.replace('_caked_mask.mat', '.mat')

        mat_path = base.replace('.mat', '_caked_mask.mat')
        npz_path = base.replace('.mat', '_caked_mask.npz')

        np.savez(npz_path, caked_mask=caked_mask,
                 valid_fraction=valid_fraction,
                 chi_valid_caked=chi_valid_caked)
        savemat(mat_path, {
            'caked_mask':      caked_mask,
            'valid_fraction':  valid_fraction,
            'chi_valid_caked': chi_valid_caked
        })
        print(f"  Caked-Maske gespeichert: {mat_path}")
        return caked_mask, valid_fraction

    except Exception as e:
        print(f"  Warning [caked_mask]: {e}")
        traceback.print_exc()
        return np.ones((npt_azim, npt_rad), dtype=np.uint8), \
               np.ones((npt_azim, npt_rad), dtype=np.float32)

# =====================================================================
# Variante 1: Bilderstapel
# =====================================================================
def save_raw_stack(imgs, out_mat_base, out_npz_base):
    try:
        from scipy.io import savemat
        imgs_stack = np.stack(imgs, axis=0).astype(np.float32)
        imgs_sum   = np.sum(imgs_stack,  axis=0).astype(np.float32)
        imgs_mean  = np.mean(imgs_stack, axis=0).astype(np.float32)
        mat_path   = out_mat_base.replace('.mat', '_raw_stack.mat')
        npz_path   = out_npz_base.replace('.npz', '_raw_stack.npz')
        np.savez(npz_path, imgs_stack=imgs_stack, imgs_sum=imgs_sum, imgs_mean=imgs_mean)
        savemat(mat_path, {"imgs_stack": imgs_stack, "imgs_sum": imgs_sum,
                           "imgs_mean": imgs_mean, "n_imgs": len(imgs)})
        print(f"OK [Variante 1]: raw stack -> {mat_path}")
        return mat_path
    except Exception as e:
        print(f"Warning [Variante 1]: {e}")
        traceback.print_exc()
        return None

# =====================================================================
# Variante 2: Ringbild (Rückprojektion in 2theta-chi-Raster)
# =====================================================================
def save_reassembled(ais, imgs, out_mat_base, out_npz_base,
                     tth_range_deg=(0, 60), npt_tth=1500,
                     chi_range_deg=(-180, 180), npt_chi=360):
    try:
        from scipy.io import savemat
        tth_edges   = np.linspace(tth_range_deg[0], tth_range_deg[1], npt_tth + 1)
        chi_edges   = np.linspace(chi_range_deg[0],  chi_range_deg[1],  npt_chi  + 1)
        tth_centers = 0.5 * (tth_edges[:-1] + tth_edges[1:])
        chi_centers = 0.5 * (chi_edges[:-1] + chi_edges[1:])
        ring_sum    = np.zeros((npt_chi, npt_tth), dtype=np.float64)
        ring_count  = np.zeros((npt_chi, npt_tth), dtype=np.int32)

        for ai, img in zip(ais, imgs):
            try:
                tth_pix_deg = np.degrees(ai.center_array(img.shape, unit="2th_rad")).ravel()
                chi_pix_deg = np.degrees(ai.center_array(img.shape, unit="chi_rad")).ravel()
            except Exception as e1:
                try:
                    tth_pix_deg = np.degrees(ai.twoThetaArray(img.shape)).ravel()
                    chi_pix_deg = np.degrees(ai.chiArray(img.shape)).ravel()
                except Exception as e2:
                    print(f"Warning: pixel coords failed: {e1} / {e2}")
                    continue

            I_pix = img.ravel().astype(np.float64)
            i_tth = np.searchsorted(tth_edges, tth_pix_deg, side='right') - 1
            i_chi = np.searchsorted(chi_edges,  chi_pix_deg,  side='right') - 1
            mask  = ((i_tth >= 0) & (i_tth < npt_tth) &
                     (i_chi >= 0) & (i_chi < npt_chi)  &
                     np.isfinite(I_pix))
            np.add.at(ring_sum,   (i_chi[mask], i_tth[mask]), I_pix[mask])
            np.add.at(ring_count, (i_chi[mask], i_tth[mask]), 1)

        ring_mean = np.where(ring_count > 0,
                             ring_sum / np.maximum(ring_count, 1),
                             np.nan).astype(np.float16)
        mat_path  = out_mat_base.replace('.mat', '_ring.mat')
        npz_path  = out_npz_base.replace('.npz', '_ring.npz')
        np.savez(npz_path, ring_mean=ring_mean,
                 ring_sum=ring_sum.astype(np.float16),
                 ring_count=ring_count,
                 tth_centers=tth_centers.astype(np.float32),
                 chi_centers=chi_centers.astype(np.float32))
        savemat(mat_path, {"ring_mean": ring_mean,
                           "ring_sum":  ring_sum.astype(np.float16),
                           "ring_count": ring_count,
                           "tth_centers": tth_centers.astype(np.float32),
                           "chi_centers": chi_centers.astype(np.float32)})
        print(f"OK [Variante 2]: ring image -> {mat_path}")
        return mat_path
    except Exception as e:
        print(f"Warning [Variante 2]: {e}")
        traceback.print_exc()
        return None

# =====================================================================
# Variante 3: Ringbild (Rückprojektion in Pixel-Raster)
# =====================================================================
def save_ring_detector_space(ais, imgs, out_mat_base, out_npz_base,
                              output_size=2000):
    try:
        from scipy.io import savemat
        from scipy.ndimage import uniform_filter

        all_x, all_y, all_I = [], [], []
        sdd_list = []
        for ai in ais:
            try:    sdd_list.append(ai.dist * 1000.0)
            except: pass
        sdd_mm = float(np.mean(sdd_list)) if sdd_list else 0.0

        for ai, img in zip(ais, imgs):
            try:
                pos   = ai.position_array(img.shape, corners=False)
                x_lab = pos[..., 2].ravel() * 1000.0
                y_lab = pos[..., 1].ravel() * 1000.0
            except Exception as e1:
                try:
                    z, y, x = ai.calc_pos_zyx(corners=False)
                    x_lab   = x.ravel() * 1000.0
                    y_lab   = y.ravel() * 1000.0
                except Exception as e2:
                    print(f"Warning: skip detector: {e1} / {e2}")
                    continue

            try:
                mask_det = ai.detector.mask
                img      = img.copy()
                if mask_det is not None:
                    img[mask_det.astype(bool)] = np.nan
                module_mask      = (img <= 0)
                img[module_mask] = np.nan
            except Exception as e:
                print(f"  Warning: could not apply detector mask: {e}")

            all_x.append(x_lab)
            all_y.append(y_lab)
            all_I.append(img.ravel().astype(np.float32))

        if not all_x:
            print("Warning [ring_detector]: no valid detectors")
            return None

        x_concat = np.concatenate(all_x)
        y_concat = np.concatenate(all_y)
        I_concat = np.concatenate(all_I)
        center_x_mm = 0.0
        center_y_mm = 0.0

        mask  = (np.isfinite(I_concat) & (I_concat >= 0) &
                 np.isfinite(x_concat) & np.isfinite(y_concat))
        x_all = x_concat[mask];  y_all = y_concat[mask];  I_all = I_concat[mask]

        x_min, x_max = np.percentile(x_all, [0.1, 99.9])
        y_min, y_max = np.percentile(y_all, [0.1, 99.9])

        pixel_size_mm = 0.172
        output_size_x = min(output_size, int((x_max - x_min) / pixel_size_mm))
        output_size_y = min(output_size, int((y_max - y_min) / pixel_size_mm))

        x_edges   = np.linspace(x_min, x_max, output_size_x + 1)
        y_edges   = np.linspace(y_min, y_max, output_size_y + 1)
        x_centers = 0.5 * (x_edges[:-1] + x_edges[1:])
        y_centers = 0.5 * (y_edges[:-1] + y_edges[1:])
        ring_sum   = np.zeros((output_size_y, output_size_x), dtype=np.float64)
        ring_count = np.zeros((output_size_y, output_size_x), dtype=np.int32)

        i_x   = np.searchsorted(x_edges, x_all, side='right') - 1
        i_y   = np.searchsorted(y_edges, y_all, side='right') - 1
        valid = ((i_x >= 0) & (i_x < output_size_x) &
                 (i_y >= 0) & (i_y < output_size_y))
        np.add.at(ring_sum,   (i_y[valid], i_x[valid]), I_all[valid].astype(np.float64))
        np.add.at(ring_count, (i_y[valid], i_x[valid]), 1)

        ring_mean = np.where(ring_count > 0,
                             ring_sum / np.maximum(ring_count, 1),
                             np.nan).astype(np.float32)
        for _ in range(3):
            still_empty = ~np.isfinite(ring_mean)
            if not np.any(still_empty): break
            sum_img   = uniform_filter(np.nan_to_num(ring_mean, nan=0.0), size=3)
            count_img = uniform_filter((~still_empty).astype(np.float32), size=3)
            filled    = np.where(count_img > 0, sum_img / count_img, np.nan)
            ring_mean = np.where(still_empty, filled, ring_mean).astype(np.float32)

        mat_path = out_mat_base.replace('.mat', '_ring_det.mat')
        npz_path = out_npz_base.replace('.npz', '_ring_det.npz')
        np.savez(npz_path, ring_mean=ring_mean,
                 x_centers_mm=x_centers.astype(np.float32),
                 y_centers_mm=y_centers.astype(np.float32),
                 center_x_mm=np.float32(center_x_mm),
                 center_y_mm=np.float32(center_y_mm),
                 sdd_mm=np.float32(sdd_mm))
        savemat(mat_path, {"ring_mean":    ring_mean,
                           "x_centers_mm": x_centers.astype(np.float32),
                           "y_centers_mm": y_centers.astype(np.float32),
                           "center_x_mm":  float(center_x_mm),
                           "center_y_mm":  float(center_y_mm),
                           "sdd_mm":       float(sdd_mm)})
        print(f"OK [ring detector space]: {mat_path}")
        return mat_path
    except Exception as e:
        print(f"Warning [ring_detector]: {e}")
        traceback.print_exc()
        return None

def write_dat_file(filepath, q, I, ai, pol_factor):
    """Schreibt 1D-Profil im xlab .dat Format"""
    try:
        f2d      = ai.getFit2D()
        dist_mm  = f2d.get('directDist', ai.dist * 1000)
        center_x = f2d.get('centerX', 0)
        center_y = f2d.get('centerY', 0)
        tilt     = f2d.get('tilt', 0)
        tilt_rot = f2d.get('tiltPlanRotation', 0)
    except Exception:
        dist_mm  = ai.dist * 1000
        center_x = center_y = tilt = tilt_rot = 0

    det      = ai.detector
    p1, p2   = det.pixel1, det.pixel2
    pol_str  = str(pol_factor) if pol_factor is not None else 'None'

    with open(filepath, 'w') as f:
        f.write('# == pyFAI calibration ==\n')
        f.write(f'# Distance Sample to Detector: {ai.dist:.12g} m\n')
        f.write(f'# PONI: {ai.poni1:.3e}, {ai.poni2:.3e} m\n')
        f.write(f'# Rotations: {ai.rot1:.6f} {ai.rot2:.6f} {ai.rot3:.6f} rad\n')
        f.write('# \n')
        f.write('# == Fit2d calibration ==\n')
        f.write(f'# Distance Sample-beamCenter: {dist_mm:.3f} mm\n')
        f.write(f'# Center: x={center_x:.3f}, y={center_y:.3f} pix\n')
        f.write(f'# Tilt: {tilt:.3f} deg  TiltPlanRot: {tilt_rot:.3f} deg\n')
        f.write('# \n')
        f.write(f'# Detector {det.__class__.__name__}\t PixelSize= {p1:.3e}, {p2:.3e} m\n')
        f.write('#    Detector has a mask: True \n')
        f.write('#    Detector has a dark current: False \n')
        f.write('#    detector has a flat field: False \n')
        f.write('# \n')
        f.write(f'# Wavelength: {ai.wavelength:.11e} m\n')
        f.write('# Mask applied: provided\n')
        f.write('# Dark current applied: False\n')
        f.write('# Flat field applied: False\n')
        f.write(f'# Polarization factor: {pol_str}\n')
        f.write('# Normalization factor: 1.0\n')
        f.write(f'# --> {filepath}\n')
        f.write('#       q_nm^-1             I \n')
        for qi, Ii in zip(q, I):
            f.write(f'  {qi:.6e}    {Ii:.6e}\n')

# =====================================================================
# Main
# =====================================================================
def main(job_json_path: str) -> int:
    try:
        with open(job_json_path, "r") as f:
            job = json.load(f)

        import importlib.metadata as m
        try:    print("pyFAI dist version:", m.version("pyFAI"))
        except: pass

        import pyFAI
        from pyFAI.multi_geometry import MultiGeometry
        import fabio
        from scipy.io import savemat

        img_paths    = job["img_paths"]
        poni_paths   = job["poni_paths"]
        wavelength_m = float(job["wavelength_m"])

        mode        = job.get("mode",            "2d")
        unit        = job.get("unit",            "2th_deg")
        npt_rad     = int(job.get("npt_rad",     2000))
        npt_azim    = int(job.get("npt_azim",    360))
        method      = job.get("method",          "csr")
        error_model = job.get("error_model",     "poisson")
        chi_disc    = job.get("chi_discont_deg", 180)

        save_stack    = bool(job.get("save_raw_stack",   False))
        save_ring     = bool(job.get("save_ring_image",  False))
        save_ring_det = bool(job.get("save_ring_det",    False))

        ring_npt_tth = int(job.get("ring_npt_tth",       1500))
        ring_npt_chi = int(job.get("ring_npt_chi",         360))
        ring_tth_max = float(job.get("ring_tth_max_deg",   60.0))
        ring_chi_min = float(job.get("ring_chi_min_deg", -180.0))
        ring_chi_max = float(job.get("ring_chi_max_deg",  180.0))

        out_npz  = job.get("out_npz",  "pyfai_out.npz")
        out_mat  = job.get("out_mat",  "pyfai_out.mat")
        out_json = job.get("out_json", "pyfai_out_meta.json")

        ais = []
        for p in poni_paths:
            ai = pyFAI.load(p)
            ai.wavelength = wavelength_m
            ais.append(ai)

        mg = MultiGeometry(ais, chi_disc=chi_disc)

        kwargs = {}
        kwargs["correctSolidAngle"] = bool(job.get("correctSolidAngle", True))
        _maybe_add(kwargs, job, "polarization_factor", float)
        _maybe_add(kwargs, job, "dummy",       float)
        _maybe_add(kwargs, job, "delta_dummy", float)
        for k in ("dark", "flat", "mask"):
            v = job.get(k, "")
            if isinstance(v, str) and len(v) > 0: kwargs[k] = v

        # Detektormaske aus erstem AI
        try:
            mask_pix = ais[0].detector.mask
            if mask_pix is not None and "mask" not in kwargs:
                kwargs["mask"] = mask_pix.astype(np.int8)
                print(f"  Integrator mask applied: {mask_pix.sum()} pixels")
            else:
                print("  No detector mask found in AI")
        except Exception as e:
            print(f"  Warning: could not set integrator mask: {e}")

        # NEU: Maske zum Vergleich exportieren
        if mask_pix is not None:
            try:
                debug_mask_path = out_mat.replace('.mat', '_debug_mask.mat')
                savemat(debug_mask_path, {'detector_mask': mask_pix.astype(np.uint8)})
                print(f"  DEBUG: Detektormaske exportiert -> {debug_mask_path}")
            except Exception as e:
                print(f"  Warning: Maske konnte nicht exportiert werden: {e}")
                
        # Fallback: externe Maske
        mask_path = job.get("mask_path", "")
        if isinstance(mask_path, str) and len(mask_path) > 0:
            try:
                mask_ext = fabio.open(mask_path).data.astype(bool)
                if "mask" not in kwargs:
                    kwargs["mask"] = mask_ext.astype(np.int8)
                print(f"  External mask loaded: {mask_path}")
            except Exception as e:
                print(f"  Warning: could not load external mask: {e}")

        imgs = [np.asarray(fabio.open(ip).data, dtype=np.float32) for ip in img_paths]

        if mode == "2d":
            res = integrate2d_compat(mg, imgs, npt_rad, npt_azim,
                                     unit, method, error_model, kwargs)
            if isinstance(res, tuple) and len(res) >= 3:
                I, radial, azim = res[0], res[1], res[2]
                count = res[3] if len(res) >= 4 else None
            else:
                I, radial, azim = res.intensity, res.radial, res.azimuthal
                count = getattr(res, 'count', None)

            I      = np.asarray(I,      dtype=np.float32)
            radial = np.asarray(radial, dtype=np.float32)
            azim   = np.asarray(azim,   dtype=np.float32)

            # NEU: rohe Signal-/Normierungssumme zusätzlich extrahieren
            # (sum_signal ~ unkorrigierte Photon-Counts, direkt vergleichbar
            #  mit dem 1D-.dat-Profil; sum_normalization enthält u.a. die
            #  Solid-Angle-Korrektur, die intensity = sum_signal/sum_normalization
            #  auf sehr große Werte hochskaliert)
            sum_signal = getattr(res, 'sum_signal', None)
            sum_norm   = getattr(res, 'sum_normalization', None)
            if sum_signal is not None:
                sum_signal = np.asarray(sum_signal, dtype=np.float32)
            if sum_norm is not None:
                sum_norm = np.asarray(sum_norm, dtype=np.float32)

            # chi_valid aus count-Array
            if count is not None:
                count      = np.asarray(count, dtype=np.float32)
                chi_counts = count.sum(axis=1).astype(np.float32)
                nonzero    = chi_counts[chi_counts > 0]
                threshold  = np.median(nonzero) * 0.10 if len(nonzero) > 0 else 1.0
                chi_valid  = (chi_counts >= threshold).astype(np.uint8)
                n_valid    = int(chi_valid.sum())
                print(f"  chi_valid: {n_valid}/{len(chi_valid)} Bins über Schwellenwert")
            else:
                count      = np.zeros((npt_azim, npt_rad), dtype=np.float32)
                chi_counts = np.zeros(npt_azim,            dtype=np.float32)
                chi_valid  = np.ones(npt_azim,             dtype=np.uint8)
                print("  Warning: count array not available")

            # Haupt-MAT speichern
            npz_kwargs = dict(I=I, radial=radial, azimuthal=azim,
                               count=count, chi_counts=chi_counts, chi_valid=chi_valid)
            mat_kwargs = dict(I=I, radial=radial, azimuthal=azim,
                               count=count, chi_counts=chi_counts, chi_valid=chi_valid)
            if sum_signal is not None:
                npz_kwargs['sum_signal'] = sum_signal
                mat_kwargs['sum_signal'] = sum_signal
            if sum_norm is not None:
                npz_kwargs['sum_normalization'] = sum_norm
                mat_kwargs['sum_normalization'] = sum_norm

            np.savez(out_npz, **npz_kwargs)
            savemat(out_mat, mat_kwargs)
            print(f"OK [caked 2D]: {out_mat}")

            # ── Caked-Maske berechnen und in Haupt-MAT ergänzen ──────────────
            # out_mat ist sauber (z.B. ..._alpha2.mat) — kein _caked_mask im Namen
            caked_mask, valid_fraction = compute_caked_mask(
                ais, imgs, npt_rad, npt_azim, unit, method, kwargs, out_mat)

            try:
                from scipy.io import loadmat
                existing = loadmat(out_mat)
                existing['caked_mask']     = caked_mask
                existing['valid_fraction'] = valid_fraction
                savemat(out_mat, {k: v for k, v in existing.items()
                                  if not k.startswith('__')})
                print(f"  caked_mask in {out_mat} ergänzt")
            except Exception as e:
                print(f"  Warning: caked_mask konnte nicht ergänzt werden: {e}")

            # ── Optionale Ausgaben ────────────────────────────────────────────
            if save_stack:
                save_raw_stack(imgs, out_mat, out_npz)

            if save_ring:
                save_reassembled(ais, imgs, out_mat, out_npz,
                                 tth_range_deg=(0.0, ring_tth_max),
                                 npt_tth=ring_npt_tth,
                                 chi_range_deg=(ring_chi_min, ring_chi_max),
                                 npt_chi=ring_npt_chi)

            if save_ring_det:
                save_ring_detector_space(ais, imgs, out_mat, out_npz,
                                         output_size=int(job.get("ring_output_size", 2000)))

        elif mode == "1d":
            res = integrate1d_compat(mg, imgs, npt_rad,
                                     unit, method, error_model, kwargs)
            if isinstance(res, tuple) and len(res) >= 2:
                radial, I = res[0], res[1]
            else:
                radial, I = res.radial, res.intensity
            I      = np.asarray(I,      dtype=np.float32)
            radial = np.asarray(radial, dtype=np.float32)
            np.savez(out_npz, I=I, radial=radial)
            savemat(out_mat,  {"I": I, "radial": radial})
            print(f"OK [1D]: {out_mat}")
        elif mode == "1d_standard":
            # Standard pyFAI: ais[0] mit Pilatus-Detektormaske (calc_mask aktiv)
            # Gap-Pixel werden korrekt ausgeschlossen
            ai_single  = ais[0]
            img_single = imgs[0].copy()
            img_single[img_single < 0] = 0  # negative Werte nullsetzen

            npt_std = int(job.get("npt_std", 1000))

            azimuth_range = job.get("azimuth_range", None)
            if isinstance(azimuth_range, list):
                azimuth_range = tuple(azimuth_range)

            integrate_kwargs = {}
            if azimuth_range is not None:
                integrate_kwargs["azimuth_range"] = azimuth_range

            q_std, I_std = ai_single.integrate1d(
                img_single,
                npt=npt_std,
                unit="q_nm^-1",
                **integrate_kwargs
            )

            I_std = np.asarray(I_std, dtype=np.float32)
            q_std = np.asarray(q_std, dtype=np.float32)

            np.savez(out_npz, I=I_std, radial=q_std)
            savemat(out_mat, {"I": I_std, "radial": q_std})
            print(f"OK [1D standard, Pilatus-Maske aktiv]: {out_mat}")    
        elif mode == "1d_simple":
            # Repliziert xlab's AzimuthalIntegrator.integrate1d Aufruf:
            # KEINE expliziten Korrekturparameter (Solid-Angle, Polarisation etc.
            # nutzen pyFAI's eigene Defaults für AzimuthalIntegrator)
            ai_single = ais[0]
            img_single = imgs[0]

            q_simple, I_simple = ai_single.integrate1d(
                img_single,
                npt=int(job.get("npt_simple", 1500)),
                unit=unit
                # bewusst KEINE weiteren kwargs (mask, dummy, polarization_factor, ...)
                # genau wie im xlab-Code
            )

            I_simple = np.asarray(I_simple, dtype=np.float32)
            q_simple = np.asarray(q_simple, dtype=np.float32)

            np.savez(out_npz, I=I_simple, radial=q_simple)
            savemat(out_mat, {"I": I_simple, "radial": q_simple})
            print(f"OK [1D simple, AzimuthalIntegrator]: {out_mat}")    
        elif mode == "1d_xlab":
            img_single = imgs[0].copy()
            npt_xlab   = int(job.get("npt_xlab", 1000))

            # Frischen AI erstellen
            ai_from_file = pyFAI.load(poni_paths[0])
            poni_dict    = ai_from_file.get_config()
            for k in ["poni_version", "detector_config"]:
                poni_dict.pop(k, None)

            from pyFAI.integrator.azimuthal import AzimuthalIntegrator as AI
            from pyFAI.detectors import Detector
            ai_fresh = AI(**poni_dict)

            # Pilatus-Detektor durch generischen ersetzen -> keine calc_mask(), keine Lückenmaske
            pixel1 = ai_from_file.detector.pixel1
            pixel2 = ai_from_file.detector.pixel2
            shape  = img_single.shape
            ai_fresh.detector = Detector(pixel1=pixel1, pixel2=pixel2, max_shape=shape)

            print(f"Pixel < 0:              {np.sum(img_single < 0)}")
            print(f"detector.calc_mask():   {ai_fresh.detector.calc_mask()}")

            matrix_mask = np.zeros(img_single.shape, dtype=np.int8)

            azimuth_range = job.get("azimuth_range", None)
            if isinstance(azimuth_range, list):
                azimuth_range = tuple(azimuth_range)

            integrate_kwargs = {"mask": matrix_mask}
            if azimuth_range is not None:
                integrate_kwargs["azimuth_range"] = azimuth_range

            q_xlab, I_xlab = ai_fresh.integrate1d(
                img_single,
                npt=npt_xlab,
                unit="q_nm^-1",
                **integrate_kwargs
            )
            print(f"integrate1d OK, I min: {I_xlab.min():.3f}, I max: {I_xlab.max():.3f}")

            I_xlab = np.asarray(I_xlab, dtype=np.float32)
            q_xlab = np.asarray(q_xlab, dtype=np.float32)
            I_xlab[I_xlab < 0] = 0

            np.savez(out_npz, I=I_xlab, radial=q_xlab)
            savemat(out_mat, {"I": I_xlab, "radial": q_xlab})
            print(f"OK [1D xlab-replica]: {out_mat}")
        elif mode == "1d_xlab_noneg":
            ai_single  = ais[0]
            img_single = imgs[0].copy()

            # Negative Pixel (Lücken-Codes -1, -2) vor der Integration auf 0 setzen
            img_single[img_single < 0] = 0

            npt_xlab = int(job.get("npt_xlab", 1000))

            azimuth_range = job.get("azimuth_range", None)
            if isinstance(azimuth_range, list):
                azimuth_range = tuple(azimuth_range)

            maskB = job.get("maskB", None)
            if maskB is not None:
                matrix_mask = np.zeros_like(img_single, dtype=np.int8)
                matrix_mask[int(round(maskB)):, :] = 1
            else:
                matrix_mask = None

            integrate_kwargs = {}
            if matrix_mask is not None:
                integrate_kwargs["mask"] = matrix_mask
            if azimuth_range is not None:
                integrate_kwargs["azimuth_range"] = azimuth_range

            q_out, I_out = ai_single.integrate1d(
                img_single,
                npt=npt_xlab,
                unit="q_nm^-1",
                **integrate_kwargs
            )

            I_out = np.asarray(I_out, dtype=np.float32)
            q_out = np.asarray(q_out, dtype=np.float32)
            I_out[I_out < 0] = 0  # nachträgliches Clipping wie xlab

            np.savez(out_npz, I=I_out, radial=q_out)
            savemat(out_mat, {"I": I_out, "radial": q_out})
            print(f"OK [1D xlab, neg->0 vor Integration]: {out_mat}")
        elif mode == "find_maskB":
            ai_single = ais[0]
            shape     = imgs[0].shape

            # q-Wert für jeden Pixel berechnen
            q_map = ai_single.array_from_unit(shape=shape, unit="q_nm^-1")

            # Minimum-q pro Zeile (entlang Spalten mitteln)
            q_min_per_row = np.nanmin(q_map, axis=1)

            savemat(out_mat, {
                "q_min_per_row": q_min_per_row,
                "shape":         list(shape)
            })
            print(f"OK [find_maskB]: {out_mat}")   
        elif mode == "1d_batch_standard":
            npt_rad       = int(job.get("npt_rad", 1000))
            azimuth_range = job.get("azimuth_range", None)
            if isinstance(azimuth_range, list):
                azimuth_range = tuple(azimuth_range)

            correct_sa = job.get("correctSolidAngle", True)
            pol_factor = job.get("polarization_factor", None)

            N             = len(imgs)
            I_stack       = np.zeros((N, npt_rad), dtype=np.float32)
            radial_common = None

            for i, img_i in enumerate(imgs):
                img_single = img_i.copy()
                img_single[img_single < 0] = 0

                # ais[i] direkt verwenden → Pilatus-Maske bleibt aktiv
                ai = ais[i]

                integrate_kwargs = {"correctSolidAngle": correct_sa}
                if azimuth_range is not None:
                    integrate_kwargs["azimuth_range"] = azimuth_range
                if pol_factor is not None:
                    integrate_kwargs["polarization_factor"] = float(pol_factor)

                q_i, I_i = ai.integrate1d(
                    img_single,
                    npt  = npt_rad,
                    unit = "q_nm^-1",
                    **integrate_kwargs
                )

                I_i[I_i < 0] = 0
                I_stack[i, :] = I_i.astype(np.float32)
                # .dat-Datei im Cache-Ordner speichern
                img_base  = os.path.splitext(os.path.basename(img_paths[i]))[0]
                cache_dir = os.path.dirname(out_mat)
                dat_path  = os.path.join(cache_dir, img_base + '_integrated.dat')
                write_dat_file(dat_path, q_i, I_i, ai, pol_factor)
                if radial_common is None:
                    radial_common = q_i.astype(np.float32)

                if (i + 1) % 10 == 0 or i == N - 1:
                    print(f"  1d_batch_standard: {i+1}/{N}")

            np.savez(out_npz, I=I_stack, radial=radial_common)
            savemat(out_mat, {"I": I_stack, "radial": radial_common})
            print(f"OK [1D batch standard]: {out_mat}")
        elif mode == "1d_batch":
            all_I = []
            for i, (img, ai_i) in enumerate(zip(imgs, ais)):
                q, I_single = ai_i.integrate1d(
                    img,
                    npt_rad,
                    unit=unit,
                    method=method,
                    **{k: v for k, v in kwargs.items()
                       if k in ('correctSolidAngle', 'polarization_factor',
                                'dummy', 'delta_dummy', 'mask')}
                )

                all_I.append(I_single)
                if i % 50 == 0:
                    print(f"  {i}/{len(imgs)} integriert...")

            I_stack = np.array(all_I, dtype=np.float32)
            radial  = np.asarray(q, dtype=np.float32)

            np.savez(out_npz, I=I_stack, radial=radial)
            savemat(out_mat,  {"I": I_stack, "radial": radial})
            print(f"OK [1D batch]: {out_mat}")
        elif mode == "2d_batch":
            all_I      = []
            all_radial = []
            all_azim   = []

            for i, (img, ai_i) in enumerate(zip(imgs, ais)):
                res = ai_i.integrate2d(
                    img,
                    npt_rad,
                    npt_azim,
                    unit=unit,
                    method=method,
                    **{k: v for k, v in kwargs.items()
                       if k in ('correctSolidAngle', 'polarization_factor',
                                'dummy', 'delta_dummy', 'mask')}
                )
                if isinstance(res, tuple):
                    I2d, radial2d, azim2d = res[0], res[1], res[2]
                else:
                    I2d, radial2d, azim2d = res.intensity, res.radial, res.azimuthal

                all_I.append(np.asarray(I2d,      dtype=np.float32))
                all_radial.append(np.asarray(radial2d, dtype=np.float32))
                all_azim.append(np.asarray(azim2d,    dtype=np.float32))

                if i % 50 == 0:
                    print(f"  {i}/{len(imgs)} integriert...")

            I_stack      = np.stack(all_I,      axis=0)  # [N x npt_azim x npt_rad]
            radial_stack = np.stack(all_radial, axis=0)  # [N x npt_rad]
            azim_stack   = np.stack(all_azim,   axis=0)  # [N x npt_azim]

            np.savez(out_npz, I=I_stack, radial=radial_stack, azimuthal=azim_stack)
            savemat(out_mat,  {"I": I_stack,
                               "radial":    radial_stack,
                               "azimuthal": azim_stack})
            print(f"OK [2D batch]: {out_mat}")
        else:
            raise ValueError("mode must be '1d' or '2d'")

        meta = {
            "img_paths": img_paths, "poni_paths": poni_paths,
            "wavelength_m": wavelength_m, "mode": mode, "unit": unit,
            "npt_rad": npt_rad, "npt_azim": npt_azim,
            "method": method, "error_model": error_model,
            "chi_discont_deg": chi_disc,
            "save_raw_stack": save_stack, "save_ring_image": save_ring,
            "save_ring_det": save_ring_det,
            "kwargs": {k: str(v) for k, v in kwargs.items()},
        }
        with open(out_json, "w") as f:
            json.dump(meta, f, indent=2)

        print("OK: wrote", out_npz, "and", out_mat)
        return 0

    except Exception:
        traceback.print_exc()
        return 1

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("usage: pyfai_multigeom_run.py job.json")
        sys.exit(2)
    sys.exit(main(sys.argv[1]))