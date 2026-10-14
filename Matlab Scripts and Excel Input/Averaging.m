%% 2/3 averaging
%
% author E.M.Schulenberg / RUB EcoEvo / 10.2026
%
% Processing order:
%   1. Control (undefended) animal group
%   2. Treatment (defended) animal group
%
% This script uses the results from the alignment script (1/3). It combines
% the separated locomotion phases into a full locomotion cycle.
% 
% It averages the coordinates of the first animal group and then identifies
% the minimum and maximum coordinates for every frame. The still-rotated 
% vector quantities are interpolated onto a straight coordinate grid that 
% is generated between the minima and maxima. If the average of the second 
% animal group is computed, their vector quantities are interpolated onto 
% grid of first animal group, so that the vector quantities of both animal 
% groups lie on the same coordinates.
% 
% Then it calculates the average velocities for every video. Serial 
% locomotion cycles in one video are thus weighted per video. For this, the
% available vector quantities for every video are summed up and divided by 
% their respective number.
%
% Then, the overall averge is computed by summing up the averages of every
% video and diving them by the number of videos.
%
% The resulting velocity magnitude is computed from the average of u- and
% v-values. This ensures that vectors pointing in opposite directions 
% cancel each other out rather than being averaged as positive magnitudes.
%
% The results are printed and saved as images, the workspace is saved.

clc;
clear;
close all;

%% Input
table = inputdlg({'Enter Table filename with File Extension (.xlsx)'}, 'Filenames', [1 70]);
vars = inputdlg({'Enter Output Framerate [fps]', 'Enter Treamtent: type C for Control or I for Induced',}, 'Input Variables', [1 70; 1 70]);
%'Enter Frame you want to see (0 for no figures)', 'Enter Locomotion Phase from this frame', 'Enter Cycle Nr from this frame'

% Find minimum and maximum numbers of interpolation files
filenames = dir('*.mat');
nrs_D = [];
nrs_U = [];
nrs_R = [];
for i = 1:numel(filenames)
    if contains(filenames(i).name, 'D_Interpolation')
        nrs_D(end+1, 1) = str2double(filenames(i).name(1));
    end
    if contains(filenames(i).name, 'U_Interpolation')
        nrs_U(end+1, 1) = str2double(filenames(i).name(1));
    end
    if contains(filenames(i).name, 'R_Interpolation')
        nrs_R(end+1, 1) = str2double(filenames(i).name(1));
    end
end
seq = [min(nrs_D) max(nrs_D); min(nrs_U) max(nrs_U); min(nrs_R) max(nrs_R)];
locPhase = ['D'; 'U'; 'R'];

% Read timestamps
timestampsTable = readtable(table{1});

% Iteration variables for masks
start_D = timestampsTable{timestampsTable{1,7}, 4};
dur_D = timestampsTable{timestampsTable{1,7}, 5};
end_D = timestampsTable{timestampsTable{1,7}, 6};

start_U = timestampsTable{timestampsTable{1,11}, 8};
dur_U = timestampsTable{timestampsTable{1,11}, 9};
end_U = timestampsTable{timestampsTable{1,11}, 10};

start_R = timestampsTable{timestampsTable{1,15}, 12};
dur_R = timestampsTable{timestampsTable{1,15}, 13};
end_R = timestampsTable{timestampsTable{1,15}, 14};

% Load and combine locomotion phases
for n = 1:3
    vM_temp = cell(0, 1);
    u_temp = cell(0, 1);
    v_temp = cell(0, 1);
    x_temp = cell(0, 1);
    y_temp = cell(0, 1);
    for i = seq(n,1):seq(n,2)
        if isfile(sprintf('%d_%s_Interpolation.mat', i, locPhase(n)))
            load(sprintf('%d_%s_Interpolation.mat', i, locPhase(n)), 'vM_int', 'u_int', 'v_int', 'x_int', 'y_int');
            vM_temp{end+1, 1} = vM_int;
            u_temp{end+1, 1} = u_int;
            v_temp{end+1, 1} = v_int;
            x_temp{end+1, 1} = x_int;
            y_temp{end+1, 1} = y_int;
        end
    end
    vM_all{n,1} = vertcat(vM_temp{:});
    u_all{n,1} = vertcat(u_temp{:});
    v_all{n,1} = vertcat(v_temp{:});
    x_all{n,1} = vertcat(x_temp{:});
    y_all{n,1} = vertcat(y_temp{:});
