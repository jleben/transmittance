
Server.default.options.numOutputBusChannels = 6;
~dir = PathName(thisProcess.nowExecutingPath).pathOnly;

~preproc_envir = PatchEnvironment(currentEnvironment);
(
~preproc_envir.push;
protect {
    this.executeFile(~dir +/+ "preprocessing.scd");
}{
    Environment.pop;
}
);


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
);

/************************************
Define sounds
*************************************/
~sound_envir=PatchEnvironment(~preproc_envir.envir);
(
~sound_envir.push;
protect {
    this.executeFile(~dir +/+ "sound.scd");
}{
    Environment.pop;
}
);

/***********************************
Make GUI
************************************/
(
~toggle_preprocessing_btn = Button();
~toggle_preprocessing_btn.states = [
    ["OFF", Color.white, Color.red(0.6)],
    ["ON", Color.white, Color.green(0.6)]
];
~toggle_preprocessing_btn.action = { arg x;
    ~preproc_envir.use {
        x.value.switch(
            1, ~run_preprocessing,
            0, ~stop_preprocessing
        )
    };
};

~proxy_views = List();
~sound_envir.envir.keysValuesDo { arg name, item;
    ~proxy_views.add( ProxyGui(name, item) );
};
~proxy_ctl_layout = VLayout();
~proxy_views.do { |v| ~proxy_ctl_layout.add(v.view) };

~window = Window();
~window.layout = VLayout(
    HLayout(
        StaticText().string_("Preprocessing:"),
        ~toggle_preprocessing_btn,
        nil
    ),
    ~proxy_ctl_layout
);

~window.front;
);
