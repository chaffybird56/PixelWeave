# PixelWeave — Demosaicing with Least‑Squares & Gaussian Smoothing

> A compact project that reconstructs full‑color images from a **Bayer** sensor mosaic using two classical approaches:
>
> **(A)** local **least‑squares regression** on $5\times5$ patches and **(B)** **Gaussian weighted averaging**. Both are compared against MATLAB’s built‑in `demosaic`, with **RMSE** reporting.

---

## 🎯 What this project is

Digital cameras with a Bayer filter record **one color per pixel** (R, G, or B). **Demosaicing** infers the two missing colors at each pixel to produce an RGB image. This repo implements and compares two demosaicers:

* **Algorithm 1 — Patchwise Least‑Squares (LS):** learn a linear filter for each Bayer phase that best predicts the **center pixel’s** missing color from its $5\times5$ neighborhood. Coefficients are computed once from ground‑truth patches, then applied to a simulated mosaic.
* **Algorithm 2 — Gaussian Weighted Average (GAUSS):** fill missing colors by convolving a $5\times5$ **Gaussian kernel** ($\sigma=1$) over local neighborhoods—simple, smooth, and fast.

Both pipelines generate a **Bayer mosaic** from a clean RGB image for controlled testing, using the pattern with **B at $(1,1)$**, **G at $(1,2)$ and $(2,1)$**, **R at $(2,2)$** (BGGR).

---

## 🔎 How the Bayer mosaic is synthesized

From a ground‑truth RGB image $I$, a single‑channel mosaic $M$ is created by sampling the appropriate color at each pixel according to the Bayer pattern (BGGR). That gives a grayscale image that still encodes color **by location**.

> This synthetic setup allows “apples‑to‑apples” evaluation: demosaic the mosaic and measure RMSE against the original RGB frame. The scripts also compare to MATLAB’s `demosaic(...,'bggr')` (or `...,'rggb'` for raw inputs) and report **RMSE**.

---

## 🧮 Algorithm 1 — Patchwise Least‑Squares (LS)

### Idea in words

For each of the **four Bayer phases** and for each **output color channel**, learn a **linear filter** that predicts the **center pixel value** from its local $5\times5$ mosaic neighborhood. During inference, slide the learned filter over the mosaic and fill in the two missing colors at each pixel.

### The optimization

Let $x\in\mathbb{R}^{25}$ be a vectorized $5\times5$ mosaic patch (centered at a pixel with a known Bayer phase), and let $y\in\mathbb{R}$ be the **ground‑truth center pixel** in the target color channel. The model is a linear predictor

$$
\hat y = w^\top x,
$$

with coefficients $w\in\mathbb{R}^{25}$ found by minimizing the least‑squares error over many training patches:

$$
\min_{w}\ \|X^\top w - g\|_2^2 .
$$

Here, **columns** of $X$ are patch vectors, and $g$ is the **row** of center pixels from the ground‑truth image (one center per patch). The closed‑form normal‑equation solution gives $w = (XX^\top)^{-1}Xg^\top$.

**What those symbols mean, practically:** the vector $w$ is just a small **learned filter** (reshape to $5\times5$) that—when dotted with the neighborhood around a pixel—produces the best estimate of the **missing color at that pixel**. There is one $w$ for each **Bayer phase** (which neighbor pattern is visible) and **color channel** (R, G, or B).

### Applying the filters

At inference time, for each pixel $(r,c)$ the code (i) picks which **phase** the pixel belongs to, (ii) extracts the $5\times5$ patch $P$, and (iii) applies the right coefficient vector $w$ (reshaped as a kernel) to fill the **two missing channels**; the present channel is kept as‑is.

**Pseudocode (LS, single cell):**

```text
phase = f(r,c)              # which of 4 Bayer offsets
P = M[r-2:r+2, c-2:c+2]     # 5x5 neighborhood
for color in {R,G,B}:
    if color is missing at (r,c):
        w = W[phase,color]  # learned 25-vector
        Ihat[r,c,color] = sum(P .* reshape(w,5,5))
    else:
        Ihat[r,c,color] = M[r,c]    # keep observed channel
```