end

% 1st level: locomotion phase (1 = Downstroke, 2 = Upstroke, 3 = Sinking)
% 2nd level: sequence
% 3rd level: frames
% 4th level: content

% Combine masks
load('xMask_D.mat', 'xMask_save');
xMask_save_D = xMask_save;

load('xMask_U.mat', 'xMask_save');
xMask_save_U = xMask_save;

load('xMask_R.mat', 'xMask_save');
xMask_save_R = xMask_save;

load('yMask_D.mat', 'yMask_save');
yMask_save_D = yMask_save;

load('yMask_U.mat', 'yMask_save');
yMask_save_U = yMask_save;

load('yMask_R.mat', 'yMask_save');
yMask_save_R = yMask_save;

xMask_all = cell(dur_D + dur_U + dur_R, 1);
yMask_all = cell(dur_D + dur_U + dur_R, 1);

for i = start_D:end_D
    xMask_all{i + 1 - start_D, 1} = xMask_save_D{i, 1};
    yMask_all{i + 1 - start_D, 1} = yMask_save_D{i, 1};
end

for i = start_U:end_U
    xMask_all{dur_D + i + 1 - start_U, 1} = xMask_save_U{i, 1};
    yMask_all{dur_D + i + 1 - start_U, 1} = yMask_save_U{i, 1};
end

for i = start_R:end_R
    xMask_all{dur_D + dur_U + i + 1 - start_R, 1} = xMask_save_R{i, 1};
    yMask_all{dur_D + dur_U + i + 1 - start_R, 1} = yMask_save_R{i, 1};
end

% Input variables
treatment = vars{2};
framenr = str2double(vars{3});
locnr = str2double(vars{4});
phasenr = str2double(vars{5});

% Framerate
load(filenames(1).name, 'framerate');
framestep = framerate / str2double(vars{1});

% Scaling for quiver plot
quivscale = 16;

% Colours
origCol = [5/255 3/255 52/255];
changeCol = [218/255 91/255 103/255];
cmap_8col = [0.176 0.376 0.612; ...
    0.261 0.448 0.675; ...
    0.346 0.521 0.738; ...
    0.431 0.593 0.801; ...
    0.517 0.666 0.864; ...
    0.602 0.738 0.927; ...
    0.683 0.742 0.940; ...
    0.765 0.745 0.953];

% Contour levels
Levs8 = [-1 0.001 0.002 0.003 0.004 0.005 0.006 0.007 0.008 0.009 0.01 0.011 0.012];


%% average coordinates (only one animal group)
treatment = vars{2,1};

if treatment == 'C' 
    for n = 1:numel(x_all) % Average of all coordinates
        for i = 1:numel(x_all{n,1}{1}) %pre-allocation
            x_sum{n,1}{i,1} = zeros(size(x_all{n,1}{1}{i,1}));
            y_sum{n,1}{i,1} = zeros(size(y_all{n,1}{1}{i,1}));
        end

        for i = 1:numel(x_all{n,1}{1})
            for h = 1:numel(x_all{n,1})
                x_sum{n,1}{i,1} = x_sum{n,1}{i,1} + x_all{n,1}{h,1}{i,1};
                y_sum{n,1}{i,1} = y_sum{n,1}{i,1} + y_all{n,1}{h,1}{i,1};
            end
        end

        for i = 1:numel(x_all{n,1}{1})
            x_mean{n,1}{i,1} = x_sum{n,1}{i,1} ./ numel(x_all{n,1});
            y_mean{n,1}{i,1} = y_sum{n,1}{i,1} ./ numel(y_all{n,1});
        end
    end

    for n = 1:numel(x_mean) % identification of minima and maxima
        for i = 1:numel(x_mean{n,1})
            xmin_temp{n,1}(i,1) = min(x_mean{n,1}{i,1}, [], 'all');
            xmax_temp{n,1}(i,1) = max(x_mean{n,1}{i,1}, [], 'all');
            ymin_temp{n,1}(i,1) = min(y_mean{n,1}{i,1}, [], 'all');
            ymax_temp{n,1}(i,1) = max(y_mean{n,1}{i,1}, [], 'all');
        end
        xmin_temp2(n,1) = min(xmin_temp{n,1}, [], 'all');
        xmax_temp2(n,1) = max(xmax_temp{n,1}, [], 'all');
        ymin_temp2(n,1) = min(ymin_temp{n,1}, [], 'all');
        ymax_temp2(n,1) = max(ymax_temp{n,1}, [], 'all');
    end

    xmin = min(xmin_temp2, [], 'all');
    xmax = max(xmax_temp2, [], 'all');
    ymin = min(ymin_temp2, [], 'all');
    ymax = max(ymax_temp2, [], 'all');

