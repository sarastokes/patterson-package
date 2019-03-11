classdef SwitchingNoiseFigure < symphonyui.core.FigureHandler
    % LEDNOISEFIGURE
    %
    % Description:
    %   Linear-nonlinear analysis for continuous stimuli switching between
    %   two stimulus conditions
    %
    % Todo:
    %   Maybe merge LedNoiseFigure?
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
        allResponsesOne
        allStimuliOne
        allResponsesTwo
        allStimuliTwo
        linearFilterOne
        linearFilterTwo
        epochNum
    end
    
    properties (Constant, Hidden)
        BIN_RATE = 480;
        ADAPT_TIME = 250;
        FILTER_LEN = 500;
        
        DEBUG = true;
    end
    
    methods
        function obj = SwitchingNoiseFigure(device, led, stimTime, groupName, varargin)
            obj.device = device;
            obj.led = led;
            obj.stimTime = stimTime;
            obj.groupName = groupName;
            
            ip = inputParser();
            ip.CaseSensitive = false;
            addParameter(ip, 'recordingType', [], @ischar);
            addParameter(ip, 'preTime', 0, @isnumeric);
            addParameter(ip, 'adaptTime', obj.ADAPT_TIME, @isnumeric);
            addParameter(ip, 'filterColor', [], @(x) ischar(x) || ismatrix(x));
            addParameter(ip, 'frequencyCutoff', 60, @isnumeric);
            addParameter(ip, 'figureTitle', 'Linear-Nonlinear Analysis', @ischar);
            parse(ip, varargin{:});
            obj.recordingType = ip.Results.recordingType;
            obj.preTime = ip.Results.preTime;
            obj.adaptTime = ip.Results.adaptTime;
            obj.figureTitle = ip.Results.figureTitle;
            obj.frequencyCutoff = ip.Results.frequencyCutoff;
            if isempty(ip.Results.filterColor)
                obj.filterColor = edu.washington.riekelab.patterson.utils.multigradient(...
                    'preset', 'div.cb.spectral.9', 'length', 2);
            else
                obj.filterColor = ip.Results.filterColor;
            end
            
            obj.allResponsesOne = []; obj.allStimuliOne = [];
            obj.allResponsesTwo = []; obj.allStimuliTwo = [];
            obj.linearFilterOne = []; obj.linearFilterTwo = [];
            
            obj.epochNum = 0;
            
            obj.createUi();
        end
        
        function createUi(obj)
            import appbox.*;
            iconDir = [fileparts(fileparts(mfilename('fullpath'))), '\+icons\'];
            
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
            
            pos = get(obj.figureHandle, 'Position');
            set(obj.figureHandle,...
                'Position', [pos(1:3), pos(4)-100],...
                'Name', obj.figureTitle,...
                'Color', 'w');
        end
        
        function handleEpoch(obj, epoch)
            
            obj.epochNum = obj.epochNum + 1;
            assignin('base', 'epoch', epoch);
            assignin('base', 'obj', struct(obj));
            
            if obj.DEBUG
                groupInd = mod(obj.epochNum, 2) + 1;
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
                groupInd = epoch.parameters(obj.groupName);
                response = epoch.getResponse(obj.amp);
                response = response.getData();
                sampleRate = response.sampleRate.quantityInBaseUnits;
                
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
            
            % Group responses and new linear filter
            if groupInd == 1
                obj.allResponsesOne = cat(1, obj.allResponsesOne, response);
                obj.allStimuliOne = cat(1, obj.allStimuliOne, stimulus);
                newFilter = edu.washington.riekelab.patterson.utils.getLinearFilterOnline(...
                    obj.allStimuliOne, obj.allResponsesOne, obj.BIN_RATE, obj.frequencyCutoff);
                lfTag = 'LinearFilterOne';
            else
                obj.allResponsesTwo = cat(1, obj.allResponsesTwo, response);
                obj.allStimuliTwo = cat(1, obj.allStimuliTwo, stimulus);
                newFilter = edu.washington.riekelab.patterson.utils.getLinearFilterOnline(...
                    obj.allStimuliTwo, obj.allResponsesTwo, obj.BIN_RATE, obj.frequencyCutoff);
                lfTag = 'LinearFilterTwo';
            end
            
            newFilter = newFilter / max(abs(newFilter));
            
            filterPts = (obj.FILTER_LEN/1000)*obj.BIN_RATE;
            filterTimes = linspace(0, obj.FILTER_LEN, filterPts);
            
            h = findobj(obj.figureHandle, 'Tag', lfTag);
            if isempty(h)
                line(filterTimes, newFilter(1:filterPts),...
                    'Parent', obj.axesHandle(1),...
                    'Color', obj.filterColor(groupInd, :),... 
                    'LineWidth', 1.25,...
                    'Tag', lfTag);
            else
                set(h, 'YData', newFilter(1:filterPts));
            end
            
            if obj.groupInd == 1
                obj.linearFilterOne = newFilter;
            else
                obj.linearFilterTwo = newFilter;
            end
        end
    end
    
    methods (Access = private)
        function onSelectedFitLN(obj, ~, ~)
            
            [x, y] = obj.getNL(obj.allResponsesOne, obj.allStimuliOne, obj.linearFilterOne);
            h = findobj(obj.figureHandle, 'Tag', 'NonlinearityOne');
            if isempty(h)
                line(x, y, 'Parent', obj.axesHandle(2),...
                    'Marker', 'o', 'MarkerSize', 5,...
                    'Color', obj.filterColor(1, :),...
                    'LineStyle', 'none',...
                    'Tag', 'NonlinearityOne');
            else
                set(h, 'XData', x, 'YData', y);
            end
            
            [x, y] = obj.getNL(obj.allResponsesTwo, obj.allStimuliTwo, obj.linearFilterTwo);
            h = findobj(obj.figureHandle, 'Tag', 'NonlinearityTwo');
            if isempty(h)
                line(x, y, 'Parent', obj.axesHandle(2),...
                    'Marker', 'o', 'MarkerSize', 5,...
                    'Color', obj.filterColor(2, :),...
                    'LineStyle', 'none',...
                    'Tag', 'NonlinearityTwo');
            else
                set(h, 'XData', x, 'YData', y);
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
    
    methods (Static)
        function [x, y] = getNL(responses, stimuli, linearFilter)
            if isempty(response) || isempty(linearFilter)
                x = []; y = [];
                return;
            end
            
            measuredResponse = reshape(responses', 1, numel(responses));
            stimulusArray = reshape(stimuli', 1, numel(stimuli));
            
            linearPrediction = conv(stimulusArray, linearFilter);
            linearPrediction = linearPrediction(1:length(stimulusArray));
            
            [~, edges, bins] = histcounts(linearPrediction,...
                'BinMethod', 'auto');
            x = edges(1:end-1) + diff(edges);
            
            y = zeros(size(x));
            for i = 1:length(x)
                y(i) = mean(measuredResponse(bins == i));
            end
        end
    end
    
end