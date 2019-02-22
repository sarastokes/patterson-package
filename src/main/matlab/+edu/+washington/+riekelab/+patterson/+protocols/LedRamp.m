classdef LedRamp < edu.washington.riekelab.protocols.RiekeLabProtocol
% LEDRAMP
%
% Description:
%   Presents a set of ramp stimuli to a specified LED and records from a 
%   specified amplifier
%
% History:
%   21Feb2019
% -------------------------------------------------------------------------

    properties
        led                             % Output LED
        preTime = 250                   % Pulse leading duration (ms)
        stimTime = 1000                 % Pulse duration (ms)
        tailTime = 1000                 % Pulse trailing duration (ms)
        lightAmplitude = 1.0            % Final LED voltage (V)
        lightMean = 0                   % Baseline LED voltage (V)
        numberOfAverages = uint16(1)    % Number of epochs
        onlineAnalysis = 'none'         % Online analysis type
        keepFinalAmplitude = false      % Set final LED V as background 
        interpulseInterval = 0          % Duration between ramps (s)
        amp                             % Output amplifier
    end
        
    properties (Dependent, SetAccess = private)
        amp2                            % Secondary amplifier
    end

    properties (Hidden)
        ampType
        ledType
        onlineAnalysisType = symphonyui.core.PropertyType('char', 'row',...
            {'none', 'extracellular', 'exc', 'inh'});
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
            p = symphonyui.builtin.previews.StimuliPreview(panel,... 
                @()obj.createLedStimulus());
        end
        
        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.protocols.RiekeLabProtocol(obj);
            
            if numel(obj.rig.getDeviceNames('Amp')) < 2
                obj.showFigure('edu.washington.riekelab.patterson.figures.LedResponseFigure',... 
                    obj.rig.getDevice(obj.amp), obj.rig.getDevice(obj.led));
                obj.showFigure('edu.washington.riekelab.patterson.figures.MeanResponseFigure',... 
                    obj.rig.getDevice(obj.amp), 'sweepColor', [0, 0, 0.1],...
                    'recordingType', obj.onlineAnalysis);
            else
                obj.showFigure('edu.washington.riekelab.figures.DualResponseFigure',... 
                    obj.rig.getDevice(obj.amp), obj.rig.getDevice(obj.amp2));
                obj.showFigure('edu.washington.riekelab.figures.DualMeanResponseFigure',... 
                    obj.rig.getDevice(obj.amp), obj.rig.getDevice(obj.amp2));
            end
            
            device = obj.rig.getDevice(obj.led);
            device.background = symphonyui.core.Measurement(... 
                obj.lightMean, device.background.displayUnits);
        end
        
        function stim = createLedStimulus(obj)
            gen = edu.washington.riekelab.patterson.stimuli.RampGenerator();
            
            gen.preTime = obj.preTime;
            gen.stimTime = obj.stimTime;
            gen.tailTime = obj.tailTime;
            gen.amplitude = obj.lightAmplitude;
            gen.mean = obj.lightMean;
            gen.keepFinalAmplitude = obj.keepFinalAmplitude;
            gen.sampleRate = obj.sampleRate;
            gen.units = obj.rig.getDevice(obj.led).background.displayUnits;
            
            stim = gen.generate();
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, epoch);
            
            epoch.addStimulus(obj.rig.getDevice(obj.led), obj.createLedStimulus());
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
end