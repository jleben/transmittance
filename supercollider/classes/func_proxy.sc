FuncProxy {
    var <source, def, <numChannels;
    var worker, bus;
    var <running = false;

    *new { arg def, numChannels = (0);
        ^super.newCopyArgs(nil, nil, numChannels.asInteger).def_(def);
    }

    def { ^def }

    def_ { arg object;
        var new_worker, old_worker;

        def = object;

        if (def.notNil)
        {
            if (numChannels > 0)
            {
                new_worker = { |src, data|
                    var result;
                    result = def.value(*data);
                    if (bus.notNil && result.notNil) {
                        bus.setn(result);
                    }
                };
            }{
                new_worker = { |src, data| def.value(*data) };
            };
        };

        old_worker = worker;
        worker = new_worker;

        if (running && source.notNil) {
            if (old_worker.notNil) { source.removeFunc(old_worker) };
            if (new_worker.notNil) { source.addFunc(new_worker) };
        }
    }

    numChannels_ { arg num = (0);
        if (num == numChannels) { ^this };

        numChannels = num;

        if (running) {
            if (bus.notNil) { bus.free; bus = nil }; // will provoke automatic recreation
            this.changed(\bus);
        }
    }

    source_ { arg object;
        var old_source, new_source;
        if (object === source) { ^this };
        old_source = source;
        source = new_source = object;
        if (running && worker.notNil) {
            if (old_source.notNil) { old_source.removeFunc(worker) };
            if (new_source.notNil) { new_source.addFunc(worker) };
        }
    }

    bus {
        if (running) {
            if (bus.isNil && (numChannels > 0)) {
                bus = Bus.control(Server.default, numChannels)
            };
        };
        ^bus;
    }

    run {
        if (not(running)) {
            if (source.notNil && worker.notNil) { source.addFunc(worker) };
            CmdPeriod.add(this);
            running = true;
            this.changed(\bus);
        }
    }

    stop {
        if (running) {
            if (source.notNil && worker.notNil) { source.removeFunc(worker) };
            if (bus.notNil) { bus.free; bus = nil };
            CmdPeriod.remove(this);
            running = false;
            this.changed(\bus);
        }
    }

    doOnCmdPeriod {
        this.stop;
    }
}

F : FuncProxy {}
