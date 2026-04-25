package org.flashbacks1998.physics3d;

import org.flashbacks1998.world3d.geom.Position3D;
import org.flashbacks1998.physics3d.events.Physics3DEventReachedSensor;
import openfl.Lib;
import openfl.Vector;
import org.flashbacks1998.physics3d.objects.IPhysics3DObject;
import org.flashbacks1998.physics3d.objects.Physics3DObjectBox;
import org.flashbacks1998.physics3d.objects.Physics3DObjectCylinder;
import org.flashbacks1998.physics3d.objects.Physics3DObjectPlane;
import org.flashbacks1998.debugger.Debugger;
import openfl.geom.Vector3D;
import openfl.geom.Matrix3D;
import org.flashbacks1998.world3d.camera.Camera3D;

/**
 * Simple physics world:
 *  - substepped integration (velocity -> position)
 *  - pairwise collision detection via object.testCollision(...)
 *  - immediate positional resolution (no slop, full correction)
 *  - sensor collision collection + event dispatch
 *  - world bounds enforcement
 *
 * This is intentionally straightforward and synchronous.
 */

// Cursor ray typedef
typedef Physics3DRay = {
    origin:Vector3D,
    direction:Vector3D
}

// Collision descriptor
typedef Physics3DCollision = {
    var a:IPhysics3DObject;
    var b:IPhysics3DObject;
    var isColliding:Bool;
    var normal:Vector3D;      // expected direction: A -> B
    var penetration:Float;
    var contactPoint:Vector3D;
}

/**
 * Narrow-phase test function signature. Populated at `addObject` time via
 * `Physics3D.pickTestFn` so the per-frame collision loop can avoid the
 * `Std.isOfType` cascade that each concrete `testCollision` otherwise runs.
 */
typedef Physics3DPairTestFn = (IPhysics3DObject, IPhysics3DObject, Physics3DCollision) -> Null<Physics3DCollision>;

typedef Physics3DCollisionPair = {
    var object1:IPhysics3DObject;
    var object2:IPhysics3DObject;
    var testFn:Physics3DPairTestFn;
}

class Physics3D {
    // reusable temporaries to reduce GC
    private static var _rayCamera:Vector3D = new Vector3D();
    private static var _invView:Matrix3D = new Matrix3D();
    private static var _rayOrigin:Vector3D = new Vector3D();
    private static var _rayDirection:Vector3D = new Vector3D();

    public static function getIntersectionWithPlaneY(ray:Physics3DRay, planeY:Float):Null<Vector3D> {
        var dirY = ray.direction.y;
        if (Math.abs(dirY) < 0.0001) {
            // Ray is parallel to the plane
            return null;
        }

        var t = (planeY - ray.origin.y) / dirY;
        if (t < 0) {
            // Intersection is behind the ray origin
            return null;
        }

        var intersectX = ray.origin.x + ray.direction.x * t;
        var intersectZ = ray.origin.z + ray.direction.z * t;

        return new Vector3D(intersectX, planeY, intersectZ);
    }

    public static function getCursorRaycastInWorldspace(
        cursorX:Float, cursorY:Float, screenWidth:Float, screenHeight:Float, camera:Camera3D
    ):Physics3DRay {
        camera.updateMatrices();

        var ndcX = (2.0 * cursorX / screenWidth) - 1.0;
        var ndcY = 1.0 - (2.0 * cursorY / screenHeight);

        var fovRad = camera.fov * Math.PI / 180.0;
        var tanFov = Math.tan(fovRad * 0.5);

        _rayCamera.setTo(ndcX * camera.aspect * tanFov, ndcY * tanFov, 1);
        _rayCamera.normalize();

        _invView.copyFrom(camera.view);
        _invView.invert();

        _rayOrigin.setTo(camera.x, camera.y, camera.z);
        _rayDirection.copyFrom(_invView.deltaTransformVector(_rayCamera));
        _rayDirection.normalize();

        return { origin: _rayOrigin, direction: _rayDirection };
    }

