function rgb = getLineColor(name)
    % GETLINECOLOR
    %
    % Description:
    %   Returns consistent plot colors for cones, LEDs, etc
    %
    % Syntax:
    %   rgb = getLineColor(name)
    %
    % Input:
    %   name        Cone or LED name (char or cell)
    %
    % Output:       
    %   rgb         RGB color vector (black if not recognized)
    %
    % History:
    %   SSP - 17Feb2019 - Shorted version of getPlotColor
    % ---------------------------------------------------------------------
    
    if ischar(name)
        rgb = name2color(name);
    else  % Cell with multiple names
        rgb = [];
        for i = 1:numel(name)
            rgb = cat(1, rgb, name2color(name{i}));
        end
    end
end

function rgb = name2color(name)
    % NAME2COLOR  Process a single name
    switch lower(name)
        case {'red', 'red led', 'l'}
            rgb = [1, 0.25, 0.25];
        case {'green', 'green led', 'm'}
            rgb = [0, 0.8, 0.3];
        case {'uv', 'uv led', 's'}
            rgb = [0.2, 0.3, 0.9];
        otherwise
            fprintf('GETLINECOLOR: No color found for %s\n', name);
            rgb = [0, 0, 0];
    end
end
