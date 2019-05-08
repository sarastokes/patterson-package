classdef TrichromaticLedPulse < edu.washington.riekelab.patterson.protocols.ConeIsolationProtocol
    % TRICHROMATICLEDPULSE
    %
    % History:
    %   8May2019 - SSP
    % ---------------------------------------------------------------------
    
    properties
        preTime = 10                    % Pulse leading duration (ms)
        stimTime = 100                  % Pulse duration (ms)
        tailTime = 400                  % Pulse trailing duration (ms)
        
        redMean = 0                     % Red LED background mean (V)
        redAmp = 0                      % Red LED pulse amplitude (V)
        greenMean = 0                   % Green LED background mean (V)
        greenAmp = 0                    % Green LED pulse amplitude (V)
        uvMean = 0                      % UV LED background mean (V)
        uvAmp = 0                       % UV LED pulse amplitude (V)
        
        onlineAnalysis = 'none'         % Online analysis type
        numberOfAverages = uint16(5)    % Number of epochs
        amp                             % Input amplifier
    end
    
    properties (Dependent, SetAccess = private)
        amp2                            % Secondary amplifier
    end
    
    properties (Hidden)
        ampType
        onlineAnalysisType = symphonyui.core.PropertyType('char', 'row',...
            {'none', 'extracellular', 'voltage_clamp', 'current_clamp', 'subthreshold'})
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
                s = cell(3, 1);
                s{1} = obj.createLedStimulus(obj.redMean, obj.redAmp,...
                    obj.redLed.background.displayUnits);
                s{2} = obj.createLedStimulus(obj.greenMean, obj.greenAmp,...
                    obj.greenLed.background.displayUnits);
                s{3} = obj.createLedStimulus(obj.uvMean, obj.uvAmp,...
                    obj.uvLed.background.displayUnits);
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
            
            % Add epoch stimuli
            epoch.addStimulus(obj.redLed,...
                obj.createLedStimulus(obj.redMean, obj.redAmp,...
                obj.redLed.background.displayUnits));
            epoch.addStimulus(obj.redLed,...
                obj.createLedStimulus(obj.greenMean, obj.greenAmp,...
                obj.greenLed.background.displayUnits));
            epoch.addStimulus(obj.redLed,...
                obj.createLedStimulus(obj.uvMean, obj.uvAmp,...
                obj.uvLed.background.displayUnits));
            
            % Add response
            epoch.addResponse(obj.rig.getDevice(obj.amp));
            if numel(obj.rig.getDeviceNames('Amp')) >= 2
                epoch.addResponse(obj.rig.getDevice(obj.amp2));
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