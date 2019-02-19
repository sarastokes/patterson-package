classdef OnlineLinearFilter < handle
	
	properties
		sampleRate
		offsetForCutoffFrequency
		currentFilterFft
		numEpochs
	end

	methods
		function obj = OnlineLinearFilter(responsePoints, sampleRate, cutoffFrequency)
			obj.sampleRate = sampleRate;

			if cutoffFrequency < sampleRate / 2
				obj.offsetForCutoffFrequency = ceil(cutoffFrequency * responsePoints / sampleRate);
			else
				obj.offsetForCutoffFrequency = (responsePoints / 2) - 1;
			end

			obj.numEpochs = 0;
			obj.currentFilterFft = zeros(1, responsePoints);
		end

		function AddEpochData(obj, stimulus, response)
			stimulusFft = fft(stimulus);
			responseFft = fft(response);

			filterFft = (responseFft .* conj(stimulusFft)) ./ (stimulusFft .* conj(stimulusFft));

			% Set frequencies out of range to zero
			filterFft(1 + obj.offsetForCutoffFrequency:end - obj.offsetForCutoffFrequency) = 0;

			% Update the running mean
			obj.currentFilterFft = ...
				(obj.numEpochs / (obj.numEpochs + 1)) * obj.currentFilterFft ...
				+ (1 / (obj.numEpochs + 1)) * filterFft;

			% Increment completed epochs counter
			obj.numEpochs = obj.numEpochs + 1;
		end

		function linearFilter = ComputeCurrentLinearFilter(obj)
			linearFilter = real(ifft(obj.currentFilterFft));
		end

		function linearFilter = AddEpochDataAndComputeCurrentLinearFilter(obj, stimulus, response)
			obj.AddEpochData(stimulus, response);
			linearFilter = obj.ComputeCurrentLinearFilter();
		end
	end
end