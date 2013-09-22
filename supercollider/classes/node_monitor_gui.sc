NodeProxyMonitorGui
{
    var node, index, spec;
    var bus;
    var <view, routine, value = 0.0;
    var start, stop, update_run_state;
    var active = false;

    *new { arg node, index = 0;
        ^super.new.init(node, index);
    }

    init { arg node_, index_;
        var bkg, indicator;

        node = node_;
        index = index_;
        spec = node.monitors[index];
        if (spec.isNil) {
            Error("NodeProxyMonitorGui: monitor index % does not have a valid spec.".format(index_)).throw;
        };

        view = UserView();
        view.background = Color.black;
        view.drawFunc = {
            var r;
            r = view.bounds.moveTo(0,0);
            r.width = spec.unmap(value) * r.width;
            Pen.fillColor = Color.green;
            Pen.addRect(r);
            Pen.fill;
        };

        routine = Routine({
            loop {
                value = bus.getSynchronous;
                view.refresh;
                0.05.wait;
            }
        });

        update_run_state = {
            var node_bus;
            node_bus = node.monitor_bus;
            if (node_bus.notNil) {
                if (index < 0 || (index >= node_bus.numChannels)) {
                    "NodeProxyMonitorGui: monitor index % out of bus range.".format(index).warn;
                    bus = nil;
                }{
                    bus = Bus(\control, node_bus.index + index);
                }
            }{
                bus = nil;
            };
            if (bus.notNil) {
                routine.reset;
                routine.play(AppClock);
            }{
                routine.stop;
            }
        }
    }

    activate {
        if (active) { ^this };
        node.addDependant(this);
        update_run_state.value;
        active = true;
    }

    deactivate {
        if (not(active)) { ^this };
        node.removeDependant(this);
        bus = nil;
        routine.stop;
        active = false;
    }

    update { arg object, what;
        if (object === node) {
            what.switch (
                \bus, update_run_state;
            );
        }
    }
}
