package org.flashbacks1998.world3d.events;

import openfl.events.Event; 

class World3DEvent extends Event {

    public static final ADDED_TO_STAGE:String   = "World3DEvent.ADDED_TO_STAGE";
    public static final REMOVED_FROM_STAGE:String = "World3DEvent.REMOVED_FROM_STAGE";

    public var world:World3D;

    public function new(type:String, world:World3D, bubbles:Bool = false, cancelable:Bool = false) {
        super(type, bubbles, cancelable);
        this.world = world;
    }

    override public function clone():Event {
        return new World3DEvent(type, world, bubbles, cancelable);
    }

    override public function toString():String {
        return "[World3DEvent type=\"" + type
            + "\" bubbles=" + bubbles
            + " cancelable=" + cancelable
            + " world=" + world + "]";
    }
}
