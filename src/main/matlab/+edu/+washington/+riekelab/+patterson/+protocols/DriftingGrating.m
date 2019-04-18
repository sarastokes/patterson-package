classdef DriftingGrating < edu.washington.riekelab.protocols.RiekeLabStageProtocol
    
    properties
        amp
        preTime = 250
        waitTime = 1000
        stimTime = 4000
        tailTime = 500
        contrast = 1
        temporalFrequency = 2
        temporalClass = 'drifting'
        spatialClass = 'sinewave'
        orientation = 0
        spatialFreqs = 10.^(-0.301:0.301/3:1.4047)        % Spatial frequency (cyc/short axis of screen)
        spatialPhase = 0
        backgroundIntensity = 0.5
        onlineAnalysis = 'none'
        numberOfAverages = uint16(18)
        randomOrder = false
        interpulseInterval = 0
    end
    
    properties (Hidden)
        ampType
        spatialClassType = symphonyui.core.PropertyType('char', 'row',...
            {'sinewave', 'squarewave'})
        temporalClassType = symphonyui.core.PropertyType('char', 'row',...
            {'drifting', 'reversing'})
        onlineAnalysisType = symphonyui.core.PropertyType('char', 'row',...
            {'none', 'extracellular', 'voltage_clamp', 'subthreshold'});
        rawImage
        params
        spatialFreq
        spatialPhaseRad
    end
    
    methods
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
            
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end
        
        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
            
            % Calculate the spatial phase in radians.
            obj.spatialPhaseRad = obj.spatialPhase / 180 * pi;
            
            obj.organizeParameters();
            
            rgb = edu.washington.riekelab.patterson.utils.multigradient(...
                'preset', 'div.cb.spectral.9', 'length', numel(obj.spatialFreqs));
            
            obj.showFigure('symphonyui.builtin.figures.ResponseFigure',...
                obj.rig.getDevice(obj.amp));
            obj.showFigure('edu.washington.riekelab.patterson.figures.MeanResponseFigure',...
                obj.rig.getDevice(obj.amp), 'groupBy', {'spatialFreq'},...
                'recordingType', obj.onlineAnalysis, 'sweepColor', rgb);
            if ~strcmp(obj.onlineAnalysis, 'none')
                obj.showFigure('edu.washington.riekelab.patterson.figures.F1F2Figure',...
                    obj.rig.getDevice(obj.amp), obj.spatialFreqs, obj.onlineAnalysis,...
                    obj.preTime, obj.stimTime, 'waitTime', obj.waitTime,...
                    'temporalFrequency', obj.temporalFrequency,...
                    'xName', 'spatialFreq', 'showF2', false);
            end
        end
        
        function p = createPresentation(obj)
            device = obj.rig.getDevice('Stage');
            canvasSize = device.getCanvasSize();
            
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            p.setBackgroundColor(obj.backgroundIntensity);
            
            % Create the grating.
            grate = stage.builtin.stimuli.Image(uint8(0 * obj.rawImage));
            grate.position = canvasSize / 2;
            grate.size = ceil(sqrt(canvasSize(1)^2 + canvasSize(2)^2))*ones(1,2);
            grate.orientation = obj.orientation;
            grate.setMinFunction(GL.NEAREST);
            grate.setMagFunction(GL.NEAREST);
            p.addStimulus(grate);
            
            % Make the grating visible only during the stimulus time.
            grateVisible = stage.builtin.controllers.PropertyController(grate, 'visible', ...
                @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);
            p.addController(grateVisible);
            
            %--------------------------------------------------------------
            % Generate the grating.
            if strcmp(obj.temporalClass, 'drifting')
                imgController = stage.builtin.controllers.PropertyController(grate, 'imageMatrix',...
                    @(state)setDriftingGrating(obj, state.time - (obj.preTime + obj.waitTime) * 1e-3));
            else
                imgController = stage.builtin.controllers.PropertyController(grate, 'imageMatrix',...
                    @(state)setReversingGrating(obj, state.time - (obj.preTime + obj.waitTime) * 1e-3));
            end
            p.addController(imgController);
            
            
            % Set the drifting grating.
            function g = setDriftingGrating(obj, time)
                if time >= 0
                    phase = obj.temporalFrequency * time * 2 * pi;
                else
                    phase = 0;
                end
                
                g = cos(obj.spatialPhaseRad + phase + obj.rawImage);
                
                if strcmp(obj.spatialClass, 'squarewave')
                    g = sign(g);
                end
                
                g = obj.contrast * g;
                g = uint8(255*(obj.backgroundIntensity * g + obj.backgroundIntensity));
            end
            
            % Set the reversing grating
            function g = setReversingGrating(obj, time)
                if time >= 0
                    phase = round(0.5 * sin(time * 2 * pi * obj.temporalFrequency) + 0.5) * pi;
                else
                    phase = 0;
                end
                
                g = cos(obj.spatialPhaseRad + phase + obj.rawImage);
                
                if strcmp(obj.spatialClass, 'squarewave')
                    g = sign(g);
                end
                
                g = obj.contrast * g;
                
                g = uint8(255*(obj.backgroundIntensity * g + obj.backgroundIntensity));
            end
        end
        
        function setRawImage(obj)
            
            device = obj.rig.getDevice('Stage');
            canvasSize = device.getCanvasSize();
            downsamp = 3;
            sz = ceil(sqrt(canvasSize(1)^2 + canvasSize(2)^2));
            [x,y] = meshgrid(...
                linspace(-sz/2, sz/2, sz/downsamp), ...
                linspace(-sz/2, sz/2, sz/downsamp));
            
            % Center the stimulus.
            % x = x + obj.um2pix(obj.centerOffset(1));
            % y = y + obj.um2pix(obj.centerOffset(2));
            
            x = x / min(canvasSize) * 2 * pi;
            y = y / min(canvasSize) * 2 * pi;
            
            % Calculate the raw grating image.
            img = (cos(0)*x + sin(0) * y) * obj.spatialFreq;
            obj.rawImage = img(1,:);
            
            obj.rawImage = repmat(obj.rawImage, [1 1 3]);
            
        end
        
        function organizeParameters(obj)
            
            % Create the matrix of bar positions.
            numReps = ceil(double(obj.numberOfAverages) / length(obj.spatialFreqs));
            
            % Get the array of spatial frequencies
            freqs = obj.spatialFreqs(:) * ones(1, numReps);
            freqs = freqs(:)';
            
            % Deal with the parameter order if it is random order.
            if ( obj.randomOrder )
                epochSyntax = randperm( obj.numberOfAverages );
            else
                epochSyntax = 1 : obj.numberOfAverages;
            end
            
            % Copy the radii in the correct order.
            freqs = freqs( epochSyntax );
            
            % Copy to spatial frequencies.
            obj.params.spatialFrequencies = freqs;
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj, epoch);
            
            device = obj.rig.getDevice(obj.amp);
            duration = (obj.preTime + obj.stimTime + obj.tailTime) / 1e3;
            epoch.addDirectCurrentStimulus(device, device.background, duration, obj.sampleRate);
            epoch.addResponse(device);
            
            % Set the current spatial frequency.
            obj.spatialFreq = obj.params.spatialFrequencies(obj.numEpochsCompleted+1);
            
            % Set up the raw image.
            obj.setRawImage();
            
            % Add the spatial frequency to the epoch.
            epoch.addParameter('spatialFreq', obj.spatialFreq);
        end
        
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numberOfAverages;
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numberOfAverages;
        end
        
    end
end