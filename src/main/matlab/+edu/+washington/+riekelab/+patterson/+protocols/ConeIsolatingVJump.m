classdef ConeIsolatingVJump < edu.washington.riekelab.protocols.RiekeLabProtocol
    
    properties       
        preTime = 500                   % Pulse leading duration (ms)
        stimTime = 500                  % Pulse duration (ms)
        tailTime = 1500                 % Pulse trailing duration (ms)
        
        meanIsom = 4000                 % Background isomerizaions
        lmContrast = 0.5                % LM-cone contrast ([-1, 1])
        sContrast = 0.5                 % S-cone contrast ([-1, 1])
        
        ECl = -55                       % Apparent chloride reversal (mV)
        voltageHolds = [-20 0 20 35 50 65 90 115 0] % Change in Vhold re to ECl (mV)
        
        numberOfAverages = uint16(27)   % Number of epochs
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
            {'none', 'extracellular', 'voltage_clamp', 'current_clamp', 'subthreshold'})
        
        holdingPotential
        nextHold
        Vh 
        lmsContrasts
    end
    
    properties (Hidden, Dependent)
        redLed
        greenLed
        uvLed
        
        lmsMeanIsom
        
        lmsToRgu
        rguToLms
    end

    properties
        LED_MAX = 9;
        REPS_PER_HOLD = 3;
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
            
            obj.Vh = ones(obj.REPS_PER_HOLD, 1)*obj.voltageHolds + obj.ECl;
            obj.Vh = obj.Vh(:)';
            
            lmsContrast = obj.lmsMeanIsom .* [obj.lContrast, obj.mContrast, 0]';
            lmsContrast = cat(1, lmsContrast,... 
                obj.lmsMeanIsom .* [0, 0, obj.sContrast]');
            obj.lmsContrasts = repmat(lmsContrast, [numel(obj.voltageHolds), 1]);

            % Setup the analysis figures
            if numel(obj.rig.getDeviceNames('Amp')) < 2
                obj.showFigure('edu.washington.riekelab.patterson.figures.LedResponseFigure',...
                    obj.rig.getDevice(obj.amp),...
                    [obj.redLed, obj.greenLed, obj.uvLed]);
                obj.showFigure('edu.washington.riekelab.patterson.figures.MeanResponseFigure',...
                    obj.rig.getDevice(obj.amp), 'groupBy', {},...
                    'recordingType', obj.onlineAnalysis);
                if ~strcmp(obj.onlineAnalysis, 'none')
                    obj.showFigure('edu.washington.riekelab.patterson.figures.VJumpFigure',...
                        obj.rig.getDevice(obj.amp), obj.ECl, obj.Vh);
                end
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

            
            % Get the current contrast.
            if length(obj.contrasts) > 1
                obj.contrast = obj.allContrasts(mod(obj.numEpochsCompleted,length(obj.allContrasts))+1);
            else
                obj.contrast = obj.contrasts;
            end
            epoch.addParameter('contrast', obj.contrast);

            % Get the current holding potential.
            obj.holdingPotential = obj.Vh(mod(obj.numEpochsCompleted,length(obj.Vh))+1);
            if (obj.numEpochsCompleted+1) < obj.numberOfAverages
                obj.nextHold = obj.Vh(mod(obj.numEpochsCompleted+1,length(obj.Vh))+1);
            end
            epoch.addParameter('holdingPotential', obj.holdingPotential);
             % Set the holding potential.
            device = obj.rig.getDevice(obj.amp);
            device.background = symphonyui.core.Measurement(...
                obj.holdingPotential, device.background.displayUnits);

            % Determine whether this is a dummy epoch (i.e. no stimulus).
            isDummyEpoch = (mod(obj.numEpochsCompleted, obj.REPS_PER_HOLD) == 0);
            if isDummyEpoch
                epoch.shouldBePersisted = false;
            else
                epoch.shouldBePersisted = true;
            end
            
            rguMean = obj.lmsToRgu * obj.lmsMeanIsom;
            rguStdv = obj.lmsToRgu * obj.lmsContrasts(obj.numEpochsCompleted+1, :);
            
            % Epoch parameters
            epoch.addParameter('lMean', rguMean(1));
            epoch.addParameter('mMean', rguMean(2));
            epoch.addParameter('sMean', rguMean(3));
            epoch.addParameter('lContrast', rguStdv(1));
            epoch.addParameter('mContrast', rguStdv(2));
            epoch.addParameter('sContrast', rguStdv(3));
            
            % Epoch LED stimuli
            epoch.addStimulus(obj.redLed,...
                obj.createLedStimulus(rguMean(1), rguStdv(1),...
                obj.redLed.background.displayUnits));
            epoch.addStimulus(obj.greenLed,...
                obj.createLedStimulus(rguMean(2), rguStdv(2),...
                obj.greenLed.background.displayUnits));
            epoch.addStimulus(obj.uvLed,...
                obj.createLedStimulus(rguMean(3), rguStdv(3),... 
                obj.uvLed.background.displayUnits));
            
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

        function completeEpoch(obj, epoch)
            completeEpoch@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, epoch);

            % Set the Amp background to the next hold.
            if (obj.numEpochsCompleted+1) < obj.numberOfAverages
                device = obj.rig.getDevice(obj.amp);
                device.background = symphonyui.core.Measurement(...
                    obj.nextHold, device.background.displayUnits);
            end
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