package org.flashbacks1998.physics3d.objects;

import org.flashbacks1998.util.Vector3DUtil;
import org.flashbacks1998.util.Matrix3DUtil;
import openfl.geom.Matrix3D;
import org.flashbacks1998.world3d.geom.Position3D;
import org.flashbacks1998.physics3d.Physics3D.Physics3DCollision;
import openfl.geom.Vector3D;
import org.flashbacks1998.util.Constants;

// Pair-dispatch imports: each static `pairBoxX` below is the pre-bound
// narrow-phase function stored on a Physics3DCollisionPair when Box is the
// "first" (object1) member of that pair.

class Physics3DObjectBox extends Physics3DObject implements IPhysics3DObject {
    public var width:Float;
    public var height:Float;
    public var length:Float; 

    public function new(position:Position3D, width:Float, height:Float, length:Float, isStatic:Bool = false, isSensor:Bool = false) {
        super();

        this.isSensor = isSensor;
        this.position = position;
        this.length = length;
        this.width = width;
        this.height = height;

        oRadius = boxRadius(width, height, length);
    }
    
    public inline static function boxRadius(width:Float, height:Float, depth:Float):Float {
        return 0.5 * Math.sqrt(width * width + height * height + depth * depth);
    }

    // helper: projection radius of box (axes, extents) onto axis L (assumed normalized)
    public static function projRadius(ax0:Vector3D, ax1:Vector3D, ax2:Vector3D, e0:Float, e1:Float, e2:Float, L:Vector3D):Float {
        return Math.abs(e0 * ax0.dotProduct(L)) + Math.abs(e1 * ax1.dotProduct(L)) + Math.abs(e2 * ax2.dotProduct(L));
    }

    public function testCollisionWithBoxAABBvsAABB(other:Physics3DObjectBox, ref:Physics3DCollision):Null<Physics3DCollision> {
        // half extents
        final hx = this.width * 0.5;
        final hy = this.height * 0.5;
        final hz = this.length * 0.5;

        final ohx = other.width * 0.5;
        final ohy = other.height * 0.5;
        final ohz = other.length * 0.5;

        // displacement from this -> other
        final dx = other.position.x - this.position.x;
        final dy = other.position.y - this.position.y;
        final dz = other.position.z - this.position.z;

        // overlap on each axis
        var overlapX = (hx + ohx) - Math.abs(dx);
        var overlapY = (hy + ohy) - Math.abs(dy);
        var overlapZ = (hz + ohz) - Math.abs(dz);

        if (overlapX > 0 && overlapY > 0 && overlapZ > 0) {
            // collision — find minimum overlap axis (smallest penetration)
            var penetration = overlapX;
            var nx = (dx < 0) ? -1 : 1;
            var ny = 0;
            var nz = 0;

            if (overlapY < penetration) {
                penetration = overlapY;
                nx = 0; ny = (dy < 0) ? -1 : 1; nz = 0;
            }
            if (overlapZ < penetration) {
                penetration = overlapZ;
                nx = 0; ny = 0; nz = (dz < 0) ? -1 : 1;
            }

            // contact point approximation: midpoint of overlapping region along chosen axis
            var contactX = this.position.x;
            var contactY = this.position.y;
            var contactZ = this.position.z;

            if (nx != 0) {
                contactX = (this.position.x + (dx < 0 ? -hx : hx) + other.position.x + (dx < 0 ? ohx : -ohx)) * 0.5;
                contactY = (this.position.y + other.position.y) * 0.5;
                contactZ = (this.position.z + other.position.z) * 0.5;
            } else if (ny != 0) {
                contactY = (this.position.y + (dy < 0 ? -hy : hy) + other.position.y + (dy < 0 ? ohy : -ohy)) * 0.5;
                contactX = (this.position.x + other.position.x) * 0.5;
                contactZ = (this.position.z + other.position.z) * 0.5;
            } else {
                contactZ = (this.position.z + (dz < 0 ? -hz : hz) + other.position.z + (dz < 0 ? ohz : -ohz)) * 0.5;
                contactX = (this.position.x + other.position.x) * 0.5;
                contactY = (this.position.y + other.position.y) * 0.5;
            }

            // write into ref.normal/contactPoint safely (avoid NPEs)
            if (ref.normal == null) ref.normal = new Vector3D(nx, ny, nz);
            else ref.normal.setTo(nx, ny, nz);

            if (ref.contactPoint == null) ref.contactPoint = new Vector3D(contactX, contactY, contactZ);
            else ref.contactPoint.setTo(contactX, contactY, contactZ);

            ref.a = this;
            ref.b = other;
            ref.isColliding = true;
            ref.penetration = penetration;

            return ref;
        }

        return null;
    }
  