else %vector quantities of second animal group are interpolated onto grid of first animal group -> same coordinates for both groups
    load('C_Mean.mat', 'xmin', 'xmax', 'ymin', 'ymax');
end

% Control mean coordinates
% if framenr ~= 0
%     figure;
%     title('Mean Coordinates');
%     xlabel('x [m]');
%     ylabel('y [m]');
%     hold on;
%     for j = 1:numel(vM_all{phasenr,1})
%         scatter(x_all{phasenr,1}{j,1}{framenr,1}, y_all{phasenr,1}{j,1}{framenr,1}, 5, 'MarkerEdgeColor', origCol);
%     end
%     scatter(x_mean{phasenr,1}{framenr,1}, y_mean{phasenr,1}{framenr,1}, 5, 'MarkerEdgeColor', changeCol, 'MarkerFaceColor', changeCol);
%     axis equal;
% end

disp('averaging of coordinates completed');

%% interpolate coordinates and values

nx = size(x_all{1,1}{1,1}{1,1}, 2); %pre-allocation
ny = size(x_all{1,1}{1,1}{1,1}, 1);

[X,Y] = meshgrid(linspace(xmin, xmax, nx), linspace(ymin, ymax, ny)); %straight grid from min/max values

for n = 1:numel(vM_all) % Grid interpolation
    for i = 1:numel(vM_all{n,1}{1,1})
        display(i, 'i');
        for h = 1:numel(vM_all{n,1})
            u_grid_all{n,1}{h,1}{i,1} = griddata(double(x_all{n,1}{h,1}{i,1}),double(y_all{n,1}{h,1}{i,1}),...
                        double(u_all{n,1}{h,1}{i,1}),double(X),double(Y));
            v_grid_all{n,1}{h,1}{i,1} = griddata(double(x_all{n,1}{h,1}{i,1}),double(y_all{n,1}{h,1}{i,1}),...
                        double(v_all{n,1}{h,1}{i,1}),double(X),double(Y));
            vM_grid_all{n,1}{h,1}{i,1} = griddata(double(x_all{n,1}{h,1}{i,1}),double(y_all{n,1}{h,1}{i,1}),...
                        double(vM_all{n,1}{h,1}{i,1}),double(X),double(Y));
        end
    end
end

% Control interpolation
% if framenr ~= 0
%     figure;
%     title('Grid Coordinates');
%     xlabel('x [m]');
%     ylabel('y [m]');
%     hold on;
%     for j = 1:numel(vM_all{phasenr,1})
%         scatter(x_mean{phasenr,1}{j,1}, y_mean{phasenr,1}{j,1}, 5, 'MarkerEdgeColor', origCol);
%     end
%     scatter(X, Y, 5, 'MarkerEdgeColor', changeCol, 'MarkerFaceColor', changeCol);
%     axis equal;
% 
%     figure;
%     title('Mean Coords+Orig. Vect. vs Interp. Coords+Vect.');
%     xlabel('x [m]');
%     ylabel('y [m]');
%     hold on;
%     quiver(x_mean{phasenr,1}{framenr,1}, y_mean{phasenr,1}{framenr,1}, u_all{phasenr,1}{locnr,1}{framenr,1}, v_all{phasenr,1}{locnr,1}{framenr,1}, 3, 'Color', origCol);
%     quiver(X, Y, u_grid_all{phasenr,1}{locnr,1}{framenr,1}, v_grid_all{phasenr,1}{locnr,1}{framenr,1}, 3, 'Color', changeCol);
%     axis equal;
% end

disp('grid interpolation completed');

%% averaging vectors

