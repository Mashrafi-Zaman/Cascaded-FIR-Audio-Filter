clc;
clear all;
close all;

[file, path] = uigetfile('*.wav', 'Select an audio file');
if isequal(file, 0)
    error('No file selected. Please select a valid audio file.');
end
file_path = fullfile(path, file);

lower_cutoff_frequency = input('Enter lower cutoff frequency (Hz): ');
upper_cutoff_frequency = input('Enter upper cutoff frequency (Hz): ');
passband_ripple = input('Enter passband ripple (dB): ');
stopband_attenuation = input('Enter stopband attenuation (dB): ');
while true
        num_taps = input('Enter filter order (recommended odd number, e.g., 201): ');
        if num_taps > 0 && mod(num_taps, 2) == 1
            break;
        else
            disp('Please enter a positive odd number.');
        end
    end

[audio_signal, fs] = audioread(file_path); 
if size(audio_signal, 2) > 1
    audio_signal = mean(audio_signal, 2); 
end

t = (0:length(audio_signal)-1) / fs;



% Window selection logic based on stopband attenuation and passband ripple
if (passband_ripple >= 0.7416) && (stopband_attenuation > 0 && stopband_attenuation <= 21) % Rectangular window
    window_choice = 'rectangular';
elseif (passband_ripple >= 0.0546) && (stopband_attenuation > 21 && stopband_attenuation <= 44) % Hanning window
    window_choice = 'hanning';
elseif (passband_ripple >= 0.0194) && (stopband_attenuation > 44 && stopband_attenuation <= 53) % Hamming window
    window_choice = 'hamming';
elseif (passband_ripple >= 0.0017) && (stopband_attenuation > 53 && stopband_attenuation <= 74) % Blackman window
    window_choice = 'blackman';
else
    error('Invalid window choice. Please adjust input parameters.');
end

fprintf('Chosen window: %s\n', window_choice);

% Divide the overall filter order into smaller filter stages
num_stages = 20; % Number of cascading stages
stage_order = round(num_taps / num_stages); % Approximate order per stage

% Ensure each stage has a positive odd number of taps
if mod(stage_order, 2) == 0
    stage_order = stage_order + 1;
end

% Design the FIR band-pass filter for each stage and cascade them
bandpass_cutoff = [lower_cutoff_frequency, upper_cutoff_frequency] / (fs / 2); % Normalize cutoff frequencies

% Initialize the filtered signal
filtered_audio_signal = noisy_audio_signal;

for i = 1:num_stages
    % Choose window based on selection for each stage
    if strcmp(window_choice, 'rectangular')
        win = ones(1, stage_order);  % Rectangular window
    elseif strcmp(window_choice, 'hanning')
        win = hann(stage_order);     % Hanning window
    elseif strcmp(window_choice, 'hamming')
        win = hamming(stage_order);  % Hamming window
    elseif strcmp(window_choice, 'blackman')
        win = blackman(stage_order); % Blackman window
    end
    
    % Design the FIR filter for the current stage
    fir_coeff_stage = fir1(stage_order-1, bandpass_cutoff, 'bandpass', win);
    
    % Apply the filter stage to the audio signal
    filtered_audio_signal = filter(fir_coeff_stage, 1, filtered_audio_signal);
end

% Normalize signals
noisy_audio_signal = noisy_audio_signal / max(abs(noisy_audio_signal));
filtered_audio_signal = filtered_audio_signal / max(abs(filtered_audio_signal));

% Plot the results
figure;
subplot(3, 1, 1);
plot(t, audio_signal);
title('Original Audio Signal');
xlabel('Time (s)');
ylabel('Amplitude');
grid on;

subplot(3, 1, 2);
plot(t, noisy_audio_signal);
title('Noisy Audio Signal');
xlabel('Time (s)');
ylabel('Amplitude');
grid on;

subplot(3, 1, 3);
plot(t, filtered_audio_signal);
title('Filtered Audio Signal (Cascaded FIR Filter)');
xlabel('Time (s)');
ylabel('Amplitude');
grid on;
legend('Filtered Signal');

