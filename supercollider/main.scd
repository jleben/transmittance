~dir = PathName(thisProcess.nowExecutingPath).pathOnly;

/************************************
Load Buffers
*************************************/
(
~samples_dir = ~dir +/+ "../samples";
~samples = this.executeFile(~dir +/+ "samples.scd");
~buf_pool = BufferPool();
~samples.keysValuesDo { |key, path, idx|
    path = ~samples_dir +/+ path;
    if (File.exists(path).not) {
        warn("BufferPool: file '%' does not exist".format(path));
    }{
        ~buf_pool[key] =
        Buffer.readChannel(
            Server.default,
            path,
            channels:0,
            bufnum: idx
        )
    };
};
);

/************************************
MiniBee preprocessing & sound
************************************/

~bee_ids = [1,2];

~bees = IdentityDictionary();

~bee_ids.do { |id|
    var preprocessing, sound, bee;
    preprocessing = PatchEnvironment("bee"++id, currentEnvironment);
    preprocessing[\minibee_id] = id;
    preprocessing.use { this.executeFile(~dir +/+ "preprocessing.scd"); };

    sound = PatchEnvironment("bee"++id, preprocessing.envir);
    sound.use { this.executeFile(~dir +/+ "sound.scd"); };

    bee = IdentityDictionary[
        \preprocessing -> preprocessing,
        \sound -> sound
    ];

    ~bees[id] = bee;
};

/************************************
Load Settings
************************************/

~parse_settings = { |settings|
    var bees;
    bees = ~settings[\bees];
    try {
        bees.keysValuesDo { |id, bee_settings|
            ~parse_bee_settings.(id, bee_settings);
        }
    }{
        warn("Settings: Error trying to parse bees.");
    }
};

~parse_bee_settings = { |id, settings|
    var bee = ~bees[id];
    postln("Parsing settings for bee '%'".format(id));
    if (bee.isNil) {
        warn("Settings: No bee for id '%'".format(id));
    }{
        try {
            settings.keysValuesDo { |proxy_key, proxy_settings|
                ~parse_proxy_settings.(bee, proxy_key, proxy_settings);
            }
        }{
            warn("Settings: Error trying to parse settings for bee '%'.".format(id));
        }
    }
};

~parse_proxy_settings = { |bee, proxy_key, settings|
    var proxy = bee[\sound][proxy_key];
    postln("Parsing settings for proxy '%'".format(proxy_key));
    if (proxy.isNil) {
        warn("Settings: Bee has no proxy for '%'".format(proxy_key));
    }{
        var controls = proxy.controls;
        try {
            settings.keysValuesDo { |control_key, control_value|
                ~parse_control_settings.(proxy, controls, control_key, control_value);
            }
        }{
            warn("Settings: Error trying to parse settings for proxy '%'.".format(proxy_key));
        }
    }
};

~parse_control_settings = { |proxy, controls, control_key, value|
    var control, spec;
    postln("Parsing settings for control '%'".format(control_key));

    control = controls.detect { |control| control.key === control_key };
    if (control.notNil) { spec = control.value };

    case
    { spec.isNil }
    {
        warn("Settings: Proxy has no control named '%'"
            .format(control_key));
    }
    { spec === Buffer }
    {
        var buffer = ~buf_pool[value];
        if (buffer.isNil) {
            warn("Settings: No buffer for key '%'".format(value));
        }{
            proxy.set(control_key, buffer);
        }
    }
    { spec.isKindOf(ControlSpec) }
    {
        proxy.set(control_key, spec.constrain(value));
    }
    // else
    {
        warn("Settings: Control '%' has unrecognized spec.".format(control_key));
    }
};

try {
    ~settings = this.executeFile(~dir +/+ "settings.scd");
}{
    warn("Settings: Error trying to load file.\nCheck syntax in \"settings.scd\".");
};

if (~settings.notNil) {
    ~parse_settings.(~settings);
    "Done loading settings.";
};

/***********************************
Save Settings
************************************/

