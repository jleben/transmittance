/*****************************************************
Sequence of FM tones
- FM index controlled by tilt at trigger time
*****************************************************/

/*
(
SynthDef(\fm, {
    arg freq = 200, mod1, mod2, mod3;
    Out.ar( 0,
        SinOsc.ar(
            freq +
            Mix.ar(
                SinOsc.ar(freq * [2, 0.5, 6])
                * [mod1, mod2, mod3]
                * freq
            )
        )
        * Env.perc(0.02, 0.8).ar(2);
    );
}).add
)

(
OSCdef(\fm_control, { |msg|
    var vector = msg[3..5]; // tilt
    vector = vector * 6 + 6;
    ~fm_mod = vector;
    vector.postln
}, \trigger);

~fm_mod = [0,0,0];
Pbind(*[
    instrument: \fm,
    freq: Prand([1,1.5,2], inf) * 100,
    dur: Prand([0.1, 0.1, 0.1, 0.2], inf),
    mod1: Pfunc({~fm_mod[0]}),
    mod2: Pfunc({~fm_mod[1]}),
    mod3: Pfunc({~fm_mod[2]}),
]).play;
)
*/

/*****************************************************
Grainular FM:
- FM index and amp controlled by acceleration
- trigger randomizes carrier frequency
******************************************************/

/*
(
~grain_fm = `NodeDef { arg ratio = 1, dur = 0.1, accel, trigger;
    var amp, index, freq;
    index = accel.abs;
    amp = (accel + 0.1).max(0) * 0.1;
    freq = TRand.kr(200, 400, trigger);
    GrainFM.ar(
        1,
        TDuty.ar(Dwhite(0.01,0.05)),
        dur,
        freq,
        freq * ratio,
        index * 20 / ratio + WhiteNoise.ar(2)
    )
    * LagUD.kr(amp, 0.1, 2);
}
)
*/

/*******************************************************************

Za potrebe "What if"/"Kaj če" je to zdaj
ACT YOUR AGE scena

Granular, Bring up volume by movement
movement => raise amp, filter

ADD:
tilt => center position
Količina gibanja => hitrost premikanja center position po sample-u.
********************************************************************/

/***************************************************************
questions!

- zakaj kakršenkoli Enveloping amplifikacije eksplodira?
  recimo amp1 * XLine. hm, EnvGen seems to work now ok...
- kako sinhroniziratir start-time BufRd med bee1 in bee2?
- kako delati z 2-channel bufferji. a je sploh možno?

opcija:
- a je možna komunikacija nazaj v GUI? recimo če se en parameter
  spreminja z XLine (recimo), a lahko GUI to prikazuje?

****************************************************************/