    // assumes these statics exist (you already declared most of them)
    private static final _t = new Vector3D();
    private static final _cA = new Vector3D();
    private static final _cB = new Vector3D();
    private static final _mA = new Matrix3D();
    private static final _mB = new Matrix3D();
    private static final _A0 = new Vector3D();
    private static final _A1 = new Vector3D();
    private static final _A2 = new Vector3D();
    private static final _B0 = new Vector3D();
    private static final _B1 = new Vector3D();
    private static final _B2 = new Vector3D();
    private static final _axis:Array<Vector3D> = [
        _A0, _A1, _A2,
        _B0, _B1, _B2,
        new Vector3D(), new Vector3D(), new Vector3D(),
        new Vector3D(), new Vector3D(), new Vector3D(),
        new Vector3D(), new Vector3D(), new Vector3D()
    ];
    private static final _bestAxis = new Vector3D();
    private static final _axisNorm = new Vector3D(); 
    private static final _EPS = 1e-6;
 
    public function testCollisionWithBoxOBBSAT(other:Physics3DObjectBox, ref:Physics3DCollision):Null<Physics3DCollision> {
        // half extents
        final ea0 = this.width  * 0.5;
        final ea1 = this.height * 0.5;
        final ea2 = this.length * 0.5;

        final eb0 = other.width  * 0.5;
        final eb1 = other.height * 0.5;
        final eb2 = other.length * 0.5;

        // ensure transforms are up-to-date
        this.position.updateMatrix();
        other.position.updateMatrix();

        // read matrices
        final dA = this.position.rawData;
        final dB = other.position.rawData;

        // centers (from translation)
        _cA.setTo(dA[12], dA[13], dA[14]);
        _cB.setTo(dB[12], dB[13], dB[14]);

        // world-space axes from rotation part of matrix (columns 0,1,2)
        _A0.setTo(dA[0], dA[1], dA[2]);   _A0.normalize();
        _A1.setTo(dA[4], dA[5], dA[6]);   _A1.normalize();
        _A2.setTo(dA[8], dA[9], dA[10]);  _A2.normalize();

        _B0.setTo(dB[0], dB[1], dB[2]);   _B0.normalize();
        _B1.setTo(dB[4], dB[5], dB[6]);   _B1.normalize();
        _B2.setTo(dB[8], dB[9], dB[10]);  _B2.normalize();

        // center vector
        _t.setTo(_cB.x - _cA.x, _cB.y - _cA.y, _cB.z - _cA.z);

        // cross-product axes into _axis[6..14]
        Vector3DUtil.crossProductToOutput(_A0, _B0, _axis[6]);
        Vector3DUtil.crossProductToOutput(_A0, _B1, _axis[7]);
        Vector3DUtil.crossProductToOutput(_A0, _B2, _axis[8]);

        Vector3DUtil.crossProductToOutput(_A1, _B0, _axis[9]);
        Vector3DUtil.crossProductToOutput(_A1, _B1, _axis[10]);
        Vector3DUtil.crossProductToOutput(_A1, _B2, _axis[11]);

        Vector3DUtil.crossProductToOutput(_A2, _B0, _axis[12]);
        Vector3DUtil.crossProductToOutput(_A2, _B1, _axis[13]);
        Vector3DUtil.crossProductToOutput(_A2, _B2, _axis[14]);

        var bestPen = Math.POSITIVE_INFINITY;
        var foundBest = false;

        for (ai in 0..._axis.length) {
            var axis = _axis[ai];
            if (axis == null) continue;

            var axx = axis.x;
            var axy = axis.y;
            var axz = axis.z;
            var axLenSq = axx*axx + axy*axy + axz*axz;
            if (axLenSq <= _EPS*_EPS) continue;

            var axLen = Math.sqrt(axLenSq);
            var Lx = axx / axLen;
            var Ly = axy / axLen;
            var Lz = axz / axLen;
            _axisNorm.setTo(Lx, Ly, Lz);

            var signedDist = (_t.x * Lx + _t.y * Ly + _t.z * Lz);
            var dist = Math.abs(signedDist);

            var rA = projRadius(_A0, _A1, _A2, ea0, ea1, ea2, _axisNorm);
            var rB = projRadius(_B0, _B1, _B2, eb0, eb1, eb2, _axisNorm);
            var sumR = rA + rB;

            if (dist > sumR) {
                return null; // separating axis found
            }

            var pen = sumR - dist;
            if (pen < bestPen) {
                bestPen = pen;
                var sign = (signedDist >= 0) ? 1 : -1;
                _bestAxis.setTo(Lx * sign, Ly * sign, Lz * sign);
                foundBest = true;
            }
        }

        if (!foundBest) {
            _bestAxis.setTo(Constants.VECTOR3D_POSX.x, Constants.VECTOR3D_POSX.y, Constants.VECTOR3D_POSX.z);
        }

        var contactX = (_cA.x + _cB.x) * 0.5;
        var contactY = (_cA.y + _cB.y) * 0.5;
        var contactZ = (_cA.z + _cB.z) * 0.5;

        if (ref.normal == null) ref.normal = new Vector3D(_bestAxis.x, _bestAxis.y, _bestAxis.z);
        else ref.normal.setTo(_bestAxis.x, _bestAxis.y, _bestAxis.z);

        if (ref.contactPoint == null) ref.contactPoint = new Vector3D(contactX, contactY, contactZ);
        else ref.contactPoint.setTo(contactX, contactY, contactZ);

        ref.a = this;
        ref.b = other;
        ref.isColliding = true;
        ref.penetration = bestPen;

        return ref;
    } 


