classdef VJumpFigure < symphonyui.core.FigureHandler
   
    properties
        device
        ECl
        voltageHolds
        preTime
        stimTime
    end
    
    properties
        axesHandle
        lineMap
        dataMap
    end
    
    methods
        function obj = VJumpFigure(device, ECl, voltageHolds, varargin)
            obj.device = device;
            obj.ECl = ECl;
            obj.voltageHolds = voltageHolds;
            
            ip = inputParser();
            ip.CaseSensitive = false;
            addParameter(ip, 'preTime', 0, @isnumeric);
            addParameter(ip, 'stimTime', [], @isnumeric);
            parse(ip, varargin{:});
            obj.preTime = ip.Results.preTime;
            obj.stimTime = ip.Results.stimTime;
            
            obj.lineMap = containers.Map();
            obj.dataMap = containers.Map();
            obj.createUi();
        end
        
        function createUi(obj)
            set(obj.figureHandle, 'Color', 'w',...
                'Name', 'Cone Iso VJump');
            
            allHolds = unique(obj.voltageHolds) + obj.ECl;
            rgb = edu.washington.riekelab.patterson.utils.multigradient(...
                'preset', 'div.cb.spectral.9', 'length', numel(allHolds));
            
            obj.axesHandle(1) = subplot(1, 2, 1,...
                'Parent', obj.figureHandle,...
                'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'),...
                'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'), ...
                'XTickMode', 'auto');
            title(obj.axesHandle(1), 'LM-cone'); 
            xlabel('time (ms)');
            for i = 1:numel(allHolds)
                obj.lineMap({obj.toKey([1, allHolds(i)])}) = line(...
                    'Parent', obj.axesHandle(1),...
                    'XData', [0, 1], 'YData', [0, 0],...
                    'Color', rgb(i, :));
            end
            
            obj.axesHandle(2) = subplot(1, 2, 2,...
                'Parent', obj.figureHandle,...
                'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'),...
                'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'), ...
                'XTickMode', 'auto');
            title(obj.axesHandle(2), 'S-cone'); 
            xlabel('time (ms)');
            for i = 1:numel(obj.voltageHolds)
                obj.lineMap({obj.toKey([2, allHolds(i)])}) = line(...
                    'Parent', obj.axesHandle(2),...
                    'XData', [0, 1], 'YData', [0, 0],...
                    'Color', rgb(i, :));
            end
        end
        
        function handleEpoch(obj, epoch)
            if ~epoch.hasResponse(obj.device)
                error(['Epoch does not contain a response for ', obj.device.name]);
            end
            
            response = epoch.getResponse(obj.device);
            [quantities, units] = response.getData();
            sampleRate = response.sampleRate.quantityInBaseUnits;
            if numel(quantities) > 0
                x = (1:numel(quantities)) / sampleRate;
                y = quantities;
                
            else
                x = []; y = [];
            end
            
            epochID = [nnz(epoch.parameters('sContrast')) + 1,...
                epoch.parameters('holdingPotential')];
            epochKey = obj.toKey(epochID);
            if ~isKey(obj.dataMap, {epochKey})
                obj.dataMap({key}) = y;
            else
                obj.dataMap({key}) = cat(1, obj.dataMap({key}), y);
            end
            
            set(obj.lineMap({key}),... 
                'XData', x, 'YData', mean(obj.dataMap({key}), 1));
            
            xlim([obj.axesHandle(1), obj.axesHandle(2)], [0, max(x)]);
            ylabel(obj.axesHandle(1), units, 'Interpreter', 'none');    
        end
    end
    
    methods (Static)
        function value = fromKey(key)
            value = [floor(key/65535), rem(key, 65535)];
        end
        
        function key = toKey(value)
            key = value(1)*65535 + value(2);
        end
    end
end
