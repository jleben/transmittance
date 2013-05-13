ProxySynthDef2 : SynthDef {
    var <rate, <numChannels;

	*new { arg name, func, rates;
		var rate, numChannels, me;

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

		me.initProxy(rate, numChannels);

		^me;
	}

	initProxy { arg rate_, numChannels_;
		rate = rate_;
		numChannels = numChannels_;
	}
}
