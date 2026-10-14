%Post-processing: wird NACH PIVLab gemacht
%Erstellt aus Einzelbildern ein Video
%
%gehe in den Ordner mit den Bildern, die ein Video werden sollen
%
clc;
close all
clear all
%

% Find and sort PNG files

listFiles = dir('*.png');

for i = 1:length(listFiles)
    sortedFiles{i,1} = listFiles(i).name;
end
sortedFiles = sort(sortedFiles);
nr_images = length(sortedFiles);

% Determine image sizes
image_size = zeros(nr_images, 2);
for i = 1:nr_images
    image = imread(sortedFiles{i,1});
    image_size(i,1) = size(image, 1);
    image_size(i,2) = size(image, 2);
end

% Find maximum image size
max_height = max(image_size(:,1));
max_width = max(image_size(:,2));

% Pad images with white background
for i = 1:nr_images
    image = imread(sortedFiles{i,1});
    current_height = size(image, 1);
    current_width = size(image, 2);
    height_diff = max_height - current_height;
    width_diff = max_width - current_width;
    top_padding = floor(height_diff / 2);
    bottom_padding = height_diff - top_padding;
    left_padding = floor(width_diff / 2);
    right_padding = width_diff - left_padding;

    if size(image, 3) == 3
        image_new = ones(max_height, max_width, 3, 'like', image);
    else
        image_new = ones(max_height, max_width, 'like', image);
    end

    image_new(top_padding + 1:top_padding + current_height, left_padding + 1:left_padding + current_width, :) = image;
    imwrite(image_new, sortedFiles{i,1});
end
%
VideoName = 'Comparison_Direction_Q_5_fps.avi';
video = VideoWriter(VideoName, 'Uncompressed AVI'); %Video Objekterstellung
video.FrameRate =5;%5.58; %mit der Framerate rumprobieren, damit die Schnelligkeit in Ordnung ist
open(video); %Video zum Schreiben öffnen
%
for i = 1:length(sortedFiles) %Video Schreiben
  disp(i);
  IMG = imread(sortedFiles{i,1});
  %IMG = imresize(IMG,733/652);
  writeVideo(video,IMG);
end
close(video);
%

% induced_200fps: i = 1:length()
% down_20fps: 1- 60-25
% up_20fps: 60-25 - 112-25
%sink_20fps: 113-25 - 194-25