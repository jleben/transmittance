(
~trigger = NodeDef { arg x, y, z;
    var threshold = 0.015;

    var s, s0, mag, mag0, trigger;
    var thresh_in, thresh_out;

    s = [x,y,z] - 0.5;
    s0 = Delay1.kr(s);

    mag = s.squared.sum;
    mag0 = Delay1.kr(mag);

    thresh_in = LocalIn.kr(1);

    trigger = (mag < mag0)
    * ((mag0  * (1 - thresh_in)) > threshold )
    ;

    thresh_out =
    Env([0,1,0],[0,0.25],3).kr(gate:trigger);

    LocalOut.kr( thresh_out );

    SendReply.kr(trigger, '/trigger', s0);

    K2A.ar([trigger] ++ s0);
};
~trigger.source = ~bee;
)

(
~tilt = NodeDef { arg x,y,z;
    var coeff = 15;
    var in, tilt;
    in = ([x,y,z] - 0.5) * coeff;
    in = in / (1 + (in * in)).sqrt;
    tilt = LPF.kr( Lag.kr( in ), 5 );
    tilt;
};
~tilt.source = ~bee;
)

(
~busy = NodeDef { arg press, x, y, z;
    var grow = 0.02, attack = 1.5, decay = 10;
    var in, out;
    in = [x,y,z];
    in = ((in-0.5).abs - 0.04).max(0).sum * grow;
    out = Decay2.kr(in, attack, decay).min(1.0);
    K2A.ar(out);
};
~busy.source = ~bee;
)

(
~preproc_func = FuncDef ({ arg x, y, z;
    var raw, mag;

    raw = [x,y,z] - 0.5;

    mag = raw.squared.sum;

    raw ++ mag;
}, 4);

~preproc_func.source = ~bee;

~preproc_node = NodeDef { arg x, y, z, mag;
    var trigger_threshold = 0.015;
    var tilt_coeff = 20;

    var vec, vec0;
    var mag0;
    var tilt, tilt0;
    var thresh_in, thresh_out, trigger;


    vec = [x,y,z];

    vec0 = Delay1.kr(vec);
    mag0 = Delay1.kr(mag);

    // Tilt

    tilt = vec * tilt_coeff;
    tilt = tilt / (1 + (tilt * tilt)).sqrt;
    tilt0 = Delay1.kr(tilt);

    // Trigger

    thresh_in = LocalIn.kr(1);

    trigger = (mag < mag0)
    * ((mag0  * (1 - thresh_in)) > trigger_threshold )
    ;

    thresh_out =
    Env([0,1,0],[0,0.25],3).kr(gate:trigger);

    LocalOut.kr( thresh_out );
    SendReply.kr(trigger, '/trigger', tilt0);

    K2A.ar(tilt ++ trigger);
};

~preproc_node.source = ~preproc_func;
)
