classdef AdaptingPyramid < edu.washington.riekelab.protocols.RiekeLabProtocol
   
    properties
        led
        
        stepTime = 1000         % Duration of adapting step
        
        baseMagnitude = 0       % Magnitude of LED at first step (V)
        topMagnitude = 5        % Magnitude of LED at peak step (V)
        
        numSteps = 3            % Number of pyramid steps from base to top
        onlineAnalysis = 'none' % Online analysis type
        
        interpulseInterval = 0  % Duration between pulses (ms)
        amp                     % Input amplifier
    end
    
    properties (Dependent, SetAccess = private)
        amp2                    % Secondary amplifier
    end
    
    properties (Dependent, Hidden = true)
        totalEpochs
    end
    
    properties (Hidden)
        ledType
        ampType
        onlineAnalysisType = symphonyui.core.PropertyType('char', 'row',...
            {'none', 'extracellular', 'voltage_clamp', 'current_clamp'});
    end
    
    methods
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabProtocol(obj);
            
            [obj.led, obj.ledType] = obj.createDeviceNamesProperty('LED');
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end
        
        function d = getPropertyDescriptor(obj, name)
            d = getPropertyDescriptor@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, name);

            if strncmp(name, 'amp2', 4) && numel(obj.rig.getDeviceNames('Amp')) < 2
                d.isHidden = true;
            end
        end
        
        function p = getPreview(obj, panel)
            p = edu.washington.riekelab.patterson.previews.FullStimuliPreview(...
                panel, @()createPreviewStimuli(obj));
            
            function s = createPreviewStimuli(obj)
                s = cell(obj.totalEpochs, 1);
                for i = 1:obj.totalEpochs
                    s{i} = obj.createLedStimulus(i);
                end
            end
        end
        
        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.protocols.RiekeLabProtocol(obj);
            rgb = edu.washington.riekelab.patterson.utils.pmkmp(2*obj.numSteps-1, 'CubicL');

            if numel(obj.rig.getDeviceNames('Amp')) < 2
                
                obj.showFigure('edu.washington.riekelab.patterson.figures.LedResponseFigure',...
                    obj.rig.getDevice(obj.amp), obj.rig.getDevice(obj.led));
                obj.showFigure('edu.washington.riekelab.patterson.figures.TotalResponseFigure',...
                    obj.rig.getDevice(obj.amp), 'colorBy', {'stepAmplitude'},...
                    'recordingType', obj.onlineAnalysis, 'sweepColor', rgb);
                if strcmp(obj.onlineAnalysis, 'extracellular')
                    obj.showFigure('edu.washington.riekelab.patterson.figures.SpikeStatisticsFigure',...
                        obj.rig.getDevice(obj.amp));
                else
                    obj.showFigure('symphonyui.builtin.figures.ResponseStatisticsFigure',...
                        obj.rig.getDevice(obj.amp), {@mean, @var});
                end
            else
                obj.showFigure('symphonyui.builtin.figures.DualResponseFigure',...
                    obj.rig.getDevice(obj.amp), obj.rig.getDevice(obj.amp2));
            end
            
            device = obj.rig.getDevice(obj.led);
            device.background = symphonyui.core.Measurement(...
                obj.baseMagnitude, device.background.displayUnits);
        end
        
        function [stim, stepAmplitude] = createLedStimulus(obj, epochNum)
            
            allSteps = linspace(obj.baseMagnitude, obj.topMagnitude, obj.numSteps);
            allSteps = [allSteps, fliplr(allSteps(1:end-1))];
            
            stepAmplitude = allSteps(epochNum);
            
            gen = symphonyui.builtin.stimuli.PulseGenerator();
            gen.preTime = 0;
            gen.stimTime = obj.stepTime;
            gen.tailTime = 0;
            gen.amplitude = stepAmplitude;
            gen.mean = obj.baseMagnitude;
            gen.sampleRate = obj.sampleRate;
            gen.units = obj.rig.getDevice(obj.led).background.displayUnits;
            
            stim = gen.generate();
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, epoch);
            
            epochNum = obj.numEpochsPrepared;
            [stim, stepAmplitude] = obj.createLedStimulus(epochNum);
            
            epoch.addParameter('stepAmplitude', stepAmplitude);
            epoch.addStimulus(obj.rig.getDevice(obj.led), stim);

            epoch.addResponse(obj.rig.getDevice(obj.amp));
            if numel(obj.rig.getDeviceNames('Amp')) >= 2
                epoch.addResponse(obj.rig.getDevice(obj.amp2));
            end
        end        
        
        function prepareInterval(obj, interval)
            prepareInterval@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, interval);
            
            device = obj.rig.getDevice(obj.led);
            interval.addDirectCurrentStimulus(device, device.background,...
                obj.interpulseInterval, obj.sampleRate);
        end
        
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.totalEpochs;
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.totalEpochs;
        end
    end

    % Dependent set/get methods
    methods
        
        function value = get.totalEpochs(obj)
            value = 2 * obj.numSteps - 1;
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