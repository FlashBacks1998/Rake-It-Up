package org.flashbacks1998.world3d.entity;

import openfl.Vector;
import org.flashbacks1998.util.interfaces.IIndexed;
import openfl.events.IEventDispatcher;
import openfl.events.Event;
import openfl.events.EventDispatcher;
import org.flashbacks1998.world3d.geom.Position3D;
import org.flashbacks1998.world3d.camera.Camera3D;
import org.flashbacks1998.world3d.engine.IRendererEngine;
import org.flashbacks1998.world3d.interfaces.IUploadable3D;
import openfl.geom.Matrix3D;

//BUGGED: children

class Entity3DGroup extends EventDispatcher implements IEntity3D implements IUploadable3D {
    public var name:String = null;
    public var children:Vector<IEntity3D>;
    public var position:Position3D = new Position3D();
    public var visible:Bool = true;

    // This group's WORLD matrix (parentWorld * local)
    private var _worldMatrix:Matrix3D = new Matrix3D();

    public function new(?options:{
        ?name:String,
        ?children:Vector<IEntity3D>,
        ?position:Position3D
    }) {
        super();
        
        if (options?.name != null) this.name = options.name;
        if (options?.children != null) this.children = options.children;
        if (options?.position != null) this.position = options.position;
    }

    public function upload(engine:IRendererEngine):Void {
        if (children == null || children.length == 0) return;

        for (i in 0...children.length) {
            var e = children[i];
            if (e == null) continue;
            e.upload(engine);
        }
    }

    public function render(engine:IRendererEngine, camera:Camera3D, ?options:Dynamic):Void {
        if (!visible) return;
        if (children == null || children.length == 0) return;

        // 1) Get parent world matrix (if any) from options
        var parentWorld:Matrix3D = null;
        if (options != null && Reflect.hasField(options, "parentWorldMatrix")) {
            parentWorld = cast Reflect.field(options, "parentWorldMatrix");
        }

        // 2) Build local transform from Position3D
        position.updateMatrix(); // local transform

        // 3) Compute this group's WORLD matrix: world = parentWorld * local
        _worldMatrix.identity();
        if (parentWorld != null) {
            _worldMatrix.append(parentWorld);
        }
        _worldMatrix.append(position);

        // 4) Render children, passing THIS group's world as their parentWorldMatrix
        var childOptions:Dynamic = (options != null) ? options : {};
        Reflect.setField(childOptions, "parentWorldMatrix", _worldMatrix);

        for (i in 0...children.length) {
            var e = children[i];
            if (e == null) continue;
            e.render(engine, camera, childOptions);
        }
    }

    public function dispose(engine:IRendererEngine):Void {
        if (children != null) {
            for (i in 0...children.length) {
                var e = children[i];
                if (e != null) e.dispose(engine);
            }
        }
        children = null;
    }

    // small utility helpers
    public function add(entity:IEntity3D):Void {
        if (children == null) children = new Vector<IEntity3D>();
        children.push(entity);
    }

    public function remove(entity:IEntity3D):Bool {
        if (children == null) return false;
        var idx = children.indexOf(entity);
        if (idx >= 0) {
            children.splice(idx, 1);
            return true;
        }
        return false;
    }

    public function clone():IEntity3D {
        var copy = new Entity3DGroup();

        // Basic fields
        copy.name = this.name;
        copy.visible = this.visible;

        // New Position3D with same values
        // Option 1: use clonePosition3D()
        copy.position = this.position.clonePosition3D();

        // Option 2 (equivalent):
        // this.position.copyToPosition3D(copy.position);

        // Deep-clone the children (but their meshes can still be shared
        // according to each child's own clone() implementation).
        if (this.children != null) {
            copy.children.length = 0;
            for (child in this.children) {
                if (child != null) {
                    copy.children.push(child.clone());
                }
            }
        }

        return copy;
    }

    
    override public function dispatchEvent(event:Event):Bool {
        // 1) Dispatch on THIS entity first
        var result = super.dispatchEvent(event);

        // 2) Broadcast to children as well
        if (children != null && children.length > 0) {
            for (child in children) {
                if (child == null) continue;

                // If IEntity3D extends IEventDispatcher, you can just do:
                // child.dispatchEvent(event.clone());
                //
                // Otherwise cast to IEventDispatcher/EventDispatcher:
                var dispatcher:IEventDispatcher = cast child;
                if (dispatcher != null) {
                    // Use clone so each child gets its own instance
                    dispatcher.dispatchEvent(event.clone());
                }
            }
        }

        return result;
    }
}