(
~act_your_age = NodeDef {
    arg buf1, buf2, buf3, buf4,
	amp1=0.3, amp2=0.3, amp3=0.5, amp4=0.1,
	m1_ffreq, m1_ff_e,
	m2_ffreq, m2_ff_e,
	b_ffreq, b_ff_e,
	interval = 0.02, dur = 0.1,
    threshold = 0.002, grow = 6, attack = 0.1, decay = 3.1,
    in, trigger,
	x, y, z;



    var energy, sound, lines, melody1, melody2, beats ;

    energy = (in - threshold).max(0) * grow;
    energy = Decay2.kr(energy, attack, decay).min(1.0);
	energy = DelayN.kr(in:energy, maxdelaytime: 10, delaytime: 0);

	// amp1 = XLine.ar(0,1,200);

	lines = BufRd.ar( // buffer reading osc
		1,
		[buf1,buf1], // but we need to expand this to make two-channel buffer...
		Phasor.ar( // ramp loop
			trig: 1,
			rate: BufRateScale.kr(buf1) * 1, // can be negative for opposite direction!
			start: BufFrames.kr(buf1),
			end:0
		)
	) * amp1;

	// sound = XLine.kr(start:0, end:1, dur:10) * sound;

	lines = FreeVerb.ar(
		in:lines,
		mix:0.3,
		room:0.7,
		damp:0.5,
		mul: EnvGen.kr(Env([0.001,1],[40],\lin), doneAction: 0) - 0.001
	);

	melody1 = BufRd.ar( // buffer reading osc
		1,
		[buf2,buf2], // but we need to expand this to make two-channel buffer...
		Phasor.ar( // ramp loop
			trig: 1,
			rate: BufRateScale.kr(buf2) * 1, // can be negative for opposite direction!
			start: BufFrames.kr(buf2),
			end:0
		)
	) * amp2 ;

	// LP filter
	//m1_ffreq = XLine.kr(40,200,150);
	//m1_ff_e = XLine.kr(40,1500,150);

	//m1_ffreq = EnvGen.kr(Env([0,0,1], [30,30], \exponential));

	melody1 = RLPF.ar(
		in: melody1,
		freq: Clip.kr(m1_ffreq + (m1_ff_e * energy), 40, 20000),
		rq:0.5);


	// delays
	melody1 = CombC.ar(
		in:melody1,
		maxdelaytime:1,
		delaytime:[0.4,0.6],
		decaytime:4,
		mul:0.3,
		add:melody1
	);

	melody2 = BufRd.ar( // buffer reading osc
		1,
		[buf3,buf3], // but we need to expand this to make two-channel buffer...
		Phasor.ar( // ramp loop
			trig: 1,
			rate: BufRateScale.kr(buf3) * 1, // can be negative for opposite direction!
			start: BufFrames.kr(buf3),
			end:0
		)
	) * amp3 ;

	//m2_ffreq = XLine.kr(40,200,100);
	//m2_ff_e = XLine.kr(40,1500,100);


	melody2 = RLPF.ar(
		in: melody2,
		freq: Clip.kr(m2_ffreq + (m2_ff_e * energy), 40, 20000),
		rq: 0.5
	);


	// delays
	melody2 = CombC.ar(
		in:melody2,
		maxdelaytime:1,
		delaytime:[0.3,0.4],
		decaytime:4,
		mul:0.3,
		add:melody2
	);


	beats = BufRd.ar( // buffer reading osc
		1,
		[buf4,buf4], // but we need to expand this to make two-channel buffer...
		Phasor.ar( // ramp loop
			trig: 1,
			rate: BufRateScale.kr(buf4) * 1, // can be negative for opposite direction!
			start: BufFrames.kr(buf4),
			end:0
		)
	) * amp4 ;

	//b_ffreq = XLine.kr(40,500,300);
	//b_ff_e = XLine.kr(40,1500,300);

	beats = RLPF.ar(
		in: beats,
		freq: Clip.kr(b_ffreq + (b_ff_e * energy), 40, 20000),
		rq: 0.5,
		mul: EnvGen.kr(Env([0.001, 0.001,1],[100,60],\lin), doneAction: 0) - 0.001
	);


	decay = EnvGen.kr(Env([3.1,3.1,20],[80,60],\lin), doneAction: 0);

	sound = lines + melody1 + melody2 + beats;



	/*
	// GRANULATOR
    sound = GrainBuf.ar (
        numChannels:2,
        trigger:TDuty.ar(Dwhite(interval * 0.3, interval * 1.8)),
        dur:dur,
		sndbuf:[buf1, buf2, buf3],
        rate:BufRateScale.ir([buf1, buf2, buf3]),
		pos: x,
		mul: [amp1, amp2, amp3] - 0.01
    );
	*/
	// sound = LPF.ar( sound, energy.pow(4) * 20000 + 200 ) * ((energy * 4).min(1) + 0.01) * 0.8;

	// Reverse filter and amp:
	// sound = LPF.ar( sound, (1 - energy).pow(4) * 18000 + 800 ) * (( 1 - (energy * 0.1)).min(1) + 0.01) * 0.5;

	// sound = FreeVerb.ar(sound);
	// sound = CombC.ar(sound, 1, 0.5, 4);

/*

	sound2 = GrainBuf.ar (
        numChannels:2,
        trigger:TDuty.ar(Dwhite(interval * 0.3, interval * 1.8)),
        dur:dur,
        sndbuf:buf2,
        rate:BufRateScale.ir(buf),
		pos: y
    );


	sound = Mix.ar(sound ++ sound2);
*/
    /*
    x = (
        LPF.ar( x, (1 - movement).pow(4) * 20000 + 200 )
        * ( (1 - (movement * 1)).max(0) + 0.01)
        * 0.5;
    )
    */


/*
	sound = SinOsc.ar(
		freq:1000
	) * LFPulse.kr (0.5);
*/
};
~act_your_age.controls = [
    \buf1 -> Buffer,
	\buf2 -> Buffer,
	\buf3 -> Buffer,
	\buf4 -> Buffer,

	\amp1 -> [0.01, 1, \exp],
	\amp2 -> [0.01, 1, \exp],


	\m1_ffreq -> [20,20000, \exp],
	\m1_ff_e -> [0, 1500, \lin],

	\amp3 -> [0.01, 1, \exp],

	\m2_ffreq -> [20,20000, \exp],
	\m2_ff_e -> [0, 1500, \lin],

	\amp4 -> [0.01, 1, \exp],

	\b_ffreq -> [20,20000, \exp],
	\b_ff_e -> [0, 1500, \lin],


    //\interval -> [0.01, 0.1, \exp],
    //\dur -> [0.05, 0.2, \exp],
    \grow -> [0.1, 6, \lin],
    \decay -> [3.1, 20, \lin]
];
);

