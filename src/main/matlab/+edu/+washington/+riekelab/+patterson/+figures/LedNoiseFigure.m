classdef LedNoiseFigure < symphonyui.core.FigureHandler
    % LEDNOISEFIGURE
    %
    % Description:
    %   Linear-nonlinear analysis for continuous stimuli
    %
    % Todo:
    %   Maybe merge with LinearFilterFigure?
    %
    % History:
    %   26Feb2019 - SSP
    % ---------------------------------------------------------------------
    
    properties (SetAccess = private)
        device
        led
        stimTime
        preTime
        adaptTime
        recordingType
        frequencyCutoff
        filterColor
        groupName
        figureTitle
    end
    
    properties
        axesHandle
        allResponses
        allStimuli
        linearFilter
        epochNum
    end
    
    properties (Constant, Hidden)
        BIN_RATE = 480;
        ADAPT_TIME = 250;
        FILTER_LEN = 500;
        
        DEBUG = false;
    end
    
    methods
        function obj = LedNoiseFigure(device, led, stimTime, varargin)
            obj.device = device;
            obj.led = led;
            obj.stimTime = stimTime;
            disp('not debugging');
            
            ip = inputParser();
            ip.CaseSensitive = false;
            addParameter(ip, 'recordingType', [], @ischar);
            addParameter(ip, 'preTime', 0, @isnumeric);
            addParameter(ip, 'adaptTime', obj.ADAPT_TIME, @isnumeric);
            addParameter(ip, 'filterColor', [0, 0, 0], @(x) ischar(x) || isvector(x));
            addParameter(ip, 'frequencyCutoff', 60, @isnumeric);
            addParameter(ip, 'figureTitle', 'Linear-Nonlinear Analysis', @ischar);
            addParameter(ip, 'groupName', 1, @isnumeric);
            parse(ip, varargin{:});
            obj.recordingType = ip.Results.recordingType;
            obj.preTime = ip.Results.preTime;
            obj.adaptTime = ip.Results.adaptTime;
            obj.figureTitle = ip.Results.figureTitle;
            obj.groupName = ip.Results.groupName;
            obj.frequencyCutoff = ip.Results.frequencyCutoff;
            obj.filterColor = ip.Results.filterColor;
            
            obj.allResponses = [];
            obj.allStimuli = [];
            
            obj.epochNum = 0;
            
            obj.createUi();
        end
        
        function createUi(obj)
            import appbox.*;
            iconDir = [fileparts(fileparts(mfilename('fullpath'))), '\+icons\'];
            %set(obj.figureHandle, 'DefaultUicontrolFontSize', 10);
            
            toolbar = findall(obj.figureHandle, 'Type', 'uitoolbar');
            plotNLButton = uipushtool(toolbar,...
                'TooltipString', 'Plot nonlinearity',...
                'Separator', 'on',...
                'ClickedCallback', @obj.onSelectedFitLN);
            setIconImage(plotNLButton, [iconDir, 'scatter.gif']);
            
            captureFigureButton = uipushtool(...
                'Parent', toolbar,...
                'TooltipString', 'Capture Figure',...
                'ClickedCallback', @obj.onSelectedCaptureFigure);
            setIconImage(captureFigureButton, [iconDir, 'picture.gif']);
            
            obj.axesHandle(1) = subplot(1,3,1:2,...
                'Parent',obj.figureHandle,...
                'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'),...
                'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'), ...
                'XTickMode', 'auto');
            xlabel(obj.axesHandle(1), 'Time (ms)');
            ylabel(obj.axesHandle(1), 'Amp.');
            
            obj.axesHandle(2) = subplot(1,3,3,...
                'Parent',obj.figureHandle,...
                'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'),...
                'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'), ...
                'XTickMode', 'auto');
            xlabel(obj.axesHandle(2), 'Linear prediction');
            ylabel(obj.axesHandle(2), 'Measured');
            axis(obj.axesHandle(2), 'square');
            
            set(obj.figureHandle, 'Name', obj.figureTitle);
        end
        
        function handleEpoch(obj, epoch)
            assignin('base', 'obj', struct(obj));
            assignin('base', 'epoch', epoch);
            
            obj.epochNum = obj.epochNum + 1;
            if obj.DEBUG
                S = load('LedNoiseData.mat');
                S = S.LedNoiseData;
                sampleRate = S.params.sampleRate;
                
                prePts = S.params.preTime * sampleRate/1e3;
                stimPts = S.params.stimTime * sampleRate/1e3;
                adaptPts = obj.ADAPT_TIME * sampleRate/1e3;
                
                response = S.resp(obj.epochNum, :);
                response = edu.washington.riekelab.patterson.utils.processData(...
                    response, obj.recordingType, 'PreTime', obj.preTime);
            else
                response = epoch.getResponse(obj.device);
                response = response.getData();
                sampleRate = 10000;
                
                response = edu.washington.riekelab.patterson.utils.processData(...
                    response, obj.recordingType, 'PreTime', obj.preTime);
                
                prePts = obj.preTime * sampleRate/1e3;
                stimPts = obj.stimTime * sampleRate/1e3;
                adaptPts = obj.adaptTime * sampleRate/1e3;
            end
            
            % Trim the response
            response = response(prePts + adaptPts + 1:prePts + stimPts);
            
            % Downsample the response
            if ismember(obj.recordingType, {'extracellular', 'current_clamp'})
                response = edu.washington.riekelab.patterson.utils.binSpikeRate(...
                    response, obj.BIN_RATE, sampleRate)';
            else
                response = edu.washington.riekelab.patterson.utils.binData(...
                    response, obj.BIN_RATE, sampleRate);
            end
            
            % Get the stimulus
            if obj.DEBUG
                stimulus = S.stim(obj.epochNum, :);
            else
                stimulus = epoch.getStimulus(obj.led).getData();
            end
            stimulus = stimulus(prePts + adaptPts + 1:prePts + stimPts);
            stimulus = edu.washington.riekelab.patterson.utils.binData(...
                stimulus, obj.BIN_RATE, sampleRate);
            
            obj.allResponses = cat(1, obj.allResponses, response);
            obj.allStimuli = cat(1, obj.allStimuli, stimulus);
            
            % Calculate linear filter
            newFilter = edu.washington.riekelab.patterson.utils.getLinearFilterOnline(...
                obj.allStimuli, obj.allResponses, obj.BIN_RATE, obj.frequencyCutoff);
            newFilter = newFilter / max(abs(newFilter));
            
            filterPts = (obj.FILTER_LEN/1000)*obj.BIN_RATE;
            filterTimes = linspace(0, obj.FILTER_LEN, filterPts);
            
            h = findobj(obj.figureHandle, 'Tag', 'LinearFilter');
            if isempty(h)
                line(filterTimes, newFilter(1:filterPts),...
                    'Parent', obj.axesHandle(1),...
                    'Color', [0, 0, 0.2], 'LineWidth', 1.25,...
                    'Tag', 'LinearFilter');
            else
                set(h, 'YData', newFilter(1:filterPts));
            end
            
            obj.linearFilter = newFilter;
        end
    end
    
    methods (Access = private)
        function onSelectedFitLN(obj, ~, ~)
            if isempty(obj.allResponses)
                return;
            end
            
            measuredResponse = reshape(obj.allResponses', 1, numel(obj.allResponses));
            stimulusArray = reshape(obj.allStimuli', 1, numel(obj.allStimuli));
            
            linearPrediction = conv(stimulusArray, obj.linearFilter);
            linearPrediction = linearPrediction(1:length(stimulusArray));
            [~, edges, bins] = histcounts(linearPrediction,...
                'BinMethod', 'auto');
            binCenters = edges(1:end-1) + diff(edges);
            
            binnedResponse = zeros(size(binCenters));
            for i = 1:length(binCenters)
                binnedResponse(i) = mean(measuredResponse(bins == i));
            end
            
            h = findobj(obj.figureHandle, 'Tag', 'Nonlinearity');
            if isempty(h)
                line(binCenters, binnedResponse,...
                    'Parent', obj.axesHandle(2),...
                    'Marker', 'o', 'Color', [0, 0, 0.2],...
                    'MarkerSize', 5, 'LineStyle', 'none',...
                    'Tag', 'Nonlinearity');
            else
                set(h, 'XData', binCenters, 'YData', binnedResponse);
            end
        end
        
        function onSelectedCaptureFigure(obj, ~, ~)
            [fileName, pathName] = uiputfile('bar.png', 'Save result as');
            if ~ischar(fileName) || ~ischar(pathName)
                return;
            end
            print(obj.figureHandle, [pathName, fileName], '-dpng', '-r600');
        end
    end
    
end