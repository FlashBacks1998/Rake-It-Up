package org.flashbacks1998.ui.events;

import openfl.events.Event;
import openfl.display.DisplayObject;

class ValueChangeEvent extends Event {
    public static final CHANGE:String = "ValueChangeEvent.CHANGE";

    public var oldValue:Dynamic;
    public var newValue:Dynamic;
    public var ui:DisplayObject;

    public function new(type:String, oldValue:Dynamic, newValue:Dynamic, ui:DisplayObject = null) {
        super(type);
        this.oldValue = oldValue;
        this.newValue = newValue;
        this.ui = ui;
    }
}