NodeProxy2 {
    classvar link_group;

    var <>name, <def, source;
    var <bus, synth_def, synth_params, synth;
    var <server, server_target, server_order;
    var public_synth_def, public_synth, public_bus_index;
    var <running = false, <playing = false;
    ///
    var make_synth_def,
    make_source_dependence, remove_source_dependence,
    map_source_msg_bundle, remap,
    cleanup;

    *new { arg name, def, source;
        ^super.newCopyArgs(name, nil, source).init(def);
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

        make_synth_def = { arg function;
            ProxySynthDef2 (
                // set name later, when running
                //server.clientID.asString ++ "_proxy_" ++ this.identityHash.abs,
                nil,
                function
            )
        };

        make_source_dependence = {
            source.do { |src|
                if (src.notNil) { src.addDependant(this) };
            }
        };

        remove_source_dependence = {
            source.do { |src|
                if (src.notNil) { src.removeDependant(this) };
            }
        };

        map_source_msg_bundle =
        {
            arg node;

            var bundle = List();
            var input_idx = 0;
            var own_channels;

            own_channels = synth_def.numInputs;

            source.do { |src, src_idx|
                var bus, src_channels;
                src_channels = src.numChannels ? 0;
                if (src_channels < 1) {
                    warn("NodeProxy2: source % has no output.".format(src_idx));
                }{
                    if (not(src.running)) {
                        // Avoid warning on remapping due source being stopped:
                        //warn("NodeProxy2: source % is not running.", src_idx);
                    } {
                        bus = src.bus;
                        if (bus.notNil) { bus = bus.asBus };
                        if (bus.isNil) {
                            warn("NodeProxy2: source % does not provide a bus.".format(src_idx));
                        }
                    };
                };
                if (bus.notNil)
                {
                    bus.rate.switch (
                        \control,
                        {
                            bundle.add([
                                "/n_mapn",
                                node.nodeID,
                                input_idx,
                                bus.index,
                                src_channels
                            ]);
                        },
                        \audio,
                        {
                            bundle.add([
                                "/n_mapan",
                                node.nodeID,
                                input_idx,
                                bus.index,
                                src_channels
                            ]);
                        }
                    );
                }{
                    bundle.add([
                        "/n_mapn",
                        node.nodeID,
                        input_idx,
                        -1,
                        src_channels
                    ])
                };
                input_idx = input_idx + src_channels;
            };

            if (own_channels > input_idx)
            {
                bundle.add([
                    "/n_mapn",
                    node.nodeID,
                    input_idx,
                    -1,
                    own_channels - input_idx;
                ])
            };

            bundle.array; // return
        };

        remap = {
            var map_msg_bundle;
            if (running) {
                map_msg_bundle = map_source_msg_bundle.value(synth);
                server.sendBundle(nil, *map_msg_bundle);
            };
        };

        cleanup = {
            if (bus.notNil) { bus.free; bus = nil };
            remove_source_dependence.value;
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

        sdef = make_synth_def.value(function);

        def = function;
        synth_def = sdef;

        was_running = running;
        was_playing = playing;
        params = synth_params.asKeyValuePairs;

        this.stop;

        case
        { was_playing } {
            this.play( public_bus_index, params, server_target, server_order );
        }
        { was_running } {
            this.run( params, server_target, server_order );
        };
    }

    source { ^source.copy }

    source_ { arg object;
        var old_source;
        if (source == object) { ^this };
        remove_source_dependence.value;
        source = object;
        if (running) {
            remap.value;
            make_source_dependence.value;
        }
    }

    setAll { arg def_, source_;
        var sdef, was_running, was_playing, params;

        sdef = make_synth_def.value(def_);

        was_running = running;
        was_playing = playing;
        params = synth_params.asKeyValuePairs;

        this.stop;

        def = def_;
        synth_def = sdef;
        this.source = source_;

        case
        { was_playing } {
            this.play( public_bus_index, params, server_target, server_order );
        }
        { was_running } {
            this.run( params, server_target, server_order );
        };
    }

    numChannels { ^synth_def.numChannels }

    rate { ^synth_def.rate }

    parameters { ^synth_params.asKeyValuePairs }

    run { arg parameters, target, order;
        var args, play_bundle, play_target, play_order;

        if (running) {
            this.set(*parameters);
            ^this;
        };

        server_target = target;
        server_order = order;

        if (target.class === NodeProxy2) {
            play_target = target.node
        }{
            play_target = target ?? { Server.default.defaultGroup };
        };

        play_order = order ? 'addToHead';

        server = play_target.server;

        synth_def.name = (
            name !? { name.asString }
            ?? { "proxy_" ++ this.identityHash.abs ++  server.clientID.asString };
        );

        if (this.numChannels > 0) {
            bus = Bus.alloc(this.rate, server, this.numChannels);
            args = args ++ [\out, bus.index]
        };

        args = args ++ parameters;

        synth = Synth.basicNew(synth_def.name, server);

        play_bundle = List[nil]; // nil == the bundle time;
        play_bundle.add( synth.newMsg(play_target, args, play_order) );
        play_bundle.addAll( map_source_msg_bundle.value(synth) );

        synth_def.send(server, play_bundle.array);

        CmdPeriod.add(this);

        make_source_dependence.value;

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

    play { arg bus_index = (0), parameters, target, order;
        var synth_func;

        public_bus_index = bus_index;

        this.run(parameters, target, order);

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
        if (source === object or: {
            source.isArray and: { source.includes(object) }
        }) {
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
