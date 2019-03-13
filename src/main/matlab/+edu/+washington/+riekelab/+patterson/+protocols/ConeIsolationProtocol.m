classdef (Abstract) ConeIsolationProtocol < edu.washington.riekelab.protocols.RiekeLabProtocol
    % CONEISOLATIONPROTOCOL
    %
    % Description:
    %   Parent class for Confocal rig cone isolation
    %
    % History:
    %   13Mar2019 - SSP
    % -------------------------------------------------------------------------
    
    properties
        redLedIsomPerVoltS = 38         % S-cone isom per red LED volt
        redLedIsomPerVoltM = 363        % M-cone isom per red LED volt
        redLedIsomPerVoltL = 1744       % L-cone isom per red LED volt
        greenLedIsomPerVoltS = 134      % S-cone isom per green LED volt
        greenLedIsomPerVoltM = 1699     % M-cone isom per green LED volt
        greenLedIsomPerVoltL = 1099     % L-cone isom per green LED volt
        uvLedIsomPerVoltS = 2691        % S-cone isom per UV LED volt
        uvLedIsomPerVoltM = 360         % M-cone isom per UV LED volt
        uvLedIsomPerVoltL = 344         % L-cone isom per UV LED volt
    end
    
    properties (Hidden, Dependent = true)
        lmsToRgu
        rguToLms
        
        redLed
        greenLed
        uvLed
    end
    
    properties (Hidden, Constant)
        LED_MAX = 9;
    end
    
    properties (Abstract)
        amp
    end
    
    methods
        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.protocols.RiekeLabProtocol(obj);
            
            
            obj.showFigure('edu.washington.riekelab.patterson.figures.LedRangeFigure',...
                obj.rig.getDevice(obj.amp));
            if numel(obj.rig.getDeviceNames('Amp')) < 2
                obj.showFigure('edu.washington.riekelab.patterson.figures.LedResponseFigure',...
                    obj.rig.getDevice(obj.amp),...
                    [obj.redLed, obj.greenLed, obj.uvLed], 'rgu2lms', obj.rguToLms);
            end
        end
    end
    
    methods
        function y = checkRange(obj, stim, stimTime)
            stimData = stim.getData();
            y = 100 * (sum(stimData <= 0) + sum(stimData == obj.LED_MAX)) ...
                / (obj.sampleRate * stimTime / 1e3);
        end
    end
    
    methods  % Dependent set/get methods
        function value = get.rguToLms(obj)
            value = [obj.redLedIsomPerVoltL, obj.greenLedIsomPerVoltL, obj.uvLedIsomPerVoltL; ...
                obj.redLedIsomPerVoltM, obj.greenLedIsomPerVoltM, obj.uvLedIsomPerVoltM; ...
                obj.redLedIsomPerVoltS, obj.greenLedIsomPerVoltS, obj.uvLedIsomPerVoltS];
        end
        
        function value = get.lmsToRgu(obj)
            value = inv(obj.rguToLms);
        end
        
        function value = get.redLed(obj)
            value = obj.rig.getDevice('Red LED');
        end
        
        function value = get.greenLed(obj)
            value = obj.rig.getDevice('Green LED');
        end
        
        function value = get.uvLed(obj)
            value = obj.rig.getDevice('UV LED');
        end
    end
end