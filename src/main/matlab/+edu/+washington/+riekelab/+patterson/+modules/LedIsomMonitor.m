classdef LedIsomMonitor < symphonyui.ui.Module
    
    properties
        log
        isomFlag = false;
    end
    
    properties (Access = private)
        dIsom
        warnDlg
        autoUpdate
    end
    
    properties (Hidden, Constant)
        CONES = {'L', 'M', 'S'};
        LEDS = {'red', 'green', 'uv'};
    end
    
    methods
        function obj = LedIsomMonitor()
            obj.log = log4m.LogManager.getLogger(class(obj));
            obj.autoUpdate = false;
        end
    end
    
    methods(Access = protected)
        function bind(obj)
            bind@symphonyui.ui.Module(obj);
            
            obj.addListener(obj.acquisitionService,...
                'SelectedProtocol', @obj.onServiceSelectedProtocol);
            params = obj.acquisitionService.getProtocolPropertyDescriptors();
            if ~isempty(findByName(params, 'redLedIsomPerVoltS'))
                set(obj.dIsom, 'Enable', 'on');
                obj.isomFlag = true;
            else
                obj.isomFlag = false;
            end
        end
    end
    
    methods (Access = private)
        function setIsom(obj, ind, value)
            % SETISOM  Change one or all led-isom protocol properties 
            fh = obj.view.getFigureHandle();
            if nargin < 2
                for i = 1:numel(obj.LEDS)
                    for j = 1:numel(obj.CONES)
                        value = get(findobj(fh, 'Tag', sprintf('%u%u', i, j)), 'String');
                        try
                            value = str2double(value);
                            if ~isempty(value)
                                obj.acquisitionService.setProtocolProperty(...
                                    sprintf('%sLedIsomPerVolt%s', obj.LEDS{i}, obj.CONES{j}), value);
                            end
                            obj.setWarning('');
                        catch
                            obj.setWarning('Invalid Input');
                            continue
                        end
                    end
                end
            else
                try
                    obj.acquisitionService.setProtocolProperty(...
                        sprintf('%sLedIsomPerVolt%s', obj.LEDS{ind(1)}, obj.CONES{ind(2)}), value);
                    obj.setWarning('');
                catch
                    obj.setWarning('Invalid Input');
                end
            end
        end
        
        function setWarning(obj, warnStr)
            % SETWARNING  Display errors
            set(obj.warnDlg, 'String', warnStr);
        end
    end
    
    methods (Access = private)
        function onSetIsom(obj, ~, ~)
            % ONSETISOM  Set all valid LED isom properties
            obj.setIsom();
        end
        
        function onEditIsom(obj, src, ~)
            % ONEDITISOM  Callback for editing a single isom field
            if ~obj.autoUpdate || ~obj.isomFlag || isempty(src.String)
                return;
            end
            
            ind = [str2double(src.Tag(1)), str2double(src.Tag(2))];
            
            try
                value = str2double(src.String);
            catch
                obj.setWarning('%u - invalid input', ind);
                return;
            end
            obj.setIsom(ind, value);
            
            obj.setWarning('');
        end
        
        function onServiceSelectedProtocol(obj, ~, ~)
            % ONSERVICESELECTEDPROTOCOL  Reflect presence of cone params
            params = obj.acquisitionService.getProtocolPropertyDescriptors();
            
            if ~isempty(findByName(params, 'redLedIsomPerVoltS'))
                set(obj.dIsom, 'Enable', 'on');
                obj.isomFlag = true;
                if obj.autoUpdate
                    obj.setIsom();
                end
            else
                set(obj.dIsom, 'Enable', 'off');
                obj.isomFlag = false;
            end
        end
        
        function onToggleAutoUpdate(obj, src, ~)
            % TOGGLEAUTOUPDATE  Sets autoUpdate
            if src.Value
                obj.autoUpdate = true;
            else
                obj.autoUpdate = false;
            end
        end
    end
    
    methods
        function createUi(obj, figureHandle)
            set(figureHandle, 'Name', 'led2isom monitor',...
                'Position', appbox.screenCenter(250,200),...
                'Color', 'w');
            mainLayout = uix.VBox('Parent', figureHandle,...
                'BackgroundColor', 'w');
            coneLayout = uix.HBox('Parent', mainLayout,...
                'BackgroundColor', 'w');
            uix.Empty('Parent', coneLayout);
            uicontrol('Parent', coneLayout,...
                'Style', 'text', 'String', 'L*');
            uicontrol('Parent', coneLayout,...
                'Style', 'text', 'String', 'M*');
            uicontrol('Parent', coneLayout,...
                'Style', 'text', 'String', 'S*');
            
            redLayout = uix.HBox('Parent', mainLayout,...
                'BackgroundColor', 'w');
            uicontrol('Parent', redLayout,...
                'Style', 'text', 'String', 'Red');
            uicontrol(redLayout,...
                'Style', 'edit', 'Tag', '11', 'Callback', @obj.onEditIsom);
            uicontrol(redLayout,...
                'Style', 'edit', 'Tag', '12', 'Callback', @obj.onEditIsom);
            uicontrol(redLayout,...
                'Style', 'edit', 'Tag', '13', 'Callback', @obj.onEditIsom);
            
            greenLayout = uix.HBox('Parent', mainLayout,...
                'BackgroundColor', 'w');
            uicontrol('Parent', greenLayout,...
                'Style', 'text', 'String', 'Green');
            uicontrol(greenLayout,...
                'Style', 'edit', 'Tag', '21', 'Callback', @obj.onEditIsom);
            uicontrol(greenLayout,...
                'Style', 'edit', 'Tag', '22', 'Callback', @obj.onEditIsom);
            uicontrol(greenLayout,...
                'Style', 'edit', 'Tag', '23', 'Callback', @obj.onEditIsom);
            uvLayout = uix.HBox('Parent', mainLayout,...
                'BackgroundColor', 'w');
            
            uicontrol('Parent', uvLayout,...
                'Style', 'text', 'String', 'UV');
            uicontrol(uvLayout,...
                'Style', 'edit', 'Tag', '31', 'Callback', @obj.onEditIsom);
            uicontrol(uvLayout,...
                'Style', 'edit', 'Tag', '32', 'Callback', @obj.onEditIsom);
            uicontrol(uvLayout,...
                'Style', 'edit', 'Tag', '33', 'Callback', @obj.onEditIsom);
            
            ctrlLayout = uix.HBox(...
                'Parent', mainLayout,...
                'BackgroundColor', 'w');
            obj.dIsom = uicontrol(ctrlLayout,...
                'Style', 'push',...
                'String', 'Set Isom',...
                'Callback', @obj.onSetIsom);
            uicontrol(ctrlLayout,...
                'Style', 'check',...
                'String', 'Auto Update',...
                'Tag', 'AutoUpdate',...
                'Callback', @obj.onToggleAutoUpdate);
            
            obj.warnDlg = uicontrol(mainLayout,...
                'String', '',...
                'HorizontalAlignment', 'center',...
                'ForegroundColor', 'r');
        end
    end
end