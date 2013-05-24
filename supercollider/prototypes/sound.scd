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

/****************************
Granular Sample Stretch
****************************/

(
~grain_sample_stretch = NodeDef { arg x, y, z;
    var grains, framesInBuffer;
    var buf = ~b_have_to_be_hot;
    var interval, dur;
    interval = 0.02;
    dur = 0.1;

    grains = TGrains.ar (
        2,
        TDuty.ar(Dwhite(interval * 0.3, interval * 1.8)),
        buf,
        1, //BufRateScale.ir(buf),
        Phasor.ar(0, x * 2, 0, BufFrames.ir(buf), 0) / BufSampleRate.ir(buf),
        dur,
        0.5, // WhiteNoise.kr(0.6), // pan
        0.2 // amp
    );
    /*
    MoogFF.ar(
        grains, // source sound
        press.lincurve(0.5, 1, 40, 8000, 4, nil),
        2
    );
    */
};
~grain_sample_stretch.source = ~preproc_node;
)

/****************************
Granular Sample Travelling
****************************/

(
~grain_sample_travel_proto = { arg buf, pos, amp = 0.3;
    var grains, framesInBuffer;
    var interval, dur;
    interval = 0.02;
    dur = 0.1;

    grains = TGrains.ar (
        2,
        TDuty.ar(Dwhite(interval * 0.3, interval * 1.8)),
        buf,
        BufRateScale.ir(buf),
        pos * BufFrames.ir(buf) / BufSampleRate.ir(buf),
        dur,
        WhiteNoise.ar(0.6), // pan
        amp // amp
    );
};

~grain_sample_travel1 = NodeDef { arg x, y, z;
    ~grain_sample_travel_proto.value( ~b_cello_rough, x * 0.8, 0.2 );
};
~grain_sample_travel1.source = ~preproc_node;

~grain_sample_travel2 = NodeDef { arg x, y, z;
    ~grain_sample_travel_proto.value( ~b_cello_melody, y * 0.8, 0.6 );
};
~grain_sample_travel2.source = ~preproc_node;

~grain_sample_travel3 = NodeDef { arg x, y, z;
    ~grain_sample_travel_proto.value( ~b_hihat_bowed, z * 0.8, 0.2 );
};
~grain_sample_travel3.source = ~preproc_node;
)
