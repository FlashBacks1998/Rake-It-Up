package org.flashbacks1998.rake.systems;

import org.flashbacks1998.debugger.Debugger;
import openfl.Lib;
import openfl.Vector;

import haxe.ds.ObjectMap;

import org.flashbacks1998.world3d.World3D;
import org.flashbacks1998.world3d.entity.Entity3D;
import org.flashbacks1998.world3d.geom.Mesh3D;
import org.flashbacks1998.world3d.shader.ShaderPipeline;
import org.flashbacks1998.world3d.shader.parts.ColorIntensifierShaderPart;

import org.flashbacks1998.physics3d.Physics3D;
import org.flashbacks1998.physics3d.objects.IPhysics3DObject;
import org.flashbacks1998.physics3d.objects.Physics3DObjectBox;
import org.flashbacks1998.physics3d.events.Physics3DEventReachedSensor;

class LeafsSystem {
    // -------------------------------------------------
    // Public API
    // -------------------------------------------------

    public var leaves(default, null):Array<LeafSystem> = [];
    public var leavesIgnoreGroup(default, null):Vector<IPhysics3DObject> = new Vector();
    /**
     * Parallel to `leavesIgnoreGroup` — every leaf body points its `ignoreSet`
     * at this shared Map so the per-frame `a.ignores(b)` check in
     * `Physics3D.testForCollisions` is O(1) regardless of leaf count.
     * Kept in lockstep with the Vector in `onLeafHitGroundAt` and
     * `removeIgnoreAtSwapPop`.
     */
    public var leavesIgnoreSet(default, null):Map<IPhysics3DObject, Bool> = new Map();

    // -------------------------------------------------
    // Internal state
    // -------------------------------------------------

    private var _world:World3D;
    private var _physics:Physics3D;

    private var _mLeaf:Mesh3D;
    private var _spLeaves:ShaderPipeline;
    private var _spLeavesFalling:ShaderPipeline;
    private var _spLeavesColorOffset:ColorIntensifierShaderPart;

    // The ONE shared pile sensor (static sensor volume)
    private var _pileSensor:IPhysics3DObject;

    // Callback into SceneMain to increment score, etc.
    private var _onLeafCollected:Void->Void;

    // Map leaf physics body -> entity
    private var _bodyToEnt:ObjectMap<IPhysics3DObject, Entity3D> = new ObjectMap();

    // Map leaf physics body -> ignoreGroup index (for swap-pop removal)
    private var _bodyToIgnoreIndex:ObjectMap<IPhysics3DObject, Int> = new ObjectMap();

    private var _activeLeafCount:Int = 0;

    private var _pileListenerInstalled:Bool = false;

    public function new(
        world:World3D,
        physics:Physics3D,
        mLeaf:Mesh3D,
        pileSensor:IPhysics3DObject,
        spLeaves:ShaderPipeline,
        spLeavesFalling:ShaderPipeline,
        spLeavesColorOffset:ColorIntensifierShaderPart,
    ) {
        _world = world;
        _physics = physics;
        _mLeaf = mLeaf;

        _pileSensor = pileSensor;
        _spLeaves = spLeaves;
        _spLeavesFalling = spLeavesFalling;
        _spLeavesColorOffset = spLeavesColorOffset;

        installPileSensorListenerOnce();
    }

    private function installPileSensorListenerOnce():Void {
        if (_pileListenerInstalled) return;
        _pileListenerInstalled = true;

        // One listener, forever. No per-leaf listeners.
        _pileSensor.addEventListener(Physics3DEventReachedSensor.TYPE, onPileSensorReached);
    }

    // -------------------------------------------------
    // Spawning
    // ------------------------------------------------- 
    public function spawnNewLeaf(force:Bool = false):Void {
        // Basic guards (avoid silent no-op / null crashes)
        if (_world == null || _mLeaf == null || _spLeavesFalling == null) {
            // trace("spawnNewLeaf skipped: missing world/mesh/shader", _world, _mLeaf, _spLeavesFalling);
            return;
        }

        // "worse than 10fps" => frame time >= 100ms
        final slowFrameMs:Float = 1000.0 / 10.0; // 100ms
        final ttr:Float = Debugger.worldTTR + Debugger.physicsTTR; // ms (your code uses Lib.getTimer deltas)

        // If we're running slow AND we already have leaves, don't spawn more (unless forced)
        if (!force && _activeLeafCount > 0 && ttr >= slowFrameMs) {
            // trace("spawnNewLeaf blocked (slow): ttr=", ttr, "threshold=", slowFrameMs, "active=", _activeLeafCount);
            return;
        }

        // (Optional) hard cap safety (prevents runaway)
        // if (!force && _activeLeafCount >= 200) return;

        final rx = -7 + (Math.random() * 14);
        final rz = -7 + (Math.random() * 14);
        final ry = 10;

        final eLeaf = new Entity3D({
            meshes: Vector.ofArray(cast [{
                mesh: _mLeaf,
                shader: _spLeavesFalling
            }])
        });

        eLeaf.position.x = rx;
        eLeaf.position.y = ry;
        eLeaf.position.z = rz;

        leaves.push(new LeafSystem(eLeaf));
        _world.addChild(eLeaf);
        _activeLeafCount++;
    }

