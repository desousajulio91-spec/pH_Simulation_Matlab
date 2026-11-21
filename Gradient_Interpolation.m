clear; clc;


% 1. Generates Irregular Field Shape
field_size = 10.0;     % 10m x 10m workspace envelope
grid_res = 150;        % Resolution of the field map grid
[X_mat, Y_mat] = meshgrid(linspace(0, field_size, grid_res), linspace(0, field_size, grid_res));

center_x = field_size / 2;
center_y = field_size / 2;
target_radius = 3.8;   % Base radius of the field
irregularity = 0.28;   % Organic boundary distortion factor
num_angles = 16;

% Randomizes angular sector radii to create a unique organic shape on every run
rng('shuffle');
angle_offsets = 1 + irregularity * (rand(1, num_angles) * 2 - 1);

% Creates binary field mask (0 = Free space inside field, 1 = Boundary/Obstacle outside)
field_mask = false(grid_res, grid_res);
for r = 1:grid_res
    for c = 1:grid_res
        dx = X_mat(r,c) - center_x;
        dy = Y_mat(r,c) - center_y;
        dist = sqrt(dx^2 + dy^2);
        if dist == 0
            field_mask(r,c) = true;
            continue;
        end
        ang = atan2(dy, dx);
        ang_idx = mod(floor(((ang + pi) / (2 * pi)) * num_angles), num_angles) + 1;
        if dist < (target_radius * angle_offsets(ang_idx))
            field_mask(r,c) = true; % Inside the organic field
        end
    end
end

%2. Generates the Rows and Columns within the Boundaries
% Defines candidate row and column coordinates across the 10x10m space
candidate_x = linspace(2.5, 7.5, 4); % 4 columns
candidate_y = linspace(2.5, 7.5, 3); % 3 rows

x_pos = [];
y_pos = [];

% Checks each candidate point against the irregular field mask
for cx = candidate_x
    for cy = candidate_y
        % Finds the closest grid indices
        [~, ix] = min(abs(linspace(0, field_size, grid_res) - cx));
        [~, iy] = min(abs(linspace(0, field_size, grid_res) - cy));
        
        % Only accepts the point if it lies strictly inside the organic field boundary
        if field_mask(iy, ix)
            x_pos(end+1) = cx;
            y_pos(end+1) = cy;
        end
    end
end

num_samples = length(x_pos);
disp(['Successfully filtered and placed ', num2str(num_samples), ' structured sample sites inside the irregular field.']);

% 3. Nernst pH and Soil Simulation Loop
true_pH = 5.5 + (7.8 - 5.5) .* rand(1, num_samples);       
VWC     = 0.12 + (0.35 - 0.12) .* rand(1, num_samples);     
temp_C  = linspace(18.0, 24.5, num_samples) + rand(1, num_samples); 

ADC_Voltage     = zeros(1, num_samples);
Decoded_pH      = zeros(1, num_samples);
Error_pH        = zeros(1, num_samples);
Est_Time_Sec    = zeros(1, num_samples); 

for i = 1:num_samples
    T_K = temp_C(i) + 273.15;
    nernst_slope = ((2.303 * 8.314 * T_K) / 96485.0) * 1000.0;
    
    moisture_error = 0.0;
    if VWC(i) < 0.20
        moisture_error = (0.20 - VWC(i)) * 1.8;
        tau = 2.5 + (0.20 - VWC(i)) * 60.0; 
    else
        tau = 2.5; 
    end
    
    Est_Time_Sec(i) = 4.0 * tau;
    dynamic_pH = 7.0 + (true_pH(i) + moisture_error - 7.0) * (1 - exp(-10.0 / tau));
    
    sensor_mV = (7.0 - dynamic_pH) * nernst_slope;
    ADC_Voltage(i) = 2.5 + (sensor_mV / 1000.0);
    decoded_mV = (ADC_Voltage(i) - 2.5) * 1000.0;
    Decoded_pH(i) = 7.0 - (decoded_mV / nernst_slope);
    Error_pH(i) = Decoded_pH(i) - true_pH(i);
end

% 4. Spatial Interpolation and Mapping Over the Generated Field 
[X_grid, Y_grid] = meshgrid(linspace(0, field_size, grid_res), linspace(0, field_size, grid_res));

% Primary Interpolation: Bivariate Natural Spline
F_cubic = scatteredInterpolant(x_pos', y_pos', Decoded_pH', 'natural');
pH_map_cubic = F_cubic(X_grid, Y_grid);

% Nearest-Neighbour Fallback
F_nearest = scatteredInterpolant(x_pos', y_pos', Decoded_pH', 'nearest');
pH_map_nearest = F_nearest(X_grid, Y_grid);

pH_map_final = pH_map_cubic;
nan_indices = isnan(pH_map_final);
pH_map_final(nan_indices) = pH_map_nearest(nan_indices);

% Masks the areas outside the field boundary so the map matches the irregular shape
pH_map_final(~field_mask) = NaN;

% 5. Visualisation
figure('Name', 'Organic Field UGV Soil pH Gradient Map', 'Color', 'white');
surf(X_grid, Y_grid, pH_map_final, 'EdgeColor', 'none');
hold on;
% Plot structured waypoint insertion sites in neat rows/cols strictly inside
scatter3(x_pos, y_pos, Decoded_pH + 0.5, 90, 'k', 'filled', 'MarkerEdgeColor', 'w');
hold off;

colormap(jet);
colorbar;
title('Organic Field Soil pH Gradient Map with Structured Waypoints', 'Interpreter', 'latex');
xlabel('X Field Position (m)');
ylabel('Y Field Position (m)');
zlabel('Decoded Soil pH');
view(2); 
axis tight;
grid on;

% 6. Displays Information in the Command Window
positionTable = table((1:num_samples)', x_pos', y_pos', Decoded_pH', ...
    'VariableNames', {'Sample_ID', 'X_Coord_m', 'Y_Coord_m', 'Decoded_pH'});
disp('   ORGANIC FIELD STRUCTURED SAMPLE POSITIONS TABLE');
disp(positionTable);

resultsTable = table((1:num_samples)', true_pH', temp_C', VWC'*100, Est_Time_Sec', ADC_Voltage', Decoded_pH', Error_pH', ...
    'VariableNames', {'Sample', 'True_pH', 'Temp_C', 'VWC_Pct', 'Est_Time_s', 'ADC_Volts', 'Decoded_pH', 'Error'});
disp('       FULL SENSOR & TELEMETRY RESULTS TABLE      ');
disp(resultsTable);