    // --- Box vs Plane ---
    // plane must provide .position (point on plane) and .normal (unit)
    public function testCollisionWithPlane(plane:Physics3DObjectPlane, ref:Physics3DCollision):Null<Physics3DCollision> {
        final hx = this.width * 0.5;
        final hy = this.height * 0.5;
        final hz = this.length * 0.5;

        // radius = projected half extents onto plane normal
        final n = plane.normal;
        final radius = hx * Math.abs(n.x) + hy * Math.abs(n.y) + hz * Math.abs(n.z);

        // plane constant: distance from origin along normal to plane (d = dot(n, pointOnPlane))
        final planeD = n.x * plane.position.x + n.y * plane.position.y + n.z * plane.position.z;

        // signed distance from box center to plane
        final centerDot = n.x * this.position.x + n.y * this.position.y + n.z * this.position.z;
        final distance = centerDot - planeD; // >0 if center is in direction of n

        if (Math.abs(distance) <= radius) {
            // collision: penetration = radius - |distance|
            final penetration = radius - Math.abs(distance);

            // normal (A -> B). Avoid allocating if ref.normal exists.
            final nx = (distance > 0) ? -n.x : n.x;
            final ny = (distance > 0) ? -n.y : n.y;
            final nz = (distance > 0) ? -n.z : n.z;

            final contactX = this.position.x - n.x * distance;
            final contactY = this.position.y - n.y * distance;
            final contactZ = this.position.z - n.z * distance;

            if (ref.normal == null) ref.normal = new Vector3D(nx, ny, nz);
            else ref.normal.setTo(nx, ny, nz);

            if (ref.contactPoint == null) ref.contactPoint = new Vector3D(contactX, contactY, contactZ);
            else ref.contactPoint.setTo(contactX, contactY, contactZ);

            ref.a = this;
            ref.b = plane;
            ref.isColliding = true;
            ref.penetration = penetration;

            return ref;
        }

        return null;
    }

    public override function testCollision(objectToTestAgainst:IPhysics3DObject, ref:Physics3DCollision):Null<Physics3DCollision> {
        //trace("Testing for physobj", this, objectToTestAgainst, this.position, objectToTestAgainst.position);
        
        if(!Physics3DObjectSphere.spheresCollide(position.x, position.y, position.z, oRadius, objectToTestAgainst.position.x, objectToTestAgainst.position.y, objectToTestAgainst.position.z, objectToTestAgainst.oRadius))
            return null;

        //Box Collision
        if(Std.isOfType(objectToTestAgainst, Physics3DObjectBox)) {
            var other:Physics3DObjectBox = cast objectToTestAgainst;

            final aabb =
                other.position.roll == 0 &&
                other.position.pitch == 0 &&
                other.position.yaw == 0 &&
                position.roll == 0 &&
                position.pitch == 0 &&
                position.yaw == 0;

            if(aabb)
                return testCollisionWithBoxAABBvsAABB(cast other, ref);
            else
                return testCollisionWithBoxOBBSAT(cast other, ref);
        }

        //Plane Collison
        else if(Std.isOfType(objectToTestAgainst, Physics3DObjectPlane)) {
            return testCollisionWithPlane(cast objectToTestAgainst, ref);
        }
        else if (Std.isOfType(objectToTestAgainst, Physics3DObjectCylinder)) {
            return cast(objectToTestAgainst, Physics3DObjectCylinder).testCollisionWithBox(this, ref);
        }

        return null;
    }

