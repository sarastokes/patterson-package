classdef TwoLedAdaptingSteps < edu.washington.riekelab.protocols.RiekeLabProtocol
    
    properties
        stepLed                         % LED for background step
        flashLed                        % LED for flashes
        preTime = 2000                  % Time before step (ms)
        waitTime = 0                    % Time at epoch start and end w/out flashes (ms)
        stimTime = 2000                 % Time during step (ms)
        tailTime = 2000                 % Time after step (ms)
        
        flashTime = 10                  % Duration of flashes (ms)
        flashFrequency = 2              % Temporal frequency of flashes (Hz)

        stepMean = 0                    % LED before and after step (V)
        stepAmp = 1                     % LED during step (V)
        
        flashAmp = 1                    % Flash amplitude during step (V)
        flashMean = 0                   % Flash LED background amplitude (V)
        
        onlineAnalysis = 'none'         % Online analysis type
        numberOfAverages = uint16(3)    % Number of epochs to deliver
        
        noFlashEpoch = false            % Present an epoch without the flashes
        noStepEpoch = false             % Present an epoch without the step
        
        interpulseInterval = 0
        amp                             % Input amplifier
    end
    
    properties (Dependent, SetAccess = private)
        amp2                        % Secondary amplifier
    end
    
    properties (Dependent, Hidden = true)
        numFlashes
        flashInterval
    end
    
    properties (Hidden)
        ampType
        flashLedType
        stepLedType
        onlineAnalysisType = symphonyui.core.PropertyType('char', 'row',...
            {'none', 'extracellular', 'exc', 'inh'});
    end
    
    properties (Constant, Hidden)
        LED_MAX = 9;
        LED_MIN = -9;
    end
    
    methods
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabProtocol(obj);
            
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
            [obj.flashLed, obj.flashLedType] = obj.createDeviceNamesProperty('LED');
            [obj.stepLed, obj.stepLedType] = obj.createDeviceNamesProperty('LED');
        end
        
        
        function d = getPropertyDescriptor(obj, name)
            d = getPropertyDescriptor@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, name);
            
            if strncmp(name, 'amp2', 4) && numel(obj.rig.getDeviceNames('Amp')) < 2
                d.isHidden = true;
            end
        end
        
        function p = getPreview(obj, panel)
            p = edu.washington.riekelab.patterson.previews.LedStimuliPreview(...
                panel, @()createPreviewStimuli(obj));
            
            function s = createPreviewStimuli(obj)
                lastEpoch = double(obj.numberOfAverages);
                if isequal(obj.stepLed, obj.flashLed)
                    s = obj.createLedStimulus(lastEpoch);
                else
                    s = cell(2, 1);
                    [s{1}, s{2}] = obj.createLedStimulus(lastEpoch);
                end
            end
        end
        
        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.protocols.RiekeLabProtocol(obj);
            
            if double(obj.numberOfAverages) <= nnz([obj.noFlashEpoch, obj.noFlashEpoch]) + 1
                warndlg('Not enough averages for regular and no flash/no step epochs!');
            end

            if isequal(obj.stepLed, obj.flashLed) && nnz([obj.flashMean, obj.stepMean]) > 1
                warndlg('Not setup to handle both flash and step means for a single LED!');
            end

            % Setup the analysis figures
            if numel(obj.rig.getDeviceNames('Amp')) < 2
                obj.showFigure('edu.washington.riekelab.patterson.figures.LedResponseFigure',...
                    obj.rig.getDevice(obj.amp),...
                    [obj.rig.getDevice(obj.stepLed), obj.rig.getDevice(obj.flashLed)]);
                obj.showFigure('edu.washington.riekelab.patterson.figures.MeanResponseFigure',...
                    obj.rig.getDevice(obj.amp),...
                    'groupBy', {'epochType'}, 'recordingType', obj.onlineAnalysis);
            else
                obj.showFigure('edu.washington.riekelab.figures.DualResponseFigure',...
                    obj.rig.getDevice(obj.amp), obj.rig.getDevice(obj.amp2));
            end
            
            % Set the background
            device1 = obj.rig.getDevice(obj.stepLed);
            device1.background = symphonyui.core.Measurement(...
                obj.stepMean, device1.background.displayUnits);
            
            device2 = obj.rig.getDevice(obj.flashLed);
            device2.background = symphonyui.core.Measurement(...
                obj.flashMean, device2.background.displayUnits);
        end

        
        function [stim1, stim2] = createLedStimulus(obj, epochType)
            % Step
            gen = symphonyui.builtin.stimuli.PulseGenerator();
            gen.preTime = obj.preTime;
            gen.stimTime = obj.stimTime;
            gen.tailTime = obj.tailTime;
            if epochType == 2  % No step epoch
                gen.amplitude = 0;
            else
                gen.amplitude = obj.stepAmp - obj.stepMean;
            end
            gen.mean = obj.stepMean;
            gen.sampleRate = obj.sampleRate;
            gen.units = obj.rig.getDevice(obj.stepLed).background.displayUnits;
            stim1 = gen.generate();

            % Flashes
            totalTime = obj.preTime + obj.stimTime + obj.tailTime;
            
            gen = symphonyui.builtin.stimuli.PulseGenerator();
            gen.preTime = 0;
            gen.stimTime = totalTime;
            gen.tailTime = 0;
            gen.mean = obj.flashMean;
            gen.amplitude = 0;
            gen.sampleRate = obj.sampleRate;
            gen.units = obj.rig.getDevice(obj.flashLed).background.displayUnits;
            if epochType == 3  % No flash epoch
                stim2 = gen.generate();
            else
                flashStimuli = {gen.generate()};
                currentTime = obj.waitTime;
                while currentTime < (totalTime - obj.waitTime)
                    gen = symphonyui.builtin.stimuli.PulseGenerator();
                    gen.preTime = currentTime;
                    gen.stimTime = obj.flashTime;
                    gen.tailTime = totalTime - (currentTime + obj.flashTime);
                    gen.amplitude = obj.flashAmp - obj.flashMean;
                    gen.mean = 0;
                    gen.sampleRate = obj.sampleRate;
                    gen.units = obj.rig.getDevice(obj.flashLed).background.displayUnits;
                    flashStimuli = cat(2, flashStimuli, {gen.generate()});
                    
                    currentTime = currentTime + 10 + obj.flashInterval;
                end
                sumgen = symphonyui.builtin.stimuli.SumGenerator();
                sumgen.stimuli = flashStimuli;
                stim2 = sumgen.generate();
            end

            % Sum if working with a single LED
            if isequal(obj.stepLed, obj.flashLed)
                sumgen = symphonyui.builtin.stimuli.SumGenerator();
                sumgen.stimuli = [{stim1}, {stim2}];
                stim1 = sumgen.generate();
                stim2 = [];
            end
        end

        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, epoch);
            
            epochType = obj.getEpochType(obj.numEpochsPrepared);
            epoch.addParameter('epochType', epochType);

            [stim1, stim2] = obj.createLedStimulus(epochType);
            epoch.addStimulus(obj.rig.getDevice(obj.stepLed), stim1);
            if ~isequal(obj.stepLed, obj.flashLed)
                epoch.addStimulus(obj.rig.getDevice(obj.flashLed), stim2);
            end

            epoch.addResponse(obj.rig.getDevice(obj.amp));
            if numel(obj.rig.getDeviceNames('Amp')) >= 2
                epoch.addResponse(obj.rig.getDevice(obj.amp2));
            end
        end
        
        function prepareInterval(obj, interval)
            prepareInterval@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, interval);
            
            device = obj.rig.getDevice(obj.flashLed);
            interval.addDirectCurrentStimulus(device,...
                device.background, obj.interpulseInterval, obj.sampleRate);
            
            device = obj.rig.getDevice(obj.stepLed);
            interval.addDirectCurrentStimulus(device,...
                device.background, obj.interpulseInterval, obj.sampleRate);
        end

        
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numberOfAverages;
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numberOfAverages;
        end
        
        function epochType = getEpochType(obj, epochNum)
            % 1 = steps + flash, 2 = steps, 3 = flashes
            epochType = 1;
            if epochNum == 1
                if obj.noStepEpoch
                    epochType = 2;
                elseif obj.noFlashEpoch
                    epochType = 3;
                end
            elseif epochNum == 2
                if obj.noFlashEpoch
                    epochType = 3;
                end
            end
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

        function value = get.flashInterval(obj)
            value = floor((1000/obj.flashFrequency) - obj.flashTime);
        end

        function value = get.numFlashes(obj)
            totalTime = obj.preTime + obj.stimTime + obj.tailTime;
            value = floor((totalTime - 2*obj.waitTime)/(1000/obj.flashFrequency)) - 1;
        end
    end
end