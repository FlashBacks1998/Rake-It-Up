package org.flashbacks1998.physics3d.objects;

import openfl.Vector;
import openfl.events.IEventDispatcher;
import org.flashbacks1998.world3d.geom.Position3D;
import openfl.geom.Vector3D;
import org.flashbacks1998.physics3d.Physics3D.Physics3DCollision;

interface IPhysics3DObject extends IEventDispatcher {
    public var isStatic:Bool;
    public var isKinematic:Bool;
    public var isSensor:Bool;
    public var position:Position3D;
    public var velocity:Vector3D;
    public var ignoreGroup:Vector<IPhysics3DObject>;
    /**
     * Parallel O(1)-lookup set mirroring `ignoreGroup`. Use `addIgnore` /
     * `removeIgnore` on the implementing class to keep the two in sync; read
     * via `ignores(other)` in hot paths instead of `ignoreGroup.indexOf(...)`.
     */
    public var ignoreSet:Map<IPhysics3DObject, Bool>;
    public var oRadius:Float;
    public function addIgnore(other:IPhysics3DObject):Void;
    public function removeIgnore(other:IPhysics3DObject):Void;
    public function ignores(other:IPhysics3DObject):Bool;
    public function testCollision(objectToTestAgainst:IPhysics3DObject, ref:Physics3DCollision):Null<Physics3DCollision>;
    public function testAndResolveForOutOfBounds(minx:Float, miny:Float, minz:Float, maxx:Float, maxy:Float, maxz:Float):Void;
}