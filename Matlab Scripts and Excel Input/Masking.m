clc;
clear all;
close all;
%% Masking
%Creates a black-white mask for multiple images from a brightness threshold
%and an size threshold and saves it as ".tif". Masked areas are white, all
%other areas are black. For daphnids, especially the area around the
%tailspine base and around the head apex need to have a clear outline.
%
%% Input
mkdir Mask                   %folder
grayThreshold = 100;         %brightness threshold
areaThreshold = 2000;        %area threshold
%
figureFrame = dir('*.Jpeg'); %load image frame
%
%% Masking calculations
for i = 1:length(figureFrame)
disp(i);
rawIMG = imread(figureFrame(i).name); %load image
[~, ~, noCh] = size(rawIMG);          %conversion to black/white
if noCh > 1
  rawIMG = rgb2gray(rawIMG);
end
%
threshIMG = rawIMG > grayThreshold;        %brightness threshold
fillIMG = imfill(threshIMG,'holes');       %fill any holes
mask = bwareaopen(fillIMG, areaThreshold); %area threshold
imshow(mask);
%
filenameOut = strcat(figureFrame(i).name(1:length(figureFrame(i).name)-4),'.tif');
cd Mask
imwrite(mask,filenameOut) %save
cd ..
%
end
%
close all
%