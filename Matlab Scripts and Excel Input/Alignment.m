%% 1/3 Spatial and temporal interpolation of locomotion cycles
%
% author E.M.Schulenberg / RUB EcoEvo / 10.2026
%
% Processing order:
%   1. Control Downstroke
%   2. Control Upstroke
%   3. Control Resting
%   4. Induced Downstroke
%   5. Induced Upstroke
%   6. Induced Resting
%
% Excel table:
%  Rows represent locomotion cycles
%  Columns contain timestamps and cycle numbers
%
%
% The spatial interpolation determines, for every frame, the following
% critera. They have to be adapted to other morphologies.
%   1. The lowest point of the daphnid body -> tailspine base
%   2. The highest point of the head -> head maximum
%   3. The angle between the longitudinal axis of the daphnid and the
%   vertical axis of the coordinate system
%
% The head maximum is searched within:
%   xMask_min +/- distance_X
% and must be more than 300 px above the tailspine base.
%
% If the required interpolation data already exists, it is loaded instead
% of being calculated again.
%
% All mask and PIV coordinates are multiplied by the calibration factor. 
% The coordinate system is shifted, so that the calibrated head maximum
% becomes the origin.
%
% The calibrated mask coordinates are stored in xMask_Img and yMask_Img
% later for saving and figure generation in the second and third scripts.
%
% The rotation matrix is applied to coordinates, velocity vectors and mask
% coordinates. The sign of angle determines the direction of rotation. Now,
% all locomotion cycles have identical coordinates.
%
%
% The temporal interpolation uses the timestamps from the .xlsx table. A 
% model locomotion phase onto wich all other locomotion phases (targets) 
% are fittet, is pre-defined.
% 
% The interpolation checks whether a temporal difference between the model 
% locomotion phase and the current target locomotion phase exists. If this 
% is not the case, the target frames are copied.
%
% It linearly compresses or stretches the differing (target) locomotion
% phase between start- and endtimestamp of the model locomotion phase.
%
% Then, it compares the timestamps of the model locomotion phase to the 
% timestamps of the differing (target) locomotion phase and identifies the 
% target timestamps that are closest to every model timestamp. The closest
% target timestamps are always before and after one model timestamp.
%
% Then, it computes the weighted average of the respective velocity 
% matrices from the closest target timestamps based on their distance to 
% the model timestamp. Now, model and differing (target) locomotion phases
% have identical durations.
%
%The workspace is saved for following averaging and statistical analysis.

clc;
clear;
close all;

%% Input

%files
filenames = inputdlg({ ...
    'Enter Workspace Filename', ...
    'Enter Mask Filename', ...
    'Enter Table filename with File Extension (.xlsx)' ...
    }, 'Load Files', [1 70; 1 70; 1 70]);

if isempty(filenames) % Abort if input dialog was cancelled
    error('File selection was cancelled.');
end

% variables
vars = inputdlg({ ...
    'Enter Treatment: type 0 for Control or 1 for Induced', ...
    'Enter locomotory Phase. type 1 for Downstroke, 2 for Upstroke, 3 for Resting', ...
    'Enter Current Video Number (see Excel Table 2nd Column)', ...
    'Enter Framerate [fps]', ...
    'Do you want to use this Videos masks for later Image Generation in the 2nd Script? type 1 for Yes, press 0 for No.', ...
    'Do you want to create Figures? Yes: type Framenumber you want to see, No: type 0.' ...
    }, 'Input Variables', [1 70; 1 70; 1 70; 1 70; 1 70; 1 70]);

if isempty(vars) % Abort if input dialog was cancelled
    error('Variable input was cancelled.');
end

% Convert input strings to numbers
nr_video   = str2double(vars{3,1});
framerate  = str2double(vars{4,1});
modelMask  = str2double(vars{5,1});
framenr    = str2double(vars{6,1});


% Check input values
if ~ismember(vars{1,1}, {'0', '1'})
    error('Treatment must be 0 (Control) or 1 (Induced).');
end

