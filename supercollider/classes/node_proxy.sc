NodeProxy2 {
    classvar link_group;

    var def, <source, <server;
    var <bus, synth_def, synth, public_synth;
    var <running = false, <playing = false;

    *new { arg def, source, server = (Server.default);
        ^super.newCopyArgs(def, source, server).init;
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
        synth_def = ProxySynthDef2(
            server.clientID.asString ++ "_proxy_" ++ this.identityHash.abs,
            def
        );
    }

    numChannels { ^synth_def.numChannels }

    rate { ^synth_def.rate }

    run { arg ...synth_args;
        var args, source_bus, source_node;
        if (not(running))
        {
            args = args ++ synth_args;

            if (source.notNil) {
                source_bus = source.bus;
                if (source_bus.notNil) { source_bus = source_bus.asBus };
                if (source_bus.isNil) {
                    warn("NodeProxy: source has no output, or it is not running.")
                };
                source_node = source.node;
            };

            if (this.numChannels > 0) {
                bus = Bus.alloc(this.rate, server, this.numChannels);
                args = args ++ [\out, bus.index]
            };

            args = args ++ synth_args;
            if (this.numChannels > 0) { args = args ++ [\out, bus.index] };

            if (source_node.notNil) {
                synth = synth_def.play(source_node, args, 'addAfter');
            }{
                synth = synth_def.play(server, args);
            };

            if (source_bus.notNil) {
                fork ({
                    server.sync;
                    synth.map(0, source.bus)
                }, SystemClock);
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
            if (this.numChannels > 0 && this.rate.notNil)
            {
                synth_func = this.rate.switch (
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
            synth.map(0, source_bus);
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
