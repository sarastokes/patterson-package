classdef F1Figure < symphonyui.core.FigureHandler

	properties (SetAccess = private)
		device
		% Required
		stimTime
		xName

		% Optional
		preTime
		onlineAnalysis
		waitTime
		temporalFrequency
	end

	properties (Access = private)
		axHandle
		plotColors
		F1Sweep
		P1Sweep
		rawSweep
	end

	properties (Hidden, Constant = true)
		BIN_RATE = 60;
	end

	methods
		function obj = F1Figure(device, xName, onlineAnalysis, stimTime, varargin)
			obj.device = device;
			obj.xName = xName;

			obj.onlineAnalysis = onlineAnalysis;
			obj.preTime = preTime;
			obj.stimTime = stimTime;

			ip = inputParser();
			addParameter(ip, 'onlineAnalysis', 'extracellular', @(x)ischar(x));
			addParameter(ip, 'preTime', 0, @(x)isnumeric(x));
			addParameter(ip, 'waitTime', 0, @(x)isnumeric(x));
			addParameter(ip, 'plotColor', [0 0 0], @(x)isvector(x));
			addParameter(ip, 'temporalFrequency', [], @isnumeric);
			addParameter(ip, 'titlestr', [], @(x)ischar(x));
			parse(ip, varargin{:});

			obj.waitTime = ip.Results.waitTime;
			obj.plotColors = [ip.Results.plotColor; lighten(ip.Results.plotColor)];

			obj.createUi();

			if ~isempty(titlestr)
				obj.setTitle(obj.titlestr);
			end
		end

        function setTitle(obj, t)
            set(obj.figureHandle, 'Name', t);
            title(obj.axHandle(1), t);
        end

        function clear(obj)
        	cla(obj.axHandle(1)); cla(obj.axHandle(2));
        	obj.T = [];
        end

		function createUi(obj)
			import appbox.*;

			set(obj.figureHandle,...
				'Name', 'F1 Figure',...
				'Color', 'w');

			toolbar = findall(obj.figureHandle, 'Type', 'uitoolbar');
			
			storeDataButton = uipushtool(toolbar,...
				'TooltipString', 'Store data',...
				'Separator', 'on',...
				'ClickedCallback', @obj.onSelectedStoreData);

			obj.axHandle(1) = subplot(3, 1, 1:2,...
				'Parent', obj.figureHandle,...
				'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'),...
				'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'),...
				'XTickMode', 'auto',...
				'Tag', 'F1Axis');
			ylabel(obj.axHandle(1), 'F1 amplitude (spikes/sec)');

			obj.axHandle(2) = subplot(4, 1, 4,...
				'Parent', obj.figureHandle,...
				'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'),...
				'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'),...
				'XTickMode', 'auto',...
				'Tag', 'P1Axis');
			ylabel(obj.axHandle(2), 'Phase (deg)');

		end

		function handleEpoch(obj, epoch)
			% Process the response
			if ~epoch.hasResponse(obj.device)
				error(['Epoch does not contain a response for ', obj.device.name]);
			end

			response = epoch.getResponse(obj.device);
			responseTrace = response.getData();
			sampleRate = response.sampleRate.quantityInBaseUnits;

			[epochF1, epochP1] = obj.analyze(responseTrace, sampleRate);

			% Add F1 amplitude and xdata to table
			xVal = epoch.parameter(obj.xName);

			if isempty(obj.T)
				obj.T = table({epochF1, epochP1, xVal, false});
				obj.T.Properties.VariableNames = {'F1', 'P1', 'X', 'Omit'};
			else
				obj.T = [obj.T; {epochF1, epochP1, xVal, false}];
			end

			% Calculate mean
			[groups, x] = findgroups(obj.T.xVal);
			F1mean = splitapply(@mean, obj.T.F1, groups);
			P1mean = splitapply(@mean, obj.T.P1, groups);

			% Update the graph
			if isempty(obj.F1Sweep)
				obj.F1Sweep = line(obj.axHandle(1), x, F1mean,...
					'Color', obj.plotColor(1, :),...
					'LineWidth', 1.5,...
					'Marker', 'o',...
					'Tag', 'F1Line');
				hold(obj.axHandle(1), 'on');
				obj.rawSweep = line(obj.axHandle(1), obj.T.xVal, obj.T.F1,...
					'Color', obj.plotColor(2, :),...
					'LineStyle', 'none',...
					'Marker', 'o',...
					'Tag', 'RawData');
				hold(obj.axHandle(1), 'off');
			else
				set(obj.F1Sweep, 'XData', x, 'YData', F1mean);
				set(obj.rawSweep, 'XData', obj.T.xVal, 'YData', obj.T.F1);
			end

			if isempty(obj.P1Sweep)
				obj.P1Sweep = line(obj.axHandle(2), x, P1mean,...
					'Color', obj.plotColor(1, :),...
					'LineWidth', 1.5,...
					'Marker', 'o',...
					'Tag', 'P1Line');
			else
				set(obj.P1Sweep, 'XData', x, 'YData', P1mean);
			end

			axis([obj.axHandle(1), obj.axHandle(2)], 'tight');
		end
	end

	% Analysis methods
	methods (Access = private)

		function [F1, P1] = analyze(obj, responseTrace, sampleRate)
			responseTrace = edu.washington.riekelab.sara.util.processData(...
                responseTrace, obj.onlineAnalysis,...
                'preTime', obj.preTime, 'sampleRate', sampleRate);

			% Calc F1 amplitude
			responseTrace = responseTrace((obj.preTime+obj.waitTime)/1000*sampleRate+1 : end);
            binWidth = sampleRate / obj.BINRATE; % Bin at 60 Hz.
            numBins = floor((obj.stimTime-obj.waitTime)/1000 * obj.BINRATE);
            binData = zeros(1, numBins);
            for k = 1 : numBins
                index = round((k-1)*binWidth+1 : k*binWidth);
                binData(k) = mean(responseTrace(index));
            end
            binsPerCycle = obj.BINRATE / tempFreq;
            numCycles = floor(length(binData)/binsPerCycle);

            if numCycles == 0
                error('Make sure stimTime is greater than 1 cycle');
            end
            cycleData = zeros(1, floor(binsPerCycle));
            for k = 1 : numCycles
                index = round((k-1)*binsPerCycle) + (1 : floor(binsPerCycle));
                cycleData = cycleData + binData(index);
            end
            cycleData = cycleData / k;

            ft = fft(cycleData);
            F1 = abs(ft(2))/length(ft)*2;
            P1 = angle(ft(2)) * 180/pi;
		end
	end

	% Callback methods
    methods (Access = private)
        function onSelectedSendSweep(obj, ~, ~)
            outputStruct.F1 = obj.F1;
            outputStruct.F2 = obj.P1;
            answer = inputdlg('Save to workspace as:', 'save dialog', 1, {'r'});
            fprintf('%s new F1 data named %s\n', datestr(now), answer{1});
            assignin('base', sprintf('%s', answer{1}), outputStruct);
        end
        
        function onSelectedSwitchAxis(obj,~,~)
            % haven't debugged yet
            if strcmp(get(obj.axesHandle(1), 'YScale'), 'log');
                set(findobj(obj.figureHandle, 'Type', 'axes'),...
                    'YScale', 'linear')
            else
                set(findobj(obj.figureHandle, 'Type', 'axes'),...
                    'YScale', 'log');
            end
        end
	end
end