% Preparing data
for n = 1:numel(vM_all) %every locPhase gets same amount of cycles/filled with NaNs -> Important for next loop
    disp(n);
    q = 4 * n;
    beforeNaN = 0;
    if length(u_grid_all{n,1}) < height(timestampsTable)
            for p = 1:height(timestampsTable)
                if isnan(timestampsTable{p,q}) == true
                    u_grid_all{n,1}{p,2} = NaN;
                    v_grid_all{n,1}{p,2} = NaN;
                    vM_grid_all{n,1}{p,2} = NaN;
                    beforeNaN = beforeNaN + 1;
                else
                    u_grid_all{n,1}{p,2} = u_grid_all{n,1}{p-beforeNaN,1};
                    v_grid_all{n,1}{p,2} = v_grid_all{n,1}{p-beforeNaN,1};
                    vM_grid_all{n,1}{p,2} = vM_grid_all{n,1}{p-beforeNaN,1};
                end
            end
    else
        for r = 1:length(u_grid_all{n,1})
            u_grid_all{n,1}{r,2} = u_grid_all{n,1}{r,1};
            v_grid_all{n,1}{r,2} = v_grid_all{n,1}{r,1};
            vM_grid_all{n,1}{r,2} = vM_grid_all{n,1}{r,1};
        end
    end
end

% Calculation of divisor: if a cell has a value (not NaN), the divisor is increased by 1
% NaNs are replaced with 0, because they cannot be calculated with

u_mean{n,1}{r,1} = repmat({zeros(ny,nx)}, numel(u_grid_all{n,1}{1,1}), 1);
v_mean{n,1}{r,1} = repmat({zeros(ny,nx)}, numel(v_grid_all{n,1}{1,1}), 1);
vM_mean{n,1}{r,1} = repmat({zeros(ny,nx)}, numel(vM_grid_all{n,1}{1,1}), 1);

for n = 1:length(vM_all) %compute only once, otherwise _div gets wrong
    disp(n);
    maxSeq = max(timestampsTable{:,2});
    nr_sequences = accumarray(timestampsTable{:,2}, 1, [maxSeq 1]);
    beforeSeq = 0;
    for r = 1:length(nr_sequences)
        %disp(r);

        u_div{n,1}{r,1} = repmat({zeros(ny,nx)}, numel(u_grid_all{n,1}{1,1}), 1); % pre-allocation
        v_div{n,1}{r,1} = repmat({zeros(ny,nx)}, numel(v_grid_all{n,1}{1,1}), 1);
        vM_div{n,1}{r,1} = repmat({zeros(ny,nx)}, numel(vM_grid_all{n,1}{1,1}), 1);

        u_sum{n,1}{r,1} = repmat({zeros(ny,nx)}, numel(u_grid_all{n,1}{1,1}), 1); % pre-allocation
        v_sum{n,1}{r,1} = repmat({zeros(ny,nx)}, numel(v_grid_all{n,1}{1,1}), 1); 
        vM_sum{n,1}{r,1} = repmat({zeros(ny,nx)}, numel(vM_grid_all{n,1}{1,1}), 1);

        for h = 1:nr_sequences(r,1)
            disp(h);
            %disp(r);
            %disp(beforeSeq);
            %
            if numel(u_grid_all{n,1}{h+beforeSeq,2}) > 1 %if cell has content
                for i = 1:length(vM_all{n,1}{1,1})
                    for j = 1:height(u_grid_all{n,1}{h+beforeSeq,2}{i,1})
                        for k = 1:width(u_grid_all{n,1}{h+beforeSeq,2}{i,1})
                            if isnan(u_grid_all{n,1}{h+beforeSeq,2}{i,1}(j,k)) == false
                                u_div{n,1}{r,1}{i,1}(j,k) = u_div{n,1}{r,1}{i,1}(j,k) + 1; % calculation divisor
                            else
                                u_grid_all{n,1}{h+beforeSeq,2}{i,1}(j,k) = 0; %no nans for later division
                            end
                            if isnan(v_grid_all{n,1}{h+beforeSeq,2}{i,1}(j,k)) == false
                                v_div{n,1}{r,1}{i,1}(j,k) = v_div{n,1}{r,1}{i,1}(j,k) + 1;
                            else
                                v_grid_all{n,1}{h+beforeSeq,2}{i,1}(j,k) = 0;
                            end
                            if isnan(vM_grid_all{n,1}{h+beforeSeq,2}{i,1}(j,k)) == false
                                vM_div{n,1}{r,1}{i,1}(j,k) = vM_div{n,1}{r,1}{i,1}(j,k) + 1;
                            else
                                vM_grid_all{n,1}{h+beforeSeq,2}{i,1}(j,k) = 0;
                            end
                        end
                    end
                    u_sum{n,1}{r,1}{i,1} = u_sum{n,1}{r,1}{i,1} + u_grid_all{n,1}{h+beforeSeq,2}{i,1}; %calculation sum
                    v_sum{n,1}{r,1}{i,1} = v_sum{n,1}{r,1}{i,1} + v_grid_all{n,1}{h+beforeSeq,2}{i,1};
                    vM_sum{n,1}{r,1}{i,1} = vM_sum{n,1}{r,1}{i,1} + vM_grid_all{n,1}{h+beforeSeq,2}{i,1};
                end
            end
        end
    beforeSeq = beforeSeq + h;
    end
    
    for i = 1:length(vM_sum{n,1}) %average of vectors: divisor/dividend, mean of every Video
        for j = 1:length(vM_sum{n,1}{i,1})
            u_mean{n,1}{i,1}{j,1} = double(u_sum{n,1}{i,1}{j,1}./u_div{n,1}{i,1}{j,1});
            v_mean{n,1}{i,1}{j,1} = double(v_sum{n,1}{i,1}{j,1}./v_div{n,1}{i,1}{j,1});
            vM_mean{n,1}{i,1}{j,1} = double(vM_sum{n,1}{i,1}{j,1}./vM_div{n,1}{i,1}{j,1});
        end
    end
