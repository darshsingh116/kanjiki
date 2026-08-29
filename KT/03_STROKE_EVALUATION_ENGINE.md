# 03. Stroke Recognition & Evaluation Engine

## 1. How the Recognition Engine Works

The handwriting verification engine in `lib/widgets/kanji_canvas.dart` compares hand-drawn user strokes against the standardized vector curves from the **KanjiVG (Kanji Vector Graphics)** project.

---

## 2. Mathematical Pipeline

```
[Raw User Points] ──► Length Check ──► Resample to 30 pts ──┐
                                                              ├──► [Composite Scoring]
[KanjiVG SVG]     ──► Length Check ──► Resample to 30 pts ──┘
```

### 1. Arc-Length Ratio Evaluation (`lengthFactor`)
Before points are resampled, the actual pixel path length is computed:
$$\text{Ratio} = \frac{\text{User Stroke Length}}{\text{Reference Stroke Length}}$$
* $\text{Ratio} \in [0.60, 1.60] \implies \text{Factor} = 1.0$ (Allows normal handwriting variance).
* $\text{Ratio} < 0.60 \implies \text{Factor} = 1.0 - (0.60 - \text{Ratio}) \times 1.5$ (Penalizes tiny ticks/specks).
* $\text{Ratio} > 1.60 \implies \text{Factor} = 1.0 - (\text{Ratio} - 1.60) \times 0.9$ (Penalizes drawing a huge L for a small stroke).

### 2. Equidistant Point Resampling (`_resample`)
To eliminate drawing speed and screen touch sample rate differences, each stroke is converted into **exactly 30 equidistant points** along its arc length.

### 3. Direction & Vector Trajectory (`dirScore`)
Vector $\vec{R} = R_{\text{end}} - R_{\text{start}}$ and vector $\vec{U} = U_{\text{end}} - U_{\text{start}}$ are compared using a normalized dot product:
$$\cos(\theta) = \frac{\vec{R} \cdot \vec{U}}{\|\vec{R}\| \|\vec{U}\|}$$
* $\cos(\theta) \ge 0.50 \implies 1.0$ (Angle within $60^\circ$).
* $\cos(\theta) \in [0.0, 0.50] \implies 0.40 + 0.60 \times (\cos(\theta) / 0.50)$.
* $\cos(\theta) < 0.0 \implies 0.10$ (Severely penalizes backwards/reverse strokes).

### 4. Curvature / Sagitta Check (`shapeFactor`)
Distinguishes straight lines from curved or right-angled corners (e.g. `L` vs `|`):
* Calculates the midpoint offset (sagitta) from the straight line between start and end.
* If a straight stroke is drawn with a bend or corner (or vice-versa), the sagitta discrepancy reduces `shapeFactor`.

### 5. Elastic Dynamic Time Warping (DTW, $w = 10$)
Measures the non-linear distance between the 30 resampled points using windowed dynamic programming:
$$\text{normDist} = \frac{\text{avgDist}}{\text{canvasSize} \times 0.24}$$
$$\text{dtwSim} = (1.0 - \text{normDist}).\text{clamp}(0.0, 1.0)$$

### 6. Endpoint Distance Proximity
$$\text{endpointDist} = \frac{\|U_{\text{start}} - R_{\text{start}}\| + \|U_{\text{end}} - R_{\text{end}}\|}{2 \times \text{canvasSize}}$$
$$\text{endpointSim} = (1.0 - \text{endpointDist} \times 1.5).\text{clamp}(0.0, 1.0)$$

---

## 3. Composite Accuracy & Extra Stroke Formula

For each stroke pair:
$$\text{Accuracy} = \left( 0.40 \times \text{dtwSim} + 0.25 \times \text{endpointSim} + 0.20 \times \text{dirScore} + 0.15 \times \text{shapeFactor} \right) \times \text{lengthFactor}$$

### Overall Score Calculation:
If extra strokes are drawn beyond the expected count:
* Each extra stroke is recorded as `0.0` (displayed as `Extra Stroke X: Invalid (0%)` in Red).
* A strict penalty of $0.20$ per extra stroke is applied to the final score:
$$\text{Final Score} = \left( \frac{\sum \text{Accuracy} - \text{extraStrokes} \times 0.20}{\text{expectedCount} + \text{extraStrokes} \times 0.5} \right).\text{clamp}(0.0, 1.0)$$

---

## 4. Visual Feedback & CustomPainter Overlay

When checking or revealing answers:
* 🟢 **Green ($\ge 70\%$):** Correct shape, order, and trajectory.
* 🟠 **Amber / Orange ($45\%–69\%$):** Minor directional tilt or endpoint drift.
* 🔴 **Red ($< 45\%$):** Wrong direction, wrong shape, or missing/extra stroke.
* **Numbered Circular Badges:** Displays contrasting numbered badges (`1`, `2`, `3`...) at the start position of each stroke.
