classdef ExpandingSpotsModulation < edu.washington.riekelab.protocols.RiekeLabStageProtocol
% EXPANDINGCONTRASTSPOTS
%
% Description:
%	Present series of contrast modulated spots with increasing sizes.
%
% See also:
%   ExpandingSpots
%
% History:
%	25Mar2019 - SSP
% -------------------------------------------------------------------------

    properties
        amp                             % Output amplifier
        preTime = 250                   % Spot leading duration (ms)
        stimTime = 2000                 % Spot duration (ms)
        tailTime = 1000                 % Spot trailing duration (ms)
        intensity = 1.0                 % Bar intensity (0-1)
        temporalFrequency = 2.0         % Modulation frequency (Hz)
        temporalClass = 'squarewave'    % Squarewave or pulse?
        spotSizes = [40 80 120 160 180 200 220 240 280 320 460 600] % um
        backgroundIntensity = 0.5       % Background light intensity (0-1)
        centerOffset = [0,0]            % Center offset in pixels (x,y) 
        onlineAnalysis = 'none'         % Online analysis type.
        numberOfAverages = uint16(13)   % Number of epochs
        interpulseInterval = 0          % Duration between spots (s)
    end

 	properties (Dependent, SetAccess = private)
 		amp2
 	end

 	properties (Hidden)
 		ampType
 		temporalClassType = symphonyui.core.PropertyType('char', 'row',... 
 			{'squarewave', 'sinewave'});
 		onlineAnalysisType = symphonyui.core.PropertyType('char', 'row',... 
 			{'none', 'extracellular', 'voltage_clamp', 'subthreshold'});
 		currentSpotSize
	end 

	methods
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
            
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end
        
        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
		
			rgb = edu.washington.riekelab.patterson.utils.multigradient(...
                'preset', 'div.cb.spectral.9', 'length', numel(obj.spotSizes));
            
            if numel(obj.rig.getDeviceNames('Amp')) < 2
                obj.showFigure('symphonyui.builtin.figures.ResponseFigure',...
                    obj.rig.getDevice(obj.amp));
                obj.showFigure('edu.washington.riekelab.patterson.figures.MeanResponseFigure',...
                    obj.rig.getDevice(obj.amp), 'groupBy', {'currentSpotSize'},...
                    'recordingType', obj.onlineAnalysis, 'sweepColor', rgb);
                if ~strcmp(obj.onlineAnalysis, 'none')
                    obj.showFigure('edu.washington.riekelab.patterson.figures.sMTFFigure', ...
                        obj.rig.getDevice(obj.amp), obj.preTime, obj.stimTime,...
                        'onlineAnalysis',obj.onlineAnalysis,...
                        'temporalType', obj.temporalClass,...
                        'spatialType', 'spot', ...
                        'xName', 'currentSpotSize', 'xaxis', unique(obj.spotSizes), ...
                        'temporalFrequency', obj.temporalFrequency);
                end
            else
                obj.showFigure('edu.washington.riekelab.figures.DualResponseFigure',...
                    obj.rig.getDevice(obj.amp), obj.rig.getDevice(obj.amp2));
            end
		end 

        function p = createPresentation(obj)
            device = obj.rig.getDevice('Stage');
            canvasSize = device.getCanvasSize();
            
            %convert from microns to pixels...
            spotDiameterPix = device.um2pix(obj.currentSpotSize);
            centerOffsetPix = device.um2pix(obj.centerOffset);
            
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            p.setBackgroundColor(obj.backgroundIntensity);

            % Create spot stimulus.            
            spot = stage.builtin.stimuli.Ellipse();
            spot.color = obj.intensity*obj.backgroundIntensity + obj.backgroundIntensity;
            spot.radiusX = spotDiameterPix/2;
            spot.radiusY = spotDiameterPix/2;
            spot.position = canvasSize/2 + centerOffsetPix;
            p.addStimulus(spot);
            
            % Control when the spot is visible.
            spotVisible = stage.builtin.controllers.PropertyController(spot, 'visible', ...
                @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);
            p.addController(spotVisible);

            % Control the spot contrast.
            if strcmp(obj.temporalClass, 'squarewave')
                spotColor = stage.builtin.controllers.PropertyController(spot, 'color', ...
                    @(state)getSpotSquarewave(obj, state.time - obj.preTime * 1e-3));
            else
                spotColor = stage.builtin.controllers.PropertyController(spot, 'color',...
                    @(state)getSpotSinewave(obj, state.time - obj.preTime * 1e-3));
            end
            p.addController(spotColor);

            function c = getSpotSquarewave(obj, time)       
                c = obj.intensity * sign(sin(obj.temporalFrequency*time*2*pi)) * ... 
                	obj.backgroundIntensity + obj.backgroundIntensity;
            end
            
            function c = getSpotSinewave(obj, time)
                c = obj.intensity * sin(obj.temporalFrequency*time*2*pi) * ...
                	obj.backgroundIntensity + obj.backgroundIntensity;
            end            
    	end

        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj, epoch);
            
            device = obj.rig.getDevice(obj.amp);
            duration = (obj.preTime + obj.stimTime + obj.tailTime) / 1e3;
            epoch.addDirectCurrentStimulus(device, device.background, duration, obj.sampleRate);
            epoch.addResponse(device);

            obj.currentSpotSize = obj.spotSizes(obj.numEpochsPrepared + 1);
            epoch.addParameter('currentSpotSize', obj.currentSpotSize);
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