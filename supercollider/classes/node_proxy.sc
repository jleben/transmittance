NodeProxy2 {
    classvar link_group;

    var <def, <source, <server;
    var <bus, synth_def, synth_params, synth;
    var public_synth_def, public_synth, public_bus_index;
    var <running = false, <playing = false;
    ///
    var make_synth_def, remap, cleanup;

    *new { arg def, source, server = (Server.default);
        ^super.newCopyArgs(nil, source, server).init(def);
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

    init { arg def_;

        make_synth_def = { arg function, server;
            ProxySynthDef2 (
                server.clientID.asString ++ "_proxy_" ++ this.identityHash.abs,
                function
            )
        };

        remap = {
            var source_bus, source_channels, own_channels;
            if (running) {
                own_channels = synth_def.controls.size;
                source_channels = 0;
                // remap source channels
                if (source.notNil && { source.running } ) {
                    source_bus = source.bus;
                    if (source_bus.notNil) { source_bus = source_bus.asBus };
                    if (source_bus.isNil) {
                        warn("NodeProxy2: source has no output.")
                    }{
                        synth.map(0, source_bus);
                        source_channels = source_bus.numChannels;
                    }
                };
                // unmap the rest
                if (own_channels > source_channels) {
                    synth.mapn(source_channels, -1, own_channels - source_channels);
                };
            }
        };

        cleanup = {
            if (bus.notNil) { bus.free; bus = nil };
            if (source.notNil) { source.removeDependant(this) };
            synth_params.clear;
            CmdPeriod.remove(this);
            synth = nil;
            public_synth = nil;
            running = false;
            playing = false;
            this.changed(\bus);
        };

        synth_params = IdentityDictionary();
        this.def = def_;
    }

    def_ { arg function;
        var sdef, was_running, was_playing, params;

        sdef = make_synth_def.value(function, server);

        def = function;
        synth_def = sdef;

        was_running = running;
        was_playing = playing;
        params = synth_params.asKeyValuePairs;

        this.stop;

        case
        { was_playing } {
            this.play( public_bus_index, *params );
        }
        { was_running } {
            this.run( *params );
        };
    }

    source_ { arg object;
        var old_source;
        if (source == object) { ^this };
        old_source = source;
        source = object;
        if (running) {
            remap.value;
            if (old_source.notNil) { source.removeDependant(this) };
            if (source.notNil) { source.addDependant(this) };
        }
    }

    setAll { arg def_, source_, server_ = (Server.default);
        var sdef, was_running, was_playing, params;

        sdef = make_synth_def.value(def_, server_);

        was_running = running;
        was_playing = playing;
        params = synth_params.asKeyValuePairs;

        this.stop;

        server = server_;
        def = def_;
        synth_def = sdef;
        source = source_;

        case
        { was_playing } {
            this.play( public_bus_index, *params );
        }
        { was_running } {
            this.run( *params );
        };
    }

    numChannels { ^synth_def.numChannels }

    rate { ^synth_def.rate }

    parameters { ^synth_params.asKeyValuePairs }

    run { arg ...parameters;
        var args, source_bus, source_node, server_target, server_add_action, map_msg, play_bundle;

        if (running) {
            this.set(*parameters);
            ^this;
        };

        if (source.notNil) {
            source_node = source.node;
            source_bus = source.bus;
            if (source_bus.notNil) { source_bus = source_bus.asBus };
            if (source_bus.isNil) {
                warn("NodeProxy: source has no output, or it is not running.")
            };
        };

        if (source_node.notNil) {
            server_target = source.node;
            server_add_action = 'addAfter';
        }{
            server_target = server.defaultGroup;
            server_add_action = 'addToHead';
        };

        if (this.numChannels > 0) {
            bus = Bus.alloc(this.rate, server, this.numChannels);
            args = args ++ [\out, bus.index]
        };

        args = args ++ parameters;

        synth = Synth.basicNew(synth_def.name, server);

        play_bundle = [nil];

        play_bundle = play_bundle.add( synth.newMsg(server_target, args, server_add_action) );

        if (source_bus.notNil) {
            map_msg = synth.mapMsg(0, source_bus);
            if (map_msg[0].isString) {
                play_bundle = play_bundle.add( map_msg );
            }{
                play_bundle = play_bundle.addAll( map_msg );
            };
        };

        synth_def.send(server, play_bundle);

        CmdPeriod.add(this);

        if (source.notNil) { source.addDependant(this) };

        running = true;

        synth_params.putPairs( parameters );

        this.changed(\bus);
    }

    set { arg ...parameters;
        if (running && (parameters.size > 0)) {
            synth.set(*parameters);
            synth_params.putPairs( parameters );
        };
    }

    play { arg bus_index = (0) ...parameters;
        var synth_func;

        public_bus_index = bus_index;

        this.run(*parameters);

        if (playing) {
            public_synth.set(*[out: bus_index]);
            ^this;
        };

        if (this.numChannels > 0 && this.rate.notNil)
        {
            synth_func = this.rate.switch (
                \audio, `{ Out.ar( \out.kr, In.ar(bus.index, bus.numChannels) ) },
                \control, `{ Out.kr( \out.kr, In.kr(bus.index, bus.numChannels) ) }
            );
            if (synth_func.notNil) {
                public_synth = synth_func.play(NodeProxy2.linkGroup, args: [out: bus_index]);
                playing = true;
            }{
                Error("Processor: invalid output rate!").throw;
            }
        }{
            warn("Processor: trying to play, but have no output!")
        }
    }

    update { arg object, what;
        if (object == source) {
            what.switch (
                \bus, remap
            );
        }
    }

    node {
        ^ if (running, synth);
    }

    stop {
        if(not(running)) { ^this };
        synth.free;
        if (playing) { public_synth.free };
        cleanup.value;
    }

    doOnCmdPeriod {
        cleanup.value;
    }
}

N : NodeProxy2 {}