if ~ismember(vars{2,1}(1), '123')
    error('Locomotory phase must be 1 (Downstroke), 2 (Upstroke), or 3 (Resting).');
end

if isnan(nr_video) || nr_video < 1 || mod(nr_video,1) ~= 0
    error('Current Video Number must be a positive integer.');
end

if isnan(framerate) || framerate <= 0
    error('Framerate must be greater than 0.');
end

if ~ismember(modelMask, [0 1])
    error('Mask input must be 0 (No) or 1 (Yes).');
end

if isnan(framenr) || framenr < 0
    error('Figure frame number must be 0 or greater.');
end

% Load timestamp table
% Structure of the Excel table:
% Rows = locomotion cycles, Columns = timestamps + numbers
timestampsTable = readtable(filenames{3,1});

% Number of usable sequences in all videos
maxSeq = max(timestampsTable{:,2}); % Column 2 = video nr
nr_sequences = accumarray(timestampsTable{:,2}, 1, [maxSeq 1]);
nr_sequences = nr_sequences.';
beforeSeq = sum(nr_sequences(1:nr_video-1)); % Number of sequences before current video

% Determine columns depending on locomotion phase
switch vars{2,1}(1)
    case '1' % Downstroke
        TabIdxStart = 1;
        TabIdxDur   = 2;
        TabIdxEnd   = 3;
        row_model = timestampsTable{1,7}; % Model locomotion cycle
    case '2' % Upstroke
        TabIdxStart = 4;
        TabIdxDur   = 5;
        TabIdxEnd   = 6;
        row_model = timestampsTable{1,11}; % Model locomotion cycle
    case '3' % Resting
        TabIdxStart = 7;
        TabIdxDur   = 8;
        TabIdxEnd   = 9;
        row_model = timestampsTable{1,15}; % Model locomotion cycle
end

% Timestamps for temporal interpolation
down_start_frame = timestampsTable{:,4};
down_dur         = timestampsTable{:,5};
down_end_frame   = timestampsTable{:,6};

up_start_frame   = timestampsTable{:,8};
up_dur           = timestampsTable{:,9};
up_end_frame     = timestampsTable{:,10};

rest_start_frame = timestampsTable{:,12};
rest_dur         = timestampsTable{:,13};
rest_end_frame   = timestampsTable{:,14};

% Combined timestamp table
% Columns:
%   1 = Downstroke start
%   2 = Downstroke duration
%   3 = Downstroke end
%   4 = Upstroke start
%   5 = Upstroke duration
%   6 = Upstroke end
%   7 = Resting start
%   8 = Resting duration
%   9 = Resting end

Tab = [down_start_frame, down_dur, down_end_frame, ...
       up_start_frame,   up_dur,   up_end_frame, ...
       rest_start_frame, rest_dur, rest_end_frame];

% Treatment and locomotion direction
switch vars{1,1}
    case '0' % Control
        direction = 'Control';
        distance_X = 50;
    case '1'  % Induced
        direction = 'Induced';
        distance_X = 80;
end

% Locomotion phase abbreviation
switch vars{2,1}(1)
    case '1'
        locPhase = 'D';
    case '2'
        locPhase = 'U';
    case '3'
        locPhase = 'R';
end

% Create treatment folder
% Only create folder when starting with the first video
if nr_video == 1 && ~isfolder(direction)
    mkdir(direction);
end

% Colours
gray = [0.8 0.8 0.8];
origCol = [5/255, 3/255, 52/255];
changeCol = [218/255, 91/255, 103/255];

% Load workspace and mask
load(filenames{1,1});
load(filenames{2,1});

% Select original or smoothed PIV values
% If smoothed values should be used, replace the following two
% assignments with:
%
%   u_values = u_smoothed;
%   v_values = v_smoothed;

u_values = u_original;
v_values = v_original;

% Display processing information
fprintf('\n');
fprintf('---------------------------------------------\n');
fprintf('Spatial and temporal interpolation\n');
fprintf('---------------------------------------------\n');
fprintf('Treatment:        %s\n', direction);
fprintf('Locomotion phase: ');

