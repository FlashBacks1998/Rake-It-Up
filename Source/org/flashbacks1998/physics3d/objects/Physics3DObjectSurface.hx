package org.flashbacks1998.physics3d.objects;

import openfl.geom.Vector3D;
import openfl.geom.Matrix3D;

import org.flashbacks1998.util.Constants;
import org.flashbacks1998.util.Matrix3DUtil;
import org.flashbacks1998.physics3d.Physics3D.Physics3DCollision;
import org.flashbacks1998.world3d.geom.Position3D;

class Physics3DObjectSurface extends Physics3DObject implements IPhysics3DObject {
    public var width:Float;
    public var length:Float;
    public var twoSided:Bool;

    // Orthonormal frame in world space: U (width axis), V (length axis), N (normal)
    public var U:Vector3D = new Vector3D();
    public var V:Vector3D = new Vector3D();
    public var N:Vector3D = new Vector3D();

    // local half extents
    private inline function ex():Float return width * 0.5;
    private inline function ey():Float return length * 0.5;

    // scratch
    private static var _m:Matrix3D = new Matrix3D();
    private static var _t:Vector3D = new Vector3D(); // (unused here but reserved if needed)
    private static var _Q:Vector3D = new Vector3D(); // projected point on plane
    private static var _A0:Vector3D = new Vector3D(); // box axes
    private static var _A1:Vector3D = new Vector3D();
    private static var _A2:Vector3D = new Vector3D();

    public function new(position:Position3D, width:Float, length:Float, twoSided:Bool = true, isStatic:Bool = true) {
        super();
        this.position = position;
        this.width = width;
        this.length = length;
        this.twoSided = twoSided;
        this.isStatic = isStatic;
        recomputeAxes(); // fill U,V,N based on yaw/pitch/roll
    }

    /**
     * Recompute world-space U,V,N from position's yaw/pitch/roll.
     * Convention: local X->U, local Y->V, local Z->N
     */
    public inline function recomputeAxes():Void {
        _m.identity();
        _m.appendRotation(position.roll,  Constants.VECTOR3D_POSZ);
        _m.appendRotation(position.pitch, Constants.VECTOR3D_POSX);
        _m.appendRotation(position.yaw,   Constants.VECTOR3D_POSY);

        Matrix3DUtil.deltaTransformVectorToOutput(_m, Constants.VECTOR3D_POSX, U); U.normalize();
        Matrix3DUtil.deltaTransformVectorToOutput(_m, Constants.VECTOR3D_POSY, V); V.normalize();
        Matrix3DUtil.deltaTransformVectorToOutput(_m, Constants.VECTOR3D_POSZ, N); N.normalize();
    }

    // --------------------------
    // Collision helpers
    // --------------------------

    /** Signed distance from point P to this surface plane. */
    private inline function signedDistanceToPlane(px:Float, py:Float, pz:Float):Float {
        // dist = dot(N, (P - C))
        return N.x * (px - position.x) + N.y * (py - position.y) + N.z * (pz - position.z);
    }

    /** Project P to plane: Q = P - N * dist, written into outQ. */
    private inline function projectPointToPlane(px:Float, py:Float, pz:Float, outQ:Vector3D):Void {
        final dist = signedDistanceToPlane(px, py, pz);
        outQ.setTo(px - N.x * dist, py - N.y * dist, pz - N.z * dist);
    }

