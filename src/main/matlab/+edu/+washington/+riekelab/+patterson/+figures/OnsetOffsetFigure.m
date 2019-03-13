classdef OnsetOffsetFigure < symphonyui.core.FigureHandler
% ONSETOFFSETFIGURE
%
% Description:
%	Plots spike count or charge during onset and offset of a stimulus
%
% History:
%	10Mar2019 - SSP
% -------------------------------------------------------------------------

	properties (SetAccess = private)
		device
		preTime
		stimTime
		xRange

		xName
		recordingType
	end

	properties (Hidden, Access = private)
		axesHandle
		allOnset
		allOffset
		avgOnset 
		avgOffset 
	end

	properties (Hidden, Constant)
		ON_RGB = [0, 0.8, 0.3];
		OFF_RGB = [1, 0.25, 0.25];
	end

	methods
		function obj = OnsetOffsetFigure(device, preTime, stimTime, xRange, varargin)
			obj.device = device;
			obj.preTime = preTime;
			obj.stimTime = stimTime;
			obj.xRange = xRange;

			ip = inputParser();
			ip.CaseSensitive = false;
			addParameter(ip, 'recordingType', 'extracellular', @ischar);
			addParameter(ip, 'xName', [], @isvector);
			parse(ip, varargin{:});

			obj.recordingType = ip.Results.recordingType;
			obj.xName = ip.Results.xName;

			% obj.countByX = zeros(size(unique(xRange)));
			% obj.onsetByX = zeros(size(obj.countByX));
			% obj.offsetByX = zeros(size(obj.countByX));

			obj.createUi();
		end

		function createUi(obj)
			import appbox.*;

			set(obj.figureHandle,...
				'Name', 'OnsetOffsetFigure',...
				'Color', 'w');

			toolbar = findall(obj.figureHandle, 'Type', 'uitoolbar');
            captureFigureButton = uipushtool(...
                'Parent', toolbar,...
                'TooltipString', 'Store Sweep',...
                'Separator', 'on',...
                'ClickedCallback', @obj.onSelectedCaptureFigure);
            iconDir = [fileparts(fileparts(mfilename('fullpath'))), '\+icons\'];
            setIconImage(captureFigureButton, [iconDir, 'save_image.png']);

			obj.axesHandle = axes('Parent', obj.figureHandle,...
                'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'),...
                'FontSize', get(obj.figureHandle, 'DefaultLegendFontSize'),...
                'XTickMode', 'auto');
			xlim(obj.axesHandle, [min(obj.xRange), max(obj.xRange)]);
            
            if ~isempty(obj.xName)
                xlabel(obj.axesHandle, obj.xName);
            end
	        switch obj.recordingType
		        case {'extracellular', 'current_clamp'}
	                ylabel(obj.axesHandle,'Spike count')
	            otherwise
	                ylabel(obj.axesHandle,'Charge transfer (pC)')
	        end

		end

		function clear(obj)
            cla(obj.axesHandle);
            obj.avgOnset = []; obj.avgOffset = []; 
            obj.allOnset = []; obj.allOffset = [];
            obj.dataTable = [];
        end

        function setTitle(obj, t)
            set(obj.figureHandle, 'Name', t);
            title(obj.axesHandle, t);
        end

		function handleEpoch(obj, epoch)
            if ~epoch.hasResponse(obj.device)
                error(['Epoch does not contain a response for ' obj.device.name]);
            end
            
			response = epoch.getResponse(obj.device);
            responseTrace = response.getData();
            sampleRate = response.sampleRate.quantityInBaseUnits;
            
            prePts = obj.preTime * 1e-3 * sampleRate;
            stimPts = obj.stimTime * 1e-3 * sampleRate;

            if strcmp(obj.onlineAnalysis,'extracellular')
                S = edu.washington.riekelab.patterson.utils.spikeDetectorOnline(responseTrace);
                spikeResponse = S.sp;
                onset = nnz(spikeResponse(prePts+1:prePts+stimPts)); 
                offset = nnz(spikeResponse(prePts+stimPts+1:end));
            else
            	responseTrace = responseTrace - mean(responseTrace(1:prePts));
            	onResponse = responseTrace(prePts+1:prePts+stimPts);
            	offResponse = responseTrace(prePts+stimPts+1:end);

            	if strcmp(obj.recordingType, 'inh')
                    chargeMult = 1;
                else % Not great but assume exc
                    chargeMult = -1;
                end
                onset = chargeMult * trapz(onResponse/sampleRate);
                offset = chargeMult * trapz(offResponse/sampleRate);
            end

            % Epoch x-value
            if isempty(obj.xName)
                xValue = obj.xRange(obj.epochNum);
                % xIndex = obj.epochNum;
            else
                xValue = epoch.parameters(obj.xName);
                % xIndex = obj.xvals == xValue;
            end
            % obj.countByX(xIndex) = obj.countByX(xIndex) + 1;

            if isempty(obj.dataTable)
            	obj.dataTable = table([xValue, onset, offset],...
            		'PropertyNames', {'X', 'Onset', 'Offset'});
            else
            	obj.dataTable = [obj.dataTable; table(xValue, onset, offset)];
            end

            [groupIndex, groupNames] = findgroups(obj.dataTable.X);
            avgOnset = splitapply(@mean, obj.dataTable.Onset, groupIndex);
            avgOffset = splitapply(@mean, obj.dataTable.Offset, groupIndex);

            % Update plots
            if isempty(obj.allOnset)
            	% If missing one, prob missing all...
            	obj.allOnset = line(obj.dataTable.X, obj.dataTable.Onset,... 
            		'Parent', obj.axesHandle,...
            		'Marker', '.', 'MarkerSize', 16,...
            		'Color', lighten(obj.ON_RGB, 0.5), 'LineStyle', 'none');
            else
            	set(obj.allOnset,... 
            		'XData', obj.dataTable.X, 'YData', obj.dataTable.Onset);
            end
            if isempty(obj.allOffset)
            	obj.allOffset = line(obj.dataTable.X, obj.dataTable.Offset,... 
            		'Parent', obj.axesHandle,...
            		'Marker', '.', 'MarkerSize', 16,...
            		'Color', lighten(obj.OFF_RGB, 0.5), 'LineStyle', 'none');
            else
            	set(obj.allOffset,...
            		'XData', obj.dataTable.X, 'YData', obj.dataTable.Offset);
            end
            % Average 
            if isempty(obj.avgOnset)
            	obj.avgOnset = line(groupNames, avgOnset,... 
            		'Parent', obj.axesHandle,...
            		'Marker', 'o', 'Color', obj.ON_RGB, 'LineWidth', 1.5);
            else
            	set(obj.avgOffset, 'XData', groupNames, 'YData', avgOnset);
            end
            if isempty(obj.avgOffset)
            	obj.avgOffset = line(groupNames, avgOffset,... 
            		'Parent', obj.axesHandle,...
            		'Marker', 'o', 'Color', obj.OFF_RGB, 'LineWidth', 1.5);
            else  	
            	set(obj.avgOffset, 'XData', groupNames, 'YData', avgOffset);
            end
		end
	end
end