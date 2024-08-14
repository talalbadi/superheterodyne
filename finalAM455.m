[soundData, fs] = audioread('114.mp3');
soundData = soundData / max(abs(soundData));

[soundData2, fs2] = audioread('1.mp3');
soundData2 = soundData2 / max(abs(soundData2));

if fs ~= fs2
    soundData2 = resample(soundData2, fs, fs2);
end

minLength = min(length(soundData), length(soundData2));
soundData = soundData(1:minLength);
soundData2 = soundData2(1:minLength);


target_fs = 2 * (455e3 + 4.5e3); 
soundData = resample(soundData, target_fs, fs);
soundData2 = resample(soundData2, target_fs, fs);
fs = target_fs;

nyquistFreq = fs / 2;


f_c1 = 125e3;  
f_c2 = 75e3;  
t1 = (0:length(soundData)-1)/fs;

carrier1 = cos(2*pi*f_c1*t1);
carrier2 = cos(2*pi*f_c2*t1);

modulatedSignal1 = (1 + soundData') .* carrier1;
modulatedSignal2 = (1 + soundData2') .* carrier2;

RF_signal = modulatedSignal1 + modulatedSignal2;

RF_bandwidth = 1e3;

selected_channel = 2;

if selected_channel == 1
    f_c = f_c1;
else
    f_c = f_c2;
end

% Design the RF filter within the Nyquist range
RF_filter = designfilt('bandpassiir', 'FilterOrder', 4, ...
                       'HalfPowerFrequency1', f_c - RF_bandwidth / 2, ...
                       'HalfPowerFrequency2', f_c + RF_bandwidth / 2, ...
                       'SampleRate', fs);

filtered_RF_signal = filter(RF_filter, RF_signal);

f_IF = 455e3;
f_LO = f_c + f_IF;
localOscillator = cos(2*pi*f_LO*t1);

mixedSignal = filtered_RF_signal .* localOscillator;

IF_bandwidth = 9e3;

% Ensure the IF filter design is within the valid frequency range
IF_filter = designfilt('bandpassiir', 'FilterOrder', 4, ...
                       'HalfPowerFrequency1', f_IF - IF_bandwidth / 2, ...
                       'HalfPowerFrequency2', f_IF + IF_bandwidth / 2, ...
                       'SampleRate', fs);

IF_signal = filter(IF_filter, mixedSignal);

envelopeSignal = abs(IF_signal);

lowpassFilter = designfilt('lowpassiir', 'FilterOrder', 4, ...
                           'HalfPowerFrequency', 1.5e3, ...
                           'SampleRate', fs);

audioSignal = filter(lowpassFilter, envelopeSignal);

audioSignal = audioSignal / max(abs(audioSignal));
audiowrite('demodulatedOutput2.wav', audioSignal, fs);
fs_playback = 44100; % Typical playback sample rate
audioSignal = resample(audioSignal, fs_playback, fs);
sound(audioSignal, fs_playback);


% Plot the spectrum of the original soundData
figure;
subplot(3,1,1);
originalSpectrum = abs(fft(soundData)/length(soundData));
f = linspace(0, fs/2, length(originalSpectrum)/2+1);
plot(f, 2*originalSpectrum(1:length(f)));
title('Spectrum of Original Sound Data');
xlabel('Frequency (Hz)');
ylabel('Magnitude');
grid on;

% Plot the spectrum of the modulated RF signal
subplot(3,1,2);
modulatedSpectrum = abs(fft(RF_signal)/length(RF_signal));
f_mod = linspace(0, fs/2, length(modulatedSpectrum)/2+1);
plot(f_mod, 2*modulatedSpectrum(1:length(f_mod)));
title('Spectrum of Modulated RF Signal');
xlabel('Frequency (Hz)');
ylabel('Magnitude');
grid on;

% Plot the spectrum of the demodulated audio signal
subplot(3,1,3);
demodulatedSpectrum = abs(fft(audioSignal)/length(audioSignal));
f_demod = linspace(0, fs/2, length(demodulatedSpectrum)/2+1);
plot(f_demod/100, 2*demodulatedSpectrum(1:length(f_demod/1000)));
title('Spectrum of Demodulated Audio Signal');
xlabel('Frequency (Hz)');
ylabel('Magnitude');
grid on;

% Adjust the plot to show all subplots clearly
sgtitle('Spectrum Analysis of Audio Signals');