    /** 2D rectangle membership test for a point Q on the plane (centered at C with axes U,V). */
    private inline function isInsideRectOnPlane(qx:Float, qy:Float, qz:Float, halfW:Float, halfL:Float):Bool {
        final rx = qx - position.x;
        final ry = qy - position.y;
        final rz = qz - position.z;

        final du = rx * U.x + ry * U.y + rz * U.z; // local U coord
        final dv = rx * V.x + ry * V.y + rz * V.z; // local V coord

        return (Math.abs(du) <= halfW + 1e-6) && (Math.abs(dv) <= halfL + 1e-6);
    }

private function testCollisionWithBox(other:Physics3DObjectBox, ref:Physics3DCollision):Null<Physics3DCollision> {
    // 0) Recompute surface axes (rotation-aware)
    recomputeAxes(); // U,V,N are normalized

    // 1) Box half extents and world-space axes (rotation-aware)
    var hx = other.width  * 0.5;
    var hy = other.height * 0.5;
    var hz = other.length * 0.5;

    _m.identity();
    _m.appendRotation(other.position.roll,  Constants.VECTOR3D_POSZ);
    _m.appendRotation(other.position.pitch, Constants.VECTOR3D_POSX);
    _m.appendRotation(other.position.yaw,   Constants.VECTOR3D_POSY);

    Matrix3DUtil.deltaTransformVectorToOutput(_m, Constants.VECTOR3D_POSX, _A0); _A0.normalize();
    Matrix3DUtil.deltaTransformVectorToOutput(_m, Constants.VECTOR3D_POSY, _A1); _A1.normalize();
    Matrix3DUtil.deltaTransformVectorToOutput(_m, Constants.VECTOR3D_POSZ, _A2); _A2.normalize();

    // 2) Center delta
    var dx = other.position.x - position.x;
    var dy = other.position.y - position.y;
    var dz = other.position.z - position.z;

    // 3) SAT along N (plane axis) — height overlap
    var distN = Math.abs(dx * N.x + dy * N.y + dz * N.z);
    var rBoxN =
        Math.abs(hx * (_A0.x * N.x + _A0.y * N.y + _A0.z * N.z)) +
        Math.abs(hy * (_A1.x * N.x + _A1.y * N.y + _A1.z * N.z)) +
        Math.abs(hz * (_A2.x * N.x + _A2.y * N.y + _A2.z * N.z));

    if (!twoSided && (dx * N.x + dy * N.y + dz * N.z) > 0) return null; // one-sided test
    if (distN > rBoxN) return null; // separated along N

    // Helpers to compute projection radii
    inline function rBoxOn(Lx:Float, Ly:Float, Lz:Float):Float {
        return
            Math.abs(hx * (_A0.x * Lx + _A0.y * Ly + _A0.z * Lz)) +
            Math.abs(hy * (_A1.x * Lx + _A1.y * Ly + _A1.z * Lz)) +
            Math.abs(hz * (_A2.x * Lx + _A2.y * Ly + _A2.z * Lz));
    }
    inline function rSurfOn(Lx:Float, Ly:Float, Lz:Float):Float {
        // surface is a rectangle in the plane: radius is ex*|dot(U,L)| + ey*|dot(V,L)|
        return ex() * Math.abs(U.x * Lx + U.y * Ly + U.z * Lz)
             + ey() * Math.abs(V.x * Lx + V.y * Ly + V.z * Lz);
    }
    inline function satInPlane(Lx:Float, Ly:Float, Lz:Float):Bool {
        // L must be in-plane; caller ensures orthonormalization
        var dist = Math.abs(dx * Lx + dy * Ly + dz * Lz);
        var r = rBoxOn(Lx, Ly, Lz) + rSurfOn(Lx, Ly, Lz);
        return dist <= r + 1e-6; // overlapped if true
    }

    // 4) 2D SAT in the plane: test U, V, and the projected box axes T0/T1/T2
    // U
    if (!satInPlane(U.x, U.y, U.z)) return null;
    // V
    if (!satInPlane(V.x, V.y, V.z)) return null;

    // Ti = Ai projected onto plane (remove normal component), normalized if not degenerate
    // T0
    var t0x = _A0.x - N.x * (_A0.x * N.x + _A0.y * N.y + _A0.z * N.z);
    var t0y = _A0.y - N.y * (_A0.x * N.x + _A0.y * N.y + _A0.z * N.z);
    var t0z = _A0.z - N.z * (_A0.x * N.x + _A0.y * N.y + _A0.z * N.z);
    var len = Math.sqrt(t0x*t0x + t0y*t0y + t0z*t0z);
    if (len > 1e-8) {
        t0x /= len; t0y /= len; t0z /= len;
        if (!satInPlane(t0x, t0y, t0z)) return null;
    }

    // T1
    var dotA1N = _A1.x * N.x + _A1.y * N.y + _A1.z * N.z;
    var t1x = _A1.x - N.x * dotA1N;
    var t1y = _A1.y - N.y * dotA1N;
    var t1z = _A1.z - N.z * dotA1N;
    len = Math.sqrt(t1x*t1x + t1y*t1y + t1z*t1z);
    if (len > 1e-8) {
        t1x /= len; t1y /= len; t1z /= len;
        if (!satInPlane(t1x, t1y, t1z)) return null;
    }

    // T2
    var dotA2N = _A2.x * N.x + _A2.y * N.y + _A2.z * N.z;
    var t2x = _A2.x - N.x * dotA2N;
    var t2y = _A2.y - N.y * dotA2N;
    var t2z = _A2.z - N.z * dotA2N;
    len = Math.sqrt(t2x*t2x + t2y*t2y + t2z*t2z);
    if (len > 1e-8) {
        t2x /= len; t2y /= len; t2z /= len;
        if (!satInPlane(t2x, t2y, t2z)) return null;
    }

    // 5) If all axes overlap, we have a collision. Resolve along ±N.
    // Contact point: project center to plane and clamp into the rectangle
    projectPointToPlane(other.position.x, other.position.y, other.position.z, _Q);

    var qrx = _Q.x - position.x;
    var qry = _Q.y - position.y;
    var qrz = _Q.z - position.z;
    var du = qrx * U.x + qry * U.y + qrz * U.z;
    var dv = qrx * V.x + qry * V.y + qrz * V.z;

    var halfW = ex(), halfL = ey();
    var duClamped = (du < -halfW) ? -halfW : (du > halfW ? halfW : du);
    var dvClamped = (dv < -halfL) ? -halfL : (dv > halfL ? halfL : dv);

    var contactX = position.x + U.x * duClamped + V.x * dvClamped;
    var contactY = position.y + U.y * duClamped + V.y * dvClamped;
    var contactZ = position.z + U.z * duClamped + V.z * dvClamped;

    var penetration = rBoxN - distN; // overlap along N
    var signN = (dx * N.x + dy * N.y + dz * N.z) >= 0 ? -1 : 1;
    var nx = N.x * signN, ny = N.y * signN, nz = N.z * signN;

    if (ref.normal == null) ref.normal = new Vector3D(nx, ny, nz); else ref.normal.setTo(nx, ny, nz);
    if (ref.contactPoint == null) ref.contactPoint = new Vector3D(contactX, contactY, contactZ);
    else ref.contactPoint.setTo(contactX, contactY, contactZ);

    ref.a = other;  // box
    ref.b = this;   // surface
    ref.isColliding = true;
    ref.penetration = penetration;

    return ref;
}



