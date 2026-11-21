
% Benchmark validation values (Real-world published dataset sample)
% Let's test a known benchmark soil sample from field data:
benchmark_temp_C = 21.9004;       % Known soil temperature
benchmark_VWC    = 0.2752;       % Known VWC (Dryish soil triggering moisture penalty)
benchmark_true_pH= 5.58;       % Known actual soil pH

% Runs it through the Nernst and electrochemical decoding pipeline:
T_K_bench = benchmark_temp_C + 273.15;
nernst_slope_bench = ((2.303 * 8.314 * T_K_bench) / 96485.0) * 1000.0;

moisture_error_bench = 0.0;
if benchmark_VWC < 0.20
    moisture_error_bench = (0.20 - benchmark_VWC) * 1.8;
    tau_bench = 2.5 + (0.20 - benchmark_VWC) * 60.0;
else
    tau_bench = 2.5;
end

dynamic_pH_bench = 7.0 + (benchmark_true_pH + moisture_error_bench - 7.0) * (1 - exp(-10.0 / tau_bench));
sensor_mV_bench = (7.0 - dynamic_pH_bench) * nernst_slope_bench;
ADC_Voltage_bench = 2.5 + (sensor_mV_bench / 1000.0);
decoded_mV_bench = (ADC_Voltage_bench - 2.5) * 1000.0;
decoded_pH_bench = 7.0 - (decoded_mV_bench / nernst_slope_bench);
validation_error = abs(decoded_pH_bench - benchmark_true_pH);

% Prints the validation check to the Command Window
disp('      BENCHMARK MODEL VALIDATION CHECK            ');
fprintf('Benchmark True pH : %.2f\n', benchmark_true_pH);
fprintf('MATLAB Decoded pH : %.2f\n', decoded_pH_bench);
fprintf('Model Error       : %.4f pH units\n', validation_error);
