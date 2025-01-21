%Ahmad Choudhry - 400312026- chouda27

% Read the input image and create a ground truth image
input_image = imread('C:\\Users\\ahmad\\Downloads\\rose.jpg');

% Convert the input image to double precision
input_img = im2double(input_image);

% Generate the mosaic image from the input image
mosaic_img = simulate_mosaic(input_img);

% Demosaic the mosaic image using the averaging approach
demosaiced_image = demosaic_image(mosaic_img);

% Calculate the RMSE between the ground truth image and the custom demosaiced image
rmse_custom = calculate_rmse(input_img, demosaiced_image);

% Demosaic the mosaic image using the built-in MATLAB function
demosaiced_image_builtin = demosaic(uint8(mosaic_img*255), 'bggr');
demosaiced_image_builtin = im2double(demosaiced_image_builtin);

% Calculate the RMSE between the ground truth image and the built-in demosaiced image
rmse_builtin = calculate_rmse(input_img, demosaiced_image_builtin);

% Calculate the RMSE difference between custom and built-in demosaicing methods
rmse_difference = abs(rmse_custom - rmse_builtin);

% Display the input image, mosaic image, custom demosaiced image,
% and built-in demosaiced image along with their respective RMSE values
% Define the figure window size and position
figure_width = 1200; % Adjust this value for the desired width of the figure window
figure_height = 300; % Adjust this value for the desired height of the figure window
figure_position = [100, 100, figure_width, figure_height]; % [left, bottom, width, height]

% Create the figure window with the specified size and position
set(0, 'DefaultFigurePosition', figure_position);
figure;

% Display the input image, mosaic image, custom demosaiced image,
% and built-in demosaiced image along with their respective RMSE values
subplot(1, 4, 1);
imshow(input_img);
title('Original Image');

subplot(1, 4, 2);
imshow(mosaic_img);
title('Bayer Image');

subplot(1, 4, 3);
imshow(demosaiced_image);
title(['Custom Demosaic, RMSE: ' num2str(rmse_custom)]);

subplot(1, 4, 4);
imshow(demosaiced_image_builtin);
title(['Built-in Demosaic, RMSE: ' num2str(rmse_builtin)]);

% Output the RMSE difference on the figure pane
annotation('textbox', [0.4, 0.95, 0.2, 0.05], 'String', ...
    ['RMSE difference: ' num2str(rmse_difference)], 'EdgeColor', 'none', 'HorizontalAlignment', 'center');


% Functions

function mosaic_patches = simulate_mosaic_patches(img)
    [rows, cols, ~] = size(img);
    mosaic_patches = cell(2, 2);
    
    for i = 1:2
        for j = 1:2
            mosaic_patches{i, j} = img(i:2:end, j:2:end, :);
        end
    end
end

function mosaic_img = simulate_mosaic(img)
    [rows, cols, ~] = size(img);
    mosaic_img = zeros(rows, cols);

    % Assign B channel
    mosaic_img(1:2:end, 1:2:end) = img(1:2:end, 1:2:end, 3);
    
    % Assign G channel
    mosaic_img(1:2:end, 2:2:end) = img(1:2:end, 2:2:end, 2);
    mosaic_img(2:2:end, 1:2:end) = img(2:2:end, 1:2:end, 2);
    
    % Assign R channel
    mosaic_img(2:2:end, 2:2:end) = img(2:2:end, 2:2:end, 1);
end


function demosaiced_image = demosaic_image(mosaic_img)
    [height, width, ~] = size(mosaic_img);
    demosaiced_image = zeros(height, width, 3);

    % Create a Gaussian filter for weighted average
    gauss_filter = fspecial('gaussian', [5, 5], 1);

    for row = 3:height-2
        for col = 3:width-2
            index = mod(row, 2) * 2 + mod(col, 2) + 1;
            patch = mosaic_img(row-2:row+2, col-2:col+2);

            for color = 1:3
                if color ~= index
                    weighted_patch = patch .* gauss_filter;
                    demosaiced_image(row, col, color) = sum(weighted_patch(:));
                else
                    demosaiced_image(row, col, color) = mosaic_img(row, col);
                end
            end
        end
    end
end


function rmse = calculate_rmse(ground_truth_img, demosaiced_image)
    error = ground_truth_img - demosaiced_image;
    squared_error = error .^ 2;
    mean_squared_error = mean(squared_error(:));
    rmse = sqrt(mean_squared_error);
end