switch locPhase
    case 'D'
        fprintf('Downstroke\n');
    case 'U'
        fprintf('Upstroke\n');
    case 'R'
        fprintf('Resting\n');
end

fprintf('Video number:     %d\n', nr_video);
fprintf('Framerate:        %.2f fps\n', framerate);
fprintf('Model cycle:      %d\n', row_model);
fprintf('Sequences before: %d\n', beforeSeq);
fprintf('---------------------------------------------\n\n');

% Rearrange masks into one array
maskiererx = cell(size(masks_in_frame)); %pre-allocation
maskierery = cell(size(masks_in_frame));

for i = 1:length(masks_in_frame)
    maskiererx{1,i} = masks_in_frame{1,i}{1,2}(:,1); % Replace the original mask arrays
    maskierery{1,i} = masks_in_frame{1,i}{1,2}(:,2);
end

maskiererx = maskiererx';
maskierery = maskierery';

% Display and Check PIVlab mask
if framenr ~= 0
    figure;
    scatter(maskiererx{1, framenr}, maskierery{1, framenr}, 10, 'MarkerEdgeColor', gray, 'MarkerFaceColor', gray);
    title('PIVlab Mask');
    xlabel('x [px]');
    ylabel('y [px]');
    axis equal;
    box on;
end

%% Spatial interpolation
disp('SPATIAL INTERPOLATION');

% Check whether spatial interpolation already exists
% Spatial interpolation is already available for Upstroke and Resting
% phases because the Downstroke calculation can be reused.
if (vars{1,1} == '1' && (vars{2,1}(1) == '2' || vars{2,1}(1) == '3'))
    if exist(fullfile('Induced', [vars{3,1}, '_D_Interpolation.mat']), 'file') == 2
        load(fullfile('Induced', [vars{3,1}, '_D_Interpolation.mat']), ...
             'u_rot', 'v_rot', 'vM_rot', 'x_rot', 'y_rot', 'xMask_rot', 'yMask_rot', 'direction');
        disp('Spatial interpolation data loaded.');
    end
elseif (vars{1,1} == '0' && (vars{2,1}(1) == '2' || vars{2,1}(1) == '3'))
    if exist(fullfile('Control', [vars{3,1}, '_D_Interpolation.mat']), 'file') == 2
        load(fullfile('Control', [vars{3,1}, '_D_Interpolation.mat']), ...
             'u_rot', 'v_rot', 'vM_rot', 'x_rot', 'y_rot', 'xMask_rot', 'yMask_rot', 'direction');
        disp('Spatial interpolation data loaded.');
    end

