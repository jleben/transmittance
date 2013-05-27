
Server.default.options.numOutputBusChannels = 6;
PatchEnvironment().push;
~dir = PathName(thisProcess.nowExecutingPath).pathOnly;

this.executeFile(~dir +/+ "preprocessing.scd");
PathName("/home/jakob/projects/transmittance_u3").folders
(
var dir = ~dir +/+ "../samples";
var files = IdentityDictionary[
	\dvorak10 -> "sadsamlucky/dvorak10.wav",
	\dvorak11 -> "sadsamlucky/dvorak11.wav",
	\dvorak12 -> "sadsamlucky/dvorak12.wav"
];
~bufs = IdentityDictionary();
files.keysValuesDo { |key, path, idx|
	~bufs.put(key, Buffer.readChannel(Server.default, dir +/+ path, channels:0, bufnum: idx));
};
)

~busy.map(\grow, 0.5);

/************************************
Granular:
- slow random pos
- movement -> filter, amp
*************************************/

(
~test = NodeDef { arg buf, interval = 0.02, dur = 0.1, movement;
    var x;
    x = GrainBuf.ar (
        2,
        TDuty.ar(Dwhite(interval * 0.3, interval * 1.8)),
        dur,
        buf,
        BufRateScale.ir(buf),
        LFNoise1.kr(0.5) * 0.5 + 0.5;
    );
    x = LPF.ar( x, movement.pow(4) * 20000 + 200 ) * ((movement * 4).min(1) + 0.01) * 0.2;
    // Reverse filter and amp:
    /*
    x = (
        LPF.ar( x, (1 - movement).pow(4) * 20000 + 200 )
        * ( (1 - (movement * 1)).max(0) + 0.01)
        * 0.5;
    )
    */
};
~test.map(\buf, ~bufs[\dvorak10]);
~test.map(\movement, [~busy, 0]);
)

/************************************
Granular:
- trigger -> envelope, rand pos
*************************************/

(
~test2 = NodeDef { arg buf, interval = 0.02, dur = 0.1, trigger;
    var x;
    x = GrainBuf.ar (
        2,
        TDuty.ar(Dwhite(interval * 0.3, interval * 1.8)),
        dur,
        buf,
        BufRateScale.ir(buf),
        Latch.kr( WhiteNoise.kr() * 0.5 + 0.5, trigger);
    );
    x = x * EnvGen.ar( Env.linen(0.03, 0, 2), trigger, 0.5);
    // Reverse amp envelope:
    // x = x * (0.5 - EnvGen.ar( Env.linen(0.03, 0, 2), trigger, 0.5));

    /*
    Na trigger zamenjaj filter frekvenco.
    Problem: preskok iz ene v drugo je slišen.
    BPF.ar( x,
        Lag.kr(
            TRand.kr(0, 1, trigger).linexp(0,1,100, 15000),
            1
        ),
        0.5
    );
    */
    //x = LPF.ar( x, movement.pow(4) * 20000 + 200 ) * ((movement * 4).min(1) + 0.01) * 0.2;
};
~test2.map(\buf, ~bufs[\dvorak10]);
~test2.map(\trigger, [~trigger, 0]);
)

/*
//Change sample on trigger;
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

/************************************
Granular Disintegration
- slow rand pos
- movement -> filter
- movement -> dur
*************************************/
(
~test3 = NodeDef { arg buf, interval = 0.05, dur = 0.005, movement;
    var x;
    interval = (1 - movement).squared * 0.07  + 0.02;
    x = GrainBuf.ar (
        2,
        TDuty.ar(Dwhite(interval * 0.3, interval * 1.8)),
        dur + (movement * 0.4),
        buf,
        BufRateScale.ir(buf),
        LFNoise1.kr(0.1) * 0.5 + 0.5;
    );
    x = (
        //LPF.ar( x, movement.pow(4) * 20000 + 600 )
        HPF.ar( x, (1 - movement).pow(3) * 1500 + 50 )
        * ((movement * 1).min(1) + 0.4)
        * 0.5
    )
};
~test3.map(\buf, ~bufs[\dvorak12]);
~test3.map(\movement, [~busy, 0]);
)

/**************************************
Play patterns, control by movement
**************************************/

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
    movement = (msg[3] * 20 - 0.2).max(0).asInteger;
}, "/movement");

pattern = Pbind(*[
    degree: Pwhite(Pfunc({ 0-movement }), Pfunc({ movement })),
    dur: Prand(1 / [4,8], inf)
]);
pattern.play;
)

/////////// PLAY CONTROL ///////////////

~run_preprocessing.value;

~test.play
~test2.play
~test3.play
~test_pattern.run;


/*
(
~grain_fm_1 = ~grain_fm.value;
~grain_fm_1.map(\ratio, 2.123, \dur, 0.5);
~grain_fm_1.map(\accel, [~vector_slow, 0], \trigger, [~trigger, 0]);

~grain_fm_2 = ~grain_fm.value;
~grain_fm_2.map(\ratio, 1.532, \dur, 0.5);
~grain_fm_2.map(\accel, [~vector_slow, 1], \trigger, [~trigger, 0]);

~girls_have_to_be_hot = ~granular_stretch.value;
~girls_have_to_be_hot.map(\buf, ~b_have_to_be_hot, \accel, 0.1);
~girls_have_to_be_hot.map(\buf, ~b_have_to_be_hot, \accel, [~scaled, 0]);

~granular_seek_1 = ~granular_seek.value;
~granular_seek_1.map(\buf, ~b_have_to_be_hot, \accel, [~vector_scaled, 0]);
)



(
~grain_fm_1.play;
~grain_fm_2.play;
)
(
~grain_fm_1.stop;
~grain_fm_2.stop;
)

~girls_have_to_be_hot.play;
~girls_have_to_be_hot.stop

~granular_seek_1.play;
~granular_seek_1.stop;
*/