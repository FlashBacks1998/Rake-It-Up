package org.flashbacks1998.physics3d.objects;

import org.flashbacks1998.util.Matrix3DUtil;
import openfl.geom.Matrix3D;
import openfl.geom.Vector3D;
import org.flashbacks1998.world3d.geom.Position3D;
import org.flashbacks1998.physics3d.Physics3D.Physics3DCollision;
import org.flashbacks1998.util.Constants;

class Physics3DObjectCylinder extends Physics3DObject implements IPhysics3DObject {
    public var radius:Float;
    public var height:Float;

    public function new(position:Position3D, radius:Float, height:Float, isStatic:Bool = false) {
        super();
        this.position = position;
        this.radius = radius;
        this.height = height;
        this.isStatic = isStatic;

        this.oRadius = Math.sqrt(radius * radius + (height / 2) * (height / 2));
    }

    // local helper: projection radius of box (axes, extents) onto axis L (assumed normalized)
    private static inline function projRadiusLocal(ax0:Vector3D, ax1:Vector3D, ax2:Vector3D, e0:Float, e1:Float, e2:Float, L:Vector3D):Float {
        return Math.abs(e0 * ax0.dotProduct(L)) + Math.abs(e1 * ax1.dotProduct(L)) + Math.abs(e2 * ax2.dotProduct(L));
    }

    // replace/add inside your Cylinder class (or wherever this method lives)
    private static final _mB = new Matrix3D();
    private static final _B0 = new Vector3D();
    private static final _B1 = new Vector3D();
    private static final _B2 = new Vector3D();

    // scratch vectors (if you want, for clarity; we mostly use scalars)
    private static final _boxCenter = new Vector3D();
    private static final _d = new Vector3D();
    private static final _closest = new Vector3D();

    // small epsilon
    private static final _EPS = 1e-6;


    /**
     * Cylinder (vertical, world-Y) vs Box (OBB) test.
     * ref is filled and returned on collision; fields are written into safely to avoid NPEs.
     *
     * Fast path: when the box has zero roll/pitch/yaw (the common leaf case)
     * its OBB axes are the world axes, so the whole rotation-matrix +
     * deltaTransformVector + normalize sequence is skipped and we work with
     * scalar axis components throughout (no `Vector3D.dotProduct` calls).
     */
    public function testCollisionWithBox(other:Physics3DObjectBox, ref:Physics3DCollision):Null<Physics3DCollision> {
        // cylinder center (scalars)
        final cx = this.position.x;
        final cy = this.position.y;
        final cz = this.position.z;
        final hh = this.height * 0.5;

        // box half-extents (scalars)
        final eb0 = other.width * 0.5;
        final eb1 = other.height * 0.5;
        final eb2 = other.length * 0.5;

        // box center (scalars)
        final bx = other.position.x;
        final by = other.position.y;
        final bz = other.position.z;

        // Axis-aligned fast path — the leaf case. Skip matrix building and
        // use world axes directly via scalar components. Also collapses the
        // dotProduct calls that would otherwise dispatch through Vector3D.
        final axisAligned = other.position.roll == 0
                         && other.position.pitch == 0
                         && other.position.yaw == 0;

        var B0x:Float, B0y:Float, B0z:Float;
        var B1x:Float, B1y:Float, B1z:Float;
        var B2x:Float, B2y:Float, B2z:Float;

        if (axisAligned) {
            B0x = 1; B0y = 0; B0z = 0;
            B1x = 0; B1y = 1; B1z = 0;
            B2x = 0; B2y = 0; B2z = 1;
        } else {
            _mB.identity();
            _mB.appendRotation(other.position.roll,  Constants.VECTOR3D_POSZ);
            _mB.appendRotation(other.position.pitch, Constants.VECTOR3D_POSX);
            _mB.appendRotation(other.position.yaw,   Constants.VECTOR3D_POSY);

            Matrix3DUtil.deltaTransformVectorToOutput(_mB, Constants.VECTOR3D_POSX, _B0); _B0.normalize();
            Matrix3DUtil.deltaTransformVectorToOutput(_mB, Constants.VECTOR3D_POSY, _B1); _B1.normalize();
            Matrix3DUtil.deltaTransformVectorToOutput(_mB, Constants.VECTOR3D_POSZ, _B2); _B2.normalize();

            B0x = _B0.x; B0y = _B0.y; B0z = _B0.z;
            B1x = _B1.x; B1y = _B1.y; B1z = _B1.z;
            B2x = _B2.x; B2y = _B2.y; B2z = _B2.z;
        }

        // --- 1) vertical overlap test (project box onto world-Y) ---
        // For axis-aligned the box's Y projection is exactly eb1.
        final rBoxY = axisAligned
            ? eb1
            : (Math.abs(eb0 * B0y) + Math.abs(eb1 * B1y) + Math.abs(eb2 * B2y));
        if (Math.abs(by - cy) > rBoxY + hh) return null;

        // --- 2) closest point on box to the cylinder axis point ---
        final dx = cx - bx;
        final dy = cy - by;
        final dz = cz - bz;

        final localX = dx * B0x + dy * B0y + dz * B0z;
        final localY = dx * B1x + dy * B1y + dz * B1z;
        final localZ = dx * B2x + dy * B2y + dz * B2z;

        final clampedX = (localX < -eb0) ? -eb0 : ((localX > eb0) ? eb0 : localX);
        final clampedY = (localY < -eb1) ? -eb1 : ((localY > eb1) ? eb1 : localY);
        final clampedZ = (localZ < -eb2) ? -eb2 : ((localZ > eb2) ? eb2 : localZ);

        final closestX = bx + B0x * clampedX + B1x * clampedY + B2x * clampedZ;
        final closestY = by + B0y * clampedX + B1y * clampedY + B2y * clampedZ;
        final closestZ = bz + B0z * clampedX + B1z * clampedY + B2z * clampedZ;

        // --- 3) horizontal distance on XZ plane (squared check avoids sqrt
        // when not colliding, which is the common case) ---
        final vx = closestX - cx;
        final vz = closestZ - cz;
        final hDistSq = vx*vx + vz*vz;
        final rSq = this.radius * this.radius;
        if (hDistSq > rSq) return null;

        final hDist = Math.sqrt(hDistSq);
        final penetration = this.radius - hDist;

        // normal (A -> B), cylinder center toward closest point on box
        if (hDist > _EPS) {
            final invH = 1.0 / hDist;
            if (ref.normal == null) ref.normal = new Vector3D(vx * invH, 0, vz * invH);
            else ref.normal.setTo(vx * invH, 0, vz * invH);
        } else {
            // degenerate: pick world +X as fallback
            if (ref.normal == null) ref.normal = new Vector3D(1, 0, 0);
            else ref.normal.setTo(1, 0, 0);
        }

        if (ref.contactPoint == null) ref.contactPoint = new Vector3D(closestX, closestY, closestZ);
        else ref.contactPoint.setTo(closestX, closestY, closestZ);

        ref.a = this;
        ref.b = other;
        ref.isColliding = true;
        ref.penetration = penetration;

        return ref;
    }