% Calculate spatial interpolation
else
    disp('Calculating spatial interpolation...');

    %Determine body orientation for every frame
    for i = 1:length(x)
        fprintf('Frame %d / %d\n', i, length(x));
        % Prepare mask coordinates
        xMask_temp{i,1} = maskiererx{1,i}; % Extract mask coordinates
        yMask_temp{i,1} = maskierery{1,i};
        yMask_temp{i,1} = yMask_temp{i,1} * (-1); % Flip y-coordinates
        yMask_min(i) = min(yMask_temp{i,1}); % Find tailspine base
        idx_yMask = find(yMask_temp{i,1} == yMask_min(i)); % Find mask point with the minimum y-coordinate
        xMask_min(i) = xMask_temp{i,1}(idx_yMask(1)); % If several points have same minimum y-coordinate, use first one

        % Find possible head points
        for n = 1:length(xMask_temp{i,1})
            %+- 50 for cnt/75 for ind px in x direction and > 300px in y direction difference
            if xMask_temp{i,1}(n,1) > xMask_min(i) - distance_X && xMask_temp{i,1}(n,1) < xMask_min(i) + distance_X && (yMask_temp{i,1}(n,1) - yMask_min(i)) > 300
                headPointsX{i,1}(n,1) = xMask_temp{i,1}(n,1);
                headPointsY{i,1}(n,1) = yMask_temp{i,1}(n,1);
            else
                headPointsX{i,1}(n,1) = -inf;
                headPointsY{i,1}(n,1) = -inf;
            end
        end

        % Remove points whose connecting vector intersects the body = not the longitudinal axis
        for n = find(idx_head).'
            intersect{i,1}{n,1} = polyxpoly([xMask_min(i), headPointsX{i,1}(n)], [yMask_min(i), headPointsY{i,1}(n)], xMask_temp{i,1}, yMask_temp{i,1});
            if length(intersect{i,1}{n,1}) > 2
                headPointsX{i,1}(n) = -inf;
                headPointsY{i,1}(n) = -inf;
            end
        end

        % Determine head maximum
        maximumHeadY{i,1} = max(headPointsY{i,1}(headPointsY{i,1} < 0));
        idx_max_temp = find(headPointsY{i,1} == maximumHeadY{i,1}); % Find corresponding x-coordinate
        idx_max{i,1} = idx_max_temp;
        maximumHeadX{i,1} = xMask_temp{i,1}(idx_max{i,1}(1));

        % Calculate longitudinal and vertical vectors
        angArmDaphnid{i,1} = [maximumHeadX{i,1} - xMask_min(i), maximumHeadY{i,1} - yMask_min(i)];% Vector from tailspine base to head maximum
        angArmVert = [0, maximumHeadY{i,1} - yMask_min(i)]; % Vertical vector starting at the tailspine base
            
        % Display current frame for manual correction
        figure;
        set(gcf, 'Position', [100 300 600 500]);
        title('Angle between Daphnid Longitudinal and Vertical Axis');
        subtitle({'In case of wrong calculation, press n, select Head Max once and press Enter.', 'Otherwise press y.'});
        xlabel('x [px]');
        ylabel('y [px]');
        hold on;
        for j = 1:S_mask(1) % Plot available mask contours
            scatter(maskiererx{j,i},maskierery{j,i} * (-1),10,'MarkerEdgeColor', gray,'MarkerFaceColor', gray);
        end
        scatter(xMask_min(i),yMask_min(i),100,'x','MarkerEdgeColor', changeCol,'MarkerFaceColor', changeCol,'LineWidth', 2);
        scatter(maximumHeadX{i,1},maximumHeadY{i,1},100,'x','MarkerEdgeColor', changeCol,'MarkerFaceColor', changeCol,'LineWidth', 2);
        plot([xMask_min(i), maximumHeadX{i,1}],[yMask_min(i), maximumHeadY{i,1}],'Color', changeCol,'LineWidth', 1);
        plot([xMask_min(i), xMask_min(i)],[yMask_min(i), yMask_min(i) + 425],'Color', origCol,'LineWidth', 1);
        axis equal;
        box on;

        % Manual correction of head maximum
        forward = inputdlg({'Move one Frame forward? (y/n)'}, 'Input',[1 70]);

        if isempty(forward) % Stop safely if the dialog was cancelled
            close;
            error('Manual frame selection was cancelled.');
        end

        if strcmpi(forward{1,1}, 'n')
            [getX{i,1}(1,1), getY{i,1}(1,1)] = getpts; % User selects the correct head maximum manually
            getXY{i,1} = [getX{i,1}(1,1), getY{i,1}(1,1)];

            xyMask_temp{i,1} = [ xMask_temp{i,1}, yMask_temp{i,1}]; % Find closest point of original mask
            idx_nearestP = dsearchn(xyMask_temp{i,1}, getXY{i,1});

            correctedX{i,1}(1,1) = xyMask_temp{i,1}(idx_nearestP, 1); % Use the actual mask point nearest to the manually selected position
            correctedY{i,1}(1,1) = xyMask_temp{i,1}(idx_nearestP, 2);

            angArmDaphnid{i,1} = [correctedX{i,1}(1,1) - xMask_min(i), correctedY{i,1}(1,1) - yMask_min(i)];% Recalculate longitudinal vector using corrected head point
            angArmVert = [0, correctedY{i,1}(1,1) - yMask_min(i)]; % Recalculate vertical vector

            maximumHeadY{i,1} = correctedY{i,1}(1,1); % Replace automatically detected head maximum
            maximumHeadX{i,1} = correctedX{i,1}(1,1);
        end
        close;

        % Calculate rotation angle
        angle(i,1) = acos(dot(angArmVert, angArmDaphnid{i,1}) / (norm(angArmVert) * norm(angArmDaphnid{i,1})));
        angle(i,2) = rad2deg(angle(i,1));

        if angArmDaphnid{i,1}(1) < 0 % Determine the direction of rotation
            angle(i,:) = angle(i,:) * (-1);
        end
    end

    disp('Angle calculation completed.');

    % Display selected frame
    if framenr ~= 0
        figure; % Display possible head vectors
        title({'Vectors from Tailspine Base to Maxima', '(+-distance_X px in x-dir and > 300 px from x min)'});
        xlabel('x [px]');
        ylabel('y [px]');
        hold on;
        for j = 1:S_mask(1)
            scatter(maskiererx{j,framenr}, maskierery{j,framenr} * (-1), 10, 'MarkerEdgeColor', gray, 'MarkerFaceColor', gray);
        end
        for j = 1:length(headPointsY{framenr,1})
            if headPointsY{framenr,1}(j) ~= -inf && headPointsY{framenr,1}(j) > -1500
                plot( [xMask_min(framenr), xMask_temp{framenr,1}(j)], [yMask_min(framenr), headPointsY{framenr,1}(j)], 'Color', changeCol, 'LineWidth', 1);
            end
        end
        axis equal;
        box on;

        figure; % Display final angle
        title('Angle between Daphnid Longitudinal and Vertical Axis');
        xlabel('x [px]');
        ylabel('y [px]');
        hold on;
        for j = 1:S_mask(1) % Plot mask
            scatter(maskiererx{j,framenr}, maskierery{j,framenr} * (-1), 10, 'MarkerEdgeColor', gray, 'MarkerFaceColor', gray);
        end
        scatter(xMask_min(framenr), yMask_min(framenr), 100, 'x', 'MarkerEdgeColor', changeCol, 'MarkerFaceColor', changeCol, 'LineWidth', 2);
        scatter(maximumHeadX{framenr}, maximumHeadY{framenr}, 100, 'x', 'MarkerEdgeColor', changeCol, 'MarkerFaceColor', changeCol, 'LineWidth', 2);
        plot([xMask_min(framenr), maximumHeadX{framenr}], [yMask_min(framenr), maximumHeadY{framenr}], 'Color', changeCol, 'LineWidth', 1);
        plot([xMask_min(framenr), xMask_min(framenr)], [yMask_min(framenr), maximumHeadY{framenr}], 'Color', origCol, 'LineWidth', 1);
        axis equal;
        box on;
    end
