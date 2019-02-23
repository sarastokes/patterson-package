classdef LedRangeFigure < symphonyui.core.FigureHandler
% LEDRANGEFIGURE
%
% Description:
%   Monitors stimuli for values exceeding each LED's range.
%
% 19Feb2019 - SSP
% -------------------------------------------------------------------------

    properties
        redRange
        greenRange
        uvRange
        
        redCounter
        greenCounter
        uvCounter
    end
    
    methods
        function obj = LedRangeFigure(device)
            obj.createUi();
        end
        
        function createUi(obj)
            import appbox.*;
            
            set(obj.figureHandle,...
                'Name', 'Response Figure',...
                'Position', screenCenter(150, 150),...
                'Toolbar', 'none',...
                'Color', 'w');
            
            mainLayout = uix.VBox('Parent', obj.figureHandle,...
                'BackgroundColor', 'w');
            uicontrol(mainLayout,...
                'Style', 'text',...
                'String', 'Out of Range:',...
                'FontWeight', 'bold',...
                'HorizontalAlignment', 'center');
            redLayout = uix.HBox('Parent', mainLayout,...
                'BackgroundColor', 'w');
            uicontrol(redLayout,...
                'Style', 'text', 'String', 'Red: ');
            obj.redRange = uicontrol(redLayout,...
                'Style', 'text', 'String', '');
                      
            greenLayout = uix.HBox('Parent', mainLayout,...
                'BackgroundColor', 'w');
            uicontrol(greenLayout,...
                'Style', 'text', 'String', 'Green: ');
            obj.greenRange = uicontrol(greenLayout,...
                'Style', 'text', 'String', '');
            
            uvLayout = uix.HBox('Parent', mainLayout,...
                'BackgroundColor', 'w');
            uicontrol(uvLayout,...
                'Style', 'text', 'String', 'UV: ');
            obj.uvRange = uicontrol(uvLayout,...
                'Style', 'text', 'String', '');

            set(findall(obj.figureHandle, 'Type', 'uicontrol'),...
                'BackgroundColor', 'w');
        end
        
        function handleEpoch(obj, epoch)
            set(obj.redRange, 'String',...
                sprintf('%.2f%%', epoch.parameters('redOutliers')));
            set(obj.greenRange, 'String',...
                sprintf('%.2f%%', epoch.parameters('greenOutliers')));
            set(obj.uvRange, 'String',...
                sprintf('%.2f%%', epoch.parameters('uvOutliers')));
            
            % Use red text as a warning of LED range outliers
            if epoch.parameters('redOutliers') > 0
                set(obj.redRange, 'ForegroundColor', 'r');
            end
            if epoch.parameters('greenOutliers') > 0
                set(obj.greenRange, 'ForegroundColor', 'r');
            end
            if epoch.parameters('uvOutliers') > 0
                set(obj.uvRange, 'ForegroundColor', 'r');
            end

        end
    end
end