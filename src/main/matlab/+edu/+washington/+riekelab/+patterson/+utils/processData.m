function response = processData(response, analysisType, varargin)
    % GETRESPONSEBYTYPE  Process data by recordingType

    ip = inputParser();
    addParameter(ip, 'sampleRate', 10000, @isnumeric);
    addParameter(ip, 'preTime', [], @isnumeric);
    parse(ip, varargin{:});
    sampleRate = ip.Results.sampleRate;
    preTime = ip.Results.preTime; 

    switch analysisType
        case 'spikes'
            response = wavefilter(response(:)', 6);
            S = spikeDetectorOnline(response);
            spikesBinary = zeros(size(response));
            spikesBinary(S.sp) = 1;
            response = spikesBinary * sampleRate;
        case 'ic_spikes'
            spikeTimes = getThresCross([0 diff(response(:)')], 1.5, 1);
            spikesBinary = zeros(size(response));
            spikesBinary(spikeTimes) = 1;
            response = spikesBinary * sampleRate;
        case 'subthreshold'
            spikeTimes = getThresCross([0 diff(response(:)')], 1.5, 1);
            % Get the subthreshold potential.
            if ~isempty(spikeTimes)
                response = getSubthreshold(response(:)', spikeTimes);
            else
                response = response(:)';
            end

            % Subtract the median.
            if preTime > 0
                response = response - median(response(1:round(sampleRate*preTime/1000)));
            else
                response = response - median(response);
            end
        case 'analog'
            % Deal with band-pass filtering analog data here.
            response = bandPassFilter(response, 0.2, 500, 1/sampleRate);
            % Subtract the median.
            if preTime > 0
                response = response - median(response(1:round(sampleRate*preTime/1000)));
            else
                response = response - median(response);
            end
    end
end