    public static function getPositionInScreenSpace(
        camera:Camera3D,
        object:Position3D,
        viewportWidth:Float,
        viewportHeight:Float,
        ref:Vector3D = null
    ):Vector3D {
        // Make sure matrices are current
        camera.updateMatrices();
        object.updateMatrix();

        // Object origin in local space
        var localPos = new Vector3D(0, 0, 0, 1);

        // Local -> World
        var worldPos = object.transformVector(localPos);

        // World -> View
        var viewPos = camera.view.transformVector(worldPos);

        // View -> Clip (homogeneous)
        var clipPos = camera.projection.transformVector(viewPos);

        // If w <= 0, the point is behind the camera plane
        if (clipPos.w <= 0) return null;

        // Perspective divide: NDC in [-1,1] on x,y, and [0,1] on z (D3D-style)
        final ndcX = clipPos.x / clipPos.w;
        final ndcY = clipPos.y / clipPos.w;
        final ndcZ = clipPos.z / clipPos.w;

        // Optional: reject if outside clip-space
        /*
        if (ndcX < -1 || ndcX > 1 || ndcY < -1 || ndcY > 1 || ndcZ < 0 || ndcZ > 1) {
            // off-screen or clipped; return null or clamp if you prefer
            // return null;
        }
        */

        // NDC -> screen pixels
        // NDC x: -1 (left) -> 1 (right)
        // NDC y: -1 (bottom) -> 1 (top)
        final screenX = (ndcX + 1) * 0.5 * viewportWidth;
        final screenY = (1 - ndcY) * 0.5 * viewportHeight; // flip Y because screen Y grows downward

        final ret = ref ?? new Vector3D();
        ret.setTo(screenX, screenY, ndcZ);

        return ret;
    }

    // public state
    private var objects:Vector<IPhysics3DObject> = new Vector();
    private var _objectsToTest:Vector<Physics3DCollisionPair> = new Vector();
    public var gravity:Vector3D = new Vector3D(0, -20, 0);

    // world bounds (defaults = infinite/unbounded)
    public var minWorldX:Float = -Math.POSITIVE_INFINITY;
    public var maxWorldX:Float = Math.POSITIVE_INFINITY;
    public var minWorldY:Float = -Math.POSITIVE_INFINITY;
    public var maxWorldY:Float = Math.POSITIVE_INFINITY;
    public var minWorldZ:Float = -Math.POSITIVE_INFINITY;
    public var maxWorldZ:Float = Math.POSITIVE_INFINITY;

    // internal buffers (reused)
    private var _collisions:Vector<Physics3DCollision> = new Vector();
    private var _totalCollisions:Int = 0;
    private var _sensorCollisions:Vector<Physics3DCollision> = new Vector();

    public function new() {}

    // -------------------------------------------------------------------
    // Narrow-phase dispatch table (Phase 2A)
    // -------------------------------------------------------------------
    // Each shape class owns the `pair<X><Y>` static functions for pairs it
    // is the "a" (object1) side of — see `Physics3DObjectBox.pairBoxBox`,
    // `Physics3DObjectCylinder.pairCylinderBox`, etc. Physics3D only keeps
    // the type-dispatch router (`pickTestFn`) and the generic fallback for
    // shapes that haven't been specialized.

    /**
     * Fallback: objects of unknown / not-specialized types (e.g. Surface).
     * Runs the legacy virtual dispatch — same behaviour as before Phase 2A.
     * Keeps the engine correct for any new shape added later without
     * requiring an update to the dispatch table.
     */
    private static function _pairFallback(a:IPhysics3DObject, b:IPhysics3DObject, ref:Physics3DCollision):Null<Physics3DCollision> {
        return a.testCollision(b, ref);
    }

    /**
     * One-time concrete-type dispatch lookup. Called at `addObject` when
     * building the pair list. The returned function is stored on the pair
     * and reused every frame. All the heavy lifting lives on the shape
     * classes themselves; this is just the router.
     */
    private static function pickTestFn(a:IPhysics3DObject, b:IPhysics3DObject):Physics3DPairTestFn {
        final aBox = Std.isOfType(a, Physics3DObjectBox);
        final bBox = Std.isOfType(b, Physics3DObjectBox);
        final aCyl = Std.isOfType(a, Physics3DObjectCylinder);
        final bCyl = Std.isOfType(b, Physics3DObjectCylinder);
        final aPln = Std.isOfType(a, Physics3DObjectPlane);
        final bPln = Std.isOfType(b, Physics3DObjectPlane);

        if (aBox && bBox) return Physics3DObjectBox.pairBoxBox;
        if (aBox && bCyl) return Physics3DObjectBox.pairBoxCylinder;
        if (aCyl && bBox) return Physics3DObjectCylinder.pairCylinderBox;
        if (aBox && bPln) return Physics3DObjectBox.pairBoxPlane;
        if (aPln && bBox) return Physics3DObjectPlane.pairPlaneBox;
        return _pairFallback;
    }

