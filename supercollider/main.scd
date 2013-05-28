
Server.default.options.numOutputBusChannels = 6;
PatchEnvironment().push;
~dir = PathName(thisProcess.nowExecutingPath).pathOnly;

this.executeFile(~dir +/+ "preprocessing.scd");

(
var dir = ~dir +/+ "../samples";
var files = IdentityDictionary[
	\dvorak10 -> "sadsamlucky/dvorak10.wav",
	\dvorak11 -> "sadsamlucky/dvorak11.wav",
	\dvorak12 -> "sadsamlucky/dvorak12.wav",
	\levy_bunny -> "speech_long/ariel_levy_bunny.wav",
	\levy_sexualized -> "speech_long/ariel_levy_heavily_sexualized.wav",
	\pinkola_not_like -> "speech_long/pinkola_not_like_40s.wav",
	\pinkola_trigger -> "speech_long/pinkola_trigger_40s.wav"
];
~bufs = IdentityDictionary();
files.keysValuesDo { |key, path, idx|
	~bufs.put(key, Buffer.readChannel(Server.default, dir +/+ path, channels:0, bufnum: idx));
};
)

~busy.map(\grow, 1, \decay, 5);

/************************************
Granular, Bring up volume by movement
movement => raise amp, filter
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
Granular, Trigger Amp (Freq?) Envelope
trigger => start envelope
trigger => choose rand pos
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

/************************************
Speech - bring closer from distance
************************************/

(
~speech_distance = NodeDef { arg buf, energy;
    var x, gesture;
    gesture = LagUD.kr((energy * 3).min(1), 0.1, 5);
    x = PlayBuf.ar(1, buf, loop:1);
    x = FreeVerb.ar(x, 0.9 - gesture.min(0.9), 0.2, 0);
    x = LPF.ar(x, gesture.linexp(0,1,700,20000));
    x = x * (gesture.min(0.2) + 0.8);
};
~speech_distance.map(
    \buf, ~bufs[\pinkola_trigger],
    \energy, [~vector_smooth, 3, 1]
);
)

/************************************
Speech - undistort
************************************/
(
~speech_distort = NodeDef { arg buf, x,y,z,energy;
    var a, b, gesture;
    gesture = LagUD.kr((energy - 0.1), 0.5, 5);
    a = PlayBuf.ar(1, buf, loop:1);
    b = a;
    b = b * SinOsc.ar([x,y,z].linexp(-1, 1, 30,2000)).reduce('*');
    b = (b * 3).softclip * 0.6;
    //b = BPF.ar(b, x.linexp(-0.8,0.8,100,3000), 5);
    XFade2.ar(b, a, gesture * 10 - 1);
};
)

(
~speech_distort.map(
    \buf, ~bufs[\levy_sexualized],
    \x, ~vector_smooth
);
)

/************************************
Speech Crowd
busy => single loud <> all loud
tilt => pick one loud
************************************/
(
~speech_crowd = NodeDef { arg buf1, buf2, buf3, vector = #[0,0,0], busy;
    var a, b, amp;
    a = PlayBuf.ar(1, [buf1, buf2, buf3], startPos: BufFrames.ir([buf1, buf2, buf3]) * 0.5, loop:1);
    b = PlayBuf.ar(1, [buf1, buf2, buf3], loop:1, );
    amp = [1,1,0.5];
    a = a * amp * ((busy - 0.1).max(0) * 2.5).min(1);
    b = b * amp * ((vector.abs * 3).squared + ((busy - 0.1).max(0) * 2)).min(1);
    Mix.ar(a ++ b);
}
);
(
~speech_crowd.map(
    \buf1, ~bufs[\pinkola_not_like],
    \buf2, ~bufs[\pinkola_trigger],
    \buf3, ~bufs[\levy_bunny],
    \vector, [~vector_smooth, 0, 3],
    \busy, ~busy

)
)

/************************************
Speech Crowd
Trigger => make one loud
Trigger Direction => choose which one
************************************/

