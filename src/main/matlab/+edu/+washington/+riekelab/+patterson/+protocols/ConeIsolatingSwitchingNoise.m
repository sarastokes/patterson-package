classdef ConeIsolatingSwitchingNoise < edu.washington.riekelab.protocols.RiekeLabProtocol
    % CONEISOLATINGSWITCHINGNOISE
    %
    % Description:
    %   Presents Gaussian noise stimuli with control over L, M and S-cone
    %   isomerizations for both the mean and sd. 
    %   Switching stimulus setup. If 2 numbers are provided for LMS mean or
    %   contrast, the 2nd number will apply to group 2
    %
    % 19Feb2019 - SSP
    % ---------------------------------------------------------------------
    
    properties
        preTime = 500                   % Noise leading duration (ms)
        stimTime = 10000                % Noise duration (ms)
        tailTime = 500                  % Noise trailing duration (ms)
        
        sMeanIsom = [1000 2000]         % Mean for S-cones (isomerizations)
        mMeanIsom = 2000                % Mean for M-cones (isomerizations)
        lMeanIsom = 2000                % Mean for L-cones (isomerizations)
        
        sStdvContrast = 0.3             % S-cone noise SD (contrast [0 1])
        mStdvContrast = 0               % M-cone noise SD (contrast [0 1])
        lStdvContrast = 0               % L-cone noise SD (contrast [0 1])
        
        frequencyCutoff = 60            % Noise frequency cutoff for smoothing (Hz)
        numberOfFilters = 4             % Number of filters in cascade for noise smoothing
        useRandomSeed = true            % Use a random seed for the noise repeats
        groupOneFirst = true            % Start with first group (t/f)
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
        
        numberOfAverages = uint16(10);  % Number of epochs to deliver
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
            {'none', 'extracellular', 'exc', 'inh'})
        
        firstGroup  % Tracks whether or not epoch is first group
        
        analysisFigure
        analysisFigureAxes
        analysisFigureData
        analysisFigureLines
    end
    
    properties (Constant, Hidden)
        % TODO: Get real values for Confocal rig
        LED_MAX = 9; %10.239;
        LED_MIN = -9; %-10.24;
        
        LED_COLORS = [0.25, 0.25, 1; 0, 0.8, 0.3; 0.2, 0.3, 0.9];
    end
    
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
            if obj.firstGroup
                value = [obj.lMeanIsom(1); obj.mMeanIsom(1); obj.sMeanIsom(1)];
            else
                value = [obj.lMeanIsom(end); obj.mMeanIsom(end); obj.sMeanIsom(end)];
            end
        end
        
        function value = get.lmsStdvIsomerizations(obj)
            if obj.firstGroup
                value = obj.lmsMeanIsomerizations .* [obj.lStdvContrast(1), obj.mStdvContrast(1), obj.sStdvContrast(1)]';
            else
                value = obj.lmsMeanIsomerizations .* [obj.lStdvContrast(end), obj.mStdvContrast(end), obj.sStdvContrast(end)]';
        
            end
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
            
            % Set to opposite bc prepareEpoch switches firstGroup
            if obj.groupOneFirst
                obj.firstGroup = false;
            else
                obj.firstGroup = true;
            end
            
            % Setup the analysis figures
            obj.showFigure('edu.washington.riekelab.patterson.figures.LedRangeFigure',...
                obj.rig.getDevice(obj.amp));
            if numel(obj.rig.getDeviceNames('Amp')) < 2
                obj.showFigure('edu.washington.riekelab.patterson.figures.LedResponseFigure',...
                    obj.rig.getDevice(obj.amp),...
                    [obj.redLed, obj.greenLed, obj.uvLed]);
                % obj.showFigure('edu.washington.riekelab.patterson.figures.MeanResponseFigure',...
                %     obj.rig.getDevice(obj.amp), 'groupBy', {'stimGroup'},...
                %    'recordingType', obj.onlineAnalysis);
                rgb = repmat(obj.LED_COLORS(2:3, :), [ceil(double(obj.numberOfAverages)), 1]);
                obj.showFigure('edu.washington.riekelab.patterson.figures.TotalResponseFigure',...
                    obj.rig.getDevice(obj.amp), 'colorBy', {'stimGroup'},...
                    'recordingType', obj.onlineAnalysis, 'sweepColor', rgb);
                if ~strcmp(obj.onlineAnalysis, 'none')
                    obj.analysisFigure = obj.showFigure('symphonyui.builtin.figures.CustomFigure',...
                        @obj.updateAnalysisFigure);
                    obj.createAnalysisFigure();
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
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, epoch);
            
            % Calculate and add epoch parameters
            if obj.firstGroup
                obj.firstGroup = false; groupInd = 2;
            else
                obj.firstGroup = true; groupInd = 1;
            end
            epoch.addParameter('stimGroup', groupInd);
            
            if ~obj.useRandomSeed
                seed = 0;
            else
                seed = RandStream.shuffleSeed;
            end
            epoch.addParameter('seed', seed);
            
            rguMean = obj.lmsToRgu * obj.lmsMeanIsomerizations;
            rguStdv = obj.lmsToRgu * obj.lmsStdvIsomerizations;
            
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
            
            interval.addDirectCurrentStimulus(...
                obj.redLed, obj.redLed.background, obj.interpulseInterval, obj.sampleRate);
            interval.addDirectCurrentStimulus(...
                obj.greenLed, obj.greenLed.background, obj.interpulseInterval, obj.sampleRate);
            interval.addDirectCurrentStimulus(...
                obj.uvLed, obj.uvLed.background, obj.interpulseInterval, obj.sampleRate);
        end
        
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numberOfAverages;
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numberOfAverages;
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
    
    % Online analysis methods
    methods
        function y = checkRange(obj, stim)
            stimData = stim.getData();
            y = 100 * (sum(stimData <= 0) + sum(stimData == obj.LED_MAX)) ...
                / (obj.sampleRate * obj.stimTime / 1e3);
        end
        
        function createAnalysisFigure(obj)
            if ~isempty(obj.analysisFigureAxes) && isvalid(obj.analysisFigureAxes)
                cla(obj.analysisFigureAxes);
            else
                obj.analysisFigureAxes = axes('Parent', obj.analysisFigure.getFigureHandle);
            end
            set(obj.analysisFigureAxes.Parent, 'Color', 'w');
            
            obj.analysisFigureAxes.NextPlot = 'add';
            obj.analysisFigureAxes.XLabel.String = 'time (ms)';
            obj.analysisFigureAxes.YLabel.String = 'norm. filter ampl.';
            obj.analysisFigureAxes.Title.String = 'fast linear filters';
            obj.analysisFigureAxes.XLim = [0, 200];
            
            responsePoints = obj.stimTime * obj.sampleRate / 1e3;
            
            obj.analysisFigureData = edu.washington.riekelab.patterson.utils.OnlineLinearFilter(...
                responsePoints, obj.sampleRate, obj.frequencyCutoff / 2);
            obj.analysisFigureData(2) = obj.analysisFigureData;
            
            obj.analysisFigureLines = plot(obj.analysisFigureAxes,...
                (1:responsePoints) * 1e3 / obj.sampleRate, zeros(1, responsePoints),...
                'LineWidth', 1, 'Color', obj.LED_COLORS(2, :));
            obj.analysisFigureLines(2) = obj.analysisFigureLines;
            obj.analysisFigureLines(2).Color = obj.LED_COLORS(3, :);
        end
        
        function updateAnalysisFigure(obj, ~, epoch)
            ind = epoch.parameters('stimGroup');
            
            prePts = obj.preTime * obj.sampleRate/1e3;
            stimPts = obj.stimTime * obj.sampleRate/1e3;
            
            % Get and trim response
            response = epoch.getResponse(obj.rig.getDevice(obj.amp)).getData();
            response = response(prePts + 1:prePts + stimPts);
            
            % If necessary, detect spikes
            if strcmp(obj.onlineAnalysis, 'extracellular')
                spikeDetectionResults = edu.washington.riekelab.patterson.utils.spikeDetectorOnline(response);
                response = zeros(size(response));
                response(spikeDetectionResults.sp) = 1;
            end
            
            % Get and trim stimulus
            stimulus = epoch.getStimulus(obj.greenLed).getData();
            stimulus = stimulus(prePts + 1:prePts + stimPts);
            
            newLinearFilter = obj.analysisFigureData(ind).AddEpochDataAndComputeCurrentLinearFilter(...
                stimulus, response);
            
            % Normalize the new linear filter
            newLinearFilter = newLinearFilter / max(abs(newLinearFilter));
            newLinearFilter = newLinearFilter * (2 * (max(newLinearFilter) > abs(min(newLinearFilter))) - 1);
            
            % Update plot line
            obj.analysisFigureLines(ind).YData = newLinearFilter;
        end
    end
    
end