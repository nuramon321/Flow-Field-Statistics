### Settings for Daphnia longicephala

## Image Aquisition

# Hardware
- ZQ1, ZLASER GmbH, Freiburg, Germany (λ = 520 nm, d = 0.5mm)
- Optronis CamRecord CR3000x2

# Software
- Optronis TimeViewer 1.4.8


## Image Pre-Processing + Masking

Masking was performed in the general Matlab Environment (Script: 0_Masking.mat)

Image Pre-Processing was done with in-build PIVlab (Matlab Add-on Version 2.63) functions.

# Settings
- CLAHE: 64
- highpass: 15
- contrast stretch: 0.09-0.6

Irfan View was used for possible mask correction


## Cross-Correlation

The PIV analysis was done in PIVlab (2.63).

# Settings
- PIV algorithm: FFT window deformation
- 1rst pass: 120x120px
- 2nd pass: 80x80px
- Sub-pixel estimator: Gauss 2x3-point
- Correlation robustness: Standard (recommended)

# Calibration settings
- Reference length [px]: select inner diameter
- Real distance [mm]: 9
- time step [ms]: 5

# Exported Parameters
- Vectors [px/frame]
- Velocity Magnitude [m/s]
- u component [m/s]
- v component [m/s]
- Correlation Coefficient