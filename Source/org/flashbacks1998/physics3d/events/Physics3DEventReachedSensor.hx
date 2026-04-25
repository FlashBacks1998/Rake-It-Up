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

    // ---------------------------------------------------------------------
    // Object pool (Phase 3A)
    // ---------------------------------------------------------------------
    // `Physics3D.resolveSensorCollisions` dispatches these events every frame
    // — at a few dozen leaves landing on the pile this allocates a lot of
    // short-lived event objects and triggers GC pauses on Flash. Pool them
    // so steady-state dispatch becomes allocation-free.

    private static var _pool:Array<Physics3DEventReachedSensor> = [];

    /**
     * Get a ready-to-dispatch event from the pool, or allocate a new one if
     * the pool is empty. Mutates `sensor` and `object` in-place so listeners
     * see the current contact. Callers MUST call `release(e)` once every
     * listener has run.
     */
    public static function acquire(sensor:IPhysics3DObject, object:IPhysics3DObject):Physics3DEventReachedSensor {
        final e = _pool.length > 0 ? _pool.pop() : new Physics3DEventReachedSensor(sensor, object);
        e.sensor = sensor;
        e.object = object;
        return e;
    }

    /**
     * Return an acquired event to the pool. Clears refs so the GC can free
     * the sensor/object if they get removed from the scene later. Safe to
     * call even if the event was never acquired via the pool (just adds it).
     */
    public static function release(e:Physics3DEventReachedSensor):Void {
        if (e == null) return;
        e.sensor = null;
        e.object = null;
        _pool.push(e);
    }
}