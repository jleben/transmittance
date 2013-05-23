/*****************************************************
Sequence of FM tones
Modulation index controlled by tilt at trigger time
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
