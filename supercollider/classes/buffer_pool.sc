BufferPool {
    var buffers, gui;

    *new { ^super.new.init }

    init {
        buffers = IdentityDictionary();
    }

    keys { ^buffers.keys }

    at { arg key;
        ^buffers.at(key);
    }

    put { arg key, buffer;
        var path;
        this.free(key);
        buffers.put(key, buffer);
        this.changed(\buffer_added, key);
    }

    find { arg buffer;
        ^buffers.findKeyForValue(buffer);
    }
/*
    load { arg key, path, channels = 0, callback;
        if (PathName(path).exists.not) {
            warn("BufferPool: file '%' does not exist".format(path));
        }{
            this.put(
                key,
                Buffer.readChannel(
                    Server.default,
                    path,
                    channels: channels,
                )
            )
            Buffer.readChannel(
                Server.default,
                path,
                channels: channels,
                action: { |buffer|
                    this.put(key, buffer);
                    callback.value(key, this);
                }
            )
        }
    }
*/
    free { arg key;
        var buffer;
        buffer = buffers.at(key);
        if (buffer.notNil) {
            buffers.put(key, nil);
            if (buffer.isKindOf(Collection)) {
                buffer.do(_.free)
            }{
                buffer.free;
            };
            this.changed(\buffer_removed, key);
        }
    }

    freeAll {
        buffers.do { |buffer|
            if (buffer.isKindOf(Collection)) {
                buffer.do(_.free)
            }{
                buffer.free;
            };
        };
        buffers.clear;
    }

    choose { arg initial_key, ok_action, cancel_action, label;
        if (gui.isNil) { gui = BufferPoolSelector(this) };
        gui.ok_action = ok_action;
        gui.cancel_action = cancel_action;
        gui.label = label;
        gui.selection = initial_key;
        gui.show;
    }
}