    // -------------------------------------------------------------------
    // Pre-bound pair dispatchers (Phase 2A)
    // -------------------------------------------------------------------
    // These live here instead of `Physics3D.hx` so each shape owns the
    // narrow-phase entry points for pairs it is the "a" side of. Called by
    // `Physics3D.pickTestFn` once per pair at `addObject` time; the pair
    // caches the chosen function and calls it every frame with no further
    // dispatch. Each function replicates the behaviour of the legacy
    // `testCollision` virtual (broad-phase sphere test + the right narrow
    // phase) but skips the `Std.isOfType` cascade.

    /** Box-vs-Box: picks AABB-vs-AABB when both boxes have zero rotation, OBB-SAT otherwise. */
    public static function pairBoxBox(a:IPhysics3DObject, b:IPhysics3DObject, ref:Physics3DCollision):Null<Physics3DCollision> {
        final ab:Physics3DObjectBox = cast a;
        final bb:Physics3DObjectBox = cast b;
        if (!Physics3DObjectSphere.spheresCollide(
                ab.position.x, ab.position.y, ab.position.z, ab.oRadius,
                bb.position.x, bb.position.y, bb.position.z, bb.oRadius)) return null;
        final aabb = ab.position.roll == 0 && ab.position.pitch == 0 && ab.position.yaw == 0
                  && bb.position.roll == 0 && bb.position.pitch == 0 && bb.position.yaw == 0;
        return aabb ? ab.testCollisionWithBoxAABBvsAABB(bb, ref)
                    : ab.testCollisionWithBoxOBBSAT(bb, ref);
    }

    /** Box-vs-Cylinder (a=Box, b=Cylinder) — forwards to Cylinder's box test. */
    public static function pairBoxCylinder(a:IPhysics3DObject, b:IPhysics3DObject, ref:Physics3DCollision):Null<Physics3DCollision> {
        final ab:Physics3DObjectBox = cast a;
        final cb:Physics3DObjectCylinder = cast b;
        if (!Physics3DObjectSphere.spheresCollide(
                ab.position.x, ab.position.y, ab.position.z, ab.oRadius,
                cb.position.x, cb.position.y, cb.position.z, cb.oRadius)) return null;
        // Cylinder writes ref.a = cylinder, ref.b = box so the normal
        // (cylinder -> box) matches col.a -> col.b for the resolver.
        return cb.testCollisionWithBox(ab, ref);
    }

    /** Box-vs-Plane (a=Box, b=Plane). Plane is infinite — no sphere broad-phase. */
    public static function pairBoxPlane(a:IPhysics3DObject, b:IPhysics3DObject, ref:Physics3DCollision):Null<Physics3DCollision> {
        final ab:Physics3DObjectBox = cast a;
        final pb:Physics3DObjectPlane = cast b;
        return ab.testCollisionWithPlane(pb, ref);
    }

    public override function testAndResolveForOutOfBounds(minx:Float, miny:Float, minz:Float, maxx:Float, maxy:Float, maxz:Float) {
        // half extents
        final hx = this.width * 0.5;
        final hy = this.height * 0.5;
        final hz = this.length * 0.5;

        // compute box bounds
        final minBX = this.position.x - hx;
        final maxBX = this.position.x + hx;
        final minBY = this.position.y - hy;
        final maxBY = this.position.y + hy;
        final minBZ = this.position.z - hz;
        final maxBZ = this.position.z + hz;

        // corrections to apply to the center position
        var corrX:Float = 0;
        var corrY:Float = 0;
        var corrZ:Float = 0;

        // X axis
        if (minBX < minx) {
            // push right so minBX == minx
            corrX = minx - minBX;
        } else if (maxBX > maxx) {
            // push left so maxBX == maxx
            corrX = maxx - maxBX;
        }
        if (corrX != 0) {
            this.position.x += corrX;
            // remove velocity along X so the box doesn't keep trying to escape
            this.velocity.x = 0;
        }

        // Y axis
        if (minBY < miny) {
            corrY = miny - minBY;
        } else if (maxBY > maxy) {
            corrY = maxy - maxBY;
        }
        if (corrY != 0) {
            this.position.y += corrY;
            this.velocity.y = 0;
        }

        // Z axis
        if (minBZ < minz) {
            corrZ = minz - minBZ;
        } else if (maxBZ > maxz) {
            corrZ = maxz - maxBZ;
        }
        if (corrZ != 0) {
            this.position.z += corrZ;
            this.velocity.z = 0;
        }
    }
}
