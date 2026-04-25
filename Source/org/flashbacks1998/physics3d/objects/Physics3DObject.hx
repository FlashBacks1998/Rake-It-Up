package org.flashbacks1998.physics3d.objects;

import openfl.Vector;
import org.flashbacks1998.physics3d.Physics3D.Physics3DCollision;
import openfl.events.EventDispatcher;
import org.flashbacks1998.world3d.geom.Position3D;
import openfl.geom.Vector3D;

class Physics3DObject extends EventDispatcher implements IPhysics3DObject{
    public var position:Position3D = new Position3D();
    public var velocity:Vector3D = new Vector3D();
    public var isStatic:Bool = false;
    public var isKinematic:Bool = true;
    public var isSensor:Bool = false;
    public var ignoreGroup:Vector<IPhysics3DObject> = new Vector();
    /**
     * Parallel O(1)-lookup set for `ignoreGroup`. Hot-path code calls
     * `ignores(other)` instead of `ignoreGroup.indexOf(other) != -1`.
     * NOTE: direct assignment of an external map (e.g. shared leaves set)
     * is supported, but you must then mutate both `ignoreGroup` AND
     * `ignoreSet` together, or use the `addIgnore` / `removeIgnore` helpers.
     */
    public var ignoreSet:Map<IPhysics3DObject, Bool> = new Map();
    public var oRadius:Float = -1;

    public function new() {
        super();

    }

    /**
     * Add `other` to this object's ignore list. O(1) — maintains both the
     * Vector (for ordering / legacy iteration) and the Map (for the per-frame
     * collision-test hot path).
     */
    public function addIgnore(other:IPhysics3DObject):Void {
        if (other == null || ignoreSet.exists(other)) return;
        ignoreGroup.push(other);
        ignoreSet.set(other, true);
    }

    /**
     * Remove `other` from this object's ignore list. O(n) on the Vector
     * (swap-pop), O(1) on the Map. Infrequent compared to `ignores()`.
     */
    public function removeIgnore(other:IPhysics3DObject):Void {
        if (other == null || !ignoreSet.exists(other)) return;
        var idx = ignoreGroup.indexOf(other);
        if (idx >= 0) {
            var last = ignoreGroup.length - 1;
            if (idx != last) ignoreGroup[idx] = ignoreGroup[last];
            ignoreGroup.pop();
        }
        ignoreSet.remove(other);
    }

    /**
     * O(1) membership check for the ignore list. Replaces
     * `ignoreGroup.indexOf(other) != -1` in hot paths.
     */
    public inline function ignores(other:IPhysics3DObject):Bool {
        return ignoreSet.exists(other);
    }

    public function testCollision(objectToTestAgainst:IPhysics3DObject, ref:Physics3DCollision):Null<Physics3DCollision> {
        return null;
    }

    public function testAndResolveForOutOfBounds(minx:Float, miny:Float, minz:Float, maxx:Float, maxy:Float, maxz:Float) {
        return;
    }
}
