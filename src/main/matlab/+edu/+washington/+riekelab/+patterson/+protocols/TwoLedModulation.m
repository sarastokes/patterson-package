classdef TwoLedModulation < edu.washington.riekelab.protocols.RiekeLabProtocol
%   Runs epochs in groups of three: each LED is modulated independently, 
%   then together. 
%
% History:
%   20Jan2019 - SSP - Built off RedBlueSine
%   17Feb2019 - SSP - Added amp2, rectification, figures and new preview
% -------------------------------------------------------------------------

    properties
        led1                                % 1st LED
        lightMean1 = 0.1                    % Mean of LED1
        Amp1 = 0.05                         % Amplitude of LED1 modulation
        led2                                % 2nd LED name
        lightMean2 = 0.1                    % Mean of LED2
        Amp2 = 0.05                         % Amplitude of LED2 modulation
        preTime = 250                       % Leading time (ms)
        stimTime = 2000                     % Stimulus time (ms)
        tailTime = 100                      % Trailing stim (ms)
        period = 500                        % Modulation period (ms)
        phaseShift = 0                      % Phase shift (degrees)
        temporalClass = 'sinewave'          % Modulation type
        rectify = false                     % Rectify stimulus (t/f)
        onlineAnalysis = 'extracellular'    % Online analysis type
        numberOfAverages = uint16(12)       % Number of epochs
        interpulseInterval = 0              % Duration between pulses (s)
        amp                                 % Input amplifier
    end

    properties (Dependent, SetAccess = private)
        amp2
    end
    
    properties (Hidden)
        led1Type
        led2Type
        ampType
        temporalClassType = symphonyui.core.PropertyType('char', 'row',...
            {'sinewave', 'squarewave'})
        onlineAnalysisType = symphonyui.core.PropertyType('char', 'row',...
            {'none', 'extracellular', 'exc', 'inh'})
    end
    
    methods
        
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabProtocol(obj);
            
            [obj.led1, obj.led1Type] = obj.createDeviceNamesProperty('LED');
            [obj.led2, obj.led2Type] = obj.createDeviceNamesProperty('LED');
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
                numPulses = 1;
                s = cell(numPulses*2, 1);
                for i = 1:numPulses
                    [s{2*i-1}, s{2*i}] = obj.createLedStimulus(i);
                end
            end
        end
        
        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.protocols.RiekeLabProtocol(obj);

            if numel(obj.rig.getDeviceNames('Amp')) < 2
                obj.showFigure('symphonyui.builtin.figures.ResponseFigure',...
                    obj.rig.getDevice(obj.amp));
                obj.showFigure('edu.washington.riekelab.patterson.figures.MeanResponseFigure',...
                    obj.rig.getDevice(obj.amp), 'groupBy',{'PlotGroup'},...
                    'recordingType', obj.onlineAnalysis,...
                    'sweepColor', [1, 0.25, 0.25; 0.2, 0.3, 0.9; 0, 0.8, 0.3]);
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

            device1 = obj.rig.getDevice(obj.led1);
            device1.background = symphonyui.core.Measurement(...
                obj.lightMean1, device1.background.displayUnits);
            
            device2 = obj.rig.getDevice(obj.led2);
            device2.background = symphonyui.core.Measurement(...
                obj.lightMean2, device2.background.displayUnits);
        end
        
        function [stim1, stim2] = createLedStimulus(obj, pulseNum)
            if strcmp(obj.temporalClass, 'sinewave')
                gen = edu.washington.riekelab.patterson.stimuli.SineGenerator();
            else
                gen = edu.washington.riekelab.patterson.stimuli.SquareGenerator();

            end
            
            gen.preTime = obj.preTime;
            gen.stimTime = obj.stimTime;
            gen.tailTime = obj.tailTime;
            gen.period = obj.period;
            gen.phase = 0;
            gen.mean = obj.lightMean1;
            gen.rectify = obj.rectify;
            gen.sampleRate = obj.sampleRate;
            gen.units = obj.rig.getDevice(obj.led1).background.displayUnits;

            gen.amplitude = obj.Amp1;
            if (rem(pulseNum, 3) == 2)
                gen.amplitude = 0;
            end
            
            stim1 = gen.generate();

            gen.mean = obj.lightMean2;
            gen.phase = (pi/180) * obj.phaseShift;
            gen.amplitude = obj.Amp2;
            if (rem(pulseNum, 3) == 1)
                gen.amplitude = 0;
            end
   
            stim2 = gen.generate();
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, epoch);
             % Add LED stimulus.
            [stim1, stim2] = obj.createLedStimulus(obj.numEpochsPrepared);
            cnt = rem(obj.numEpochsPrepared, 3);
            epoch.addParameter('PlotGroup', cnt);
            
            epoch.addStimulus(obj.rig.getDevice(obj.led1), stim1);
            if ~strcmp(obj.led1, obj.led2)
                epoch.addStimulus(obj.rig.getDevice(obj.led2), stim2);
            end
            
            epoch.addResponse(obj.rig.getDevice(obj.amp));
            if numel(obj.rig.getDeviceNames('Amp')) >= 2
                epoch.addResponse(obj.rig.getDevice(obj.amp2));
            end
        end
        
        function prepareInterval(obj, interval)
            prepareInterval@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, interval);
            
            device = obj.rig.getDevice(obj.led1);
            interval.addDirectCurrentStimulus(device,...
                device.background, obj.interpulseInterval, obj.sampleRate);
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