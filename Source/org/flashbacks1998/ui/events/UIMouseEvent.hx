package org.flashbacks1998.ui.events;

import openfl.events.Event;
import openfl.display.DisplayObject;

class UIMouseEvent extends Event {

    public static inline var CLICK:String = "UIMouseEvent.CLICK";

    public var ui:DisplayObject;

    public function new(type:String, ui:DisplayObject, bubbles:Bool = false, cancelable:Bool = false) {
        super(type, bubbles, cancelable);
        this.ui = ui;
    }

    // Required so events redispatch correctly
    override public function clone():Event {
        return new UIMouseEvent(type, ui, bubbles, cancelable);
    }

    override public function toString():String {
        return '[UIMouseEvent type="$type" bubbles=$bubbles cancelable=$cancelable ui=$ui]';
    }
}