---

## 🟢 Algorithm 2 — Gaussian Weighted Averaging (GAUSS)

### Idea in words

Replace the learned filter with a **fixed** $5\times5$ **Gaussian kernel** $G$ ($\sigma=1$). For each pixel and each **missing** color channel, take the weighted average of the $5\times5$ neighborhood. Pixels closer to the center contribute more; far pixels contribute less. This reduces noise and yields smooth color fields.

### The computation

Let $P$ be the local $5\times5$ patch around $(r,c)$. The estimate is

$$
\hat y = \sum_{i,j} G[i,j]\; P[i,j],
$$

evaluated **only** for channels that are missing at $(r,c)$; the observed channel is copied through unchanged. In implementation, `fspecial('gaussian',[5,5],1)` creates $G$, then the code multiplies element‑wise and sums.

**Pseudocode (GAUSS, single cell):**

```text
phase = f(r,c)
P = M[r-2:r+2, c-2:c+2]
for color in {R,G,B}:
    if color missing at (r,c):
        Ihat[r,c,color] = sum(P .* G)
    else:
        Ihat[r,c,color] = M[r,c]
```

---

## 🧪 Evaluation & what to expect

**Metric.** Root Mean Squared Error (RMSE) between the demosaiced image and ground truth:

$$
\mathrm{RMSE} = \sqrt{\tfrac{1}{N}\sum_{p=1}^{N} \|I_{\text{true}}(p)-I_{\text{demo}}(p)\|_2^2},
$$

computed channel‑wise and averaged (the helper routine follows exactly this).

**Comparison to MATLAB `demosaic`.** In tests, the **Gaussian** method often lands within about **0.07–0.12 RMSE** of MATLAB’s built‑in algorithm—close for a simple baseline. The built‑in likely adds edge‑aware tricks that reduce artifacts further. The **LS** method typically preserves edges/fine detail better if the training patches are representative.

---

## 📸 Visuals

<div align="center">
  <img src="[FIG2_URL](https://github.com/user-attachments/assets/2a8058b6-8648-4bdc-9c39-b05628aed68a)" width="500" alt="Fig 2 — Input, Bayer mosaic, and demosaiced result (Algorithm 2 example)"/>
  <br/>
  <sub><b>Fig 2.</b> Algorithm 1</sub>
</div>

<div align="center">
  <img src="[FIG3_URL](https://github.com/user-attachments/assets/69a68e0b-f376-4198-b4f3-f40bb2d3e2d1)" width="500" alt="Fig 3 — Another test scene showing texture handling"/>
  <br/>
  <sub><b>Fig 3.</b> Algorithm 2</sub>
</div>

---

## 🧠 When each method shines

* **GAUSS**: simple, robust, and noise‑reducing; best when computational budget is tiny and scenes are not edge‑dense.
* **LS**: preserves edges/fine detail better by adapting to local color relationships—but costs more to train/apply.

---

## 🔩 Repo notes (what’s where)

* `algo_1_.txt` — MATLAB for **Algorithm 1 (LS)**: makes mosaic, builds per‑phase coefficient vectors by least squares, demosaics by convolving the learned $5\times5$ kernels, and reports RMSE & figures. See the *generate coefficients* routine and *apply* loop.
* `algo_2.txt` — MATLAB for **Algorithm 2 (GAUSS)**: uses `fspecial('gaussian',[5,5],1)` and a neighborhood sum for missing channels; also computes RMSE and side‑by‑side plots.

---

## ⚖️ Takeaways

* Both custom methods are **credible baselines**: GAUSS trails MATLAB by \~0.1 RMSE on average, while LS offers a path to **edge‑aware** quality if coefficients are well learned.
* The **Bayer synthesis + RMSE harness** makes it easy to swap in other demosaicers (edge‑directed, gradient‑based, CNNs) for fair comparisons.

---

### License

MIT — see `LICENSE`.