    /**
     * Pairwise collision test (simple O(n^2) loop).
     * Calls each object's testCollision(b, ref) and then fallback b.testCollision(a, ref).
     * Re-uses preallocated collision slots in `collisionsRef`.
     * After running: `_totalCollisions` will contain the number of active collisions
     * and `collisionsRef[0.._totalCollisions-1]` will be valid entries.
     */
    public inline function testForCollisions(objects:Vector<IPhysics3DObject>, collisionsRef:Vector<Physics3DCollision>):Vector<Physics3DCollision> {
        _totalCollisions = 0;

        final n = objects.length; 

        //for (i in 0...n) {
            //final a = objects[i];
            //if (a == null) continue;

            //for (j in (i + 1)...n) {
                //final b = objects[j];

        for(i in 0..._objectsToTest.length) {
            final pair = _objectsToTest[i];
            final a = pair.object1;
            final b = pair.object2;
            final testFn = pair.testFn;

                if (a == null) continue;
                if (b == null) continue;
                if (b == a) continue;
                if (testFn == null) continue;

                // skip static-static pairs
                if (a.isStatic && b.isStatic) continue;
                // O(1) set lookup — mirrors `ignoreGroup` via Physics3DObject.ignoreSet.
                // Prior `ignoreGroup.indexOf(...)` was O(k) per pair, turning this loop
                // into O(n³) when the leaf ignore group grew to leaf-count.
                if (b.ignores(a) || a.ignores(b)) continue;
 
                // ensure we have a reusable slot in collisionsRef at index _totalCollisions
                var slot:Physics3DCollision;
                if (_totalCollisions < collisionsRef.length) {
                    slot = collisionsRef[_totalCollisions];
                    // reset the primitive fields but keep allocated Vector3D instances
                    slot.a = a;
                    slot.b = b;
                    slot.isColliding = false;
                    slot.penetration = 0;
                    if (slot.normal == null) slot.normal = new Vector3D(); else { slot.normal.x = 0; slot.normal.y = 0; slot.normal.z = 0; }
                    if (slot.contactPoint == null) slot.contactPoint = new Vector3D(); else { slot.contactPoint.x = 0; slot.contactPoint.y = 0; slot.contactPoint.z = 0; }
                } else {
                    slot = { a: a, b: b, isColliding: false, normal: new Vector3D(), penetration: 0, contactPoint: new Vector3D() };
                    collisionsRef.push(slot);
                }

                // Phase 2A: pre-bound narrow-phase from pickTestFn. Falls
                // back to a.testCollision via _pairFallback for unknown types.
                final col:Null<Physics3DCollision> = testFn(a, b, slot);
                
                // prefer a's detection, fallback to b's detection
                /*if (col == null) {
                    // try the fallback; set slot.a/slot.b to match the call
                    slot.a = b;
                    slot.b = a;
                    col = b.testCollision(a, slot);
                }*/

                if (col != null && col.penetration > 0) {
                    // keep the returned collision in the active slice
                    collisionsRef[_totalCollisions] = col;
                    _totalCollisions++; 
                } else {
                    // no collision — leave slot allocated for reuse later
                }
            }
            //}
        //}

        return collisionsRef;
    }

