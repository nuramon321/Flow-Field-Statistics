# Flow Field Statistics

This workflow enables the averaging of multiple PIV recordings and the statistical analysis of flow fields, including velocities and directions, between two different groups. It is specifically adapted to the morphology of water fleas (*Daphnia*).

Different flow fields are spatially synchronized using translational and rotational transformations and temporally synchronized using a time warp. All vector quantities are interpolated onto the same coordinate grid for every timestamp. This results in a distribution of vector quantities at identical coordinates, which can then be averaged and statistically compared.

![Overview of the Flow Field Statistics workflow](Figures/Fig_4_Overview_workflow.png)

## Contents

- [Prerequisites / Requirements](#prerequisites--requirements)
- [PIVlab](#pivlab)
- [contourfcmap](#contourfcmap)
- [Input](#input)
- [Script Explanation](#script-explanation)
  - [1/3 Alignment](#13-alignment)
  - [2/3 Averaging](#23-averaging)
  - [3/3 Statistics](#33-statistics)
- [License](#license)

## Prerequisites / Requirements

- **MATLAB**
  - [PIVlab](https://www.pivlab.de/) (Thielicke, 2026); alternatively, any other PIV software that returns vector quantities and coordinates can be used.
  - **`Alignment.m`**
    - Mapping Toolbox
    - Image Processing Toolbox
  - **`Averaging.m`**
    - `inpaint_nans.m` (D'Errico, 2026)
  - **`Statistics.m`**
    - Mapping Toolbox
    - Image Processing Toolbox
    - Statistics and Machine Learning Toolbox
    - Curve Fitting Toolbox
    - Bioinformatics Toolbox
    - Circular Statistics Toolbox (Berens, 2026)
    - `contourfcmap.m` (Kearny, 2026)
- **Microsoft Excel**

Some lines of code in PIVlab and `contourfcmap` have been modified to support the required computations and visualizations.

## PIVlab (`PIVlab_GUI.m`)

### 1. Comment out

The following code needs to be commented out:

```matlab
A(:,round(size(A,2)/2))=0; 
A(round(size(A,1)/2),:)=0; 
B=A; 
B=im2bw(abs(A-B));
```

### 1. Replace boundary detection

Replace:

```matlab
bwbound=bwboundaries(A);
```

with:

```matlab
bwbound=[bwboundaries(A1); bwboundaries(A2); bwboundaries(A3); bwboundaries(A4)];
```

### contourfcmap
### 1. Replace boundary detection

Replace:

```matlab
clevcbar = [clev(1)-dy; clev(:); clev(end)+dy]; 
cmapcbar = [Opt.lo; cmap; Opt.hi];
```

with:

```matlab
clevcbar = [clev(1)-dy;clev(:)];
cmapcbar = [Opt.lo;cmap];
```

Replace:

```matlab
[hout.c, hout.h] = contour(x,y,z,clev); 
```

with:

```matlab
[hout.c, hout.h] = contour(x,y,z,clev, 'LineColor','none');
```


## Input

The script corresponding to the first step, `Alignment.m`, requires a MATLAB workspace containing the matrices and masks needed for spatial synchronization, as well as video timestamps for temporal synchronization.

| Software | Variable | Description |
|---|---|---|
| MATLAB | PIVlab workspace | Calibration factor, vector quantities (`u`, `v`, `vM`), and coordinate system (`x`, `y`) |
| MATLAB | PIVlab exported mask | `x`- and `y`-coordinates required for spatial synchronization |
| Excel | Table with timestamps | Start and end timestamps of movements and video numbers required for temporal synchronization |

The computations in the other two steps/scripts are independent of each other. However, the visualized results build upon the results of the preceding steps. Therefore, it is recommended to follow the steps in the specified order.


## Script Explanation

### 1/3 Alignment

The **Alignment** step consists of two parts:

1. Spatial synchronization
2. Temporal synchronization

It is specifically adapted to *Daphnia* morphology. The criteria used for identifying morphological landmarks must be adapted when applying the workflow to other morphologies.

#### Spatial Synchronization

For every frame, the spatial synchronization determines:

1. The highest point of the head (**head maximum**)
2. The lowest point of the daphnid body (**tailspine base**)
3. The longitudinal axis of the daphnid between these two points

The highest point of the head is used as the new origin, and all coordinates are translated accordingly. The line connecting the tailspine base and the head maximum defines the longitudinal axis of the animal. The angle between this axis and the vertical axis of the coordinate system is then used to calculate the required rotation matrix.

#### Temporal Synchronization

The temporal synchronization uses the timestamps provided in the Excel table. A model locomotion phase is predefined, onto which all other locomotion phases (**targets**) are fitted.

The algorithm first checks whether a temporal difference exists between the model locomotion phase and the current target locomotion phase. If no temporal difference exists, the target frames are copied directly.

If a temporal difference exists, the target locomotion phase is linearly compressed or stretched between its start and end timestamps to match the duration of the model locomotion phase.

The timestamps of the model locomotion phase are then compared with those of the target locomotion phase. For each model timestamp, the two closest target timestamps are identified, with one timestamp occurring before and one after the corresponding model timestamp.

The velocity matrices corresponding to these target timestamps are then combined using a weighted average based on their temporal distance from the model timestamp.

As a result, the model and target locomotion phases have identical durations and corresponding timestamps.

The resulting workspace is saved for subsequent averaging and statistical analysis.

#### Processing Order

1. Control Downstroke
2. Control Upstroke
3. Control Resting
4. Induced Downstroke
5. Induced Upstroke
6. Induced Resting

#### Excel Table

- **Rows:** Locomotion cycles
- **Columns:** Timestamps and cycle numbers

![Alignment workflow](Figures/Fig_5_Alignment.png)


### 2/3 Averaging

The **Averaging** script uses the results from the Alignment step (1/3). It combines the separated locomotion phases into a complete locomotion cycle.

First, the coordinates of the first animal group are averaged, and the minimum and maximum coordinates are determined for every frame. The still-rotated vector quantities are then interpolated onto a regular coordinate grid generated between the minimum and maximum coordinates.

When calculating the average for the second animal group, its vector quantities are interpolated onto the coordinate grid of the first animal group. This ensures that the vector quantities of both animal groups are represented at identical coordinates and can therefore be directly compared.

The script then calculates the average velocities for each video. Multiple locomotion cycles within the same video are weighted equally at the video level. For this purpose, the available vector quantities for each video are summed and divided by the respective number of locomotion cycles.

The overall average is then calculated by summing the averages of all videos and dividing by the total number of videos.

The resulting velocity magnitude is calculated from the averaged `u`- and `v`-components. This ensures that vectors pointing in opposite directions cancel each other out rather than being averaged as positive magnitudes.

The results are printed and saved as images, and the resulting workspace is saved for subsequent analysis.

#### Processing Order

1. Control (undefended animal) group
2. Treatment (defended animal) group

![Averaging workflow](Figures/Fig_6_Averaging.png)


### 3/3 Statistics

The **Statistics** script uses the results from the Alignment step (1/3) and the Averaging step (2/3). It combines the separated locomotion phases into a complete locomotion cycle.

If flow directions are analyzed, angles are calculated for every frame.

The data are prepared for statistical analysis in two steps:

1. All zeros are converted to `NaN` values.
2. The vector quantities are rearranged so that each cell corresponding to a specific coordinate and frame contains an array of vector quantities from all locomotion cycles at that coordinate.

A **Wilcoxon rank-sum test** is used to analyze velocity differences, while a **circular Watson-Williams test** is used to analyze differences in flow directions.

The resulting **p-values** are printed and saved as images.

A **False Discovery Rate (FDR)** correction is applied to account for multiple testing. The resulting **q-values** are printed and saved as images.

![Statistical analysis workflow](Figures/Fig_6_Statistics.png)


## License

Flow Field Statistics is released under the XXX license. See the [LICENSE](LICENSE) file for the full license text.

Flow Field Statistics orchestrates external software and may use external reference resources. These dependencies and resources are not relicensed by Flow Field Statistics and remain subject to their respective licenses and terms of use. Users are responsible for ensuring that their use of external dependencies complies with the applicable terms.





