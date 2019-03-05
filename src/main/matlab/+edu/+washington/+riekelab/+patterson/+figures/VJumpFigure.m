classdef VJumpFigure < symphonyui.core.FigureHandler
% VJUMPFIGURE
%
% Description:
%   2 plots of responses to LM and S cone modulations with one line per
%   holding potential
%
% History:
%   5Mar2019 - SSP - works
% -------------------------------------------------------------------------

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
            
            allHolds = unique(obj.voltageHolds); %+ obj.ECl;
            rgb = edu.washington.riekelab.patterson.utils.multigradient(...
                'preset', 'div.cb.spectral.9', 'length', numel(allHolds));
            
            ax1 = subplot(1, 2, 1,...
                'Parent', obj.figureHandle,...
                'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'),...
                'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'), ...
                'XTickMode', 'auto', 'Tag', 'AxesOne');
            title(ax1, 'LM-cone'); 
            xlabel(ax1, 'time (s)');
            for i = 1:numel(allHolds)
                obj.lineMap(obj.toKey([1, allHolds(i)])) = line(...
                    'Parent', ax1,...
                    'XData', [0, 1], 'YData', [0, 0],...
                    'Color', rgb(i, :));
            end

            ax2 = subplot(1, 2, 2,...
                'Parent', obj.figureHandle,...
                'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'),...
                'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'), ...
                'XTickMode', 'auto', 'Tag', 'AxesTwo');
            title(ax2, 'S-cone'); 
            xlabel(ax2, 'time (s)');
            
            for i = 1:numel(allHolds)
                obj.lineMap(obj.toKey([2, allHolds(i)])) = line(...
                    'Parent', ax2,...
                    'XData', [0, 1], 'YData', [0, 0],...
                    'Color', rgb(i, :));
            end
        end
        
        function handleEpoch(obj, epoch)
            if ~epoch.hasResponse(obj.device)
                error(['Epoch does not contain a response for ', obj.device.name]);
            end
            if ~epoch.shouldBePersisted
                return;
            end

            epochContrast = epoch.parameters('contrast');

            response = epoch.getResponse(obj.device);
            [quantities, units] = response.getData();
            sampleRate = response.sampleRate.quantityInBaseUnits;
            if numel(quantities) > 0
                x = (1:numel(quantities)) / sampleRate;
                y = quantities;
                
            else
                x = []; y = [];
            end

            epochID = [nnz(epochContrast(3)) + 1,...
                epoch.parameters('holdingPotential')];
            epochKey = obj.toKey(epochID);
            if ~isKey(obj.dataMap, epochKey)
                obj.dataMap(epochKey) = y;
            else
                obj.dataMap(epochKey) = cat(1, obj.dataMap(epochKey), y);
            end
            
            set(obj.lineMap(epochKey),... 
                'XData', x, 'YData', mean(obj.dataMap(epochKey), 1));
            
            xlim(obj.lineMap(epochKey).Parent, [0, max(x)]);
            ylabel(obj.lineMap(epochKey).Parent, units, 'Interpreter', 'none');    
        end
    end
    
    methods (Static)
        function value = fromKey(key)
            key = str2double(key);
            value = [floor(key/65535), rem(key, 65535)];
        end
        
        function key = toKey(value)
            key = value(1)*65535 + value(2);
            key = num2str(key);
        end
    end
end
