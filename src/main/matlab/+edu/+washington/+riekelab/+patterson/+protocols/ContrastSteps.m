classdef ContrastSteps < edu.washington.riekelab.protocols.RiekeLabProtocol
    
    properties
        led                             % Output LED
        preTime = 500                   % Pulse leading duration (ms)
        stimTime = 500                 % Pulse duration (ms)
        tailTime = 500                  % Pulse trailing duration (ms)
        contrasts = [-100 -50 -25 -10 10 25 50 100] % in percent
        lightMean = 2                   % Pulse and background mean (V)
        amp                             % Input amplifier
        numberOfAverages = uint16(5)    % Number of epochs
        onlineAnalysis = 'extracellular'    % Online analysis type
        interpulseInterval = 0          % Duration between pulses (s)
    end
    
    properties (Hidden)
        ledType
        ampType
        contrastsType = symphonyui.core.PropertyType('denserealdouble', 'matrix')
        onlineAnalysisType = symphonyui.core.PropertyType('char', 'row',...
            {'none', 'extracellular', 'exc', 'inh'})
    end
    
    properties (Dependent)
        totalEpochs
        numContrasts
    end
    
    methods
        
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabProtocol(obj);
            
            [obj.led, obj.ledType] = obj.createDeviceNamesProperty('LED');
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end
        
        function p = getPreview(obj, panel)
            p = symphonyui.builtin.previews.StimuliPreview(...
                panel, @()createPreviewStimuli(obj));
            
            function s = createPreviewStimuli(obj)
                s = cell(obj.numContrasts, 1);
                for i = 1:obj.numContrasts
                    s{i} = obj.createLedStimulus(i);
                end
            end
        end
        
        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.protocols.RiekeLabProtocol(obj);

            rgb = edu.washington.riekelab.patterson.utils.multigradient(...
                'preset', 'div.cb.spectral.9', 'length', length(obj.contrasts));
            
            if numel(obj.rig.getDeviceNames('Amp')) < 2
                obj.showFigure('edu.washington.riekelab.patterson.figures.LedResponseFigure',...
                    obj.rig.getDevice(obj.amp), obj.rig.getDevice(obj.led));
                obj.showFigure('edu.washington.riekelab.patterson.figures.MeanResponseFigure',... 
                    obj.rig.getDevice(obj.amp), 'groupBy', {'Contrast'},... 
                    'recordingType', obj.onlineAnalysis, 'sweepColor', rgb);   
        
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

            obj.rig.getDevice(obj.led).background = symphonyui.core.Measurement(...
                obj.lightMean, 'V');
        end
        
        function stim = createLedStimulus(obj, epochNum)
            
            gen = symphonyui.builtin.stimuli.PulseGenerator();
            
            gen.preTime = obj.preTime;
            gen.stimTime = obj.stimTime;
            gen.tailTime = obj.tailTime;
            gen.amplitude = obj.percentContrastToVolts( ...
                obj.determineContrast(epochNum));
            disp(gen.amplitude);
            gen.mean = obj.lightMean;
            gen.sampleRate = obj.sampleRate;
            gen.units = 'V';
            
            stim = gen.generate();
            
        end
        
        function idx = determineContrastIdx(obj, epochNum)
            idx = mod(epochNum - 1, obj.numContrasts) + 1;
        end
        
        function contr = determineContrast(obj, epochNum)
            contr = obj.contrasts(obj.determineContrastIdx(epochNum));
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, epoch);
            
            % get epoch number
            epochNum = obj.numEpochsPrepared;
            
            epoch.addStimulus(obj.rig.getDevice(obj.led), obj.createLedStimulus(epochNum));
            epoch.addResponse(obj.rig.getDevice(obj.amp));
            
            
            epoch.addParameter('Contrast', obj.determineContrast(epochNum));
        end
        
        function prepareInterval(obj, interval)
            prepareInterval@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, interval);
            
            device = obj.rig.getDevice(obj.led);
            interval.addDirectCurrentStimulus(device, device.background, obj.interpulseInterval, obj.sampleRate);
        end
        
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.totalEpochs;
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.totalEpochs;
        end
        
        function volts = percentContrastToVolts(obj, percentContrast)
            volts = obj.lightMean * percentContrast / 100;
        end
        
    end
    
    % for dependent properites
    methods
        function value = get.totalEpochs(obj)
            value = obj.numContrasts * obj.numberOfAverages;
        end
        
        function value = get.numContrasts(obj)
            value = numel(obj.contrasts);
        end
    end
    
end

