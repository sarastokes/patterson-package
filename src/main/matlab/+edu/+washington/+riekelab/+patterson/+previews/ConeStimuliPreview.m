classdef ConeStimuliPreview < symphonyui.core.ProtocolPreview
    % Displays a cell array of stimuli and the corresponding cone
    % isomerizations.
    %
    % History:
    %   18Feb2019 - SSP
    % ---------------------------------------------------------------------
    
    properties 
        createStimuliFcn
        led2isom
    end
    
    properties (Access = private)
        log
        ledAxes
        coneAxes
    end
    
    properties (Hidden, Constant)
        LED_COLORS = [0.25, 0.25, 1; 0, 0.8, 0.3; 0.2, 0.3, 0.9];
    end
    
    methods
        function obj = ConeStimuliPreview(panel, createStimuliFcn, led2isom)
            obj@symphonyui.core.ProtocolPreview(panel);
            obj.createStimuliFcn = createStimuliFcn;
            obj.led2isom = led2isom;
            
            obj.log = log4m.LogManager.getLogger(class(obj));
            obj.createUi();
        end
        
        function createUi(obj)
            mainLayout = uix.VBox('Parent', obj.panel,...
                'BackgroundColor', 'w');
            
            obj.ledAxes = axes(...
                'Parent', mainLayout,...
                'FontName', get(obj.panel, 'DefaultUicontrolFontName'),...
                'FontSize', get(obj.panel, 'DefaultUicontrolFontSize'),...
                'XTickMode', 'auto');
            obj.coneAxes = axes(...
                'Parent', mainLayout,...
                'FontName', get(obj.panel, 'DefaultUicontrolFontName'),...
                'FontSize', get(obj.panel, 'DefaultUicontrolFontSize'),...
                'XTickMode', 'auto');
            % xlabel(obj.coneAxes, 'sec');
            ylabel(obj.coneAxes, 'isom.');
            
            obj.update();
        end
        
        function update(obj)
            cla(obj.ledAxes); cla(obj.coneAxes);
            
            try
                stimuli = obj.createStimuliFcn();
            catch x
                cla(obj.ledAxes); cla(obj.coneAxes);
                text(0.5, 0.5, 'Cannot create stimuli',...
                    'Parent', obj.ledAxes,...
                    'FontName', get(obj.panel, 'DefaultUicontrolFontName'),...
                    'FontSize', get(obj.panel, 'DefaultUicontrolFontSize'),...
                    'HorizontalAlignment', 'center',...
                    'Units', 'normalized');
                obj.log.debug(x.message, x);
                return;
            end
            
            if ~iscell(stimuli) && isa(stimuli, 'symphonyui.core.Stimulus')
                stimuli = {stimuli};
            end
            colors = edu.washington.riekelab.patterson.utils.pmkmp(numel(stimuli), 'CubicL');
            
            allStim = [];
            ylabels = cell(1, numel(stimuli));
            for i = 1:numel(stimuli)
                [y, units] = stimuli{i}.getData();
                x = (1:numel(y)) / stimuli{i}.sampleRate.quantityInBaseUnits;
                line(x, y, 'Parent', obj.ledAxes,... 
                    'LineWidth', 0.8, 'Color', colors(i, :));
                ylabels{i} = units;  
                allStim = cat(1, allStim, y);
            end
            ylabel(obj.ledAxes, strjoin(unique(ylabels), ', '),... 
                'Interpreter', 'none');
            if min(allStim(:)) > 0
                yLim = ylim(obj.ledAxes); ylim(obj.ledAxes, [0, yLim(2)]);
            end

            try
                allStim(allStim < 0) = 0;
                calcIsom = obj.led2isom * allStim;
            catch x
                text(0.5, 0.5, 'Cannot calculate isomerizations', ...
                    'Parent', obj.coneAxes, ...
                    'FontName', get(obj.panel, 'DefaultUicontrolFontName'), ...
                    'FontSize', get(obj.panel, 'DefaultUicontrolFontSize'), ...
                    'HorizontalAlignment', 'center', ...
                    'Units', 'normalized');
                obj.log.debug(x.message, x);
                return;
            end
            
            for i = 1:3
                line(x, calcIsom(i, :), 'Parent', obj.coneAxes,...
                        'LineWidth', 0.8, 'Color', colors(i, :));
            end
            yLim = ylim(obj.coneAxes); ylim(obj.coneAxes, [0, yLim(2)]);
        end
    end
end