MiniBee {
    var <id;
    var <status = \off;
    var data_osc, status_osc, data_funcs, status_funcs;
    var cleanup_osc;
    var setup_osc;

    *new { arg id = (0);
        ^super.newCopyArgs(id).init
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
        data_osc.enable;
        status_osc.enable
    }

    stop {
        data_osc.disable;
        data_osc.disable;
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

    *new { arg bee, channel_count = (1), server = (Server.default);
        ^super.newCopyArgs(bee, channel_count, server).init
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

}
