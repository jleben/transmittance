(
var group;

~bee = MiniBee(id:2, numChannels: 3);

~preproc_func = FuncDef ({ arg x, y, z;
    var raw, energy;

    raw = [x,y,z] - 0.5;

    energy = raw.squared.sum;

    raw ++ energy;
}, 4);
~preproc_func.source = ~bee;

~scaled = NodeDef { arg x, y, z, energy;
    var coeff = 15;
    var in = [x, y, z, energy];
    in = in * coeff;
    in = in / (1 + (in * in)).sqrt;
};
~scaled.map(0, ~preproc_func);

~tilt = NodeDef { arg x, y, z;
    LPF.kr( [x,y,z], 0.5 );
};
~tilt.map(0, [~scaled, 0, 3]);

~trigger = NodeDef { arg energy, scaled = #[0,0,0,0];
    var trigger_threshold = 0.015;

    var energy1, scaled1;

    var thresh_in, thresh_out, trigger;


    energy1 = Delay1.kr(energy);
    scaled1 = Delay1.kr(scaled);

    // Trigger

    thresh_in = LocalIn.kr(1);

    trigger = (energy < energy1)
    * ((energy1  * (1 - thresh_in)) > trigger_threshold )
    ;

    thresh_out =
    Env([0,1,0],[0,0.25],3).kr(gate:trigger);

    LocalOut.kr( thresh_out );

    // Output

    SendReply.kr(trigger, '/trigger', scaled1);

    [trigger] ++ scaled1;
};
~trigger.map(\energy, [~preproc_func, 3], \scaled, ~scaled);

~run_preprocessing = {
    group = Group(Server.default, 'addBefore');
    ~bee.run;
    ~preproc_func.run;
    ~scaled.run(group);
    ~tilt.run(~scaled, 'addAfter');
    ~trigger.run(~scaled, 'addAfter');
};

)
