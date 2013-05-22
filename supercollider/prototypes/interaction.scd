(
// Assuming a MiniBee as source.
~trigger = NodeDef { arg press, x, y, z;
    var threshold = 0.15;

    var x0, x1, x2, trigger;
    var thresh_in, thresh_out;

    thresh_in = LocalIn.kr(1);

    x0 = (x - 0.5).abs + (y - 0.5).abs + (z - 0.5).abs;

    x1 = Delay1.kr(x0);
    //x2 = Delay1.kr(x1);
    trigger = (x0 < x1)
    * ((x1  * (1 - thresh_in)) > threshold )
    ;

    thresh_out =
    Env([0,1,0],[0,0.25],3).kr(gate:trigger);

    LocalOut.kr( thresh_out );

    //K2A.ar(x - 0.5);
    K2A.ar(trigger);
};
~trigger.source = ~bee;

~tilt = NodeDef { arg press, x,y,z;
	var coeff = 15;
	var in, tilt;
	in = ([x,y,z] - 0.5) * coeff;
	in = in / (1 + (in * in)).sqrt;
	tilt = LPF.kr( Lag.kr( in ), 5 );
	K2A.ar(tilt)
};
~tilt.source = ~bee;

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
