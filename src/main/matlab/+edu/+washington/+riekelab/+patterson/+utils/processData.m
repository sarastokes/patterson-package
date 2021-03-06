function response = processData(response, analysisType, varargin)
    % GETRESPONSEBYTYPE  
    %
    % Description:
    %   Process data by recordingType
    %
    % Syntax:
    %   response = processData(response, analysisType, varargin);
    %
    % 9Sept2017 - SSP
    % 2Feb2019 - SSP - Updated for online use in +patterson
    % ---------------------------------------------------------------------

    ip = inputParser();
    ip.CaseSensitive = false;
    addParameter(ip, 'SampleRate', 10000, @isnumeric);
    addParameter(ip, 'PreTime', 0, @isnumeric);
    parse(ip, varargin{:});
    sampleRate = ip.Results.SampleRate;
    preTime = ip.Results.PreTime; 

    switch analysisType

        case {'extracellular', 'spikes'}
            try
                response = wavefilter(response(:)', 6);
            end
            S = edu.washington.riekelab.patterson.utils.spikeDetectorOnline(response);
            spikesBinary = zeros(size(response));
            spikesBinary(S.sp) = 1;
            response = spikesBinary * sampleRate;

        case {'current_clamp', 'ic_spikes'}
            spikeTimes = edu.washington.riekelab.patterson.utils.getThresCross(...
                [0, diff(response(:)')], 1.5, 1);
            spikesBinary = zeros(size(response));
            spikesBinary(spikeTimes) = 1;
            response = spikesBinary * sampleRate;

        case 'subthreshold'
            spikeTimes = edu.washington.riekelab.patterson.utils.getThresCross(...
                [0, diff(response(:)')], 1.5, 1);

            if ~isempty(spikeTimes)
                response = edu.washington.riekelab.patterson.utils.getSubthreshold(...
                    response(:)', spikeTimes);
            else
                response = response(:)';
            end

            if preTime > 0
                response = response - median(response(1:round(sampleRate*preTime/1000)));
            else
                response = response - median(response);
            end

        case {'voltage_clamp', 'analog', 'exc', 'inh'}
            response = edu.washington.riekelab.patterson.utils.bandPassFilter(...
                response, 0.2, 500, 1/sampleRate);

            if preTime > 0
                response = response - median(response(1:round(sampleRate*preTime/1000)));
            else
                response = response - median(response);
            end
    end
end