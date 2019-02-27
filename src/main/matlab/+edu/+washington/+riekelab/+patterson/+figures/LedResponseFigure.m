classdef LedResponseFigure < symphonyui.core.FigureHandler
% LEDRESPONSEFIGURE
%
% Description:
%   Shows amp response with any associated LED stimuli
%
% 19Feb2019 - SSP
% -------------------------------------------------------------------------
    
    properties
        % Required:
        device
        leds
        
        % Optional
        sweepColor
        ledColor
        storedSweepColor
    end
    
    properties (Access = private)
        % Responses
        sweep
        stimSweep
        
        % Axes
        respAxes
        stimAxes
    end

    properties (Hidden, Constant)
        LED_COLORS = [0.25, 0.25, 1; 0, 0.8, 0.3; 0.2, 0.3, 0.9];
    end
    
    methods
        function obj = LedResponseFigure(device, leds, varargin)
            obj.device = device;
            obj.leds = leds;
            
            ip = inputParser();
            ip.CaseSensitive = false;
            addParameter(ip, 'sweepColor', 'k', @(x)ischar(x) || isvector(x));
            addParameter(ip, 'ledColor', obj.LED_COLORS, @(x)ischar(x) || ismatrix(x));
            addParameter(ip, 'storedSweepColor', 'r', @(x)ischar(x) || isvector(x));
            parse(ip, varargin{:});

            obj.sweepColor = ip.Results.sweepColor;
            obj.storedSweepColor = ip.Results.storedSweepColor;
            obj.ledColor = ip.Results.ledColor;
            
            obj.createUI();
        end
        
        function createUI(obj)
            import appbox.*;
            
            set(obj.figureHandle,...
                'Name', 'Response Figure',...
                'Color', 'w');
            
            % ------------------------------------------------- toolbar ---
            toolbar = findall(obj.figureHandle, 'Type', 'uitoolbar');
            storeSweepButton = uipushtool(...
                'Parent', toolbar,...
                'TooltipString', 'Store Sweep',...
                'ClickedCallback', @obj.onSelectedStoreSweep);
            setIconImage(storeSweepButton,...
                symphonyui.app.App.getResource('icons', 'sweep_store.png'));
            
            clearSweepButton = uipushtool(...
                'Parent', toolbar,...
                'TooltipString', 'Clear Sweep',...
                'ClickedCallback', @obj.onSelectedClearSweep);
            setIconImage(clearSweepButton,...
                symphonyui.app.App.getResource('icons', 'sweep_clear.png'));

            captureFigureButton = uipushtool(...
                'Parent', toolbar,...
                'TooltipString', 'Capture Figure',...
                'ClickedCallback', @obj.onSelectedCaptureFigure);
            iconDir = [fileparts(fileparts(mfilename('fullpath'))), '\+icons\'];
            setIconImage(captureFigureButton, [iconDir, 'picture.gif']);
            
            % ---------------------------------------------------- axes ---
            obj.respAxes = subplot(4,1,1:3,...
                'Parent', obj.figureHandle);
            xlabel(obj.respAxes, 'sec');
            
            obj.stimAxes = subplot(4,1,4,...
                'Parent', obj.figureHandle,...
                'XTick', [], 'XColor', 'w');
            
            set(findall(obj.figureHandle, 'Type', 'axes'),...
                'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'),...
                'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'),...
                'XTickMode', 'auto');
            set(findall(obj.figureHandle, 'Type', 'uipushtool'),...
                'Separator', 'on');
            
            obj.sweep = [];
            obj.stimSweep = cell(1, numel(obj.leds));
        end
        
        function setTitle(obj, t)
            set(obj.figureHandle, 'Name', t);
            title(obj.respAxes, t);
        end
        
        function clear(obj)
            cla(obj.respAxes);
            cla(obj.stimAxes);
            obj.sweep = [];
            obj.stimSweep = [];
        end
        
        function handleEpoch(obj, epoch)
            if ~epoch.hasResponse(obj.device)
                error(['Epoch does not contain a response for ' obj.device.name]);
            end
            
            if isempty(obj.stimSweep)
                obj.stimSweep = cell(1, numel(obj.leds));
            end
            
            % Parse and plot response
            response = epoch.getResponse(obj.device);
            [quantities, units] = response.getData();
            sampleRate = response.sampleRate.quantityInBaseUnits;
            if numel(quantities) > 0
                x = (1:numel(quantities)) / sampleRate;
                y = quantities;
            else
                x = [];
                y = [];
            end
            
            if isempty(obj.sweep)
                obj.sweep = line(x, y,...
                    'Parent', obj.respAxes,...
                    'Color', obj.sweepColor);
            else
                set(obj.sweep, 'XData', x, 'YData', y);
            end
            ylabel(obj.respAxes, units,...
                'Interpreter', 'none');
            xlim(obj.respAxes, [0, max(x)]);

            % Parse and plot stimuli
            for i = 1:numel(obj.leds)
                stimulus = epoch.getStimulus(obj.leds(i));
                stimTrace = stimulus.getData();
                if ~isempty(stimTrace)
                    xs = linspace(0, max(x), length(stimTrace));
                    rgb = edu.washington.riekelab.patterson.utils.getLineColor(...
                        obj.leds(i).name);
                    if isempty(obj.stimSweep{i})
                        obj.stimSweep{i} = line(...
                            'Parent', obj.stimAxes,...
                            'XData', xs, 'YData', stimTrace,...
                            'Color', rgb,...
                            'LineWidth', 1);
                    else
                        set(obj.stimSweep{i},...
                            'XData', xs, 'YData', stimTrace);
                    end
                    ylabel(obj.stimAxes, obj.leds(i).background.displayUnits);
                    xlim(obj.stimAxes, xlim(obj.respAxes));
                end
            end
        end
    end
    
    % Callback methods
    methods (Access = private)
        function onSelectedStoreSweep(obj, ~, ~)
            % ONSELECTEDSTORESWEEP  Calls method to store sweeps
            obj.storeSweep();
        end
        
        function onSelectedClearSweep(obj, ~, ~)
            % ONSELECTEDCLEARSWEEP  Calls method to clear sweeps
            obj.clearSweep();
        end
    end
    
    methods (Access = private)
        function clearSweep(obj)
            stored = obj.storedSweep();
            if ~isempty(stored)
                delete(stored.line);
            end
            
            obj.storedSweep([]);
        end
        
        function storeSweep(obj)
            obj.clearSweep();
            
            store = obj.sweep;
            if ~isempty(store)
                store.line = copyobj(obj.sweep.line, obj.respAxes);
                set(store.line, ...
                    'Color', obj.storedSweepColor, ...
                    'HandleVisibility', 'off');
            end
            obj.storedSweep(store);
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
        function sweep = storedSweep(sweep)
            % This method stores a sweep across figure handlers.
            persistent stored;
            if nargin > 0
                stored = sweep;
            end
            sweep = stored;
        end
    end
end
