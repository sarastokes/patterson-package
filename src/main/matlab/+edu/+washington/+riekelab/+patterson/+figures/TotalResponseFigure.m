classdef TotalResponseFigure < symphonyui.core.FigureHandler
% TOTALRESPONSEFIGURE
%
% Description:
%   Plots all epochs together on a single plot
%
% Syntax:
%   obj = TotalResponseFigure(device, varargin);
%
% Optional key/value inputs:
%   'colorBy'               [], cellstr
%       Epoch parameter to use for grouping colormap
%   'sweepColor'            'k', char/matrix
%       Colormap to use for plotting each epoch
%   'recordingType'         [], char
%       If 'extracellular', will plot firing rate
%
% Without a grouping parameter, sweepColor could just be:
%   pmkmp(numEpochs, 'CubicL');
%
% See also:
%   MeanResponseFigure
%
% History:
%   7Feb2019 - SSP - built off MeanResponseFigure
% -------------------------------------------------------------------------


    properties (SetAccess = private)
        device
        colorBy
        sweepColor
        recordingType
    end

    properties (Access = private)
        axesHandle
        sweeps

        epochNum
    end

    methods 
        function obj = TotalResponseFigure(device, varargin)
            % co = get(groot, 'defaultAxesColorOrder');

            ip = inputParser();
            ip.addParameter('colorBy', [], @(x)iscellstr(x)); %#ok
            ip.addParameter('sweepColor', 'k', @(x)ischar(x) || ismatrix(x));
            ip.addParameter('recordingType', [], @(x)ischar(x));
            parse(ip, varargin{:});

            obj.device = device;
            obj.colorBy = ip.Results.colorBy;
            obj.sweepColor = ip.Results.sweepColor;
            obj.recordingType = ip.Results.recordingType;
            
            obj.epochNum = 0;
            obj.createUi();
        end

        function createUi(obj)
            import appbox.*;

            toolbar = findall(obj.figureHandle, 'Type', 'uitoolbar');
            captureFigureButton = uipushtool(...
                'Parent', toolbar,...
                'TooltipString', 'Capture Figure',...
                'ClickedCallback', @obj.onSelectedCaptureFigure);
            iconDir = [fileparts(fileparts(mfilename('fullpath'))), '\+icons\'];
            setIconImage(captureFigureButton, [iconDir, 'save_image.gif']);
            
            obj.axesHandle = axes( ...
                'Parent', obj.figureHandle, ...
                'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'), ...
                'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'), ...
                'XTickMode', 'auto');
            xlabel(obj.axesHandle, 'sec');
            obj.sweeps = {};
            obj.setTitle([obj.device.name ' Total Response']);
        end
        
        function setTitle(obj, t)
            set(obj.figureHandle, 'Name', t);
            title(obj.axesHandle, t);
        end
        
        function clear(obj)
            cla(obj.axesHandle);
            obj.sweeps = {};
        end
        
        function handleEpoch(obj, epoch)
            if ~epoch.hasResponse(obj.device)
                error(['Epoch does not contain a response for ' obj.device.name]);
            end

            obj.epochNum = obj.epochNum + 1;
            
            response = epoch.getResponse(obj.device);
            [quantities, units] = response.getData();
            sampleRate = response.sampleRate.quantityInBaseUnits;
            if numel(quantities) > 0
                x = (1:numel(quantities)) / sampleRate;
                y = quantities;
                
                if strcmp(obj.recordingType, 'extracellular')
                    filterSigma = (15/1000)*sampleRate; %15 msec -> dataPts
                    newFilt = normpdf(1:10*filterSigma, 10*filterSigma/2, filterSigma);
                    res = edu.washington.riekelab.patterson.utils.spikeDetectorOnline(...
                        y, [], sampleRate);
                    y = zeros(size(y));
                    y(res.sp) = 1; %spike binary
                    y = sampleRate*conv(y,newFilt,'same'); %inst firing rate, Hz
                    LW = 1;
                else
                    LW = 0.8;
                end
                
            else
                x = [];
                y = [];
            end

            p = epoch.parameters;
            if isempty(obj.colorBy) && isnumeric(obj.colorBy)
                parameters = p;
            else
                parameters = containers.Map();
                for i = 1:length(obj.colorBy)
                    key = obj.colorBy{i};
                    parameters(key) = p(key);
                end
            end

            if isempty(parameters)
                t = 'All epochs grouped together';
            else
                t = ['Grouped by ', strjoin(parameters.keys, ', ')];
            end
            obj.setTitle([obj.device.name, ' Total Response (', t, ')']);


            if isempty(obj.sweeps)
                newSweep = line(x, y, 'Parent', obj.axesHandle,...
                    'Color', obj.sweepColor(1, :),...
                    'LineWidth', LW);
            else
                offset = max(obj.sweeps(end).XData);
                newSweep = line(offset+x, y, 'Parent', obj.axesHandle,...
                    'Color', obj.sweepColor(numel(obj.sweeps)+1, :),...
                    'LineWidth', LW);
            end
            obj.sweeps = cat(1, obj.sweeps, newSweep);

            ylabel(obj.axesHandle, units, 'Interpreter', 'none');
        end   
    end
    
    methods (Access = private)
        function onSelectedCaptureFigure(obj, ~, ~)
            [fileName, pathName] = uiputfile('total.png', 'Save result as');
            if ~ischar(fileName) || ~ischar(pathName)
                return;
            end
            print(obj.figureHandle, [pathName, fileName], '-dpng', '-r600');
        end
    end
 
end