end


%% Translation and Rotation

for i = 1:70%length(x)
    display(i, 'i');

    y_neg{i,1} = y{i,1} * (-1); % Flip y-coordinates because PIVlab output is upside down
    v_neg{i,1} = v_values{i,1} * (-1);

    x0(i) = maximumHeadX{i,1} * calxy; % Calculate calibrated head maximum
    y0(i) = maximumHeadY{i,1} * calxy;

    x_corr{i,1} = x{i,1} - x0(i); % Shift PIV coordinates so that the head maximum is the origin
    y_corr{i,1} = y_neg{i,1} - y0(i);

    xMask_corr{i,1} = xMask_temp{i,1} * calxy - x0(i); % Shift and calibrate mask coordinates
    yMask_corr{i,1} = yMask_temp{i,1} * calxy - y0(i);

    if angle(i,1) < 0 % Display direction of rotation.
        display('angle < 0: counter-clockwise rotation');
    else
        display('angle >= 0: clockwise rotation');
    end

    u_rot{i,1} = u_values{i,1} .* cos(angle(i,1)) - v_neg{i,1} .* sin(angle(i,1)); % Rotate velocity vectors
    v_rot{i,1} = u_values{i,1} .* sin(angle(i,1)) + v_neg{i,1} .* cos(angle(i,1));

    vM_rot{i,1} = sqrt(u_rot{i,1}.^2 + v_rot{i,1}.^2); % Calculate magnitude of rotated velocity vectors

    x_rot{i,1} = x_corr{i,1} .* cos(angle(i,1)) - y_corr{i,1} .* sin(angle(i,1)); % Rotate PIV coordinates
    y_rot{i,1} = x_corr{i,1} .* sin(angle(i,1)) + y_corr{i,1} .* cos(angle(i,1));

    xMask_rot{i,1} = xMask_corr{i,1} .* cos(angle(i,1)) - yMask_corr{i,1} .* sin(angle(i,1)); % Rotate mask coordinates
    yMask_rot{i,1} = xMask_corr{i,1} .* sin(angle(i,1)) + yMask_corr{i,1} .* cos(angle(i,1));
