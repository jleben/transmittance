BufferPoolSelector
{
    var <pool, window, list, label;
    var <>ok_action, <>cancel_action;
    // functions
    var update_listing;

    *new { arg pool; ^super.newCopyArgs(pool).init }

    init
    {
        var ok_btn, cancel_btn;

        update_listing = {
            var keys = pool.keys.asArray.sort;
            list.items = keys;
        };

        label = StaticText().font_(Font(size:15, bold:true));

        list = ListView();

        ok_btn = Button().states_([["OK"]]);

        cancel_btn = Button().states_([["Cancel"]]);

        window = Window("Choose Buffer");
        window.view.deleteOnClose_(false);
        window.layout =
        VLayout(
            label,
            list,
            HLayout(nil, ok_btn, cancel_btn);
        );

        ok_btn.action = {
            var selection = this.selection;
            protect {
                if (selection.notNil) { ok_action.value(selection, this) };
            }{
                window.close;
            }
        };

        cancel_btn.action = {
            protect {
                cancel_action.value;
            }{
                window.close;
            }
        };

        list.enterKeyAction = ok_btn.action;

        update_listing.value;

        pool.addDependant(this);
    }

    update { arg source, what, data;
        what.switch(
            \buffer_added, update_listing,
            \buffer_removed, update_listing
        )
    }

    selection {
        var index, key;
        index = list.value;
        if (index.notNil) { key = list.items[index].asSymbol };
        ^key;
    }

    selection_ { arg key;
        var items, index;
        items = list.items;
        if (items.notNil and: key.notNil) {
            index = items.indexOf(key);
        };
        list.value = index;
    }

    label_ { arg text;
        label.string = text;
    }

    show { window.front }

    close { window.close }

    free {
        pool.removeDependant(this);
        window.view.remove;
    }
}
