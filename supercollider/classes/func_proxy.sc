FuncProxy {
    var <source, func;
    var <running = false;

    *new { arg func, source;
        ^super.new.source_(source).def_(func);
    }

    def { ^func }

    def_ { arg function;
        var new_func, old_func;
        old_func = func;
        func = new_func = function;
        if (running && source.notNil) {
            if (old_func.notNil) { source.removeFunc(old_func) };
            if (new_func.notNil) { source.addFunc(new_func) };
        }
    }

    source_ { arg object;
        var old_source, new_source;
        if (object === source) { ^this };
        old_source = source;
        source = new_source = object;
        if (running && func.notNil) {
            if (old_source.notNil) { old_source.removeFunc(func) };
            if (new_source.notNil) { new_source.addFunc(func) };
        }
    }

    run {
        if (not(running)) {
            if (source.notNil && func.notNil) { source.addFunc(func) };
            CmdPeriod.add(this);
            running = true;
        }
    }

    stop {
        if (running) {
            if (source.notNil && func.notNil) { source.removeFunc(func) };
            CmdPeriod.remove(this);
            running = false;
        }
    }

    doOnCmdPeriod {
        this.stop;
    }
}

F : FuncProxy {}
