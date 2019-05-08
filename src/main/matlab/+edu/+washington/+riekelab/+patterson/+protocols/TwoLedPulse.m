classdef TrichromaticLedPulse < edu.washington.riekelab.protocols.RiekeLabProtocol
    % THREELEDPULSE
    %
    % History:
    %   8May2019 - SSP
    % ---------------------------------------------------------------------
    
    properties
        preTime = 10                    % Pulse leading duration (ms)
        stimOneTime = 100               % First pulse duration (ms)
        waitTime = 100                  % Time between pulses (ms)
        stimTwoTime = 100               % Second pulse duration (ms)
        tailTime = 400                  % Pulse trailing duration (ms)
        
        ledOne
        meanOne                         % Red LED background mean (V)
        ampOne                          % LED 1 pulse amplitude (V)
        ledTwo
        meanTwo                         % Green LED background mean (V)
        ampTwo                          % Green LED amplitude (V)
        onlineAnalysis = 'none'         % Online analysis type
        numberOfAverages = uint16(5)    % Number of epochs
        interpulseInterval = 0          % Duration between pulses (s)
        amp                             % Input amplifier
    end
    
    properties (Dependent, SetAccess = private)
        amp2                            % Secondary amplifier
    end
    
    properties (Hidden)
        ampType
        ledOneType
        ledTwoType
        onlineAnalysisType = symphonyui.core.PropertyType('char', 'row',...
            {'none', 'extracellular', 'voltage_clamp', 'current_clamp', 'subthreshold'})
    end
    
    methods
        
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabProtocol(obj);
            
            [obj.ledOne, obj.ledOneType] = obj.createDeviceNamesProperty('LED');
            [obj.ledTwo, obj.ledTwoType] = obj.createDeviceNamesProperty('LED');
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
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
                s = cell(2, 1);
                [s{1}, s{2}] = obj.createLedStimuli();
            end
        end
        
        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.protocols.RiekeLabProtocol(obj);
            
            % Setup the analysis figures
            if numel(obj.rig.getDeviceNames('Amp')) < 2
                obj.showFigure('edu.washington.riekelab.patterson.figures.LedResponseFigure',...
                    obj.rig.getDevice(obj.amp), [obj.ledOne, obj.ledTwo]);
                obj.showFigure('edu.washington.riekelab.patterson.figures.MeanResponseFigure',...
                    obj.rig.getDevice(obj.amp), 'groupBy', {},...
                    'recordingType', obj.onlineAnalysis);
            else
                obj.showFigure('symphonyui.builtin.figures.DualResponseFigure',...
                    obj.rig.getDevice(obj.amp), obj.rig.getDevice(obj.amp2));
            end
        end
        
        function [stimOne, stimTwo] = createLedStimuli(obj)

            gen = symphonyui.builtin.stimuli.PulseGenerator();
            gen.preTime = obj.preTime;
            gen.stimTime = obj.stimOneTime;
            gen.tailTime = obj.waitTime + obj.stimTwoTime + obj.tailTime;
            gen.mean = obj.meanOne;
            gen.amplitude = obj.ampOne;
            gen.sampleRate = obj.sampleRate;
            gen.units = obj.ledOne.background.displayUnits;

            stimOne = gen.generate();
            
            gen = symphonyui.builtin.stimuli.PulseGenerator();
            gen.preTime = obj.preTime + obj.stimOneTime + obj.waitTime;
            gen.stimTime = obj.stimTwoTime;
            gen.tailTime = obj.tailTime;
            gen.mean = obj.meanOne;
            gen.amplitude = obj.ampOne;
            gen.sampleRate = obj.sampleRate;
            gen.units = obj.ledTwo.background.displayUnits;
            
            stimTwo = gen.generate();
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, epoch);
            
            % Add epoch stimuli
            [stimOne, stimTwo] = obj.createLedStimuli();
            epoch.addStimulus(obj.ledOne, stimOne);
            epoch.addStimulus(obj.ledTwo, stimTwo);
            
            % Add response
            epoch.addResponse(obj.rig.getDevice(obj.amp));
            if numel(obj.rig.getDeviceNames('Amp')) >= 2
                epoch.addResponse(obj.rig.getDevice(obj.amp2));
            end
        end
        
        function prepareInterval(obj, interval)
            prepareInterval@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, interval);
            
            interval.addDirectCurrentStimulus(...
                obj.ledOne, obj.ledOne.background,... 
                obj.interpulseInterval, obj.sampleRate);
            interval.addDirectCurrentStimulus(...
                obj.ledTwo, obj.ledTwo.background,...
                obj.interpulseInterval, obj.sampleRate);
        
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numberOfAverages;
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numberOfAverages;
        end
    end
    
    % Dependent get/set methods
    methods
        
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