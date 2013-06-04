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

~window = Window(
    "SenseStage to Sound",
    Rect(0,0,800,600).center_(Window.availableBounds.center)
);
~window.layout = VLayout(
    ~header_layout,
    ~scroll_view
);

if (Platform.ideName == "none")
{
    var quit_check, quit_button;

    ~window.userCanClose = false;
    ~window.onClose = { 0.exit };

    quit_check = CheckBox().string_("May Quit?").value_(false);
    quit_check.action = {
        ~window.userCanClose = quit_check.value;
    };

    ~window.layout.add(10);
    ~window.layout.add(quit_check, align: \right);
};

~window.front;
);
