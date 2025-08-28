classdef SpeechTransmissionApp < matlab.apps.AppBase
    properties (Access = public)
        UIFigure            matlab.ui.Figure
        RecordButton        matlab.ui.control.Button
        StopButton          matlab.ui.control.Button
        TransmitButton      matlab.ui.control.Button
        PlayOriginalButton  matlab.ui.control.Button
        PlayReceivedButton  matlab.ui.control.Button
        NoiseSlider         matlab.ui.control.Slider
        NoiseLabel          matlab.ui.control.Label
        PlotAxes            matlab.ui.control.UIAxes
        SpectrumAxes        matlab.ui.control.UIAxes  
        recObj              audiorecorder
        speechSignal        double = [];
        fs                  double = 44100;
        modulatedSignal     double = [];
        noisySignal         double = [];
        filteredSignal      double = [];
        demodulatedSignal   double = [];
    end

    methods (Access = private)
        function startRecording(app)
            app.recObj = audiorecorder(app.fs, 16, 1);
            record(app.recObj);
            disp('Recording started...');
        end

        function stopRecording(app)
            stop(app.recObj);
            app.speechSignal = getaudiodata(app.recObj);
            if isempty(app.speechSignal)
                uialert(app.UIFigure, 'Recording failed. Try again.', 'Error');
                return;
            end
            plot(app.PlotAxes, app.speechSignal);
            title(app.PlotAxes, 'Recorded Speech');
            
            plotFrequencySpectrum(app, app.speechSignal, 'Analog Voice Signal');
            disp('Recording stopped.');
        end

        function transmitSpeech(app)
            if isempty(app.speechSignal)
                uialert(app.UIFigure, 'Please record speech before transmitting.', 'Error');
                return;
            end
            t = (0:length(app.speechSignal)-1)/app.fs;
            carrierFreq = 4000;
            
            amplifiedSignal = 1.5 * app.speechSignal;
            plotFrequencySpectrum(app, amplifiedSignal, 'Amplified Voice Signal');
            
            digitalSignal = resample(amplifiedSignal, 8000, app.fs);
            plotFrequencySpectrum(app, digitalSignal, 'Analog to Digital Signal');
            
            carrier = cos(2*pi*carrierFreq*t)';
            app.modulatedSignal = amplifiedSignal .* carrier;
            plotFrequencySpectrum(app, app.modulatedSignal, 'Modulated Signal');
            
            noiseLevel = app.NoiseSlider.Value;
            app.noisySignal = awgn(app.modulatedSignal, noiseLevel, 'measured');
            
            recoveredCarrier = cos(2*pi*carrierFreq*t)';
            demodulated = app.noisySignal .* recoveredCarrier;
            [b, a] = butter(6, [200 3000]/(app.fs/2), 'bandpass');
            filteredSignal = filter(b, a, demodulated);
            app.demodulatedSignal = wiener2(filteredSignal, [3 3]);
            plotFrequencySpectrum(app, app.demodulatedSignal, 'Demodulated Signal');
            
            app.filteredSignal = app.demodulatedSignal;
            plotFrequencySpectrum(app, app.filteredSignal, 'Received Analog Signal');
            
            plot(app.PlotAxes, app.filteredSignal);
            title(app.PlotAxes, 'Received Speech Signal');
        end

        function playOriginal(app)
            if isempty(app.speechSignal)
                uialert(app.UIFigure, 'No recorded audio available.', 'Error');
                return;
            end
            sound(app.speechSignal, app.fs);
        end

        function playReceived(app)
            if isempty(app.filteredSignal)
                uialert(app.UIFigure, 'No received signal to play. Transmit first.', 'Error');
                return;
            end
            sound(app.filteredSignal, app.fs);
        end
        
        function plotFrequencySpectrum(app, signal, titleText)
            N = length(signal);
            f = (0:N-1)*(app.fs/N);
            Y = abs(fft(signal));    
            
            plot(app.SpectrumAxes, f(1:floor(N/2)), Y(1:floor(N/2)));  
            title(app.SpectrumAxes, titleText);
            xlabel(app.SpectrumAxes, 'Frequency (Hz)');
            ylabel(app.SpectrumAxes, 'Magnitude');
            xlim(app.SpectrumAxes, [0 5000]);  
        end
    end

    methods (Access = public)
        function app = SpeechTransmissionApp
            app.UIFigure = uifigure('AutoResizeChildren', true);
            app.RecordButton = uibutton(app.UIFigure, 'push', 'Text', 'Record', 'Position', [20, 300, 100, 30], 'ButtonPushedFcn', @(~,~) startRecording(app));
            app.StopButton = uibutton(app.UIFigure, 'push', 'Text', 'Stop', 'Position', [140, 300, 100, 30], 'ButtonPushedFcn', @(~,~) stopRecording(app));
            app.TransmitButton = uibutton(app.UIFigure, 'push', 'Text', 'Transmit', 'Position', [260, 300, 100, 30], 'ButtonPushedFcn', @(~,~) transmitSpeech(app));
            app.PlayOriginalButton = uibutton(app.UIFigure, 'push', 'Text', 'Play Original', 'Position', [20, 250, 100, 30], 'ButtonPushedFcn', @(~,~) playOriginal(app));
            app.PlayReceivedButton = uibutton(app.UIFigure, 'push', 'Text', 'Play Received', 'Position', [140, 250, 100, 30], 'ButtonPushedFcn', @(~,~) playReceived(app));
            app.NoiseLabel = uilabel(app.UIFigure, 'Text', 'Noise Level:', 'Position', [20, 200, 100, 30]);
            app.NoiseSlider = uislider(app.UIFigure, 'Position', [120, 210, 150, 3], 'Limits', [0 20]);
            app.PlotAxes = uiaxes(app.UIFigure, 'Position', [20, 20, 400, 150]);
            app.SpectrumAxes = uiaxes(app.UIFigure, 'Position', [450, 20, 400, 150]);  
        end
    end
end
