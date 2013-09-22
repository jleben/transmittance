ProxySynthDef2 : SynthDef {
    var <rate, <numChannels, <numInputs, <numMonitors;

	*new { arg name, func, rates;
		var rate, numChannels, numMonitors, me;
        var monitorOut;

		me = super.new(name, {
			var output, signal;
			signal = SynthDef.wrap(func, rates);
			if (signal.notNil) {
				output = signal.rate.switch(
					\control, { Out.kr(\out.kr, signal) },
					\audio, { Out.ar(\out.kr, signal) },
				);
				if (output.notNil) {
					rate = signal.rate;
					numChannels = signal.size;
					if (numChannels == 0) { numChannels = 1 };
				}
			};
			output;
		});

        monitorOut = me.children.select { |x| x.class === MonitorOut }.at(0);
        numMonitors = if (monitorOut.notNil, { monitorOut.numAudioChannels }, 0);

		me.initProxy(rate, numChannels, numMonitors);

		^me;
	}

	initProxy { arg rate_, numChannels_, numMonitors_;
		rate = rate_;
		numChannels = numChannels_ ? 0;
		numInputs = this.controls.size;
		if (numChannels > 0) { numInputs = numInputs - 1}; // without the added 'out'!
        numMonitors = numMonitors_;
	}
}