(
~act_your_age.map(
	\in, [~basic, 3, 1],
	\x, [~vector_smooth, 0, 3],
	\y, [~vector_smooth, 1, 3],
	\z, [~vector_smooth, 2, 3]

);

);


/************************************
Granular Integration
- movement => integrate
- slow rand pos
*************************************/
(
~grain_integrate = NodeDef {
    arg buf,
    threshold = 0.002, grow = 0.7, attack = 3, decay = 15,
    in;

    var energy, interval, dur, x;

    energy = (in - threshold).max(0) * grow;
    energy = Decay2.kr(energy, attack, decay).min(1.0);

    interval = (1 - energy) * 0.07  + 0.02;
    dur = 0.005 + (energy.squared * 0.4);

    x = GrainBuf.ar (
        2,
        TDuty.ar(Dwhite(interval * 0.3, interval * 1.8)),
        dur,
        buf,
        BufRateScale.ir(buf),
        LFNoise1.kr(0.1) * 0.5 + 0.5;
    );
    x = (
        //LPF.ar( x, energy.pow(4) * 20000 + 600 )
        HPF.ar( x, (1 - energy).pow(3) * 1500 + 50 )
        * ((energy).min(1) + 0.4)
        * 0.5
    )
};
~grain_integrate.controls = [
    \buf -> Buffer,
    \grow -> [0.1, 2, \lin],
    \decay -> [3.1, 20, \lin]
];
);
(
~grain_integrate.map(\in, [~basic, 3, 1]);
);

/************************************
Granular Disintegration
- movement => disintegrate
- slow rand pos
*************************************/
(
~grain_disintegrate = NodeDef {
    arg buf,
    max_intrv = 0.02,
    threshold = 0.002, grow = 0.2, attack = 3, decay = 15,
    in;

    var energy, interval, dur, x;

    energy = (in - threshold).max(0) * grow;
    energy = Decay2.kr(energy, attack, decay).min(1.0);

    interval = energy * max_intrv  + 0.03;
    dur = 0.005 + ((1 - energy).pow(4) * 0.4);

    x = GrainBuf.ar (
        2,
        TDuty.ar(Dwhite(interval * 0.3, interval * 1.8)),
        dur,
        buf,
        BufRateScale.ir(buf),
        LFNoise1.kr(0.1) * 0.5 + 0.5;
    );
    x = (
        //LPF.ar( x, energy.pow(4) * 20000 + 600 )
        HPF.ar( x, (energy).pow(3) * 1500 + 20 )
        * (energy + 0.4)
        * 0.5
    )
};
~grain_disintegrate.controls = [
    \buf -> Buffer,
    \max_intrv -> [0, 0.1, \lin],
    \grow -> [0.1, 2, \lin],
    \decay -> [3.1, 20, \lin]
];
);
(
~grain_disintegrate.map(\in, [~basic, 3, 1]);
);


/************************************
Granular, Trigger Amp (Freq?) Envelope
trigger => start envelope
trigger => choose rand pos

TRY:
different envelopes
large predelay (ghost trail, magic)
*************************************/

