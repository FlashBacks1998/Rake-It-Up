package org.flashbacks1998.physics3d.objects;

import org.flashbacks1998.world3d.geom.Position3D;
import org.flashbacks1998.physics3d.Physics3D.Physics3DCollision;
import openfl.geom.Vector3D;

class Physics3DObjectPlane extends Physics3DObject implements IPhysics3DObject { 
    public var normal:Vector3D;      // must be normalized 

    public function new(position:Position3D, normal:Vector3D) {
        super();

        this.position = position;
        this.normal = normal.clone();
        this.normal.normalize();
        this.isStatic = true;
    }

    public override function testCollision(objectToTestAgainst:IPhysics3DObject, ref:Physics3DCollision):Null<Physics3DCollision> {
        if (Std.isOfType(objectToTestAgainst, Physics3DObjectBox)) {
            return (cast objectToTestAgainst : Physics3DObjectBox).testCollisionWithPlane(this, ref);
        }
        return null;
    }

    // -------------------------------------------------------------------
    // Pre-bound pair dispatchers (Phase 2A)
    // -------------------------------------------------------------------
    // Plane is always static, so pairs are always `Plane vs <something>`
    // with the plane as `a`. Only Plane-vs-Box is meaningful today — the
    // Box-is-first direction lives on Box as `pairBoxPlane`.

    /**
     * Plane-vs-Box (a=Plane, b=Box). Delegates to Box.testCollisionWithPlane
     * so the narrow-phase math lives in one place; ref.a/ref.b come back as
     * (box, plane), which is fine — the resolver reads ref.a/ref.b directly
     * rather than the pair's object1/object2 ordering.
     */
    public static function pairPlaneBox(a:IPhysics3DObject, b:IPhysics3DObject, ref:Physics3DCollision):Null<Physics3DCollision> {
        final pa:Physics3DObjectPlane = cast a;
        final bb:Physics3DObjectBox = cast b;
        return bb.testCollisionWithPlane(pa, ref);
    }

    public override function testAndResolveForOutOfBounds(minx:Float, miny:Float, minz:Float, maxx:Float, maxy:Float, maxz:Float) {

        return;
    }
}