end

% Control rotation for selected frame
if framenr ~= 0
    figure;
    title('Rotation of X- and Y-Coordinates');
    xlabel('x [m]');
    ylabel('y [m]');
    hold on;
    scatter(x_corr{framenr,1}, y_corr{framenr,1}, 5, 'MarkerEdgeColor', origCol, 'MarkerFaceColor', origCol); %original coordinates
    scatter(x_rot{framenr,1}, y_rot{framenr,1}, 5, 'MarkerEdgeColor', changeCol, 'MarkerFaceColor', changeCol); %rotated coordinates
    axis equal;
    box on;

    figure;
    title('Rotation of Vectors on Original Coordinates');
    xlabel('x [m]');
    ylabel('y [m]');
    hold on;
    quiver(x_corr{framenr,1}, y_corr{framenr,1}, u_values{framenr,1}, v_neg{framenr,1}, 5, 'Color', origCol); %original coordinates and vectors
    quiver(x_corr{framenr,1}, y_corr{framenr,1}, u_rot{framenr,1}, v_rot{framenr,1}, 5, 'Color', changeCol); %original coordinates, rotated vectors
    axis equal;
    box on;

    figure;
    title('Rotation of Coordinates and Vectors');
    xlabel('x [m]');
    ylabel('y [m]');
    hold on;
    quiver(x_corr{framenr,1}, y_corr{framenr,1}, u_values{framenr,1}, v_neg{framenr,1}, 5, 'Color', origCol); %original coordinates and vectors
    quiver(x_rot{framenr,1}, y_rot{framenr,1}, u_rot{framenr,1}, v_rot{framenr,1}, 5, 'Color', changeCol); %rotated coordinates and vectors
    axis equal;
    box on;

    figure;
    title('Rotation of Daphnid');
    xlabel('x [m]');
    ylabel('y [m]');
    hold on;
    scatter(xMask_corr{framenr,1}, yMask_corr{framenr,1}, 10, 'MarkerEdgeColor', origCol, 'MarkerFaceColor', origCol); %original mask
    scatter(xMask_rot{framenr,1}, yMask_rot{framenr,1}, 10, 'MarkerEdgeColor', changeCol, 'MarkerFaceColor', changeCol); %rotated mask
    axis equal;
    box on;
end

disp('rotation completed');

%% Temporal interpolation

model_frames = Tab(row_model, TabIdxDur);
secPerFrame = 1 / framerate;
dur_model = secPerFrame * model_frames;
startFrame_model = Tab(row_model, TabIdxStart);

%% Interpolate comparison locomotion cycles

