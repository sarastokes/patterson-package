classdef ConeContrastSteps < edu.washington.riekelab.patterson.protocols.ConeIsolationProtocol
% CONECONTRASTSTEPS
%
% Description:
%   Series of cone-isolating pulses at positive and negative contrasts
%
% History:
%   13Mar2019 - SSP
% -------------------------------------------------------------------------
    
    properties
        led                             % Output LED
        preTime = 500                   % Pulse leading duration (ms)
        stimTime = 500                  % Pulse duration (ms)
        tailTime = 500                  % Pulse trailing duration (ms)
        lMeanIsom = 4000
        mMeanIsom = 4000
        sMeanIsom = 4000
        lContrast = false
        mContrast = false
        sContrast = true
        contrasts = [-85 -75 -50 -25 -10 10 25 50 75 85] % in percent
        numberOfAverages = uint16(50)    % Number of epochs
        onlineAnalysis = 'extracellular'    % Online analysis type
        interpulseInterval = 0          % Duration between pulses (s)
        amp                             % Input amplifier
    end
    
    properties (Dependent, SetAccess = private)
        amp2                            % Secondary input amplifier
    end
    
    properties (Hidden)
        ledType
        ampType
        contrastsType = symphonyui.core.PropertyType('denserealdouble', 'matrix')
        onlineAnalysisType = symphonyui.core.PropertyType('char', 'row',...
            {'none', 'extracellular', 'exc', 'inh'})
    end
    
    properties (Hidden, Dependent)
        totalEpochs
        numContrasts
        lmsMeanIsom
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
            p = edu.washington.riekelab.patterson.previews.ConeStimuliPreview(...
                panel, @()createPreviewStimuli(obj), obj.rguToLms);
            
            function s = createPreviewStimuli(obj)
                rguMean = obj.lmsToRgu * obj.lmsMeanIsom;
                rguContrast = obj.lmsToRgu * obj.determineLmsContrast(obj.determineContrast(1));
                disp(rguMean)
                disp(rguContrast)
                
                ledList = [obj.redLed, obj.greenLed, obj.uvLed];
                
                s = cell(3, 1);
                for i = 1:3
                    s{i} = obj.createLedStimulus(rguMean(i), rguContrast(i),...
                        ledList(i).background.displayUnits);
                end
            end
        end
        
        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.patterson.protocols.ConeIsolationProtocol(obj);
            if length(obj.contrasts) > 1
                rgb = edu.washington.riekelab.patterson.utils.othercolor(...
                    'RdYlGn9', length(obj.contrasts));
            else
                rgb = [0 0 0];
            end
            
            if numel(obj.rig.getDeviceNames('Amp')) < 2
                obj.showFigure('edu.washington.riekelab.patterson.figures.MeanResponseFigure',... 
                    obj.rig.getDevice(obj.amp), 'groupBy', {'Contrast'},... 
                    'recordingType', obj.onlineAnalysis, 'sweepColor', rgb);
                
                if ~strcmp(obj.onlineAnalysis, 'none')
                    obj.showFigure('edu.washington.riekelab.patterson.figures.OnsetOffsetFigure',...
                        obj.rig.getDevice(obj.amp), obj.preTime, obj.stimTime,...
                        obj.contrasts, 'recordingType', obj.onlineAnalysis,...
                        'xName', 'contrast');
                end
        
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
        
        function idx = determineContrastIdx(obj, epochNum)
            idx = mod(epochNum - 1, obj.numContrasts) + 1;
        end
        
        function contr = determineContrast(obj, epochNum)
            contr = obj.contrasts(obj.determineContrastIdx(epochNum)) / 100;
        end
        
        function lmsContrast = determineLmsContrast(obj, contr)
            lms = contr * [obj.lContrast, obj.mContrast, obj.sContrast];
            lmsContrast = obj.lmsMeanIsom .* lms';
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, epoch);

            epochNum = obj.numEpochsPrepared;
            epochContrast = obj.determineContrast(epochNum);
            epoch.addParameter('contrast', epochContrast);
            
            rguMean = obj.lmsToRgu * obj.lmsMeanIsom;
            rguContrast = obj.lmsToRgu * obj.determineLmsContrast(epochContrast);
            
            % Epoch parameters
            epoch.addParameter('lMean', rguMean(1));
            epoch.addParameter('mMean', rguMean(2));
            epoch.addParameter('sMean', rguMean(3));
            epoch.addParameter('lContrast', rguContrast(1));
            epoch.addParameter('mContrast', rguContrast(2));
            epoch.addParameter('sContrast', rguContrast(3));
            
            % Epoch LED stimuli
            epoch.addStimulus(obj.redLed,...
                obj.createLedStimulus(rguMean(1), rguContrast(1),...
                obj.redLed.background.displayUnits));
            epoch.addStimulus(obj.greenLed,...
                obj.createLedStimulus(rguMean(2), rguContrast(2),...
                obj.greenLed.background.displayUnits));
            epoch.addStimulus(obj.uvLed,...
                obj.createLedStimulus(rguMean(3), rguContrast(3),... 
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
        
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.totalEpochs;
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.totalEpochs;
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
        
        function value = get.lmsMeanIsom(obj)
            value = [obj.lMeanIsom; obj.mMeanIsom; obj.sMeanIsom];
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

