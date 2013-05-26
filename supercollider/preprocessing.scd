(
var group;

~bee = MiniBee(id:2, numChannels: 3);

~basic = FuncDef ({ arg x, y, z;
    var raw, magnitude;

    raw = [x,y,z] - 0.5;

    magnitude = raw.squared.sum;

    raw ++ magnitude;
}, 4);
~basic.source = ~bee;

~vector_scaled = NodeDef { arg x, y, z, magnitude, scale = 15;
    var in = [x, y, z, magnitude];
    in = in * scale;
    in = in / (1 + (in * in)).sqrt;
};
~vector_scaled.map(0, ~basic);

~vector_slow = NodeDef { arg x, y, z, cutoff = 0.5;
    LPF.kr( [x,y,z], cutoff );
};
~vector_slow.map(0, [~vector_scaled, 0, 3]);

~vector_smooth = NodeDef { arg x, y, z, mag, cutoff = 15;
    LPF.kr( [x,y,z,mag], cutoff );
};
~vector_smooth.map(0, ~vector_scaled);

~busy = NodeDef { arg x, y, z, grow = 0.1, attack = 1.5, decay = 10;
    var in, out;
    in = [x,y,z];
    in = (in - Delay1.kr(in)).abs.sum * grow;
    out = Decay2.kr(in, attack, decay).min(1.0);
};
~busy.map(0, [~basic, 0, 3]);

~trigger = NodeDef { arg magnitude, scaled = #[0,0,0,0], threshold = 0.02;
    var magnitude1, scaled1;

    var thresh_in, thresh_out, trigger;


    magnitude1 = Delay1.kr(magnitude);
    scaled1 = Delay1.kr(scaled);

    // Trigger

    thresh_in = LocalIn.kr(1);

    trigger = (magnitude < magnitude1)
    * ((magnitude1  * (1 - thresh_in)) > threshold )
    ;

    thresh_out =
    Env([0,1,0],[0,0.25],3).kr(gate:trigger);

    LocalOut.kr( thresh_out );

    // Output

    SendReply.kr(trigger, '/trigger', scaled1);

    [trigger] ++ scaled1;
};
~trigger.map(\magnitude, [~basic, 3], \scaled, ~vector_scaled);

~run_preprocessing = {
    group = Group(Server.default, 'addBefore');
    ~bee.run;
    ~basic.run;
    ~vector_scaled.run(group);
    ~vector_slow.run(~vector_scaled, 'addAfter');
    ~vector_smooth.run(~vector_scaled, 'addAfter');
    ~busy.run(group);
    ~trigger.run(~vector_scaled, 'addAfter');
};

)