for i = 1:nr_sequences(nr_video)
    display(i, 'i');

    % Frame information of the comparison locomotion cycle
    startFrame_comp = Tab(i + beforeSeq, TabIdxStart);
    endFrame_comp = Tab(i + beforeSeq, TabIdxEnd);
    comp_frames = Tab(i + beforeSeq, TabIdxDur);
    comp_dur = secPerFrame * comp_frames;

    % Difference between model and comparison cycle duration
    diff_sec = dur_model - comp_dur;

    if isnan(comp_frames)
        disp('No Data');
    else
        if diff_sec ~= 0
            disp('difference');

            % Create model and comparison timestamps
            timestamps_mod(:,1) = transpose(linspace(0, dur_model, model_frames));
            timestamps_comp{i,1}(:,1) = transpose(linspace(0, dur_model, comp_frames));

            % Find nearest comparison frames and interpolate
            for h = 2:height(timestamps_mod) - 1
                for j = 1:length(timestamps_comp{i,1})
                    timestamps_mod(h,j + 1) = abs(timestamps_mod(h,1) - timestamps_comp{i,1}(j,1));
                end

                % Sort distances from smallest to largest
                [sorted_vals(h,:), sorted_idx(h,:)] = sort(timestamps_mod(h,2:width(timestamps_mod)));

                % Store first and second nearest frames
                frst_min(h,1) = sorted_vals(h,1);
                frst_idx(h,1) = sorted_idx(h,1);
                snd_min(h,1) = sorted_vals(h,2);
                snd_idx(h,1) = sorted_idx(h,2);

                if frst_min(h,1) == 0

                    % Directly copy the matching frame
                    vM_int{i,1}{h,1} = vM_rot{frst_idx(h,1) + startFrame_comp - 1,1};
                    u_int{i,1}{h,1} = u_rot{frst_idx(h,1) + startFrame_comp - 1,1};
                    v_int{i,1}{h,1} = v_rot{frst_idx(h,1) + startFrame_comp - 1,1};
                    x_int{i,1}{h,1} = x_rot{frst_idx(h,1) + startFrame_comp - 1,1};
                    y_int{i,1}{h,1} = y_rot{frst_idx(h,1) + startFrame_comp - 1,1};

                else

                    % Calculate interpolation percentages
                    frst_perc(h,1) = 1 - frst_min(h,1) / (frst_min(h,1) + snd_min(h,1));
                    snd_perc(h,1) = 1 - snd_min(h,1) / (frst_min(h,1) + snd_min(h,1));

                    % Interpolate velocity magnitude
                    vM_int{i,1}{h,1} = vM_rot{frst_idx(h,1) + startFrame_comp - 1,1} * frst_perc(h,1) + vM_rot{snd_idx(h,1) + startFrame_comp - 1,1} * snd_perc(h,1);

                    % Interpolate velocity components
                    u_int{i,1}{h,1} = u_rot{frst_idx(h,1) + startFrame_comp - 1,1} * frst_perc(h,1) + u_rot{snd_idx(h,1) + startFrame_comp - 1,1} * snd_perc(h,1);
                    v_int{i,1}{h,1} = v_rot{frst_idx(h,1) + startFrame_comp - 1,1} * frst_perc(h,1) + v_rot{snd_idx(h,1) + startFrame_comp - 1,1} * snd_perc(h,1);

                    % Interpolate coordinates
                    x_int{i,1}{h,1} = x_rot{frst_idx(h,1) + startFrame_comp - 1,1} * frst_perc(h,1) + x_rot{snd_idx(h,1) + startFrame_comp - 1,1} * snd_perc(h,1);
                    y_int{i,1}{h,1} = y_rot{frst_idx(h,1) + startFrame_comp - 1,1} * frst_perc(h,1) + y_rot{snd_idx(h,1) + startFrame_comp - 1,1} * snd_perc(h,1);

                    % Correct velocity components to match interpolated magnitude
                    divisor{i,1}{h,1} = sqrt(u_int{i,1}{h,1}.^2 + v_int{i,1}{h,1}.^2);
                    ratio{i,1}{h,1} = vM_int{i,1}{h,1} ./ divisor{i,1}{h,1};

                    u_int{i,1}{h,1} = u_int{i,1}{h,1} .* ratio{i,1}{h,1};
                    v_int{i,1}{h,1} = v_int{i,1}{h,1} .* ratio{i,1}{h,1};
                end
            end

            % Copy first and last frame
            vM_int{i,1}{1,1} = vM_rot{startFrame_comp,1};
            vM_int{i,1}{model_frames,1} = vM_rot{endFrame_comp,1};
            u_int{i,1}{1,1} = u_rot{startFrame_comp,1};
            u_int{i,1}{model_frames,1} = u_rot{endFrame_comp,1};
            v_int{i,1}{1,1} = v_rot{startFrame_comp,1};
            v_int{i,1}{model_frames,1} = v_rot{endFrame_comp,1};
            x_int{i,1}{1,1} = x_rot{startFrame_comp,1};
            x_int{i,1}{model_frames,1} = x_rot{endFrame_comp,1};
            y_int{i,1}{1,1} = y_rot{startFrame_comp,1};
            y_int{i,1}{model_frames,1} = y_rot{endFrame_comp,1};

        else
            disp('no difference');

            % Copy frames without interpolation
            for h = startFrame_comp:endFrame_comp
                vM_int{i,1}{h,1} = vM_rot{h,1};
                u_int{i,1}{h,1} = u_rot{h,1};
                v_int{i,1}{h,1} = v_rot{h,1};
                x_int{i,1}{h,1} = x_rot{h,1};
                y_int{i,1}{h,1} = y_rot{h,1};
            end
            % Delete empty cells
            vM_int{i,1} = vM_int{i,1}(~cellfun('isempty', vM_int{i,1}));
            u_int{i,1} = u_int{i,1}(~cellfun('isempty', u_int{i,1}));
            v_int{i,1} = v_int{i,1}(~cellfun('isempty', v_int{i,1}));
            x_int{i,1} = x_int{i,1}(~cellfun('isempty', x_int{i,1}));
            y_int{i,1} = y_int{i,1}(~cellfun('isempty', y_int{i,1}));
        end
    end
    clear timestamps_comp timestamps_mod sorted_vals sorted_idx