end

%calculation weighted average per video

for n = 1:length(vM_all)
    disp(n);
    
    u_div_all{n,1} = repmat({zeros(ny,nx)}, numel(u_grid_all{n,1}{1,1}), 1); %pre-allocation
    v_div_all{n,1} = repmat({zeros(ny,nx)}, numel(v_grid_all{n,1}{1,1}), 1);
    vM_div_all{n,1} = repmat({zeros(ny,nx)}, numel(vM_grid_all{n,1}{1,1}), 1);

    for h = 1:length(u_mean{n,1})
        for i = 1:length(u_mean{n,1}{h,1})
            for j = 1:height(u_mean{n,1}{h,1}{i,1})
                for k = 1:width(u_mean{n,1}{h,1}{i,1})
                    if isnan(u_mean{n,1}{h,1}{i,1}(j,k)) == false
                        u_div_all{n,1}{i,1}(j,k) = u_div_all{n,1}{i,1}(j,k) +1; % calculation divisor
                    else
                        u_mean{n,1}{h,1}{i,1}(j,k) = 0; %no nans for later division
                    end
                    if isnan(v_mean{n,1}{h,1}{i,1}(j,k)) == false
                        v_div_all{n,1}{i,1}(j,k) = v_div_all{n,1}{i,1}(j,k) +1;
                    else
                        v_mean{n,1}{h,1}{i,1}(j,k) = 0;
                    end
                    if isnan(vM_mean{n,1}{h,1}{i,1}(j,k)) == false
                        vM_div_all{n,1}{i,1}(j,k) = vM_div_all{n,1}{i,1}(j,k) +1;
                    else
                        vM_mean{n,1}{h,1}{i,1}(j,k) = 0;
                    end
                end
            end
        end
    end

    u_sum_all{n,1} = repmat({zeros(ny,nx)}, numel(u_grid_all{n,1}{1,1}), 1); %pre-allocation
    v_sum_all{n,1} = repmat({zeros(ny,nx)}, numel(v_grid_all{n,1}{1,1}), 1);
    vM_sum_all{n,1} = repmat({zeros(ny,nx)}, numel(vM_grid_all{n,1}{1,1}), 1);

    for i = 1:length(vM_all{n,1}{1,1})
        for h = 1:length(u_sum{n,1})
            u_sum_all{n,1}{i,1} = u_sum_all{n,1}{i,1} + u_mean{n,1}{h,1}{i,1}; %calculation of dividend/sum
            v_sum_all{n,1}{i,1} = v_sum_all{n,1}{i,1} + v_mean{n,1}{h,1}{i,1};
            vM_sum_all{n,1}{i,1} = vM_sum_all{n,1}{i,1} + vM_mean{n,1}{h,1}{i,1};
        end
    end
    
    for i = 1:length(vM_all{n,1}{1,1}) %average of vectors: divisor/dividend
        u_mean_all{n,1}{i,1} = double(u_sum_all{n,1}{i,1}./u_div_all{n,1}{i,1});
        v_mean_all{n,1}{i,1} = double(v_sum_all{n,1}{i,1}./v_div_all{n,1}{i,1});
        vM_mean_all{n,1}{i,1} = double(vM_sum_all{n,1}{i,1}./vM_div_all{n,1}{i,1});
    end
end


