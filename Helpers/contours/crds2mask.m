function msk = crds2mask(img, crd, buff)
%% crds2mask: create logical mask with input coordinates set to true
% This function sets up a probability distribution matrix by creating a logical mask where pixels
% containing a contour are set to true.
%
% Usage:
%   msk = crds2mask(img, crd, buff)
%
% Input:
%   img: inputted image
%   crd: set of x-/y-coordinates corresponding to inputted image
%   buff: range to extend mask image
%
% Output:
%   msk: logical mask of size matching inputted image, with coordinates set to true
%

%% Convert coordinates to integers if needed
if ~startsWith(class(crd), 'int')
    crd           = floor(crd);
    crd(crd == 0) = 1;
end

%% Create mask and set coordinates to true
% Setup / initialization.
msk = createMask(size(img), buff);
org = [round(size(msk,2)/2.5) size(msk,1)];
crd = slideCoords(crd, org);

try
    idx = sub2ind(size(msk), crd(:,2), crd(:,1));
catch
    % Subtract y-coordinates by size of out-of-bounds coordinates
    crd_max = mode(crd(crd(:,2) == max(crd(:,2)), 2) - org(2));
    org(2)  = org(2) - crd_max;
    crd     = slideCoords(crd, org);
    idx     = sub2ind(size(msk), crd(:,2), crd(:,1));
end

msk(idx) = true;
end

function m = createMask(sz, buff)
%% createMask: subfunction to create mask of different size than original image (experimental)
% This tests what happens if you give the mask a buffer of specified pixels
% Input:
%   sz: size of original image
%   buff: number pixels to buffer by
b = floor(sz * buff);
m = zeros(b);
end

function c = slideCoords(crd, org)
%% Slide x-coordinates to common starting point
d = org - crd(1,:);
c = crd + d;
end