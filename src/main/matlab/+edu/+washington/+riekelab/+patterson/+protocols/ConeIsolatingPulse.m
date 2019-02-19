classdef ConeIsolatingPulse < edu.washington.riekelab.protocols.RiekeLabProtocol
    
    properties       
        preTime = 500                   % Noise leading duration (ms)
        stimTime = 500                  % Noise duration (ms)
        tailTime = 500                  % Noise trailing duration (ms)
        
        
        sMeanIsom = 1000                % Mean for S-cones (isomerizations)
        mMeanIsom = 1000                % Mean for M-cones (isomerizations)
        lMeanIsom = 1000                % Mean for L-cones (isomerizations)
        
        lContrast = 0                   % L-cone contrast ([-1, 1])
        mContrast = 0                   % M-cone contrast ([-1, 1])
        sContrast = 0.5                 % S-cone contrast ([-1, 1])
        
        numberOfAverages = uint16(3)    % Number of epochs
        onlineAnalysis = 'none'         % Online analysis type
              
        redLedIsomPerVoltS = 38         % S-cone isom per red LED volt    
        redLedIsomPerVoltM = 363        % M-cone isom per red LED volt
        redLedIsomPerVoltL = 1744       % L-cone isom per red LED volt
        greenLedIsomPerVoltS = 134      % S-cone isom per green LED volt
        greenLedIsomPerVoltM = 1699     % M-cone isom per green LED volt
        greenLedIsomPerVoltL = 1099     % L-cone isom per green LED volt
        uvLedIsomPerVoltS = 2691        % S-cone isom per UV LED volt
        uvLedIsomPerVoltM = 360         % M-cone isom per UV LED volt
        uvLedIsomPerVoltL = 344         % L-cone isom per UV LED volt
        
        interpulseInterval = 0;         % Time between epochs (s)
        amp                             % Input amplifier
    end
    
    properties (Dependent, SetAccess = private)
        amp2                            % Secondary input amplifier
    end
    
    properties (Hidden)
        ampType
        onlineAnalysisType = symphonyui.core.PropertyType('char', 'row',...
            {'none', 'extracellular', 'exc', 'inh'})
    end
    
    properties (Hidden, Dependent)
        redLed
        greenLed
        uvLed
        
        lmsMeanIsom
        lmsStdvIsom
        
        lmsToRgu
        rguToLms
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
                rguMean = obj.lmsToRgu * obj.lmsMeanIsom;
                rguStdv = obj.lmsToRgu * obj.lmsStdvIsom;
                
                ledList = [obj.redLed, obj.greenLed, obj.uvLed];
                
                s = cell(3, 1);
                for i = 1:3
                    s{i} = obj.createLedStimulus(rguMean(i), rguStdv(i),...
                        ledList(i).background.displayUnits);
                end
            end
        end
        
        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.protocols.RiekeLabProtocol(obj);
            
            % Setup the analysis figures
            if numel(obj.rig.getDeviceNames('Amp')) < 2
                obj.showFigure('edu.washington.riekelab.patterson.figures.LedResponseFigure',...
                    obj.rig.getDevice(obj.amp),...
                    [obj.redLed, obj.greenLed, obj.uvLed]);
                obj.showFigure('edu.washington.riekelab.patterson.figures.MeanResponseFigure',...
                    obj.rig.getDevice(obj.amp), 'groupBy', {},...
                    'recordingType', obj.onlineAnalysis);
            else
                obj.showFigure('symphonyui.builtin.figures.DualResponseFigure',...
                    obj.rig.getDevice(obj.amp), obj.rig.getDevice(obj.amp2));
            end
            
            % Set the background
            rguMean = obj.lmsToRgu * obj.lmsMeanIsom;
            
            obj.redLed.background = symphonyui.core.Measurement(...
                rguMean(1), obj.redLed.background.displayUnits);
            obj.greenLed.background = symphonyui.core.Measurement(...
                rguMean(2), obj.greenLed.background.displayUnits);
            obj.uvLed.background = symphonyui.core.Measurement(...
                rguMean(3), obj.uvLed.background.displayUnits);
        end      
                
        function stim = createLedStimulus(obj, ledMean, ledAmp, ledUnits)
            if nargin < 4 % Temporary for debugging
                ledUnits = symphonyui.core.Measurement.NORMALIZED;
            end
            gen = symphonyui.builtin.stimuli.PulseGenerator();
            gen.preTime = obj.preTime;
            gen.stimTime = obj.stimTime;
            gen.tailTime = obj.tailTime;
            gen.mean = ledMean;
            gen.amplitude = ledAmp;
            gen.sampleRate = obj.sampleRate;
            gen.units = ledUnits;

            stim = gen.generate();
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, epoch);
            
            rguMean = obj.lmsToRgu * obj.lmsMeanIsom;
            rguStdv = obj.lmsToRgu * obj.lmsStdvIsom;
            
            % Epoch parameters
            epoch.addParameter('lMean', rguMean(1));
            epoch.addParameter('mMean', rguMean(2));
            epoch.addParameter('sMean', rguMean(3));
            epoch.addParameter('lContrast', rguStdv(1));
            epoch.addParameter('mContrast', rguStdv(2));
            epoch.addParameter('sContrast', rguStdv(3));
            
            % Epoch LED stimuli
            epoch.addStimulus(obj.redLed,...
                obj.createLedStimulus(rguMean(1), rguStdv(1)));
            epoch.addStimulus(obj.greenLed,...
                obj.createLedStimulus(rguMean(2), rguStdv(2)));
            epoch.addStimulus(obj.uvLed,...
                obj.createLedStimulus(rguMean(3), rguStdv(3)));
            
            % Epoch responses
            epoch.addResponse(obj.rig.getDevice(obj.amp));
            if numel(obj.rig.getDeviceNames('Amp')) >= 2
                epoch.addResponse(obj.rig.getDevice(obj.amp2));
            end
        end
        
        function prepareInterval(obj, interval)
            prepareInterval@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, interval);
            
            interval.addDirectCurrentStimulus(...
                obj.redLed, obj.redLed.background,...
                obj.interpulseInterval, obj.sampleRate);
            interval.addDirectCurrentStimulus(...
                obj.greenLed, obj.greenLed.background,... 
                obj.interpulseInterval, obj.sampleRate);
            interval.addDirectCurrentStimulus(...
                obj.uvLed, obj.uvLed.background,...
                obj.interpulseInterval, obj.sampleRate);
        end

        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numberOfAverages;
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numberOfAverages;
        end

    end
    
    % Dependent get/set methods
    methods
        function value = get.rguToLms(obj)
            value = [obj.redLedIsomPerVoltL, obj.greenLedIsomPerVoltL, obj.uvLedIsomPerVoltL; ...
                obj.redLedIsomPerVoltM, obj.greenLedIsomPerVoltM, obj.uvLedIsomPerVoltM; ...
                obj.redLedIsomPerVoltS, obj.greenLedIsomPerVoltS, obj.uvLedIsomPerVoltS];
        end
        
        function value = get.lmsToRgu(obj)
            value = inv(obj.rguToLms);
        end
        
        function value = get.lmsMeanIsom(obj)
            value = [obj.lMeanIsom; obj.mMeanIsom; obj.sMeanIsom];
        end
        
        function value = get.lmsStdvIsom(obj)
            value = obj.lmsMeanIsom .* [obj.lContrast, obj.mContrast, obj.sContrast]';
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