(
~grain_trigger_env = NodeDef { arg buf, interval = 0.02, dur = 0.1, trigger;
    var x;
    x = TGrains.ar (
        2,
        TDuty.ar(Dwhite(interval * 0.3, interval * 1.8)),
        buf,
        BufRateScale.ir(buf),
        Latch.kr( WhiteNoise.kr() * 0.4 + 0.5, trigger),
        dur,
        0.5,
        EnvGen.kr( Env.linen(0, 0, 4), trigger).squared * 0.5
    );
    //x = x * ;
    // Reverse amp envelope:
    // x = x * (0.5 - EnvGen.ar( Env.linen(0.03, 0, 2), trigger, 0.5));

    // Na trigger zamenjaj filter frekvenco:

    BPF.ar( x,
        Ramp.kr(
            TRand.kr(0, 1, trigger),
            2
        ).linexp(0,1,100, 15000),
        0.5
    );
};
~grain_trigger_env.controls = [
    \buf -> Buffer,
    \interval -> [0.01, 0.1, \exp],
    \dur -> [0.05, 0.2, \exp],
];
);
(
~grain_trigger_env.map(\trigger, [~trigger, 0]);
);

/************************************
Granular - Change sample on trigger
*************************************/
/*
(
SynthDef(\grain_env, { arg buf, interval = 0.02, dur = 0.1, pos;
    var x;
    x = GrainBuf.ar (
        2,
        TDuty.ar(Dwhite(interval * 0.3, interval * 1.8)),
        dur,
        buf,
        BufRateScale.ir(buf),
        pos
    );
    x = x * EnvGen.ar( Env.linen(0.03, 0, 2), 1, 0.5, doneAction:2);
}).send;
OSCFunc({ arg trig;
    "trig".postln;
    Synth(\grain_env, [
        \buf, ~buf_pool.at([\dvorak10,\dvorak11,\dvorak12].choose),
        \pos, 1.0.rand;
    ]);
}, "/trigger");
)
*/


/**************************************
Play patterns, control by movement
**************************************/

/*
(
~test_pattern = NodeDef { arg movement;
    SendReply.kr( Impulse.kr(5), '/movement', movement);
};
~test_pattern.map(\movement, ~busy);
)

(
var pattern;
var movement = 0.0;
OSCdef(\pattern_control, { arg msg;
	"bang".postln;
    movement = (msg[3] * 20 - 0.2).max(0).asInteger;
}, "/movement");

pattern = Pbind(*[
    degree: Pwhite(Pfunc({ 0-movement }), Pfunc({ movement })),
    dur: Prand(1 / [4,8], inf)
]);
pattern.play;
)
*/

/************************************
Distance
************************************/

(
~distance = NodeDef { arg buf, energy;
    var x, gesture;
    gesture = LagUD.kr((energy * 3).min(1), 0.1, 7);
    x = PlayBuf.ar(1, buf, loop:1);
    x = FreeVerb.ar(x, 0.9 - gesture.min(0.9), 0.2, 0);
    x = LPF.ar(x, gesture.linexp(0,1,700,20000));
    x = x * (gesture.min(0.2) + 0.8);
};
~distance.controls = [
    \buf -> Buffer
];
);
(
~distance.map(\energy, [~vector_smooth, 3, 1]);
);

/************************************
Distortion
************************************/
(
~distort = NodeDef { arg buf, x,y,z,energy;
    var a, b, gesture;
    gesture = LagUD.kr((energy - 0.1), 0.5, 5);
    a = PlayBuf.ar(1, buf, loop:1);
    b = a;
    b = b * SinOsc.ar([x,y,z].linexp(-1, 1, 30,2000)).reduce('*');
    b = (b * 3).softclip * 0.6;
    //b = BPF.ar(b, x.linexp(-0.8,0.8,100,3000), 5);
    XFade2.ar(b, a, gesture * 10 - 1);
};
);
~distort.controls = [
    \buf -> Buffer
];
(
~distort.map(\x, ~vector_smooth);
);

