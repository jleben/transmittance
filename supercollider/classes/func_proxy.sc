FuncProxy {
    var <source, func;
    var <running = false;

    *new { arg source, func;
        ^super.newCopyArgs(source, func);
    }

    run {
        if (not(running)) {
            if (func.notNil) { source.addFunc(func) };
            CmdPeriod.add(this);
            running = true;
        }
    }

    stop {
        if (running) {
            if (func.notNil) { source.removeFunc(func) };
            CmdPeriod.remove(this);
            running = false;
        }
    }

    doOnCmdPeriod {
        this.stop;
    }
}

F : FuncProxy {}
