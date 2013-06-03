
~dir = PathName(thisProcess.nowExecutingPath).pathOnly;

/************************************
Load Buffers
*************************************/
(
~samples_dir = ~dir +/+ "../samples";
~samples = IdentityDictionary[
    \dvorak10 -> "sadsamlucky/dvorak10.wav",
    \dvorak11 -> "sadsamlucky/dvorak11.wav",
    \dvorak12 -> "sadsamlucky/dvorak12.wav",
    \levy_bunny -> "speech_long/ariel_levy_bunny.wav",
    \levy_sexualized -> "speech_long/ariel_levy_heavily_sexualized.wav",
    \pinkola_not_like -> "speech_long/pinkola_not_like_40s.wav",
    \pinkola_trigger -> "speech_long/pinkola_trigger_40s.wav"
];
~bufs = IdentityDictionary();
~samples.keysValuesDo { |key, path, idx|
    ~bufs.put(key, Buffer.readChannel(Server.default, ~samples_dir +/+ path, channels:0, bufnum: idx));
};

~buf_pool = BufferPool();
~bufs.keysValuesDo { |key, buf| ~buf_pool[key] = buf };
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

/***********************************
Make GUI
************************************/
(
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
    var bee_controls = List();
    bee[\sound].envir.keysValuesDo { arg key, item;
        bee_controls.add( ProxyGui(key, item, ~buf_pool) );
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
~window.front;
)
