package org.flashbacks1998.world3d.entity;

import openfl.Vector;
import org.flashbacks1998.util.interfaces.IIndexed;
import openfl.events.IEventDispatcher;
import org.flashbacks1998.world3d.geom.Position3D;
import org.flashbacks1998.world3d.camera.Camera3D;
import org.flashbacks1998.world3d.engine.IRendererEngine;
import org.flashbacks1998.world3d.interfaces.IUploadable3D;

interface IEntity3D extends IEventDispatcher extends IUploadable3D {
    public var children:Vector<IEntity3D>;
    public var position:Position3D;
    public var visible:Bool;

	public function render(engine:IRendererEngine, camera:Camera3D, ?options:Dynamic):Void;
	public function dispose(engine:IRendererEngine):Void;
    public function clone():IEntity3D;
}