    // --- Surface vs Plane -------------------------------------------------
    private function testCollisionWithPlane(other:Physics3DObjectPlane, ref:Physics3DCollision):Null<Physics3DCollision> {
        // Recompute surface frame in case we moved/rotated
        recomputeAxes();

        // Plane data
        final n = other.normal; // assumed unit
        final planeD = n.x * other.position.x + n.y * other.position.y + n.z * other.position.z;

        // Signed distance from surface center (C) to plane
        final centerDot = n.x * this.position.x + n.y * this.position.y + n.z * this.position.z;
        final dist = centerDot - planeD;

        // Optional one-sided test: ignore from the "front" (+N) side if not two-sided
        if (!twoSided && dist > 0) return null;

        // Projection radius of the rectangle onto plane normal:
        // r = |ex * dot(U,n)| + |ey * dot(V,n)|, zero thickness along N.
        final halfW = ex();
        final halfL = ey();
        final r = Math.abs(halfW * (U.x * n.x + U.y * n.y + U.z * n.z))
            + Math.abs(halfL * (V.x * n.x + V.y * n.y + V.z * n.z));

        // Overlap test
        if (Math.abs(dist) > r) return null;

        // Contact point: project surface center to plane
        projectPointToPlane(this.position.x, this.position.y, this.position.z, _Q);

        // Finite rectangle test: ensure the projected center lies over the rectangle footprint
        if (!isInsideRectOnPlane(_Q.x, _Q.y, _Q.z, halfW, halfL)) return null;

        // Penetration
        final penetration = r - Math.abs(dist);

        // A->B normal: from plane-tested object (plane is 'other', surface is 'this')
        // Our resolution expects normal from A (other) to B (this surface), so flip sign appropriately:
        // dist > 0 means C is along +n from plane, so surface lies "above" plane → normal from plane(A) to surface(B) is +n.
        // But in your resolver A will be the dynamic object; since both are likely static, this mostly signals the direction.
        // To stay consistent with Box-vs-Plane convention (A is dynamic, B is static plane), we keep:
        final nx = (dist > 0) ? n.x : -n.x;
        final ny = (dist > 0) ? n.y : -n.y;
        final nz = (dist > 0) ? n.z : -n.z;

        if (ref.normal == null) ref.normal = new Vector3D(nx, ny, nz); else ref.normal.setTo(nx, ny, nz);
        if (ref.contactPoint == null) ref.contactPoint = new Vector3D(_Q.x, _Q.y, _Q.z); else ref.contactPoint.setTo(_Q.x, _Q.y, _Q.z);

        ref.a = other;   // plane as A
        ref.b = this;    // surface as B
        ref.isColliding = true;
        ref.penetration = penetration;

        return ref;
    }