for n = 1:numel(vM_all)
    disp(n);
    for i = 1:length(u_mean_all{n,1})
        vM_mean_new{n,1}{i,1} = hypot(u_mean_all{n,1}{i,1},v_mean_all{n,1}{i,1}); %velocity magnitude after mean calculation
        %
        for h = 1:length(u_mean_all{n,1})
            for j = 1:height(u_mean_all{n,1}{h,1})
                for k = 1:width(u_mean_all{n,1}{h,1})
                    if u_mean_all{n,1}{h,1}(j,k) == 0
                        u_mean_all{n,1}{h,1}(j,k) = NaN;
                    end
                    if v_mean_all{n,1}{h,1}(j,k) == 0
                        v_mean_all{n,1}{h,1}(j,k) = NaN;
                    end
                    if vM_mean_all{n,1}{h,1}(j,k) == 0
                        vM_mean_all{n,1}{h,1}(j,k) = NaN;
                    end
                    if vM_mean_all{n,1}{h,1}(j,k) == 0
                        vM_mean_new{n,1}{h,1}(j,k) = NaN;
                    end
                end
            end
        end

        u_full{n,1}{i,1} = inpaint_nans(u_mean_all{n,1}{i,1}); %interpolate NaNs
        v_full{n,1}{i,1} = inpaint_nans(v_mean_all{n,1}{i,1});
        vM_full{n,1}{i,1} = inpaint_nans(vM_mean_all{n,1}{i,1});
        vM_full_new{n,1}{i,1} = inpaint_nans(vM_mean_new{n,1}{i,1});
    end
end

num = 0;
for n = 1:length(vM_full) %locomotion cycle into one array
    for i = 1:length(vM_full{n,1})
        u_sort{i+num,1} = u_full{n,1}{i,1};
        v_sort{i+num,1} = v_full{n,1}{i,1};
        vM_sort{i+num,1} = vM_full{n,1}{i,1};
        vM_sort_new{i+num,1} = vM_full_new{n,1}{i,1};
    end
    num = length(vM_sort_new);
end

% control vector average
% if framenr ~= 0
%     figure;
%     title('Vectors with Average');
%     xlabel('x [m]');
%     ylabel('y [m]');
%     hold on;
%     quiver(X, Y,u_full{phasenr,1}{framenr,1}, v_full{phasenr,1}{framenr,1}, 3, "Color", changeCol); %mean coordinates and vector values
%     axis equal;
% end
%
disp('averaging of vectors completed');


%% printing images

mkdir figures

for i = 1:framestep:length(vM_sort)
    f= figure;
    f.Color = 'w';
    contourf(X,Y,vM_sort_new{i,1}, Levs8,'LineColor','none'); %colours
    hold on;
    if treatment == 'C' %vectors
        quiver(X,Y,(u_sort{i,1}/quivscale),(v_sort{i,1}/quivscale),'off','Color', [0.05 0.05 0.05]); %no automatic scaling
    elseif treatment == 'I'
        quiver(X,Y,(u_sort{i,1}/quivscale),(v_sort{i,1}/quivscale),'off','Color', [0.95 0.95 0.95]);
    end
    fill(xMask_all{i,1},yMask_all{i,1},[0.6 0.6 0.6],'EdgeColor',[0.6 0.6 0.6]) %animal
    axis equal;
    colormap(cmap_8col);
    hcb = colorbar('EastOutside','Ticks', [0,0.001,0.002,0.003,0.004,0.005,0.006,0.007,0.008,0.009]); %colourbar position and ticks
    hcb.Title.String = 'V [ms^{-1}]        '; %colourbar title
    clim([0 0.008]); %axis limits
    xlim([-0.004 0.004]);
    ylim([-0.006 0.002]);
    xlabel('x-dir [m]'); %axis labels
    ylabel('y-dir [m]');
    box on;
    set(gca, 'LooseInset', get(gca, 'TightInset'));
    exportgraphics(gca, strcat('figures_20261013/', treatment, '_', sprintf('%02d', i), '.png'), 'BackgroundColor', 'none', 'ContentType', 'image');
    close all;
end


%% save

save([treatment '_Mean.mat']);
if strcmp(treatment,'C')
    copyfile('C_Mean.mat',fullfile('..','Induced'));
else
    mkdir(fullfile('..','Comparison'));
    copyfile('C_Mean.mat',fullfile('..','Comparison'));
    copyfile('I_Mean.mat',fullfile('..','Comparison'));
end
disp('DONE :)');
