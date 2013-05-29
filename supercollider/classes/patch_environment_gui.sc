ProxyGui {
    var title, item;
    var <view;

    *new { arg title, item;
        ^super.newCopyArgs(title, item).init;
    }

    init {
        var label, run_button, volume_slider, controls_layout;

        label = StaticText().string_(title).stringColor_(Color.white).align_(\center);

        run_button = Button();
        run_button.states = [
            ["OFF", Color.white, Color.red(0.6)],
            ["ON", Color.white, Color.green(0.6)]
        ];
        run_button.action = { arg x;
            x.value.switch(
                1, { try { item.play }{ item.run } },
                0, { item.stop }
            )
        };

        volume_slider = Slider().orientation_(\horizontal);
        volume_slider.action = { |x| item.volume = x.value };
        if (item.respondsTo('volume_')) {
            volume_slider.value = item.volume;
        }{
            volume_slider.enabled = false;
        };

        if (item.controls.notNil) {
            controls_layout = HLayout().margins_(0).spacing_(2);
            item.controls.keysValuesDo { |key, spec|
                var knob, value;
                spec = spec.asSpec;
                knob = Knob()
                .fixedSize_(Size(25,25))
                .mode_(\vert)
                .color_([Color.black, Color.white, Color.gray(0.2), Color.white ]);
                knob.action = { |knob|
                    item.set(key, spec.map(knob.value));
                };
                controls_layout.add(
                    VLayout(
                        knob,
                        StaticText().string_(key).stringColor_(Color.white).align_(\center);
                    )
                );
                value = item.get(key);
                if (value.notNil) { knob.value = value };
            };
            controls_layout.add(nil);
        };

        view = View().background_(Color.gray(0.2));
        view.layout = VLayout(
            label,
            HLayout(
                run_button,
                volume_slider
            ).margins_(0).spacing_(2);
        ).margins_(3).spacing_(2);
        if (controls_layout.notNil) { view.layout.add(controls_layout) };
    }
}