    // -------------------------------------------------
    // Per-frame update
    // -------------------------------------------------

    public function update(dt:Float):Void {
        updateFallingLeaves(dt);
    }

    public function updateColor():Void {
        var tMs = Lib.getTimer();
        var t = tMs * (1.0 / 255.0);

        var mul = 1.5 + 0.5 * Math.sin(t);
        var off = mul - 1.0;

        _spLeavesColorOffset.red = off;
        _spLeavesColorOffset.green = off;
        _spLeavesColorOffset.blue = off;
    }

    // -------------------------------------------------
    // Internal helpers
    // -------------------------------------------------

    private function updateFallingLeaves(dt:Float):Void {
        var i = leaves.length - 1;
        while (i >= 0) {
            var leaf = leaves[i];
            leaf.update(dt);

            if (leaf._eRef.position.y <= 0.5) {
                onLeafHitGroundAt(i, leaf);
            }

            i--;
        }
    }

    private function onLeafHitGroundAt(i:Int, leaf:LeafSystem):Void {
        final ent = leaf._eRef;

        // Switch shader immediately
        ent.meshes[0].shader = _spLeaves;

        // Create a physics body for THIS leaf (this is what rake pushes)
        final leafBody = new Physics3DObjectBox(ent.position, 1, 1, 1, false);
        // Share BOTH the Vector and the Set across every leaf — Physics3D uses
        // the Set for O(1) `ignores()` lookup; the Vector remains the source
        // of truth for ordered swap-pop removal.
        leafBody.ignoreGroup = leavesIgnoreGroup;
        leafBody.ignoreSet = leavesIgnoreSet;
        leafBody.isStatic = false;

        // IMPORTANT: do NOT put pile sensor into ignoreGroup if you want detection!
        // leavesIgnoreGroup is only for leaf-vs-leaf ignore.

        // Track ignoreGroup index (swap-pop removal)
        final idx = leavesIgnoreGroup.length;
        leavesIgnoreGroup.push(leafBody);
        leavesIgnoreSet.set(leafBody, true);
        _bodyToIgnoreIndex.set(leafBody, idx);

        // Map leafBody -> entity
        _bodyToEnt.set(leafBody, ent);

        _physics.addObject(leafBody);

        // Remove leaf system from falling array
        removeLeafAtSwapPop(i);
    }

    // -------------------------------------------------
    // Pile sensor handler
    // -------------------------------------------------

    private function onPileSensorReached(e:Physics3DEventReachedSensor):Void {
        // The sensor is the dispatcher. We need the OTHER object (the leaf body).
        final object:IPhysics3DObject = e.object;
        if (object == null) return;

        final leaf = _bodyToEnt.get(object);
        if (leaf == null) return;

        // Remove entity + physics
        _bodyToEnt.remove(object);

        _physics.removeObject(object);
        _world.removeChild(leaf);

        // Remove from ignore group
        removeIgnoreAtSwapPop(object);
    }


    // -------------------------
    // O(1) removals (swap-pop)
    // -------------------------

    private inline function removeLeafAtSwapPop(i:Int):Void {
        var last = leaves.length - 1;
        if (i != last) leaves[i] = leaves[last];
        leaves.pop();
    }

    private inline function removeIgnoreAtSwapPop(body:IPhysics3DObject):Void {
        var idx = _bodyToIgnoreIndex.get(body);
        if (idx == null) return;

        var last = leavesIgnoreGroup.length - 1;

        if (idx != last) {
            var lastBody = leavesIgnoreGroup[last];
            leavesIgnoreGroup[idx] = lastBody;
            _bodyToIgnoreIndex.set(lastBody, idx);
        }

        leavesIgnoreGroup.pop();
        // Mirror the removal on the parallel set — otherwise Physics3D would
        // still treat `body` as ignored by every other leaf after it's gone.
        leavesIgnoreSet.remove(body);
        _bodyToIgnoreIndex.remove(body);
        _activeLeafCount--;
    }
}