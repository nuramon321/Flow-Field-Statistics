%% 3/3 statistics
%
% author E.M.Schulenberg / RUB EcoEvo / 10.2026
%
% This script uses the results from the alignment script (1/3) and the
% averaging script (2/3). It combines the separated locomotion phases into 
% a full locomotion cycle.
%
% The script uses the function contourfcmap by Kelly Kearny
% (https://github.com/kakearney/contourfcmap-pkg).
% In the code, we changed following lines for visualisation purposes:
% clevcbar = [clev(1)-dy; clev(:); clev(end)+dy];
% cmapcbar = [Opt.lo; cmap; Opt.hi];
% to
% clevcbar = [clev(1)-dy;clev(:)];
% cmapcbar = [Opt.lo;cmap];
%
% and
% [hout.c, hout.h] = contour(x,y,z,clev); 
% to
% [hout.c, hout.h] = contour(x,y,z,clev, 'LineColor','none');
%
%
% If the directions are tested, angles are computed for every frame.
%
% The data is prepared:
%   1. All 0s are changed to NaNs.
%   2. The vector quantities are rearranged, so that the each cell of every
%   frame contains an array with the vector quantities of all locomotion
%   cycles on that specific coordinate.
%
% A Wilcoxon rank sum test is used for velocities and a circular
% Watson-William test for angles. The resulting p-values printed and saved
% as images.
%
% A False-Discovery-Rate analysis is used for correction of multiple
% testing. The resulting Q-values printed and saved as images.

close all;
clear;
clc;

%% load
names = inputdlg({'Enter Control Filename','Enter Treatment Filename'},'Input',[1 70;1 70]);
vars = inputdlg({'Output Framerate [fps]','Which Variable do you want to test? Enter u, v, vM, or alpha'},'Input',[1 70;1 70]);
load(names{1},'framerate');
framestep = framerate / str2double(vars{1});
min_vals = 5;

% load vector values
load(names{1,1},'u_grid_all','v_grid_all','vM_grid_all', 'timestampsTable');
switch vars{2,1}
    case 'u'
        direction = 'u';
        mkdir('u');
        cnt = u_grid_all;
    case 'v'
        direction = 'v';
        mkdir('v');
        cnt = v_grid_all;
    case 'vM'
        direction = 'vM';
        mkdir('vM');
        cnt = vM_grid_all;
    case 'alpha'
        direction = 'alpha';
        mkdir('alpha');
        cnt_u = u_grid_all;
        cnt_v = v_grid_all;
end
cnt_ts = timestampsTable;
clear u_grid_all v_grid_all vM_grid_all timestampsTable

load(names{2,1},'u_grid_all','v_grid_all','vM_grid_all', 'timestampsTable');
switch vars{2,1}
    case 'u'
        ind = u_grid_all;
    case 'v'
        ind = v_grid_all;
    case 'vM'
        ind = vM_grid_all;
    case 'alpha'
        ind_u = u_grid_all;
        ind_v = v_grid_all;
end
ind_ts = timestampsTable;
clear u_grid_all v_grid_all vM_grid_all timestampsTable

%figure
quivscale = 16;

% load coordinates
load(names{1,1},'X','Y');

% load masks
load(names{1,1},'xMask_all','yMask_all');
xMask_all_c = xMask_all;
yMask_all_c = yMask_all;
load(names{2,1},'xMask_all','yMask_all');

% load means for figures
load(names{1,1}, 'u_sort');
cnt_u_mean = u_sort;
load(names{1,1}, 'v_sort');
cnt_v_mean = v_sort;
clear u_sort v_sort
load(names{2,1}, 'u_sort');
ind_u_mean = u_sort;
load(names{2,1}, 'v_sort');
ind_v_mean = v_sort;
clear u_sort v_sort

% colours
blue4 = [190/255,203/255,242/255];
white = [1,1,1];

% p-plot
yellow1 = [253/255,197/255,39/255];
yellow2 = [248/255,149/255,64/255];
yellow3 = [230/255,108/255,92/255];
clevP = [0.001;0.01;0.05;1];
cmapP = [yellow2;yellow1;blue4];

% Q-plot
red1 = [204/255,71/255,120/255];
red2 = [170/255,35/255,149/255];
red3 = [126/255,3/255,168/255];
clevQ = [0.001;0.01;0.05;1];
cmapQ = [red2;red1;blue4];



%% calculations
%
disp('Calculations');
%angle calculation
if strcmp(vars{2},'alpha') 
    for n = 1:numel(cnt_u)
        for i = 1:length(cnt_u{n,1})
            for h = 1:numel(cnt_u{n,1}{i,1})
                cnt{n,1}{i,1}{h,1} = mod(atan2(cnt_v{n,1}{i,1}{h,1},cnt_u{n,1}{i,1}{h,1}),2*pi);
            end
        end
    end
    for n = 1:numel(ind_u)
        for i = 1:length(ind_u{n,1})
            for h = 1:numel(ind_u{n,1}{i,1})
                ind{n,1}{i,1}{h,1} = mod(atan2(ind_v{n,1}{i,1}{h,1},ind_u{n,1}{i,1}{h,1}),2*pi); % results from 0 to 2*pi
            end
        end
    end

    for n = 1:numel(cnt) %n = locphase
        disp(n);
        q = 4 * n;
        beforeNaN = 0;
        if length(cnt{n,1}) < height(cnt_ts)
            for p = 1:height(cnt_ts)
                if isnan(cnt_ts{p,q}) == true
                    cnt{n,1}{p,2} = NaN;
                    beforeNaN = beforeNaN + 1;
                else
                    cnt{n,1}{p,2} = cnt{n,1}{p-beforeNaN,1};
                end
            end
        else
            for r = 1:length(cnt{n,1})
                cnt{n,1}{r,2} = cnt{n,1}{r,1};
            end
        end
    end

    for n = 1:numel(ind) %n = locphase
        disp(n);
        q = 4 * n;
        beforeNaN = 0;
        if length(ind{n,1}) < height(ind_ts)
            for p = 1:height(ind_ts)
                if isnan(ind_ts{p,q}) == true
                    ind{n,1}{p,2} = NaN;
                    beforeNaN = beforeNaN + 1;
                else
                    ind{n,1}{p,2} = ind{n,1}{p-beforeNaN,1};
                end
            end
        else
            for r = 1:length(ind{n,1})
                ind{n,1}{r,2} = ind{n,1}{r,1};
            end
        end
    end
end

%preparations for two-sample test
for n = 1:numel(cnt)
    %control group
    for i = 1:length(cnt{n,1})
        for h = 1:numel(cnt{n,1}{1,1})
            if ~isscalar(cnt{n,1}{i,2})
                cnt{n,1}{i,2}{h,1}(cnt{n,1}{i,2}{h,1} == 0) = NaN; %change all 0s in cnt-frames to NaNs
            end
        end
    end

    for h = 1:length(cnt{n,1}{1,1}) %rearrange to distributions on every coordinate
        display(h, 'Control Rearrangement: h');
        for i = 1:length(cnt{n,1})
            if isscalar(cnt{n,1}{i,2}) ~= 1
                for j = 1:height(cnt{n,1}{i,2}{h,1})
                    for k = 1:width(cnt{n,1}{i,2}{h,1})
                        cnt_cloud{n,1}{h,1}{j,k}(i,1) = cnt{n,1}{i,2}{h,1}(j,k);
                    end
                end
            end
        end
    end

    %same for induced
    for i = 1:length(ind{n,1})
        for h = 1:length(ind{n,1}{1,1})
            if isscalar(ind{n,1}{i,2}) ~= 1
                ind{n,1}{i,2}{h,1}(ind{n,1}{i,2}{h,1} == 0) = NaN; %change all 0s in cnt-frames to NaNs
            end
        end
    end

    for h = 1:length(ind{n,1}{1,1}) %rearrange to distributions on every coordinate
        display(h, 'Treatment Rearrangement: h');
        for i = 1:length(ind{n,1})
            if isscalar(ind{n,1}{i,2}) ~= 1
                for j = 1:height(ind{n,1}{i,2}{h,1})
                    for k = 1:width(ind{n,1}{i,2}{h,1})
                        ind_cloud{n,1}{h,1}{j,k}(i,1) = ind{n,1}{i,2}{h,1}(j,k);
                    end
                end
            end
        end
    end
end



%change all 0s to NaNs in rearranged distributions
for n = 1:length(cnt) %
    %control
    for h = 1:length(cnt_cloud{n,1})
        for j = 1:height(cnt_cloud{n,1}{h,1})
            for k = 1:width(cnt_cloud{n,1}{h,1})
                for i = 1:length(cnt_cloud{n,1}{h,1}{j,k})
                    if cnt_cloud{n,1}{h,1}{j,k}(i,1) == 0 %i=1, da pointcloud
                        cnt_cloud{n,1}{h,1}{j,k}(i,1) = NaN;
                    end
                end
            end
        end
    end
    %induced
    for h = 1:length(ind_cloud{n,1})
        for j = 1:height(ind_cloud{n,1}{h,1})
            for k = 1:width(ind_cloud{n,1}{h,1})
                for i = 1:length(ind_cloud{n,1}{h,1}{j,k})
                    if ind_cloud{n,1}{h,1}{j,k}(i,1) == 0
                        ind_cloud{n,1}{h,1}{j,k}(i,1) = NaN;
                    end
                end
            end
        end
    end
end

if strcmp(vars{2},'alpha') %no NaNs for circ_wwtest
    for n = 1:length(cnt) %
        for h = 1:length(cnt_cloud{n,1})
            for j = 1:height(cnt_cloud{n,1}{h,1})
                for k = 1:width(cnt_cloud{n,1}{h,1})
                    cnt_cloud{n,1}{h,1}{j,k} = cnt_cloud{n,1}{h,1}{j,k}(~isnan(cnt_cloud{n,1}{h,1}{j,k}));
                    ind_cloud{n,1}{h,1}{j,k} = ind_cloud{n,1}{h,1}{j,k}(~isnan(ind_cloud{n,1}{h,1}{j,k}));
                end
            end
        end
    end
end

%sort locomotion cycle into one array
num = 0;
for n = 1:length(cnt_cloud)
    for i = 1:length(cnt_cloud{n,1})
        cnt_sort{i+num,1} = cnt_cloud{n,1}{i,1};
        ind_sort{i+num,1} = ind_cloud{n,1}{i,1};
    end
    num = length(cnt_sort);
end

%Wilcoxon Test
disp('Wilcoxon Test');

p_value = cell(length(cnt_sort),1);

for h = 1:length(cnt_sort)
    display(h,'Wilcoxon: n');
    for j = 1:height(cnt_sort{1,1})
        for k = 1:width(cnt_sort{1,1}) 
            if sum(cnt_sort{h,1}{j,k}(:,1), 'omitnan') == 0 || sum(ind_sort{h,1}{j,k}(:,1), 'omitnan') == 0
                p_value{h,1}(j,k) = inf;
            elseif length(cnt_sort{h,1}{j,k}(~isnan(cnt_sort{h,1}{j,k}))) < min_vals || length(ind_sort{h,1}{j,k}(~isnan(ind_sort{h,1}{j,k}))) < min_vals
                p_value{h,1}(j,k) = inf;
            else
                if strcmp(vars{2},'vM') || strcmp(vars{2},'u') || strcmp(vars{2},'v')
                    %disp("hey");
                    p_value{h,1}(j,k) = ranksum(cnt_sort{h,1}{j,k}, ind_sort{h,1}{j,k});
                elseif strcmp(vars{2},'alpha')
                    %disp("yo");
                    p_value{h,1}(j,k) = circ_wwtest(cnt_sort{h,1}{j,k}, ind_sort{h,1}{j,k});
                end
            end
        end
    end
end

%figures

for i = 1:framestep:length(p_value)
        f1 = figure;
        f1.Color = 'w';
        contourfcmap2(double(X),double(Y),double(p_value{i,1}), clevP, cmapP, 'lo', yellow3, 'hi', white, 'method', 'calccontour', 'cbarloc', 'eastoutside', 'evencb', true); %colours
        hold on
        if strcmp(vars{2,1}, 'vM') || strcmp(vars{2,1}, 'alpha') %vectors
            quiver(X,Y,(cnt_u_mean{i,1}/quivscale),(cnt_v_mean{i,1}/quivscale),'off','Color', [0.05 0.05 0.05],'LineWidth',1); %no automatic scaling
            quiver(X,Y,(ind_u_mean{i,1}/quivscale),(ind_v_mean{i,1}/quivscale),'off','Color', [0.95 0.95 0.95],'LineWidth',1); %no automatic scaling
        elseif strcmp(vars{2,1}, 'u')
            quiver(X,Y,(cnt_u_mean{i,1}/quivscale),zeros(height(cnt_u_mean{i,1}),width(cnt_u_mean{i,1})),'off','Color', [0.05 0.05 0.05],'LineWidth',1); %no automatic scaling
            quiver(X,Y,(ind_u_mean{i,1}/quivscale),zeros(height(ind_u_mean{i,1}),width(ind_u_mean{i,1})),'off','Color', [0.95 0.95 0.95],'LineWidth',1); %no automatic scaling
        elseif strcmp(vars{2,1}, 'v')
            quiver(X,Y,zeros(height(cnt_u_mean{i,1}),width(cnt_u_mean{i,1})), (cnt_v_mean{i,1}/quivscale),'off','Color', [0.05 0.05 0.05],'LineWidth',1); %no automatic scaling
            quiver(X,Y,zeros(height(ind_u_mean{i,1}),width(ind_u_mean{i,1})), (ind_v_mean{i,1}/quivscale),'off','Color', [0.95 0.95 0.95],'LineWidth',1); %no automatic scaling
        end
        fill(xMask_all{i,1},yMask_all{i,1},[0.6 0.6 0.6],'EdgeColor',[0.6 0.6 0.6]) %animal
        axis equal;
        annotation('textbox', [0.755 0.89 0.1 0.1], 'String', 'p-value', 'EdgeColor', 'none'); %colourbar title
        xlim([-0.004 0.004]); %axis limits
        ylim([-0.006 0.002]); 
        xlabel('x-dir [m]'); %axis labels
        ylabel('y-dir [m]');
        box on
        exportgraphics(gcf, strcat(direction, '_p_', sprintf('%02d', i),'.png'));%, 'ContentType', 'vector', 'BackgroundColor', 'none');
        close all;
