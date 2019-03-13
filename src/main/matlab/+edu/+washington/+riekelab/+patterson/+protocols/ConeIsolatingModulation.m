classdef ConeIsolatingModulation < edu.washington.riekelab.patterson.protocols.ConeIsolationProtocol
% CONEISOLATINGMODULATION
%
% Description:
%   Presents a cone-isolating sine or squarewave
%
% History:
%   21Feb2019 - SSP
%   11Mar2019 - SSP - Subclass ConeIsolationProtocol
% -------------------------------------------------------------------------

    properties       
        preTime = 500                   % Pulse leading duration (ms)
        stimTime = 1000                 % Pulse duration (ms)
        tailTime = 500                  % Pulse trailing duration (ms)
        temporalFrequency = 2           % Hz
        temporalClass = 'sinewave'      % Temporal modulation type
        
        sMeanIsom = 4000                % Mean for S-cones (isomerizations)
        mMeanIsom = 4000                % Mean for M-cones (isomerizations)
        lMeanIsom = 4000                % Mean for L-cones (isomerizations)
        
        lContrast = 0                   % L-cone contrast ([-1, 1])
        mContrast = 0                   % M-cone contrast ([-1, 1])
        sContrast = 0.5                 % S-cone contrast ([-1, 1])
        
        numberOfAverages = uint16(3)    % Number of epochs
        onlineAnalysis = 'none'         % Online analysis type
        
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
        temporalClassType = symphonyui.core.PropertyType('char', 'row',...
            {'sinewave', 'squarewave'})
    end
    
    properties (Hidden, Dependent)
        lmsMeanIsom
        lmsStdvIsom
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
            prepareRun@edu.washington.riekelab.patterson.protocols.ConeIsolationProtocol(obj);
            
            % Setup the analysis figures
            if numel(obj.rig.getDeviceNames('Amp')) < 2
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
            if strcmp(obj.temporalClass, 'sinewave')
                gen = edu.washington.riekelab.patterson.stimuli.SineGenerator();
            else
                gen = edu.washington.riekelab.patterson.stimuli.SquareGenerator();
            end
            gen.preTime = obj.preTime;
            gen.stimTime = obj.stimTime;
            gen.tailTime = obj.tailTime;
            gen.period = 1000/obj.temporalFrequency;
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
            
            % Create and check LED stimuli
            redStim = obj.createLedStimulus(rguMean(1), rguStdv(1),...
                obj.redLed.background.displayUnits);
            epoch.addParameter('redOutliers', obj.checkRange(redStim, obj.stimTime));
            greenStim = obj.createLedStimulus(rguMean(2), rguStdv(2),...
                obj.greenLed.background.displayUnits);
            epoch.addParameter('greenOutliers', obj.checkRange(greenStim, obj.stimTime));
            uvStim = obj.createLedStimulus(rguMean(3), rguStdv(3),... 
                obj.uvLed.background.displayUnits);
            epoch.addParameter('uvOutliers', obj.checkRange(uvStim, obj.stimTime));
            
            % Add LED stimuli to epoch
            epoch.addStimulus(obj.redLed, redStim);
            epoch.addStimulus(obj.greenLed, greenStim);
            epoch.addStimulus(obj.uvLed, uvStim);
            
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
        
        function value = get.lmsMeanIsom(obj)
            value = [obj.lMeanIsom; obj.mMeanIsom; obj.sMeanIsom];
        end
        
        function value = get.lmsStdvIsom(obj)
            value = obj.lmsMeanIsom .* [obj.lContrast, obj.mContrast, obj.sContrast]';
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