% Compute FFT of the original audio signal
nfft = length(audio_signal); % Number of FFT points
frequencies = (0:nfft-1)*(fs/nfft); % Frequency vector

% FFT of original audio signal
fft_audio_signal = fft(audio_signal, nfft);
mag_fft_audio_signal = abs(fft_audio_signal) / nfft; % Magnitude of FFT

% FFT of noisy audio signal
fft_noisy_audio_signal = fft(noisy_audio_signal, nfft);
mag_fft_noisy_audio_signal = abs(fft_noisy_audio_signal) / nfft; % Magnitude of FFT

% FFT of filtered audio signal
fft_filtered_audio_signal = fft(filtered_audio_signal, nfft);
mag_fft_filtered_audio_signal = abs(fft_filtered_audio_signal) / nfft; % Magnitude of FFT

% Convert to dB (logarithmic scale) for better visualization of differences
mag_fft_audio_signal_db = 20 * log10(mag_fft_audio_signal); % Convert to dB
mag_fft_noisy_audio_signal_db = 20 * log10(mag_fft_noisy_audio_signal); % Convert to dB
mag_fft_filtered_audio_signal_db = 20 * log10(mag_fft_filtered_audio_signal); % Convert to dB

% Plot Frequency Response of Original, Noisy, and Filtered Audio Signals in dB
figure;
subplot(3, 1, 1);
plot(frequencies(1:nfft/2), mag_fft_audio_signal_db(1:nfft/2)); % Plot half of the spectrum
title('Frequency Response of Original Audio Signal (dB)');
xlabel('Frequency (Hz)');
ylabel('Magnitude (dB)');
grid on;

subplot(3, 1, 2);
plot(frequencies(1:nfft/2), mag_fft_noisy_audio_signal_db(1:nfft/2)); % Plot half of the spectrum
title('Frequency Response of Noisy Audio Signal (dB)');
xlabel('Frequency (Hz)');
ylabel('Magnitude (dB)');
grid on;

subplot(3, 1, 3);
plot(frequencies(1:nfft/2), mag_fft_filtered_audio_signal_db(1:nfft/2)); % Plot half of the spectrum
title('Frequency Response of Filtered Audio Signal (dB)');
xlabel('Frequency (Hz)');
ylabel('Magnitude (dB)');
grid on;

% Frequency response of the FIR filter (last stage)
figure;
freqz(fir_coeff_stage, 1, 1024, fs);
title(['Frequency Response of Cascading FIR Filter']);

% Check stability by plotting pole-zero plot of the last filter stage
figure;
zplane(fir_coeff_stage, 10); % Plot pole-zero diagram for the FIR filter
title('Pole-Zero Plot of the FIR Filter');
grid on;
axis([-1.5 1.5 -1.5 1.5]); % Adjust axis limits to make sure unit circle is visible

% Impulse response of the filter
[impulse_response, time_impulse] = impz(fir_coeff_stage, 1, 1024, fs);

% Plot impulse response
figure;
stem(time_impulse, impulse_response);
title('Impulse Response of the FIR Filter');
xlabel('Time (s)');
ylabel('Amplitude');
grid on;

% Calculate noise removed
noise_removed = noisy_audio_signal - filtered_audio_signal;

% Plot the noise removed
figure;
plot(t, noise_removed);
title('Noise Removed from the Audio Signal');
xlabel('Time (s)');
ylabel('Amplitude');
grid on;

% Compute and display noise removal percentage
noisy_power = sum(noisy_audio_signal.^2); % Power of noisy signal
filtered_power = sum(filtered_audio_signal.^2); % Power of filtered signal
noise_removed_percentage = ((noisy_power - filtered_power) / noisy_power) * 100;
fprintf('Noise removed: %.2f%%\n', abs(noise_removed_percentage));

% Save the filtered audio to a new file
audiowrite('noisy_audio.wav', noisy_audio_signal, fs);
audiowrite('filtered_audio.wav', filtered_audio_signal, fs);
