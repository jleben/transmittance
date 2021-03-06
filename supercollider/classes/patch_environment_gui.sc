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
        has_controls=false, controls_button,
        monitors_layout, knobs_layout, bufs_layout;

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

        controls_view = View();
        controls_view.layout = VLayout().margins_(1).spacing_(2);

        if (item.tryPerform(\monitors).notNil)
        {
            has_controls = true;
            monitors_layout = VLayout().margins_(0).spacing_(2);
            item.monitors.do { |spec, index|
                var monitor_gui = NodeProxyMonitorGui(item, index);
                monitor_gui.activate;
                monitor_gui.view.fixedHeight = 10;
                monitors_layout.add(monitor_gui.view);
            };
            controls_view.layout.add(monitors_layout);
        };

        if (item.controls.notNil)
        {
            has_controls = true;
            knobs_layout = HLayout().margins_(0).spacing_(5);
            bufs_layout = VLayout().margins_(0).spacing_(5);

            item.controls.do { |assoc|
                var key, spec;
                key = assoc.key;
                spec = assoc.value;

                case

                { spec.isKindOf(ControlSpec) }
                {
                    var knob, value;
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

                { spec === Buffer or: { spec == [Buffer] } }
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
                                var buffer = buffer_pool[buf_key];
                                if( (spec.isArray == buffer.isArray) ) {
                                    item.set(key, buffer_pool[buf_key]);
                                    text.string = buf_key;
                                }{
                                    warn("Incompatible buffer selection!");
                                }
                            },
                            label: "Buffer for '%: %'".format(item.name, key);
                        );
                    };

                    bufs_layout.add(
                        HLayout(button, [text, stretch:1]);
                    );

                    value = item.get(key);
                    value = buffer_pool.find(value);
                    if (value.notNil) {
                        text.string = value;
                    };
                }
            };

            knobs_layout.add(nil);

            controls_view.layout.add(knobs_layout);
            controls_view.layout.add(bufs_layout);
        };

        controls_button = Button()
        .states_([["Show Ctl"], ["Hide Ctl"]])
        .enabled_(has_controls);

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

        view.layout.add(controls_view);
        controls_view.visible = false;
        controls_button.action = { |btn|
            controls_view.visible = btn.value == 1;
        };
    }
}
