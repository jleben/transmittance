NodeProxy2 {
    classvar link_group;

    var output_rate, output_count, def, <source, <server;
    var <bus, synth, public_synth;
    var <running = false, <playing = false;
    var make_synthdef;

    *new { arg output_rate=\control, output_count = (0), def, source, server = (Server.default);
        ^super.newCopyArgs(output_rate, output_count, def, source, server).init;
    }

    *initClass {
        Class.initClassTree(CmdPeriod);
        Class.initClassTree(ServerQuit);
        CmdPeriod.add(this);
        ServerQuit.add(this);
    }

    *linkGroup {
        if (link_group.isNil) { link_group = Group(addAction:'addToTail') };
        ^link_group;
    }

    *doOnCmdPeriod {
        link_group = nil;
    }

    *doOnServerQuit {
        link_group = nil;
    }

    init {
        make_synthdef = { arg def;
            case (
                { def.isKindOf(SynthDef) }, def,
                { def.isKindOf(Function) }, {
                    ProxySynthDef(
                        server.clientID.asString ++ "_proxy_" ++ this.identityHash.abs,
                        def,
                        nil,
                        nil,
                        false,
                        0,
                        output_count,
                        output_rate
                    )
                }
            )
        };
    }
    run { arg ...synth_args;
        var synth_def, in_bus;
        if (not(running))
        {
            if (source.notNil) {
                in_bus = source.bus;
                if (in_bus.notNil) { in_bus = in_bus.asBus };
                if (in_bus.isNil) { warn("Processor: source has no bus (it's not running?)") }
            };

            if (output_count > 0) {
                bus = Bus.alloc(output_rate, server, output_count);
            };

            if (def.notNil)
            {
                synth_def = make_synthdef.(def);

                if (synth_def.isNil) {
                    warn("Processor: can not use this processing definition.")
                }{
                    synth_def.send(server);

                    fork({
                        var args, source_node;
                        server.sync;
                        //args = [\input_bus, in_bus.index];
                        if (output_count > 0) { args = args ++ [\out, bus.index] };
                        args = args ++ synth_args;
                        if (source.notNil and: { source.node.notNil }) {
                            synth = Synth.after(source.node, synth_def.name, args);
                        }{
                            synth = Synth(synth_def.name, args, server);
                        };
                        if (in_bus.notNil) { synth.map(\in, source.bus) };
                    }, SystemClock);
                }
            };

            CmdPeriod.add(this);
            running = true;
        }
    }

    stop {
        if(running) {
            if (bus.notNil) { bus.free; bus = nil };
            synth.free;
            if (playing) { public_synth.free };
            CmdPeriod.remove(this);
            running = false;
            playing = false;
        }
    }

    play { arg bus_index = (0);
        var synth_func;
        this.run;
        if (not(playing)) {
            if (output_count > 0)
            {
                synth_func = output_rate.switch (
                    \audio, `{ Out.ar( bus_index, In.ar(bus.index, bus.numChannels) ) },
                    \control, `{ Out.kr( bus_index, In.kr(bus.index, bus.numChannels) ) }
                );
                if (synth_func.notNil) {
                    public_synth = synth_func.play(NodeProxy2.linkGroup);
                    playing = true;
                }{
                    Error("Processor: invalid output rate!").throw;
                }
            }{
                warn("Processor: trying to play, but have no output!")
            }
        }
    }

    source_ { arg object;
        var source_bus;
        source = object;
        if (running) {
            if (source.notNil) {
                source_bus = source.bus;
                if (source_bus.notNil) { source_bus = source_bus.asBus };
                if (source_bus.isNil) { warn("Processor: source has no bus (it's not running?)") }
            };
            synth.map(\in, source_bus);
        }
    }

    node {
        ^ if (running, synth);
    }

    doOnCmdPeriod {
        if (bus.notNil) { bus.free; bus = nil };
        CmdPeriod.remove(this);
        running = false;
        playing = false;
    }
}

N : NodeProxy2 {}
