classdef LedStimuliPreview < symphonyui.core.ProtocolPreview
    % Displays a cell array of stimuli on a 2D plot. 
    %
    % History:
    %   11Feb2019 - SSP - Added color options to default StimuliPreview
    % ---------------------------------------------------------------------
    
    properties
        createStimuliFcn
        colors
    end
    
    properties (Access = private)
        log
        axes
    end
    
    methods
        
        function obj = LedStimuliPreview(panel, createStimuliFcn, colors)
            % Constructs a StimuliPreview on the given panel with the given
            % stimuli. createStimuliFcn should be a callback function that 
            % creates a cell array of stimuli.
            
            obj@symphonyui.core.ProtocolPreview(panel);
            obj.createStimuliFcn = createStimuliFcn;
            
            if nargin < 3
                obj.colors = [];
            else
                assert(length(colors) == 3, 'Colors must by Nx3 matrix');
                obj.colors = colors;
            end

            obj.log = log4m.LogManager.getLogger(class(obj));
            obj.createUi();
        end
        
        function createUi(obj)
            obj.axes = axes( ...
                'Parent', obj.panel, ...
                'FontName', get(obj.panel, 'DefaultUicontrolFontName'), ...
                'FontSize', get(obj.panel, 'DefaultUicontrolFontSize'), ...
                'XTickMode', 'auto'); %#ok<CPROP>
            xlabel(obj.axes, 'sec');
            obj.update();
        end
        
        function update(obj)
            cla(obj.axes);
            
            try
                stimuli = obj.createStimuliFcn();
            catch x
                cla(obj.axes);
                text(0.5, 0.5, 'Cannot create stimuli', ...
                    'Parent', obj.axes, ...
                    'FontName', get(obj.panel, 'DefaultUicontrolFontName'), ...
                    'FontSize', get(obj.panel, 'DefaultUicontrolFontSize'), ...
                    'HorizontalAlignment', 'center', ...
                    'Units', 'normalized');
                obj.log.debug(x.message, x);
                return;
            end
            
            if ~iscell(stimuli) && isa(stimuli, 'symphonyui.core.Stimulus')
                stimuli = {stimuli};
            end

            if isempty(obj.colors) || size(obj.colors, 1) < numel(stimuli)
                obj.colors = edu.washington.riekelab.patterson.utils.pmkmp(numel(stimuli), 'CubicL');
            end
            
            ylabels = cell(1, numel(stimuli));
            for i = 1:numel(stimuli)
                [y, units] = stimuli{i}.getData();
                x = (1:numel(y)) / stimuli{i}.sampleRate.quantityInBaseUnits;
                line(x, y, 'Parent', obj.axes,... 
                    'LineWidth', 0.8, 'Color', obj.colors(i, :));
                ylabels{i} = units;  
            end
            ylabel(obj.axes, strjoin(unique(ylabels), ', '),... 
                'Interpreter', 'none');
        end 
    end 
end