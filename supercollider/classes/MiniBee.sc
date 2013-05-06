MiniBee {
    var <id, <channel_count;
    var <status = \off;
    var data_osc, status_osc, data_funcs, status_funcs, bus;
    var <running = false;

    *new { arg id = (0), channel_count = (1);
        ^super.newCopyArgs(id, channel_count).init
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

    add_status_func { arg func; status_funcs.addFunc(func) }
    remove_status_func { arg func; status_funcs.removeFunc(func) }

    add_data_func { arg func; data_funcs.addFunc(func) }
    remove_data_func { arg func; data_funcs.removeFunc(func) }
}

MiniBeeResponder {
    var <bee, data_func, status_func;
    var <running = false;

    *new { arg bee, data_func, status_func;
        ^super.newCopyArgs(bee, data_func, status_func);
    }

    run {
        if (not(running)) {
            if (status_func.notNil) { bee.add_status_func(status_func) };
            if (data_func.notNil) { bee.add_data_func(data_func) };
            CmdPeriod.add(this);
            running = true;
        }
    }

    stop {
        if (running) {
            if (status_func.notNil) { bee.remove_status_func(status_func) };
            if (data_func.notNil) { bee.remove_data_func(data_func) };
            CmdPeriod.remove(this);
            running = false;
        }
    }

    doOnCmdPeriod {
        this.stop;
    }
}

MiniBeeBus {
    var <bee, <channel_count, <server;
    var <running = false;
    var responder, bus;

    *new { arg bee, server = (Server.default);
        ^super.newCopyArgs(bee, bee.channel_count, server).init
    }

    init {
        responder = MiniBeeResponder(bee, { |bee, data|
            bus.setn(data);
        });
    }

    run {
        if (not(running)) {
            bus = Bus.control(server, channel_count);
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

    doOnCmdPeriod {
        this.stop;
    }
}

MiniBeeNode {
    var <bee, def, synth;
    var <running = false;

    *new { arg bee, def;
        ^super.newCopyArgs(bee, def);
    }

    run { arg ...synth_args;
        var bus, server;
        if (not(running))
        {
            bus = bee.bus;
            server = bus.server;

            def.send(server);

            fork({
                server.sync;
                synth = Synth(def.name, [\input_bus, bus.index] ++ synth_args, server);
            }, SystemClock);

            CmdPeriod.add(this);
            running = true;
        }
    }

    stop {
        if(running) {
            synth.free;
            CmdPeriod.remove(this);
            running = false;
        }
    }

    doOnCmdPeriod {
        CmdPeriod.remove(this);
        running = false;
    }
}
