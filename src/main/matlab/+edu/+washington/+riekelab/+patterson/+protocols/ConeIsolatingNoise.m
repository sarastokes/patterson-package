classdef ConeIsolatingNoise < edu.washington.riekelab.protocols.RiekeLabProtocol
    % CONEISOLATINGNOISE
    %
    % Description:
    %   Presents Gaussian noise stimuli with control over L, M and S-cone
    %   isomerizations for both the mean and sd.
    %
    % History:
    %   19Feb2019 - SSP
    %   26Feb2019 - SSP - New online analysis
    % ---------------------------------------------------------------------
    
    properties
        preTime = 250                   % Noise leading duration (ms)
        stimTime = 10000                % Noise duration (ms)
        tailTime = 250                  % Noise trailing duration (ms)
        
        sMeanIsom = 4000                % Mean for S-cones (isomerizations)
        mMeanIsom = 4000                % Mean for M-cones (isomerizations)
        lMeanIsom = 4000                % Mean for L-cones (isomerizations)
        
        sStdvContrast = 0.3             % S-cone noise SD (contrast [0, 1])
        mStdvContrast = 0               % M-cone noise SD (contrast [0, 1])
        lStdvContrast = 0               % L-cone noise SD (contrast [0, 1])
        
        frequencyCutoff = 60            % Noise frequency cutoff for smoothing (Hz)
        numberOfFilters = 4             % Number of filters in cascade for noise smoothing
        useRandomSeed = true            % Use a random seed for the noise repeats
        onlineAnalysis = 'none'         % Recording type for online analysis
        
        redLedIsomPerVoltS = 38         % S-cone isom per red LED volt
        redLedIsomPerVoltM = 363        % M-cone isom per red LED volt
        redLedIsomPerVoltL = 1744       % L-cone isom per red LED volt
        greenLedIsomPerVoltS = 134      % S-cone isom per green LED volt
        greenLedIsomPerVoltM = 1699     % M-cone isom per green LED volt
        greenLedIsomPerVoltL = 1099     % L-cone isom per green LED volt
        uvLedIsomPerVoltS = 2691        % S-cone isom per UV LED volt
        uvLedIsomPerVoltM = 360         % M-cone isom per UV LED volt
        uvLedIsomPerVoltL = 344         % L-cone isom per UV LED volt
        
        numberOfAverages = uint16(15);  % Number of epochs to deliver
        interpulseInterval = 0;         % Duration between noise stimuli (s)
        
        amp                             % Input amplifier
    end
    
    properties (Dependent, SetAccess = private)
        amp2
    end
    
    properties (Hidden, Dependent)
        rguToLms
        lmsToRgu
        
        lmsMeanIsomerizations
        lmsStdvIsomerizations
        
        redLed
        greenLed
        uvLed
    end
    
    properties (Hidden)
        ampType
        onlineAnalysisType = symphonyui.core.PropertyType('char', 'row',...
            {'none', 'extracellular', 'voltage_clamp', 'current_clamp', 'subthreshold'})
    end
    
    properties (Constant, Hidden)
        LED_MAX = 9;        % V
        LED_MIN = -9;       % V    
        LED_COLORS = [0.25, 0.25, 1; 0, 0.8, 0.3; 0.2, 0.3, 0.9];
    end
    
    methods
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabProtocol(obj);
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end
        
        function d = getPropertyDescriptor(obj, name)
            d = getPropertyDescriptor@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, name);
            
            if strncmp(name, 'amp2', 4) && numel(obj.rig.getDeviceNames('Amp')) < 2
                d.isHidden = true;
            end
        end
        
        function p = getPreview(obj, panel)
            p = edu.washington.riekelab.patterson.previews.ConeStimuliPreview(...
                panel, @()createPreviewStimuli(obj), obj.rguToLms);
            
            function s = createPreviewStimuli(obj)
                rguMean = obj.lmsToRgu * obj.lmsMeanIsomerizations;
                rguStdv = obj.lmsToRgu * obj.lmsStdvIsomerizations;
                
                ledList = [obj.redLed, obj.greenLed, obj.uvLed];
                
                s = cell(3, 1);
                for i = 1:3
                    s{i} = obj.createLedStimulus(1, rguMean(i), abs(rguStdv(i)),...
                        ledList(i).background.displayUnits, rguStdv(i) < 0);
                end
            end
        end
        
        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.protocols.RiekeLabProtocol(obj);
            
            % Setup the analysis figures
            obj.showFigure('edu.washington.riekelab.patterson.figures.LedRangeFigure',...
                obj.rig.getDevice(obj.amp));
            if numel(obj.rig.getDeviceNames('Amp')) < 2
                obj.showFigure('edu.washington.riekelab.patterson.figures.LedResponseFigure',...
                    obj.rig.getDevice(obj.amp),...
                    [obj.redLed, obj.greenLed, obj.uvLed]);
                if ~strcmp(obj.onlineAnalysis, 'none')
                    obj.showFigure('edu.washington.riekelab.patterson.figures.LedNoiseFigure',...
                        obj.rig.getDevice(obj.amp), obj.greenLed, obj.stimTime,...
                        'preTime', obj.preTime, 'recordingType', obj.onlineAnalysis,...
                        'frequencyCutoff', obj.frequencyCutoff);
                end
                if strcmp(obj.onlineAnalysis, 'extracellular')
                    obj.showFigure('edu.washington.riekelab.patterson.figures.SpikeStatisticsFigure',...
                        obj.rig.getDevice(obj.amp),...
                        'measurementRegion', [obj.preTime, obj.preTime+obj.stimTime]);
                else
                    obj.showFigure('symphonyui.builtin.figures.ResponseStatisticsFigure',...
                        obj.rig.getDevice(obj.amp), {@mean, @var}, ...
                        'baselineRegion', [0 obj.preTime], ...
                        'measurementRegion', [obj.preTime obj.preTime+obj.stimTime]);
                end
            else
                obj.showFigure('edu.washington.riekelab.figures.DualResponseFigure',...
                    obj.rig.getDevice(obj.amp), obj.rig.getDevice(obj.amp2));
            end
            
            % Set the background
            rguMean = obj.lmsToRgu * obj.lmsMeanIsomerizations;
            
            obj.redLed.background = symphonyui.core.Measurement(...
                rguMean(1), obj.redLed.background.displayUnits);
            obj.greenLed.background = symphonyui.core.Measurement(...
                rguMean(2), obj.greenLed.background.displayUnits);
            obj.uvLed.background = symphonyui.core.Measurement(...
                rguMean(3), obj.uvLed.background.displayUnits);
        end
        
        function stim = createLedStimulus(obj, seed, ledMean, ledStd, units, inverted)
            gen = edu.washington.riekelab.stimuli.GaussianNoiseGeneratorV2();
            gen.preTime = obj.preTime;
            gen.stimTime = obj.stimTime;
            gen.tailTime = obj.tailTime;
            gen.inverted = inverted;
            gen.mean = ledMean;
            gen.stDev = ledStd;
            gen.freqCutoff = obj.frequencyCutoff;
            gen.numFilters = obj.numberOfFilters;
            gen.sampleRate = obj.sampleRate;
            gen.seed = seed;
            gen.units = units;
            gen.upperLimit = obj.LED_MAX;
            gen.lowerLimit = obj.LED_MIN;
            
            stim = gen.generate();
        end
        
        function y = checkRange(obj, stim)
            stimData = stim.getData();
            y = 100 * (sum(stimData <= 0) + sum(stimData == obj.LED_MAX)) ...
                / (obj.sampleRate * obj.stimTime / 1e3);
        end
        
        function rgb = getStimColor(obj)
            coneSD = [obj.lStdvContrast, obj.mStdvContrast, obj.sStdvContrast];
            switch nnz(coneSD)
                case 1
                    rgb = obj.LED_COLORS(coneSD > 0, :);
                case 2
                    rgb = [1, 0.5, 0];
                otherwise
                    rgb = [0, 0, 0];
            end
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, epoch);
            
            if ~obj.useRandomSeed
                seed = 0;
            else
                seed = RandStream.shuffleSeed;
            end
            
            rguMean = obj.lmsToRgu * obj.lmsMeanIsomerizations;
            rguStdv = obj.lmsToRgu * obj.lmsStdvIsomerizations;
            
            % Add the epoch parameters
            epoch.addParameter('seed', seed);
            epoch.addParameter('lConeMean', rguMean(1));
            epoch.addParameter('mConeMean', rguMean(2));
            epoch.addParameter('sConeMean', rguMean(3));
            epoch.addParameter('lConeStd', rguStdv(1));
            epoch.addParameter('mConeStd', rguStdv(2));
            epoch.addParameter('sConeStd', rguStdv(3));
            
            % Add the epoch LED stimuli
            redStim = obj.createLedStimulus(...
                seed, rguMean(1), abs(rguStdv(1)),...
                obj.redLed.background.displayUnits, rguStdv(1) < 0);
            greenStim = obj.createLedStimulus( ...
                seed, rguMean(2), abs(rguStdv(2)),...
                obj.greenLed.background.displayUnits, rguStdv(2) < 0);
            uvStim = obj.createLedStimulus( ...
                seed, rguMean(3), abs(rguStdv(3)),...
                obj.uvLed.background.displayUnits, rguStdv(3) < 0);
            
            epoch.addStimulus(obj.redLed, redStim);
            epoch.addStimulus(obj.greenLed, greenStim);
            epoch.addStimulus(obj.uvLed, uvStim);
            
            % Check the epoch LED stimuli
            epoch.addParameter('redOutliers', obj.checkRange(redStim));
            epoch.addParameter('greenOutliers', obj.checkRange(greenStim));
            epoch.addParameter('uvOutliers', obj.checkRange(uvStim));
            
            % Add the epoch responses
            epoch.addResponse(obj.rig.getDevice(obj.amp));
            if numel(obj.rig.getDeviceNames('Amp')) >= 2
                epoch.addResponse(obj.rig.getDevice(obj.amp2));
            end
        end
        
        function prepareInterval(obj, interval)
            prepareInterval@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, interval);
            
            interval.addDirectCurrentStimulus(obj.redLed,...
                obj.redLed.background, obj.interpulseInterval, obj.sampleRate);
            interval.addDirectCurrentStimulus(obj.greenLed,...
                obj.greenLed.background, obj.interpulseInterval, obj.sampleRate);
            interval.addDirectCurrentStimulus(obj.uvLed,...
                obj.uvLed.background, obj.interpulseInterval, obj.sampleRate);
        end
        
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numberOfAverages;
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numberOfAverages;
        end
    end
    
    % Dependent set/get methods
    methods
        function value = get.rguToLms(obj)
            value = [obj.redLedIsomPerVoltL, obj.greenLedIsomPerVoltL, obj.uvLedIsomPerVoltL; ...
                obj.redLedIsomPerVoltM, obj.greenLedIsomPerVoltM, obj.uvLedIsomPerVoltM; ...
                obj.redLedIsomPerVoltS, obj.greenLedIsomPerVoltS, obj.uvLedIsomPerVoltS];
        end
        
        function value = get.lmsToRgu(obj)
            value = inv(obj.rguToLms);
        end
        
        function value = get.lmsMeanIsomerizations(obj)
            value = [obj.lMeanIsom; obj.mMeanIsom; obj.sMeanIsom];
        end
        
        function value = get.lmsStdvIsomerizations(obj)
            value = obj.lmsMeanIsomerizations .* [obj.lStdvContrast, obj.mStdvContrast, obj.sStdvContrast]';
        end
        
        function value = get.redLed(obj)
            value = obj.rig.getDevice('Red LED');
        end
        
        function value = get.greenLed(obj)
            value = obj.rig.getDevice('Green LED');
        end
        
        function value = get.uvLed(obj)
            value = obj.rig.getDevice('UV LED');
        end
        
        function a = get.amp2(obj)
            amps = obj.rig.getDeviceNames('Amp');
            if numel(amps) < 2
                a = '(None)';
            else
                i = find(~ismember(amps, obj.amp), 1);
                a = amps{i};
            end
        end
    end
end