(
~speech_crowd_reverse = NodeDef { arg buf1, buf2, buf3, trigger, x, y, z;
    var a, b, trig_x, trig_y, trig_z, envs, amps;
    a = PlayBuf.ar(1, [buf1, buf2, buf3], loop:1, startPos: BufFrames.ir([buf1, buf2, buf3]) * 0.5 );
    b = PlayBuf.ar(1, [buf1, buf2, buf3], loop:1 );
    amps = [1,1,0.5];

    TRand.kr(0,2, trigger);
    x = x.abs;
    y = y.abs;
    z = z.abs;
    trig_x = trigger * (x > y) * (x > z);
    trig_y = trigger * (y > x) * (y > z);
    trig_z = trigger * (z > x) * (z > y);

    envs = Env([0,1,1,0],[0.5,2,2]).kr(gate: [trig_x, trig_y, trig_z]);
    a = a * (envs + 0.05);
    b = b * 0.05;
    Mix.ar(a ++ b);
}
);
(
~speech_crowd_reverse.map(
    \buf1, ~bufs[\pinkola_not_like],
    \buf2, ~bufs[\pinkola_trigger],
    \buf3, ~bufs[\levy_bunny],
    \trigger, ~trigger,
)
)

/************************************
Speech Crowd
busy => raise one random sample's volume
************************************/

(
~speech_crowd_reverse_smooth = NodeDef { arg buf1, buf2, buf3, busy;
    var a, b, xfade, envs, amps;
    a = PlayBuf.ar(1, [buf1, buf2, buf3], loop:1, startPos: BufFrames.ir([buf1, buf2, buf3]) * 0.5 );
    b = PlayBuf.ar(1, [buf1, buf2, buf3], loop:1 );

    amps = [1,0.5,0.5];

    //xfade = LFNoise1.kr(0.2) * 3 + 3;
    xfade = Ramp.kr( TIRand.kr(0,2,Impulse.kr(0.3)), 0.5);
    envs = [
       (0 - xfade).abs,
       (1 - xfade).abs,
       (2 - xfade).abs,
    ];
    envs = (1 - (envs)).sqrt.max(0);

    a = a * amps * 0.05;
    b = Mix.ar( b * amps * (envs) )  * (busy.squared + 0.05);

    Mix.ar(a ++ b);
}
);
(
~speech_crowd_reverse_smooth.map(
    \buf1, ~bufs[\pinkola_trigger],
    \buf2, ~bufs[\levy_sexualized],
    \buf3, ~bufs[\levy_bunny],
    \busy, ~busy,
)
)

/************************************
Toggle Granular:
trigger -> toggle granular / normal
x -> granular pitch

************************************/

(
~granulize_triggered = NodeDef { arg buf, trigger, x, y, z;
    var pos, switch, reader, trig_env, grains, grain_pitch, grain_speed;

    //env = Env([0,1,1,0], [0,3,0]).kr(gate: trigger);
    //env = 0;

    switch = Stepper.kr(trigger, max: 1);

    trig_env =  Env([0,0,1], [0,0.7], 6).kr(gate: switch > 0);

    grain_pitch = trig_env * x;
    //grain_pitch = 0.2;

    //grain_speed = trig_env * y;
    grain_speed = -0.6;

    pos = Phasor.ar(
        start:0,
        end: BufFrames.ir(buf),
        rate: 1 + (switch * grain_speed),
    );

    reader = BufRd.ar(1, buf, pos);

    grains = TGrains.ar(
        2,
        Impulse.ar(30),
        buf,
        2.pow(grain_pitch),
        pos * BufSampleRate.ir(buf).reciprocal,
        dur: 0.1,
        amp: 0.9
    );

    Select.ar(switch, [reader, grains]);
}
)
(
~granulize_triggered.map(
    \buf, ~bufs[\levy_bunny],
    \trigger, [~trigger, 0, 3],
    \x, [~vector_smooth, 0, 3]
)
)

/////////// PLAY CONTROL ///////////////

~run_preprocessing.value;

~speech_distance.play
~speech_distance.stop;

~speech_distort.play
~speech_distort.stop;

~speech_crowd.play;
~speech_crowd.stop;

~speech_crowd_reverse.play;
~speech_crowd_reverse.stop;

~speech_crowd_reverse_smooth.play;
~speech_crowd_reverse_smooth.stop;

~granulize_triggered.play;
~granulize_triggered.stop;

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