    // Cylinder vs plane: not implemented (return null). Keep signature ref-aware.
    public function testCollisionWithPlane(plane:Physics3DObjectPlane, ref:Physics3DCollision):Null<Physics3DCollision> {
        return null;
    }

    public override function testCollision(objectToTestAgainst:IPhysics3DObject, ref:Physics3DCollision):Null<Physics3DCollision> {
        if(!Physics3DObjectSphere.spheresCollide(position.x, position.y, position.z, oRadius, objectToTestAgainst.position.x, objectToTestAgainst.position.y, objectToTestAgainst.position.z, objectToTestAgainst.oRadius))
            return null;

        if (Std.isOfType(objectToTestAgainst, Physics3DObjectBox)) {
            return testCollisionWithBox(cast objectToTestAgainst, ref);
        } else if (Std.isOfType(objectToTestAgainst, Physics3DObjectPlane)) {
            return testCollisionWithPlane(cast objectToTestAgainst, ref);
        }
        return null;
    }

    // -------------------------------------------------------------------
    // Pre-bound pair dispatchers (Phase 2A)
    // -------------------------------------------------------------------
    // See the header comment in Physics3DObjectBox for the pattern. The
    // corresponding Box-is-first case (pair a=Box, b=Cylinder) lives on
    // Physics3DObjectBox as `pairBoxCylinder`.

    /** Cylinder-vs-Box (a=Cylinder, b=Box). */
    public static function pairCylinderBox(a:IPhysics3DObject, b:IPhysics3DObject, ref:Physics3DCollision):Null<Physics3DCollision> {
        final ca:Physics3DObjectCylinder = cast a;
        final bb:Physics3DObjectBox = cast b;
        if (!Physics3DObjectSphere.spheresCollide(
                ca.position.x, ca.position.y, ca.position.z, ca.oRadius,
                bb.position.x, bb.position.y, bb.position.z, bb.oRadius)) return null;
        return ca.testCollisionWithBox(bb, ref);
    }
}

