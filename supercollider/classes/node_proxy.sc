NodeProxy2 {
    classvar link_group;

    var <>name, <def;
    var <mappings, <settings, <controls, <monitors;
    var <bus, <monitor_bus, synth_def, synth;
    var <server, server_target, server_order;
    var public_synth_def, public_synth, public_bus_index, <volume = -90.0;
    var <running = false, <playing = false;
    ///
    var make_synth_def,
    make_all_source_dependences, remove_all_source_dependences,
    make_map_msg, make_map_bus_msg, remap,
    make_set_msg,
    cleanup;

    *new { arg name, def;
        ^super.newCopyArgs(name).init(def);
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

        make_synth_def = { arg function;
            ProxySynthDef2 (
                // set name later, when running
                //server.clientID.asString ++ "_proxy_" ++ this.identityHash.abs,
                nil,
                function
            )
        };

        make_all_source_dependences = {
            mappings.do { |mapping|
                if (mapping.isArray) { mapping = mapping[0] };
                mapping.addDependant(this);
            }
        };

        remove_all_source_dependences = {
            mappings.do { |mapping|
                if (mapping.isArray) { mapping = mapping[0] };
                mapping.removeDependant(this);
            }
        };

        make_map_msg =
        {
            arg node;

            var bundle = List();
            var own_channels;

            own_channels = synth_def.numInputs;

            mappings.keysValuesDo { |key, mapping|
                var src, map_index, map_channels, msg;


                if (mapping.isArray) {
                    src = mapping[0];
                    map_index = mapping[1] ? 0;
                    map_channels = mapping[2] ? 1;
                } {
                    src = mapping;
                    map_index = 0;
                    map_channels = src.numChannels;
                };

                msg = make_map_bus_msg.value(node, key, src, map_index, map_channels);
                if (msg.notNil) { bundle.add(msg) };
            };

            bundle.array; // return
        };

        make_map_bus_msg =
        {
            arg node, key, src, map_index, map_channels;

            var src_bus, src_index, src_channels, msg;

            src_channels = src.numChannels;

            case

            { src_channels < 1 }
            {
                warn("NodeProxy2: source for '%' has no output.".format(key));
            }

            { src.running }
            {
                src_bus = src.bus;
                if (src_bus.notNil) { src_bus = src_bus.asBus };
                if (src_bus.isNil) {
                    warn("NodeProxy2: source for '%'' does not provide a bus.".format(key));
                }{
                    src_index = src_bus.index;

                    if (
                        map_index < 0
                        or: {map_channels < 1}
                        or: {(map_index + map_channels) > (src_index + src_channels)}
                    ) {
                        warn("NodeProxy2: mapping for '%' out of range.".format(key));
                        map_index = nil;
                    }{
                        map_index = src_index + map_index;
                    }
                }
            };

            if (src_bus.notNil && map_index.notNil)
            {
                src_bus.rate.switch (
                    \control,
                    {
                        msg = [
                            "/n_mapn",
                            node.nodeID,
                            key,
                            map_index,
                            map_channels
                        ];
                    },
                    \audio,
                    {
                        msg = [
                            "/n_mapan",
                            node.nodeID,
                            key,
                            map_index,
                            map_channels
                        ];
                    }
                );
            };

            msg // return
        };

        make_set_msg = { arg node;
            var list = List();
            settings.keysValuesDo { |key, setting|
                list.add([
                    "/n_set",
                    node.nodeID,
                    key,
                    setting.asControlInput
                ])
            };
            // return
            list.array;
        };

        remap = {
            var map_msg;
            if (running) {
                map_msg = make_map_msg.value(synth);
                server.sendBundle(
                    nil,
                    ["/n_mapn", synth.nodeID, 0, -1, synth_def.numInputs], // unmap all
                    *map_msg
                );
            };
        };

        cleanup = {
            if (bus.notNil) { bus.free; bus = nil };
            if (monitor_bus.notNil) { monitor_bus.free; monitor_bus = nil; };
            remove_all_source_dependences.value;
            CmdPeriod.remove(this);
            synth = nil;
            public_synth = nil;
            running = false;
            playing = false;
            this.changed(\bus);
        };

        mappings = IdentityDictionary();
        settings = IdentityDictionary();
        this.def = def_;
    }

    def_ { arg function;
        var sdef, was_running, was_playing;

        sdef = make_synth_def.value(function);

        def = function;
        synth_def = sdef;

        was_running = running;
        was_playing = playing;

        this.stop;

        case
        { was_playing } {
            this.play( public_bus_index, server_target, server_order );
        }
        { was_running } {
            this.run( server_target, server_order );
        };
    }

    controls_ { arg specs;
        controls = List();
        specs.do { |spec|
            case

            { spec.value === Buffer or: { spec.value == [Buffer] } }
            {
                controls.add(spec);
            }

            { spec.value.respondsTo('asSpec') }
            {
                controls.add( (spec.key -> spec.value.asSpec) )
            }
            //else
            { Error("NodeProxy2: Invalid control spec.").throw };
        }
    }

    monitors_ { arg specs;
        monitors = List();
        specs.do { |spec|
            case

            { spec.respondsTo('asSpec') }
            {
                monitors.add( spec.asSpec )
            }

            { Error("NodeProxy2: Invalid monitor spec.").throw };
        }
    }

    map { arg ...parameters;
        parameters.pairsDo { arg param, value;
            var old_source, new_source;

            old_source = mappings[param];
            if (old_source.isArray) { old_source = old_source[0] };
            old_source.removeDependant(this);

            if (value.isArray) {
                if (
                    (value.size < 1)
                    or: { value[0].isNil }
                    or: { not(value[0].respondsTo(\bus)) }
                ) {
                    warn("NodeProxy2: invalid mapping for '%'".format(param));
                    value = nil;
                } {
                    new_source = value[0];
                }
            }{
                if (not(value.respondsTo(\bus))) {
                    warn("NodeProxy2: invalid mapping for '%'".format(param));
                    value = nil;
                }{
                    new_source = value;
                }
            };

            mappings[param] = value;

            if (running && new_source.notNil) {
                new_source.addDependant(this);
            }
        };

        remap.value;
    }

    unmapAll {
        remove_all_source_dependences.value;
        mappings.clear;
        remap.value;
    }

    get { arg key;
        var value = settings.at(key);
        if (value.isNil) {
            var ctl = synth_def.allControlNames.detect { |c| c.name === key };
            if (ctl.notNil) { value = ctl.defaultValue };
        }
        ^value;
    }

    set { arg ...parameters;
        parameters.pairsDo { |key, value|
            settings.put(key, value);
        };
        if (running) { synth.set(*parameters) };
    }

    unsetAll {
        settings.clear;
    }

    numChannels { ^synth_def.numChannels }

    numMonitors { ^synth_def.numMonitors }

    rate { ^synth_def.rate }

    run { arg target, order;
        var args, play_bundle, play_target, play_order;

        if (running) {
            ^this;
        };

        server_target = target;
        server_order = order;

        play_target = target;
        if (play_target.class === NodeProxy2) { play_target = play_target.node };
        if (play_target.isNil) {
            play_target = Server.default.defaultGroup;
            play_order = 'addToHead';
        }{
            play_order = order ? 'addToHead';
        };

        server = play_target.server;

        synth_def.name = (
            name !? { name.asString }
            ?? { "proxy_" ++ this.identityHash.abs ++  server.clientID.asString };
        );

        if (this.numChannels > 0) {
            bus = Bus.alloc(this.rate, server, this.numChannels);
            args = args ++ [\out, bus.index]
        };

        if (this.numMonitors > 0) {
            monitor_bus = Bus.alloc(\control, server, this.numMonitors);
            args = args ++ [\monitor_out_bus, monitor_bus.index];
        };

        synth = Synth.basicNew(synth_def.name, server);

        play_bundle = List[nil]; // nil == the bundle time;
        play_bundle.add( synth.newMsg(play_target, args, play_order) );
        play_bundle.addAll( make_map_msg.value(synth) );
        play_bundle.addAll( make_set_msg.value(synth) );

        synth_def.send(server, play_bundle.array);

        CmdPeriod.add(this);

        make_all_source_dependences.value;

        running = true;

        this.changed(\bus);
    }

    play { arg bus_index = (0), target, order;
        var synth_func;

        public_bus_index = bus_index;

        this.run(target, order);

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
                    args: [out: public_bus_index, bus: in_bus_index, volume: volume.dbamp]
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
        volume = value.clip(-90, 20);
        if (playing) { public_synth.set(\volume, volume.dbamp) };
    }

    silence {
        if (playing) {
            public_synth.free;
            playing = false;
        }
    }

    update { arg object, what;
        what.switch (
            \bus, remap
        );
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