    /**
     * Resolve collisions fully and remove velocity normal component.
     * Normal expected A -> B. Sensor collisions are recorded and NOT resolved.
     * Uses _totalCollisions to know how many entries in `collisions` are active.
     */
    public inline function resolveCollisions(collisions:Vector<Physics3DCollision>):Void {
        for (i in 0..._totalCollisions) {
            final col = collisions[i];
            if (col == null) continue;

            final a = col.a;
            final b = col.b;
            if (a == null || b == null) continue;
            if (a.isStatic && b.isStatic) continue;

            // sensor handling: record pair and skip resolution.
            // Dedup scan removed: every pair in `_objectsToTest` is unique
            // and tested at most once per substep, so `_sensorCollisions`
            // cannot receive the same (a,b) twice within a step — the old
            // O(m) linear scan was dead code that turned the surrounding
            // loop into O(m²) at scale.
            if (a.isSensor || b.isSensor) {
                _sensorCollisions.push(col);
                continue;
            }

            final nVec = col.normal;
            if (nVec == null) continue;

            // Every narrow-phase implementation writes a unit normal into
            // `ref.normal` (AABB axis-aligned, SAT normalizes `_bestAxis`,
            // plane uses `plane.normal` which is pre-normalized, cylinder-vs-box
            // divides by `hDist`). Skip the per-frame Math.sqrt + 3 divides
            // and just zero-guard.
            final nx = nVec.x;
            final ny = nVec.y;
            final nz = nVec.z;
            if (nx*nx + ny*ny + nz*nz < 1e-8) continue;

            final pen = col.penetration;
            if (pen <= 0) continue;

            // full positional correction
            if (a.isStatic && !b.isStatic) {
                b.position.x += nx * pen;
                b.position.y += ny * pen;
                b.position.z += nz * pen;
                removeNormalComponent(b.velocity, nx, ny, nz);
            } else if (b.isStatic && !a.isStatic) {
                a.position.x -= nx * pen;
                a.position.y -= ny * pen;
                a.position.z -= nz * pen;
                removeNormalComponent(a.velocity, nx, ny, nz);
            } else {
                var half = 0.5 * pen;
                a.position.x -= nx * half;
                a.position.y -= ny * half;
                a.position.z -= nz * half;

                b.position.x += nx * half;
                b.position.y += ny * half;
                b.position.z += nz * half;

                removeNormalComponent(a.velocity, nx, ny, nz);
                removeNormalComponent(b.velocity, nx, ny, nz);
            }
        }
    }

    /**
     * Remove component of `vel` along normalized (nx,ny,nz).
     * Keeps tangential velocity untouched.
     */
    private function removeNormalComponent(vel:Vector3D, nx:Float, ny:Float, nz:Float):Void {
        var vdot = vel.x * nx + vel.y * ny + vel.z * nz;
        vel.x -= nx * vdot;
        vel.y -= ny * vdot;
        vel.z -= nz * vdot;
    }

    /**
     * Dispatch sensor events for recorded sensor collisions.
     * The event is dispatched on the non-sensor object, with the sensor passed as the first arg.
     */
    public static function resolveSensorCollisions(sensorCollisions:Vector<Physics3DCollision>):Void {
        if (sensorCollisions == null) return;
        for (i in 0...sensorCollisions.length) {
            final col = sensorCollisions[i];

            if (col == null) continue;
            if (!(col.a.isSensor || col.b.isSensor)) continue;

            // Figure out the sensor/object pairing once, then dispatch on both
            // endpoints with pooled events (Phase 3A).
            var sensor:IPhysics3DObject;
            var other:IPhysics3DObject;
            if (col.a.isSensor && !col.b.isSensor) {
                sensor = col.a; other = col.b;
            } else if (col.b.isSensor && !col.a.isSensor) {
                sensor = col.b; other = col.a;
            } else {
                // both sensors — original behaviour dispatched both sides as
                // (sensor=b, object=a) on a and (sensor=a, object=b) on b. We
                // keep that shape with two separate pooled events.
                final e1 = Physics3DEventReachedSensor.acquire(col.b, col.a);
                col.a.dispatchEvent(e1);
                Physics3DEventReachedSensor.release(e1);

                final e2 = Physics3DEventReachedSensor.acquire(col.a, col.b);
                col.b.dispatchEvent(e2);
                Physics3DEventReachedSensor.release(e2);
                continue;
            }

            // Sensor-vs-object: both endpoints receive an event whose
            // `.sensor` is the sensor and `.object` is the non-sensor body.
            final e1 = Physics3DEventReachedSensor.acquire(sensor, other);
            sensor.dispatchEvent(e1);
            Physics3DEventReachedSensor.release(e1);

            final e2 = Physics3DEventReachedSensor.acquire(sensor, other);
            other.dispatchEvent(e2);
            Physics3DEventReachedSensor.release(e2);
        }
    }
 
