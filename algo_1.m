%

% Read the input image and create a ground truth image
input_image = imread('C:\\Users\\ahmad\\Downloads\\rose.jpg');

% Resize the input image
resize_factor = 0.5; % You can adjust this factor to resize the image to an appropriate size
input_image = imresize(input_image, resize_factor);

% Convert the input image to double precision
input_img = im2double(input_image);

% Generate the mosaic image from the input image
mosaic_img = simulate_mosaic(input_img);

% Step 1: Simulate the 4 types of mosaic patches from full-colour patches
mosaic_patches = simulate_mosaic_patches(input_img);

% Step 2: Solve the linear least square problem for each case and get the 8 optimal coefficient matrices
coef_matrices = generate_coefficient_matrices(mosaic_patches, input_img);

% Step 3: Apply the matrices on each patch of a simulated mosaic image to approximate the missing colours
demosaiced_image = demosaic_image(mosaic_img, coef_matrices);

% Demosaic the mosaic image using the built-in MATLAB function
mosaic_img_uint8 = im2uint8(mosaic_img);
demosaiced_image_builtin = im2double(demosaic(mosaic_img_uint8, 'bggr'));

% Step 4: Measure the RMSE between the demosaiced image and the ground truth
rmse_custom = calculate_rmse(input_img, demosaiced_image);
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
title('Grayscale Bayer Image');

subplot(1, 4, 3);
imshow(demosaiced_image);
title(['Custom Demosaic, RMSE: ' num2str(rmse_custom)]);

subplot(1, 4, 4);
imshow(demosaiced_image_builtin);
title(['Built-in Demosaic, RMSE: ' num2str(rmse_builtin)]);

% Output the RMSE difference on the figure pane
annotation('textbox', [0.4, 0.95, 0.2, 0.05], 'String', ...
    ['RMSE difference: ' num2str(rmse_difference)], 'EdgeColor', 'none', 'HorizontalAlignment', 'center');

%% Functions

% Function to simulate mosaic patches for each color channel

function mosaic_patches = simulate_mosaic_patches(img)
    [rows, cols, ~] = size(img);
    mosaic_patches = cell(2, 2);
    
    % Iterate through each color channel and create a mosaic patch
    for i = 1:2
        for j = 1:2
            mosaic_patches{i, j} = img(i:2:end, j:2:end, :);
        end
    end
end

% Function to generate the optimal coefficient matrices for each mosaic patch

function coef_matrices = generate_coefficient_matrices(mosaic_patches, ground_truth_img)
    patch_size = 5;
    coef_matrices = cell(2, 2, 3);
    
    % Iterate through each mosaic patch and solve the linear least square problem
    for i = 1:2
        for j = 1:2
            for color = 1:3
                % Convert the mosaic patch to columns
                X = im2col(mosaic_patches{i, j}(:,:,color), [patch_size, patch_size], 'sliding');
                % Convert the ground truth image to columns
                g = im2col(ground_truth_img(i:2:end, j:2:end, color), [patch_size, patch_size], 'sliding');
                % Get the center index of the patch
                center_idx = (patch_size^2 + 1) / 2;
                % Keep only the center values of the ground truth image
                g = g(center_idx, :);
                
                % Calculate the optimal coefficients
                coef_matrices{i, j, color} = (X * X') \ (X * g');
            end
        end
    end
end


% Function to simulate a mosaic image from a full-color image
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


% Function to demosaic the mosaic image using the optimal coefficient matrices

function demosaiced_image = demosaic_image(mosaic_img, coef_matrices)
    [height, width, ~] = size(mosaic_img);
    demosaiced_image = zeros(height, width, 3);

    % Iterate through each pixel of the mosaic image
    for row = 3:height-2
        for col = 3:width-2
            % Determine the current color channel index
            index = mod(row, 2) * 2 + mod(col, 2) + 1;
            % Extract a patch from the mosaic image
            patch = mosaic_img(row-2:row+2, col-2:col+2);

            % Iterate through each color channel
            for color = 1:3
                if color ~= index
                    % If the current color is not the same as the mosaic index, apply the coefficient matrix
                    coeff_matrix = coef_matrices{mod(row, 2) + 1, mod(col, 2) + 1, color};
                    reshaped_coeff_matrix = reshape(coeff_matrix, [5, 5]);
                    demosaiced_image(row, col, color) = sum(sum(patch .* reshaped_coeff_matrix));
                else
                    % If the current color is the same as the mosaic index, copy the value from the mosaic image
                    demosaiced_image(row, col, color) = mosaic_img(row, col);
                end
            end
        end
    end
end



% Function to calculate the root mean squared error (RMSE) between the ground truth image and the demosaiced image

function rmse = calculate_rmse(ground_truth_img, demosaiced_image)
    % Calculate the error between the ground truth image and the demosaiced image
    error = ground_truth_img - demosaiced_image;
    % Square the error values
    squared_error = error .^ 2;
    % Calculate the mean of the squared error values
    mean_squared_error = mean(squared_error(:));
    % Calculate the square root of the mean squared error
    rmse = sqrt(mean_squared_error);

end