    // --- Surface vs Cylinder ---------------------------------------------
    // Cylinder: axis-aligned to its local Y; world axis W derived from yaw/pitch/roll
    // Support (projection) of an oriented cylinder of radius rc, half-height hh on a unit axis L is:
    //   r(L) = rc * sqrt(1 - (dot(W,L))^2) + hh * |dot(W,L)|
    // Here we need r(N), where N is the surface normal (to do the plane overlap).
    private function testCollisionWithCylinder(other:Physics3DObjectCylinder, ref:Physics3DCollision):Null<Physics3DCollision> {
        recomputeAxes();

        // Cylinder world axis W from its rotation (local Y)
        _m.identity();
        _m.appendRotation(other.position.roll,  Constants.VECTOR3D_POSZ);
        _m.appendRotation(other.position.pitch, Constants.VECTOR3D_POSX);
        _m.appendRotation(other.position.yaw,   Constants.VECTOR3D_POSY);

        var W = _A1; // reuse _A1
        Matrix3DUtil.deltaTransformVectorToOutput(_m, Constants.VECTOR3D_POSY, W);
        W.normalize();

        var rc = other.radius;
        var hh = other.height * 0.5;

        // Plane overlap: rN
        var dotWN = W.x * N.x + W.y * N.y + W.z * N.z;
        var circleTermSqN = 1.0 - dotWN * dotWN; if (circleTermSqN < 0) circleTermSqN = 0;
        var rN = rc * Math.sqrt(circleTermSqN) + hh * Math.abs(dotWN);

        var dist = signedDistanceToPlane(other.position.x, other.position.y, other.position.z);
        if (!twoSided && dist > 0) return null;
        if (Math.abs(dist) > rN) return null;

        // Footprint expansion on U and V
        var dotWU = W.x * U.x + W.y * U.y + W.z * U.z;
        var circleTermSqU = 1.0 - dotWU * dotWU; if (circleTermSqU < 0) circleTermSqU = 0;
        var rU = rc * Math.sqrt(circleTermSqU) + hh * Math.abs(dotWU);

        var dotWV = W.x * V.x + W.y * V.y + W.z * V.z;
        var circleTermSqV = 1.0 - dotWV * dotWV; if (circleTermSqV < 0) circleTermSqV = 0;
        var rV = rc * Math.sqrt(circleTermSqV) + hh * Math.abs(dotWV);

        // In-plane center coordinates
        var rx = other.position.x - position.x;
        var ry = other.position.y - position.y;
        var rz = other.position.z - position.z;
        var du = rx * U.x + ry * U.y + rz * U.z;
        var dv = rx * V.x + ry * V.y + rz * V.z;

        if (Math.abs(du) > ex() + rU + 1e-6) return null;
        if (Math.abs(dv) > ey() + rV + 1e-6) return null;

        // Contact point
        projectPointToPlane(other.position.x, other.position.y, other.position.z, _Q);

        var penetration = rN - Math.abs(dist);
        var nx = (dist > 0) ? -N.x : N.x;
        var ny = (dist > 0) ? -N.y : N.y;
        var nz = (dist > 0) ? -N.z : N.z;

        if (ref.normal == null) ref.normal = new Vector3D(nx, ny, nz); else ref.normal.setTo(nx, ny, nz);
        if (ref.contactPoint == null) ref.contactPoint = new Vector3D(_Q.x, _Q.y, _Q.z); else ref.contactPoint.setTo(_Q.x, _Q.y, _Q.z);

        ref.a = other;
        ref.b = this;
        ref.isColliding = true;
        ref.penetration = penetration;

        return ref;
    }

 
    // --------------------------
    // IPhysics3DObject
    // --------------------------
    public override function testCollision(objectToTestAgainst:IPhysics3DObject, ref:Physics3DCollision):Null<Physics3DCollision> {
        // Box (AABB/OBB) vs Surface
        if (Std.isOfType(objectToTestAgainst, Physics3DObjectBox)) {
            return testCollisionWithBox(cast objectToTestAgainst, ref);
        }

        // Plane vs Surface
        if (Std.isOfType(objectToTestAgainst, Physics3DObjectPlane)) {
            return testCollisionWithPlane(cast objectToTestAgainst, ref);
        }

        // Cylinder vs Surface
        // (Assumes a collider type Physics3DObjectCylinder with .radius and .height,
        //  axis along its local Y; adjust the class name if yours differs.)
        if (Std.isOfType(objectToTestAgainst, Physics3DObjectCylinder)) {
            return testCollisionWithCylinder(cast objectToTestAgainst, ref);
        }

        return null;
    }