end


%% FDR
%
%prepare data: matrices to array format 
p_array = cell(length(p_value),1);

for h = 1:numel(p_value)
    p_array{h,1} = reshape(p_value{h,1},[],1);
    p_array{h,1}(p_array{h,1} == inf) = NaN;
end

%analysis
fdr = cell(length(p_array),1);
Q = cell(length(p_array),1);
PI = cell(length(p_array),1);
%
for h = 1:length(p_array)
    display(h, 'FDR: h');
    [fdr{h,1}, Q{h,1}, PI{h,1}] = mafdr(p_array{h,1}(:,1));
end

%prepare data for plotting
Q_test = cell(length(p_array),1);
for h = 1:length(p_array)
    Q_test{h,1} = reshape(Q{h,1}, height(p_value{1,1}), width(p_value{1,1}));
    Q_test{h,1}(isnan(Q_test{h,1})) = inf;
end

%figures
for i = 1:framestep:length(Q_test)
    f2 = figure;
    f2.Color = 'w';
    contourfcmap2(double(X),double(Y),double(Q_test{i,1}), clevQ, cmapQ, 'lo', red3, 'hi', white, 'method', 'calccontour', 'cbarloc', 'eastoutside', 'evencb', true); %colours
    hold on
    if strcmp(vars{2,1}, 'vM') || strcmp(vars{2,1}, 'alpha') %vectors
        quiver(X,Y,(cnt_u_mean{i,1}/quivscale),(cnt_v_mean{i,1}/quivscale),'off','Color', [0.05 0.05 0.05],'LineWidth',1); %no automatic scaling
        quiver(X,Y,(ind_u_mean{i,1}/quivscale),(ind_v_mean{i,1}/quivscale),'off','Color', [0.95 0.95 0.95],'LineWidth',1); %no automatic scaling
    elseif strcmp(vars{2,1}, 'u')
        quiver(X,Y,(cnt_u_mean{i,1}/quivscale),zeros(height(cnt_u_mean{i,1}),width(cnt_u_mean{i,1})),'off','Color', [0.05 0.05 0.05],'LineWidth',1); %no automatic scaling
        quiver(X,Y,(ind_u_mean{i,1}/quivscale),zeros(height(ind_u_mean{i,1}),width(ind_u_mean{i,1})),'off','Color', [0.95 0.95 0.95],'LineWidth',1); %no automatic scaling
    elseif strcmp(vars{2,1}, 'v')
        quiver(X,Y,zeros(height(cnt_u_mean{i,1}),width(cnt_u_mean{i,1})), (cnt_v_mean{i,1}/quivscale),'off','Color', [0.05 0.05 0.05],'LineWidth',1); %no automatic scaling
        quiver(X,Y,zeros(height(ind_u_mean{i,1}),width(ind_u_mean{i,1})), (ind_v_mean{i,1}/quivscale),'off','Color', [0.95 0.95 0.95],'LineWidth',1); %no automatic scaling
    end
    fill(xMask_all{i,1},yMask_all{i,1},[0.6 0.6 0.6],'EdgeColor',[0.6 0.6 0.6]) %animal
    axis equal;
    annotation('textbox', [0.74 0.89 0.1 0.1], 'String', 'Q-value', 'EdgeColor', 'none'); %colourbar title
    xlim([-0.004 0.004]); %axis limits
    ylim([-0.006 0.002]);
    xlabel('x-dir [m]'); %axis labels
    ylabel('y-dir [m]');
    box on;
    exportgraphics(gcf, strcat(direction, '_Q_', sprintf('%02d', i),'.png'));%, 'ContentType', 'image', 'BackgroundColor', 'none');
    close all;
end
%
%% saving
save(strcat(direction, '\', 'Stats_20260930_', direction));
disp('Done :)');