/************************************
Crowd vs. Isolation
movement => single loud <> all loud
tilt => pick one loud
************************************/
(
~crowd = NodeDef {
    arg buf1, buf2, buf3, amp1 = 1, amp2 = 1, amp3 = 1,
    threshold = 0.0018, grow = 0.8, attack = 0.5, decay = 7,
    vector = #[0,0,0], energy_in;

    var energy, a, b, amp;

    energy = (energy_in - threshold).max(0) * grow;
    energy = Decay2.kr(energy, attack, decay).min(1.0);

    a = PlayBuf.ar(1, [buf1, buf2, buf3], startPos: BufFrames.ir([buf1, buf2, buf3]) * 0.5, loop:1);
    b = PlayBuf.ar(1, [buf1, buf2, buf3], loop:1, );
    amp = [amp1,amp2,amp3];
    a = a * amp * ((energy - 0.1).max(0) * 1.5).min(1);
    b = b * amp * ((vector.abs * 2).squared + ((energy - 0.1).max(0) * 1.5)).min(1);
    Mix.ar(a ++ b);
};
~crowd.controls = [
    \buf1 -> Buffer,
    \buf2 -> Buffer,
    \buf3 -> Buffer,
    \amp1 -> [0.01, 1, \exp],
    \amp2 -> [0.01, 1, \exp],
    \amp3 -> [0.01, 1, \exp],
    \grow -> [0.1, 2, \lin],
    \decay -> [3.1, 20, \lin]
];
);
(
~crowd.map(
    \vector, [~vector_smooth, 0, 3],
    \energy_in, [~basic, 3, 1]
);
);

/************************************
Granular Stretch by Trigger
trigger -> toggle granular / normal
x -> granular pitch
************************************/

(
~stretch_trigger = NodeDef { arg buf, rate = 30, dur = 0.1, speed = -0.6, trigger, x, y, z;
    var pos, switch, reader, trig_env, grains, grain_pitch, grain_speed;

    //env = Env([0,1,1,0], [0,3,0]).kr(gate: trigger);
    //env = 0;

    switch = Stepper.kr(trigger, max: 1);

    trig_env =  Env([0,0,1], [0,0.7], 6).kr(gate: switch > 0);

    grain_pitch = trig_env * x;
    //grain_pitch = 0.2;

    //grain_speed = trig_env * y;
    grain_speed = speed;

    pos = Phasor.ar(
        start:0,
        end: BufFrames.ir(buf),
        rate: 1 + (switch * grain_speed),
    );

    reader = BufRd.ar(1, buf, pos);

    grains = TGrains.ar(
        2,
        Impulse.ar(rate),
        buf,
        2.pow(grain_pitch),
        pos * BufSampleRate.ir(buf).reciprocal,
        dur: dur,
        amp: 0.9
    );

    Select.ar(switch, [reader, grains]);
};
~stretch_trigger.controls = [
    \buf -> Buffer,
    \rate -> [10, 40, \exp],
    \dur -> [0.02, 0.2, \exp],
    \speed -> [-2, 2],
];
);
(
~stretch_trigger.map(
    \trigger, [~trigger, 0, 3],
    \x, [~vector_smooth, 0, 3]
);
);

/************************************
Granular Stretch by Tilt
tilt => stretch (grain buffer pos increment)
*************************************/

(
~stretch_tilt = NodeDef {
    arg buf,
    interval = 0.02, dur = 0.1,
    rate_scale = 2.5,
    rate_offset = 0.2,
    in;

    var rate, sound;

    rate = in * rate_scale + rate_offset;

    sound = TGrains.ar (
        2,
        TDuty.ar(Dwhite(interval * 0.3, interval * 1.8)),
        buf,
        BufRateScale.ir(buf),
        Phasor.ar(0, rate, 0, BufFrames.ir(buf), 0) * BufSampleRate.ir(buf).reciprocal,
        dur,
        0.5,
        0.5
    )
};
~stretch_tilt.controls = [
    \buf -> Buffer,
    \interval -> [0.01, 0.1, \exp],
    \dur -> [0.05, 0.2, \exp],
    \rate_scale -> [0.5, 5],
    \rate_offset -> [-1,1],
];
);

(
~stretch_tilt.map( \in, [~vector_smooth, 0, 1] );
)

/************************************
Word by Word Sentence
- pressure release => say next word
ALT:
- trigger => say next word
(Combined with speech crowd)
*************************************/
