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

    sound = GrainBuf.ar (
        2,
        TDuty.ar(Dwhite(interval * 0.3, interval * 1.8)),
        dur,
        buf,
        BufRateScale.ir(buf),
        LFNoise1.kr(0.5) * 0.5 + 0.5;
    );
    sound = LPF.ar( sound, energy.pow(4) * 20000 + 200 ) * ((energy * 4).min(1) + 0.01) * 0.2;
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
    \interval -> [0.01, 0.1, \exp],
    \dur -> [0.05, 0.2, \exp],
    \grow -> [0.1, 2, \lin],
    \decay -> [3.1, 20, \lin]
];
);

(
~grain_reveal.map(\in, [~basic, 3, 1]);
~grain_reveal.set(\buf, ~bufs[\dvorak11]);
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
    \grow -> [0.1, 2, \lin],
    \decay -> [3.1, 20, \lin]
];
);
(
~grain_integrate.map(\in, [~basic, 3, 1]);
~grain_integrate.set(\buf, ~bufs[\dvorak12]);
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
    \max_intrv -> [0, 0.1, \lin],
    \grow -> [0.1, 2, \lin],
    \decay -> [3.1, 20, \lin]
];
);
(
~grain_disintegrate.map(\in, [~basic, 3, 1]);
~grain_disintegrate.set(\buf, ~bufs[\dvorak12]);
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
    \interval -> [0.01, 0.1, \exp],
    \dur -> [0.05, 0.2, \exp],
];
);
(
~grain_trigger_env.map(\trigger, [~trigger, 0]);
~grain_trigger_env.set(\buf, ~bufs[\dvorak10]);
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
        \buf, ~bufs.at([\dvorak10,\dvorak11,\dvorak12].choose),
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
);
(
~distance.map(\energy, [~vector_smooth, 3, 1]);
~distance.set(\buf, ~bufs[\pinkola_trigger]);
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

(
~distort.map(\x, ~vector_smooth);
~distort.set(\buf, ~bufs[\levy_sexualized])
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
~crowd.set(
    \buf1, ~bufs[\pinkola_not_like], \amp1, 1,
    \buf2, ~bufs[\pinkola_trigger], \amp2, 1,
    \buf3, ~bufs[\levy_bunny], \amp3, 0.7,
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
~stretch_trigger.set(\buf, ~bufs[\levy_bunny]);
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
    \interval -> [0.01, 0.1, \exp],
    \dur -> [0.05, 0.2, \exp],
    \rate_scale -> [0.5, 5],
    \rate_offset -> [-1,1],
];
);

(
~stretch_tilt.map( \in, [~vector_smooth, 0, 1] );
~stretch_tilt.set( \buf, ~bufs[\levy_sexualized] );
)

/************************************
Word by Word Sentence
- pressure release => say next word
ALT:
- trigger => say next word
(Combined with speech crowd)
*************************************/