(
~save_node = { |node, stream, indent|
    node.controls.do { arg assoc;
        var key, spec;
        key = assoc.key;
        spec = assoc.value;
        case
        { spec.isKindOf(ControlSpec) } {
            stream << indent << key.asString << ": " << node.get(key).asString << ",\n";
        }
        { spec === Buffer } {
            var buffer, buf_key;
            buffer = node.get(key);
            if (buffer.notNil) {
                buf_key = ~buf_pool.find(buffer);
                stream << indent << key.asString << ": " << buf_key.cs << ",\n";
            }
        }
        // else
        {
            warn("Settings: Control '%' has unrecognized spec.".format(key));
        };
    }
};

~save_bee = { arg bee, stream, indent;
    var indent_node;
    bee[\sound].keysValuesDo { arg key, node;
        if (node.controls.size > 0) {
            stream << indent << key.asString << ": (\n";
            indent_node = indent ++ "    ";
            ~save_node.value(node, stream, indent_node);
            stream << indent << "),\n";
        }
    }
};

~save_bees = { arg stream, indent;
    var indent_bee, indent_bee_data;
    stream << indent << "bees: (\n";
    indent_bee = indent ++ "    ";
    ~bees.keysValuesDo { |id, bee|
        stream << indent_bee << id.asString << ": (\n";
        indent_bee_data = indent_bee ++ "    ";
        ~save_bee.value(bee, stream, indent_bee_data);
        stream << indent_bee << "),\n";
    };
    stream << indent << "),\n";
};

~save_settings = {
	var file, indent;
    indent = "";
    file = File(~dir +/+ "settings.scd", "w");
    if (file.isOpen.not) {
        warn("Settings: Could not open \"settings.scd\" for writing!");
    }{
        file << "(\n";
        ~save_bees.value(file, indent);
        file << ")\n";
    };
    file.close;
    postln("Done saving settings.");
};
);

/***********************************
Make GUI
************************************/
(
~sound_node_keys = [
    \grain_trigger_env,
    \grain_reveal,
    \grain_integrate,
    \grain_disintegrate,
    \distort,
    \distance,
    \stretch_trigger,
    \stretch_tilt,
    \crowd
];

~headers = List();

~bees.keysValuesDo { |id, bee|
    ~headers.add([
        StaticText().font_(Font(size: 15, bold: true)).string_("bee" + id),

        Button()
        .states_([
            ["OFF", Color.white, Color.red(0.6)],
            ["ON", Color.white, Color.green(0.6)]
        ])
        .action_({ arg btn;
            bee[\preprocessing].use {
                btn.value.switch(
                    1, ~run_preprocessing,
                    0, ~stop_preprocessing
                )
            };
        })
    ]);
};

~controls = List();

~bees.keysValuesDo { |id, bee|
    var bee_controls;
    bee_controls = ~sound_node_keys.collect { |key|
        var item = bee[\sound][key];
        ProxyGui(key, item, ~buf_pool);
    };
    ~controls.add(bee_controls);
};

~control_views = ~controls.collect { arg bee_controls;
    bee_controls.collect(_.view);
};

~main_layout = VLayout();
~header_layout = GridLayout.columns(*~headers);
~control_layout = GridLayout.columns(*~control_views);

~scroll_view = ScrollView().hasBorder_(false);
~scroll_view.canvas = View().layout_(VLayout(~control_layout, nil));

~save_settings_btn = Button().states_([["Save Settings"]]).action_({
    var win, win_bounds;
    win = Window("Overwrite Settings?");
    win.layout = VLayout(
        StaticText().string_("Are you sure you want to overwrite \"settings.scd\"?"),
        nil,
        HLayout(
            [nil, stretch:1],
            Button().states_([["OK"]]).action_({ ~save_settings.value; win.close }),
            Button().states_([["Cancel"]]).action_({ win.close })
        )
    );
    win_bounds = Rect();
    win_bounds.size = win.view.sizeHint;
    win_bounds = win_bounds.center = Window.availableBounds.center;
    win.front;
    win.bounds = win_bounds;
});

~bottom_layout = HLayout(
    [nil, stretch:1],
    ~save_settings_btn
);

~window = Window(
    "SenseStage to Sound",
    Rect(0,0,800,600).center_(Window.availableBounds.center)
);

~window.layout = VLayout(
    ~header_layout,
    ~scroll_view,
    10,
    ~bottom_layout,
);

if (Platform.ideName == "none")
{
    var quit_check, quit_button, save_settings_btn;

    ~window.userCanClose = false;
    ~window.onClose = { 0.exit };

    quit_check = CheckBox().string_("May Quit?").value_(false);
    quit_check.action = {
        ~window.userCanClose = quit_check.value;
    };

    save_settings_btn = Button().states_([["Save Settings"]]).action_(~save_settings);

    ~bottom_layout.add(quit_check);
};

~window.front;
);
