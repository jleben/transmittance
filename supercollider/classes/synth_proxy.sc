SynthProxy {
    classvar link_group;

    var <>name, init_func, run_func, stop_func, <def;
    var <mappings, environment, <>controls;
    var <bus, synth_def;
    var <server, server_target, server_order;
    var public_synth_def, public_synth, public_bus_index, <volume = 1.0;
    var <running = false, <playing = false;
    ///
    var cleanup;

    *new { arg name, def, init, run, stop;
        ^super.newCopyArgs(name, init, run, stop).init(def);
    }

    *initClass {
        Class.initClassTree(CmdPeriod);
        Class.initClassTree(ServerQuit);
        CmdPeriod.add(this);
        ServerQuit.add(this);
    }

    *linkGroup {
        if (link_group.isNil) {
            link_group = Group(Server.default.defaultGroup, addAction:'addAfter')
        };
        ^link_group;
    }

    *doOnCmdPeriod {
        link_group = nil;
    }

    *doOnServerQuit {
        link_group = nil;
    }

    init { arg def_;

        cleanup = {
            if (bus.notNil) { bus.free; bus = nil };
            CmdPeriod.remove(this);
            public_synth = nil;
            running = false;
            playing = false;
            this.changed(\bus);
            environment.use { stop_func.value(this) };
        };

        mappings = IdentityDictionary();
        environment = Environment(proto: mappings, parent: currentEnvironment);
        this.def = def_;

        environment.use { init_func.value(this) };
    }

    def_ { arg function;
        var sdef, was_running, was_playing;

        sdef = ProxySynthDef2 (
            // set name later, when running
            //server.clientID.asString ++ "_proxy_" ++ this.identityHash.abs,
            nil,
            function
        );

        def = function;
        synth_def = sdef;
    }

    numChannels { ^synth_def.numChannels }

    rate { ^synth_def.rate }

    set { arg key, value;
        mappings.put(key, value);
    }

    run {
        var server = Server.default;

        if (running) { ^this };

        if (this.numChannels > 0) {
            bus = Bus.alloc(this.rate, server, this.numChannels);
        };

        synth_def.name = (
            name !? { name.asString }
            ?? { "proxy_" ++ this.identityHash.abs ++  server.clientID.asString };
        );
        synth_def.add;

        CmdPeriod.add(this);

        running = true;

        this.changed(\bus);

        environment.use { run_func.value(this) };
    }

    stop {
        if(not(running)) { ^this };
        if (playing) { public_synth.free };
        cleanup.value;
    }

    play { arg bus_index = (0);
        var synth_func;

        public_bus_index = bus_index;

        this.run;

        if (playing) {
            public_synth.set(*[out: public_bus_index]);
            ^this;
        };

        if (this.numChannels > 0 && this.rate.notNil)
        {
            var in_bus_index, num_channels, play_def, play_def_name;

            in_bus_index = bus.index;
            num_channels = bus.numChannels;

            this.rate.switch (
                \audio, {
                    play_def_name = "audio_proxy_player_" ++ num_channels;
                    play_def = SynthDef(play_def_name, {
                        Out.ar( \out.kr, In.ar(\bus.ir, num_channels) * \volume.kr )
                    })
                },
                \control, {
                    play_def_name = "control_proxy_player_" ++ num_channels;
                    play_def = SynthDef(play_def_name, {
                        Out.ar( \out.kr, K2A.ar( In.kr(\bus.ir, num_channels) * \volume.kr ) )
                    });
                }
            );

            if (play_def.notNil) {
                public_synth = play_def.play (
                    NodeProxy2.linkGroup,
                    args: [out: public_bus_index, bus: in_bus_index, volume: volume.squared]
                );
                playing = true;
            }{
                Error("Processor: invalid output rate!").throw;
            }
        }{
            warn("Processor: trying to play, but have no output!")
        }
    }

    volume_ { arg value;
        volume = value.clip(0,1);
        if (playing) { public_synth.set(\volume, volume.squared) };
    }

    event { ^ (instrument: name, out: bus).proto_(mappings) }

    silence {
        if (playing) {
            public_synth.free;
            playing = false;
        }
    }

    doOnCmdPeriod {
        cleanup.value;
    }
}
