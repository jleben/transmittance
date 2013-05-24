/*****************************************************
Sequence of FM tones
- FM index controlled by tilt at trigger time
*****************************************************/

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

/*****************************************************
GrainFM:
- FM index and amp controlled by tilt
- trigger randomizes carrier frequency
******************************************************/
(
~grain_fm_proto = { arg freq = 440, ratio = 1, index = 0, dur = 0.1, amp = 0.1;
    GrainFM.ar(
        1,
        TDuty.ar(Dwhite(0.01,0.05)),
        dur,
        freq,
        freq * ratio,
        index * 20 / ratio + WhiteNoise.ar(2)
    )
    * LagUD.kr(amp, 0.1, 2);
};

~grain_fm_1 = NodeDef { arg x, y, z, tr;
   ~grain_fm_proto.value(
        freq: TRand.kr(200, 600, tr),
        ratio: 1.5,
        index: x.abs,
        amp: (x + 0.1).max(0) * 0.1;
    )
};
~grain_fm_1.source = ~preproc_node;

~grain_fm_2 = NodeDef { arg x, y, z, tr;
   ~grain_fm_proto.value(
        freq: TRand.kr(200, 600, tr),
        ratio: 0.5,
        index: y.abs,
        amp: (y + 0.1).max(0) * 0.1;
    )
};
~grain_fm_2.source = ~preproc_node;
)
