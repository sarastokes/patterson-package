classdef RampGenerator < symphonyui.core.StimulusGenerator
    % Generates a single ramp stimulus.
    %
    % 22Feb2019 - SSP - Added keep final amplitude option
    
    properties
        preTime                         % Leading duration (ms)
        stimTime                        % Ramp duration (ms)
        tailTime                        % Trailing duration (ms)
        amplitude                       % Ramp peak amplitude (units)
        mean                            % Mean amplitude (units)
        keepFinalAmplitude = false      % Set new mean 
        sampleRate                      % Sample rate of generated stimulus (Hz)
        units                           % Units of generated stimulus
    end
    
    methods
        
        function obj = RampGenerator(map)
            if nargin < 1
                map = containers.Map();
            end
            obj@symphonyui.core.StimulusGenerator(map);
        end
        
    end
    
    methods (Access = protected)
        
        function s = generateStimulus(obj)
            import Symphony.Core.*;
            
            timeToPts = @(t)(round(t / 1e3 * obj.sampleRate));
            
            prePts = timeToPts(obj.preTime);
            stimPts = timeToPts(obj.stimTime);
            tailPts = timeToPts(obj.tailTime);
            
            data = ones(1, prePts + stimPts + tailPts) * obj.mean;
            data(prePts + 1:prePts + stimPts) = linspace(0, obj.amplitude, stimPts) + obj.mean;
            if obj.keepFinalAmplitude
                data(end-tailPts:end) = obj.amplitude;
            end
            
            parameters = obj.dictionaryFromMap(obj.propertyMap);
            measurements = Measurement.FromArray(data, obj.units);
            rate = Measurement(obj.sampleRate, 'Hz');
            output = OutputData(measurements, rate);
            
            cobj = RenderedStimulus(class(obj), parameters, output);
            s = symphonyui.core.Stimulus(cobj);
        end
        
    end
    
end