end

% Delete empty comparison cycles
vM_int = vM_int(~cellfun('isempty', vM_int));
u_int = u_int(~cellfun('isempty', u_int));
v_int = v_int(~cellfun('isempty', v_int));
x_int = x_int(~cellfun('isempty', x_int));
y_int = y_int(~cellfun('isempty', y_int));

% Interpolated figures
if framenr ~= 0
    for i = 1:nr_sequences(nr_video)
        for h = 1:Tab(row_model, TabIdxDur)
            figure;
            contourf(x_int{i,1}{h,1}, y_int{i,1}{h,1}, vM_int{i,1}{h,1}, [0 0.001 0.002 0.003 0.004 0.005 0.006 0.007 0.008], 'LineColor', 'none');
            hold on;
            quiver(x_int{i,1}{h,1}, y_int{i,1}{h,1}, u_int{i,1}{h,1} / 16, v_int{i,1}{h,1} / 16, 'off', 'k');
            colormap(flipud(sky(8)));
            hcb = colorbar('EastOutside');
            hcb.Title.String = 'V [m/s]      ';
            caxis([0 0.008]);
            axis equal;
            xlabel('x-dir [m]');
            ylabel('y-dir [m]');
            box on;
        end
    end
end

%% Save mask for second script
if modelMask == 1
    xMask_save = xMask_rot;
    yMask_save = yMask_rot;
    save(fullfile(direction, ['xMask_' locPhase '.mat']), 'xMask_save');
    save(fullfile(direction, ['yMask_' locPhase '.mat']), 'yMask_save');
    disp('mask saved successfully');
else
    disp('no mask saved');
end

% Save interpolated data
save(fullfile(direction, [num2str(nr_video) '_' locPhase '_Interpolation']));

% Copy timestamp files
if exist('ControlTimestamps.xlsx', 'file') == 2
    if exist(fullfile(direction, 'ControlTimestamps.xlsx'), 'file') == 0
        copyfile('ControlTimestamps.xlsx', direction);
    end
end

if exist('InducedTimestamps.xlsx', 'file') == 2
    if exist(fullfile(direction, 'InducedTimestamps.xlsx'), 'file') == 0
        copyfile('InducedTimestamps.xlsx', direction);
    end
end

cd(direction);
disp('DONE! :)');
