classdef SpikeStatisticsFigure < symphonyui.core.FigureHandler
% SSP - 17Feb2019

    properties (SetAccess = private)
        device
        measurementRegion
    end

    properties (Access = private)
        axHandle
        markers
    end

    methods 
        function obj = SpikeStatisticsFigure(device, varargin)
            ip = inputParser();
            addParameter(ip, 'measurementRegion', [],...
                @(x)isnumeric(x) || ixvector(x));
            parse(ip, varargin{:});

            obj.device = device;
            obj.measurementRegion = ip.Results.measurementRegion;

            obj.createUi();
        end

        function createUi(obj)
            import appbox.*;

            set(obj.figureHandle, 'Color', 'w');

            obj.axHandle = axes(...
                'Parent', obj.figureHandle,...
                'XTickMode', 'auto',...
                'TickDir', 'out',...
                'XColor', 'none');
            ylabel(obj.axHandle, 'Count');
            xlabel(obj.axHandle, 'Epoch');

            obj.setTitle([obj.device.name, ' Spike Statistics']);
        end

        function setTitle(obj, t)
            set(obj.figureHandle, 'Name', t);
            title(obj.axHandle(1), t);
        end

        function handleEpoch(obj, epoch)
            if ~epoch.hasResponse(obj.device)
                error(['Epoch does not contain a response for ' obj.device.name]);
            end

            response = epoch.getResponse(obj.device);
            quantities = response.getData();
            sampleRate = response.sampleRate.quantityInBaseUnits;

            msToPts = @(t)max(round(t / 1e3 * rate), 1);

            if ~isempty(obj.measurementRegion)
                x1 = msToPts(obj.measurementRegion(1));
                x2 = msToPts(obj.measurementRegion(2));
                quantities = quantities(x1:x2);
            end

            S = edu.washington.riekelab.patterson.utils.spikeDetectorOnline(...
                quantities, [], sampleRate);
            result = zeros(size(quantities));
            result(S.sp) = 1;
            numSpikes = nnz(result);
            
            if isempty(obj.markers)
                obj.markers = line(1, numSpikes,...
                    'Parent', obj.axHandle,...
                    'LineStyle', 'none',...
                    'Marker', 'o',...
                    'MarkerEdgeColor', 'k',...
                    'MarkerFaceColor', [0.45, 0.73, 1]);
            else
                x = get(obj.markers, 'XData');
                y = get(obj.markers, 'YData');
                set(obj.markers, 'XData', [x, x(end)+1], 'YData', [y, numSpikes]);
            end
        end
    end
end