    public function step(delta:Float, steps:UInt = 1):Void {
        final numSteps = (steps > 0) ? steps : 1;
        final subDelta = delta / numSteps;

        // Reset sensor buffer for this substep (we record sensors during resolution)
        _sensorCollisions.length = 0;
        // DO NOT clear _collisions length; we reuse allocated slots. _totalCollisions will be reset by testForCollisions.

        for (s in 0...numSteps) {
            // Sub-phase wall-clock timing — accumulated across substeps, reset
            // per-frame by Debugger.reset() so the DebuggerStats overlay shows
            // per-frame totals.
            final t0 = Lib.getTimer();
            integrate(subDelta);
            final t1 = Lib.getTimer();
            testForCollisions(objects, _collisions);
            final t2 = Lib.getTimer();
            resolveCollisions(_collisions);
            final t3 = Lib.getTimer();
            enforceBoundsAll();
            final t4 = Lib.getTimer();

            Debugger.physicsIntegrateTTR += (t1 - t0);
            Debugger.physicsCollisionTTR += (t2 - t1);
            Debugger.physicsResolveTTR   += (t3 - t2);
            Debugger.physicsBoundsTTR    += (t4 - t3);
        }

        final t5 = Lib.getTimer();
        resolveSensorCollisions(_sensorCollisions);
        Debugger.physicsSensorDispatchTTR += Lib.getTimer() - t5;

        // Scene-state counters (cheap snapshots, overlay reads these directly).
        Debugger.physicsPairCount = _objectsToTest.length;
        Debugger.physicsCollisionCount = _totalCollisions;
        Debugger.physicsSensorCollisionCount = _sensorCollisions.length;
    }

    /**
     * Velocity -> position integration for every non-static body. Extracted
     * from `step` so it can be wall-clock timed independently.
     */
    private inline function integrate(subDelta:Float):Void {
        for (i in 0...objects.length) {
            final o = objects[i];
            if (o == null || o.isStatic) continue;

            // apply gravity
            o.velocity.x += gravity.x * subDelta;
            o.velocity.y += gravity.y * subDelta;
            o.velocity.z += gravity.z * subDelta;

            // integrate position
            o.position.x += o.velocity.x * subDelta;
            o.position.y += o.velocity.y * subDelta;
            o.position.z += o.velocity.z * subDelta;
        }
    }

    /**
     * World-bounds enforcement for every live body. Extracted from `step` so
     * it can be timed independently. Each concrete shape implements
     * `testAndResolveForOutOfBounds` via the IPhysics3DObject interface, so
     * no try/catch wrapper is needed.
     */
    private inline function enforceBoundsAll():Void {
        for (i in 0...objects.length) {
            final o = objects[i];
            if (o == null) continue;
            o.testAndResolveForOutOfBounds(minWorldX, minWorldY, minWorldZ, maxWorldX, maxWorldY, maxWorldZ);
        }
    }

    // Manage objects in the world. We avoid re-allocating the objects vector where possible
    // by setting removed slots to null; addObject will try to reuse null slots.
    public function addObject(obj:IPhysics3DObject):Void {
        // 1) Try to reuse a null slot, but DO NOT return — we still must build pairs.
        var reused = false;
        for (i in 0...objects.length) {
            if (objects[i] == null) {
                objects[i] = obj;
                reused = true;
                break;
            }
        }

        // 2) Build test pairs against all existing objects (non-null, not self),
        //    but only if they are NOT in either ignore list. Uses the O(1)
        //    parallel set; runtime ignore mutation still has to re-check every
        //    frame (see testForCollisions), but build-time filtering avoids
        //    ever enqueuing known-ignored pairs.
        for (i in 0...objects.length) {
            final aobj = objects[i];
            if (aobj == null || aobj == obj) continue;

            if (obj.ignores(aobj) || aobj.ignores(obj)) continue;
            // Static-vs-static pairs can never generate a collision. Filter
            // at build time so the per-frame collision loop doesn't even
            // visit them (Phase 3B).
            if (obj.isStatic && aobj.isStatic) continue;

            _objectsToTest.push({
                object1: obj,
                object2: aobj,
                // Pre-bind the narrow-phase function once per pair so the
                // per-frame loop can call it directly (Phase 2A).
                testFn: pickTestFn(obj, aobj)
            });
        }

        // 3) If we didn’t reuse a slot, append at the end.
        if (!reused) {
            objects.push(obj);
        }
    }

    
    public function removeObject(obj:IPhysics3DObject):Void {
        // Null out the slot to keep capacity for reuse
        for (i in 0...objects.length) {
            if (objects[i] == obj) {
                objects[i] = null;
                break;
            }
        }

        // Remove any test pairs involving this object (iterate backwards)
        var j = _objectsToTest.length - 1;
        while (j >= 0) {
            final rtest = _objectsToTest[j];
            if (rtest != null && (rtest.object1 == obj || rtest.object2 == obj)) {
                _objectsToTest.removeAt(j);
            }
            j--;
        }
    }


}
