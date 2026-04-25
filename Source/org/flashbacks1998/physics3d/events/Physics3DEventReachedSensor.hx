package org.flashbacks1998.physics3d.events;

import org.flashbacks1998.physics3d.objects.IPhysics3DObject;
import openfl.events.Event;

class Physics3DEventReachedSensor extends Event {

    public static final TYPE:String = "Physics3DEventReachedSensor";

    public var sensor:IPhysics3DObject;
    public var object:IPhysics3DObject;

    public function new(sensor:IPhysics3DObject, object:IPhysics3DObject) {
        super(TYPE, false, false);

        this.sensor = sensor;
        this.object = object;
    }

    /**
     * Required override for any subclass of `flash.events.Event`. Flash's
     * `dispatchEvent` calls `clone()` whenever it needs to redispatch an
     * already-dispatched instance; the base implementation returns a vanilla
     * `flash.events.Event`, which then fails the internal type-coercion back
     * to this subclass with `TypeError #1034`. Returning a same-type clone
     * keeps subclass fields (`sensor`, `object`) attached to the new event.
     */
    override public function clone():Event {
        return new Physics3DEventReachedSensor(sensor, object);
    }
}