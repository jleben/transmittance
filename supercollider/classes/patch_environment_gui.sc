ProxyGui {
    var title, item, buffer_pool;
    var <view, controls_view;

    *new { arg title, item, buffer_pool;
        ^super.newCopyArgs(title, item, buffer_pool).init;
    }

    init {
        var
        label,
        run_button,
        volume_slider, volume_spec, volume_label,
        main_control_layout, controls_button;

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

        volume_spec = [-90, 20, -2].asSpec;

        volume_slider = Slider().orientation_(\horizontal);
        volume_slider.action = { |x|
            var volume = volume_spec.map(x.value);
            item.volume = volume;
            volume_label.string = volume.round(0.01).asString;
        };

        volume_label = StaticText()
        .background_(Color.black)
        .stringColor_(Color.white)
        .fixedWidth_("-88.88".bounds.width);

        if (item.respondsTo('volume_')) {
            var volume = item.volume;
            volume_slider.value = volume_spec.unmap(volume);
            volume_label.string = volume.round(0.01).asString;
        }{
            volume_slider.enabled = false;
        };

        if (item.controls.notNil)
        {
            var knobs_layout, bufs_layout;
            controls_view = View();
            knobs_layout = HLayout().margins_(0).spacing_(5);
            bufs_layout = VLayout().margins_(0).spacing_(5);
            controls_view.layout = VLayout(
                knobs_layout,
                bufs_layout
            ).margins_(1).spacing_(2);

            item.controls.do { |assoc|
                var key, spec;
                key = assoc.key;
                spec = assoc.value;

                case

                { spec.respondsTo('asSpec') }
                {
                    var knob, value;
                    spec = spec.asSpec;
                    knob = Knob()
                    .fixedSize_(Size(25,25))
                    .mode_(\vert)
                    .color_([Color.black, Color.white, Color.gray(0.2), Color.white ]);
                    knob.action = { |knob|
                        item.set(key, spec.map(knob.value));
                    };
                    knobs_layout.add(
                        VLayout(
                            knob,
                            StaticText().string_(key).stringColor_(Color.white).align_(\center);
                        )
                    );
                    value = item.get(key);
                    if (value.notNil) { knob.value = spec.unmap(value) };
                }

                { spec === Buffer }
                {
                    var text, button, value;

                    text = StaticText()
                    .background_(Color.black)
                    .stringColor_(Color.white)
                    .string_("<not set>")
                    .setProperty(\indent, 4);

                    button = Button().states_([[key]]);
                    button.action = {
                        buffer_pool.choose(
                            text.string.asSymbol,
                            { arg buf_key;
                                item.set(key, buffer_pool[buf_key]);
                                text.string = buf_key;
                            },
                            label: "Buffer for '%: %'".format(item.name, key);
                        );
                    };

                    bufs_layout.add(
                        HLayout(button, [text, stretch:1]);
                    );

                    value = item.get(key);
                    if (value.class === Buffer) {
                        value = buffer_pool.find(value);
                        if (value.notNil) {
                            text.string = value;
                        }
                    }
                }
            };

            knobs_layout.add(nil);
        };

        controls_button = Button()
        .states_([["Show Ctl"], ["Hide Ctl"]])
        .enabled_(controls_view.notNil);

        view = View().background_(Color.gray(0.2));
        view.layout =
        VLayout (
            HLayout (
                run_button,
                [label, stretch: 1],
                controls_button,
            ).margins_(0).spacing_(2),
            HLayout (
                volume_slider,
                volume_label
            ).margins_(0).spacing_(2),
            nil
        ).margins_(3).spacing_(2);

        if (controls_view.notNil) {
            view.layout.add(controls_view);
            controls_view.visible = false;
            controls_button.action = { |btn|
                controls_view.visible = btn.value == 1;
            };
        };
    }
}
