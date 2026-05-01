package org.flashbacks1998.rake.ui;

import haxe.ui.containers.Absolute;
import haxe.ui.data.ArrayDataSource;
import org.flashbacks1998.newgrounds.Newgrounds;

@:xml('
    <absolute>
        <vbox left="0" top="0" width="100%" height="100%" styleNames="window">
            <hbox id="titleBar" width="100%" styleNames="window-header">
                <label
                    id="titleLabel"
                    text="Edit Gnome"
                    width="100%"
                    styleNames="window-title" />
                <button
                    id="closeButton"
                    text="X"
                    styleNames="settings-close" />
            </hbox>

            <vbox width="100%" height="100%" styleNames="window-body">
                <textarea
                    id="bodyTextarea"
                    width="100%"
                    height="100%"
                    wrap="true" 
                    styleNames="window-textarea" />

                <hbox width="100%" styleNames="window-footer">
                    <button
                        id="resetButton"
                        text="Reset"
                        styleNames="window-btn-secondary" />
                    <spacer width="100%" />
                    <button
                        id="updateButton"
                        text="Update"
                        styleNames="window-btn-primary" />
                </hbox>
            </vbox>
        </vbox>
    </absolute>
')
class GnomeEditWindow extends Absolute { 
    public var bodyText(get, set):String;

    function get_bodyText():String {
        return (bodyTextarea != null) ? bodyTextarea.text : "";
    }

    function set_bodyText(value:String):String {
        if (bodyTextarea != null) bodyTextarea.text = value;
        return value;
    }

    public function new() {
        super();

        // Close defaults to hiding the window. Consumers can override by
        // assigning their own closeButton.onClick or by registering an event.
        closeButton.onClick = _ -> hide();
    }
}
