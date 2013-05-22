MiniBee {
    var <id, <numChannels;
    var <status = \off;
    var data_osc, status_osc, data_funcs, status_funcs, bus;
    var <running = false;

    *new { arg id = (0), numChannels = (1);
        ^super.newCopyArgs(id, numChannels).init
    }

    init {
        data_funcs = FunctionList();
        status_funcs = FunctionList();

        status_osc = OSCFunc({ |msg|
            var msg_id = msg[1];
            if (msg_id == id) {
                status = msg[2];
                status_funcs.value(this, status);
            }
        }, '/minibee/status');

        data_osc = OSCFunc({ |msg|
            var msg_id = msg[1];
            var data;
            if (msg_id == id) {
                if (status !== \receiving) {
                    status = \receiving;
                    status_funcs.value(this, status);
                };
                data = msg[2..];
                data_funcs.value(this, data);
            }
        }, '/minibee/data');

        // initially disable
        status_osc.disable;
        data_osc.disable;
    }

    run {
        if (not(running)) {
            data_osc.enable;
            status_osc.enable;
            if (bus.notNil) { bus.run };
            CmdPeriod.add(this);
            running = true;
        }
    }

    stop {
        if (running) {
            data_osc.disable;
            data_osc.disable;
            if (bus.notNil) { bus.stop };
            CmdPeriod.remove(this);
            running = false;
        }
    }

    doOnCmdPeriod {
        CmdPeriod.remove(this);
        running = false;
    }

    bus {
        if (bus.isNil) {
            bus = MiniBeeBus(this);
            if (running) { bus.run };
        };
        ^bus;
    }

    // support NodeProxy2 for node ordering
    node { ^nil }

    addFunc { arg func, source = \data;
        var list;
        list = source.switch (
            \data, {data_funcs},
            \status, {status_funcs}
        );
        if (list.notNil) {
            list.addFunc(func);
        }{
            Error("MiniBee: unknown responder source:" + source).throw;
        }
    }

    removeFunc { arg func, source = \data;
        var list;
        list = source.switch (
            \data, {data_funcs},
            \status, {status_funcs}
        );
        if (list.notNil) {
            list.removeFunc(func);
        }{
            Error("MiniBee: unknown responder source:" + source).throw;
        }
    }
}

MiniBeeResponder {
    var <bee, data_func, status_func;
    var <running = false;

    *new { arg bee, data_func, status_func;
        ^super.newCopyArgs(bee, data_func, status_func);
    }

    run {
        if (not(running)) {
            if (status_func.notNil) { bee.addFunc(status_func, \status) };
            if (data_func.notNil) { bee.addFunc(data_func, \data) };
            CmdPeriod.add(this);
            running = true;
        }
    }

    stop {
        if (running) {
            if (status_func.notNil) { bee.removeFunc(status_func, \status) };
            if (data_func.notNil) { bee.removeFunc(data_func, \data) };
            CmdPeriod.remove(this);
            running = false;
        }
    }

    doOnCmdPeriod {
        this.stop;
    }
}

MiniBeeBus {
    var <bee, <numChannels, <server;
    var <running = false;
    var responder, <bus;

    *new { arg bee, server = (Server.default);
        ^super.newCopyArgs(bee, bee.numChannels, server).init
    }

    init {
        responder = MiniBeeResponder(bee, { |bee, data|
            bus.setn(data);
        });
    }

    run {
        if (not(running)) {
            bus = Bus.control(server, numChannels);
            responder.run;
            CmdPeriod.add(this);
            running = true;
        }
    }

    stop {
        if (running) {
            responder.stop;
            if (bus.notNil) { bus.free; bus = nil; };
            CmdPeriod.remove(this);
            running = false;
        }
    }

    index {
        ^bus !? { bus.index };
    }

    asBus { ^bus }

    doOnCmdPeriod {
        this.stop;
    }
}

MiniBeeNode {
    var <bee, output_count, def;
    var out_bus, synth;
    var <running = false;

    *new { arg bee, output_count = (0), def;
        ^super.newCopyArgs(bee, output_count, def);
    }

    output_bus { ^out_bus }

    run { arg ...synth_args;
        var in_bus, server;
        if (not(running))
        {
            in_bus = bee.bus;
            server = in_bus.server;

            if (output_count > 0) {
                out_bus = Bus.control(server, output_count);
            };

            def.send(server);

            fork({
                var args;
                server.sync;
                args = [\input_bus, in_bus.index];
                if (output_count > 0) { args = args ++ [\output_bus, out_bus.index] };
                args = args ++ synth_args;
                synth = Synth(def.name, args, server);
            }, SystemClock);

            CmdPeriod.add(this);
            running = true;
        }
    }

    stop {
        if(running) {
            if (out_bus.notNil) { out_bus.free; out_bus = nil };
            synth.free;
            CmdPeriod.remove(this);
            running = false;
        }
    }

    doOnCmdPeriod {
        if (out_bus.notNil) { out_bus.free; out_bus = nil };
        CmdPeriod.remove(this);
        running = false;
    }
}