    /**
     * Clamp surface center so its rectangular area stays within world bounds.
     * Zeroes velocity components if the surface moves due to clamping.
     * This ensures the visible surface area never leaks outside the simulation limits.
     */
    public override function testAndResolveForOutOfBounds(
        minx:Float, miny:Float, minz:Float,
        maxx:Float, maxy:Float, maxz:Float
    ):Void {
        // half extents
        final hx = ex();
        final hz = ey(); // surface local width (X/U) and length (Z/V) used for XY plane footprint

        // recompute axes to ensure U,V are current
        recomputeAxes();

        // compute rough bounding box corners in world space (approximate by projecting extents onto world axes)
        final absUx = Math.abs(U.x);
        final absUy = Math.abs(U.y);
        final absUz = Math.abs(U.z);

        final absVx = Math.abs(V.x);
        final absVy = Math.abs(V.y);
        final absVz = Math.abs(V.z);

        // projected half extents in world axes (covers rotation)
        final halfX = hx * absUx + hz * absVx;
        final halfY = hx * absUy + hz * absVy;
        final halfZ = hx * absUz + hz * absVz;

        var clamped = false;

        // X axis
        if (position.x - halfX < minx) {
            position.x = minx + halfX;
            velocity.x = 0;
            clamped = true;
        } else if (position.x + halfX > maxx) {
            position.x = maxx - halfX;
            velocity.x = 0;
            clamped = true;
        }

        // Y axis
        if (position.y - halfY < miny) {
            position.y = miny + halfY;
            velocity.y = 0;
            clamped = true;
        } else if (position.y + halfY > maxy) {
            position.y = maxy - halfY;
            velocity.y = 0;
            clamped = true;
        }

        // Z axis
        if (position.z - halfZ < minz) {
            position.z = minz + halfZ;
            velocity.z = 0;
            clamped = true;
        } else if (position.z + halfZ > maxz) {
            position.z = maxz - halfZ;
            velocity.z = 0;
            clamped = true;
        }

        // If moved, recompute axes again (since we modified position)
        if (clamped) {
            recomputeAxes();
        }
    }
}
