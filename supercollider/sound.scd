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

/************************************
Granular, Bring up volume by movement
movement => raise amp, filter

ADD:
tilt => center position
Količina gibanja => hitrost premikanja center position po sample-u.
*************************************/


(
~grain_reveal = NodeDef {
    arg buf, interval = 0.02, dur = 0.1,
    threshold = 0.002, grow = 0.7, attack = 3, decay = 15,
    in;

    var energy, sound;

    energy = (in - threshold).max(0) * grow;
    energy = Decay2.kr(energy, attack, decay).min(1.0);
    MonitorOut.kr(energy);

    sound = GrainBuf.ar (
        2,
        TDuty.ar(Dwhite(interval * 0.3, interval * 1.8)),
        dur,
        buf,
        BufRateScale.ir(buf),
        LFNoise1.kr(0.5) * 0.5 + 0.5;
    );
    sound = LPF.ar( sound, energy.pow(4) * 20000 + 200 ) * ((energy * 4).min(1) + 0.01) * 0.8;
    // Reverse filter and amp:
    /*
    x = (
        LPF.ar( x, (1 - movement).pow(4) * 20000 + 200 )
        * ( (1 - (movement * 1)).max(0) + 0.01)
        * 0.5;
    )
    */
};
~grain_reveal.controls = [
    \buf -> Buffer,
    \interval -> [0.01, 0.1, \exp],
    \dur -> [0.05, 0.2, \exp],
    \grow -> [0.1, 2, \lin],
    \decay -> [3.1, 20, \lin]
];
~grain_reveal.monitors = [ ControlSpec(0, 1, \lin) ];
);

(
~grain_reveal.map(\in, [~basic, 3, 1]);
);

/************************************
Granular Integration
- movement => integrate
- slow rand pos

IMPROVE: Raise volume when disintegrated!!
*************************************/
(
~grain_integrate = NodeDef {
    arg buf,
    threshold = 0.002, grow = 0.7, attack = 3, decay = 15,
    in;

    var energy, interval, dur, x;

    energy = (in - threshold).max(0) * grow;
    energy = Decay2.kr(energy, attack, decay).min(1.0);
    MonitorOut.kr(energy);

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
    );
};
~grain_integrate.controls = [
    \buf -> Buffer,
    \grow -> [0.1, 2, \lin],
    \decay -> [3.1, 20, \lin]
];
~grain_integrate.monitors = [ ControlSpec(0, 1, \lin) ];
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
    MonitorOut.kr(energy);

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
    );
};
~grain_disintegrate.controls = [
    \buf -> Buffer,
    \max_intrv -> [0, 0.1, \lin],
    \grow -> [0.1, 2, \lin],
    \decay -> [3.1, 20, \lin]
];
~grain_disintegrate.monitors = [ ControlSpec(0, 1, \lin) ];
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

IMPROVE: Use Decay instead of LagUD, expose controls
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
    MonitorOut.kr(energy);

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
~crowd.monitors = [ ControlSpec(0, 1, \lin) ];
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
);

/************************************
Word by Word
(Sample after sample - requires a collection of buffers);
- pressure release => say next word

(
ALTERNATIVE:
- trigger => say next word
(Combined with speech crowd)
)
*************************************/


(
~sampler = SynthProxy(
    \sampler,
    def: { arg buf;
        PlayBuf.ar(1, buf, doneAction:2);
    },
    init: { arg me;
        me.set(\threshold, 0.7);
        me.set(\samples, []);

        ~word = -1;

        ~run_task = {
            if (~task.isNil and: (~samples.size > 0)) {
                ~task = {
                    var proto_event = me.event;
                    var word_count = ~samples.size;
                    inf.do {
                        var buf, pause;
                        ~word = (~word + 1) % word_count;
                        buf = ~samples[~word];
                        pause = (buf.numFrames / buf.sampleRate);
                        Synth(me.name, [out: me.bus, buf: buf]);
                        pause.wait;
                    }
                }.fork(SystemClock);
            };
        };
        ~stop_task = {
            if (~task.notNil) { ~task.stop; ~task = nil };
        };

        ~task_controller =
        FuncProxy ({ arg pressure;
            me.set(\playing, pressure > ~threshold);
        });
        ~task_controller.source = ~bee;
    },
    run: {
        ~task_controller.run;
    },
    stop: {
        ~task_controller.stop;
        ~word = -1;
        ~stop_task.value;
    },

    update: { arg me, key, value;
        key.switch(
            \samples, {
                ~stop_task.value;
            },
            \playing, {
                if (me.running) {
                    if(value === true) {
                        ~run_task.value;
                    } {
                        ~stop_task.value;
                    };
                }
            },
            \gate, {
                if (me.running) {
                    if(value > 0.5) {
                        ~run_task.value;
                    } {
                        ~stop_task.value;
                    };
                }
            }
        )
    }
);
~sampler.controls = [
	\samples -> [Buffer],
    \gate -> [0,1]
];
);
