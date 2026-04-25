package org.flashbacks1998.world3d.entity;

import haxe.macro.Expr.Position;
import openfl.events.IEventDispatcher;
import openfl.events.Event;
import openfl.events.EventDispatcher;
import org.flashbacks1998.debugger.Debugger;
import org.flashbacks1998.world3d.shader.ShaderPipeline;
import org.flashbacks1998.world3d.shader.IShader.IShader3D;
import org.flashbacks1998.world3d.geom.Position3D;
import org.flashbacks1998.world3d.camera.Camera3D;
import openfl.geom.Matrix3D;
import org.flashbacks1998.world3d.engine.IRendererEngine;
import org.flashbacks1998.world3d.geom.Mesh3D;
import openfl.Vector;
import Reflect;

typedef Mesh3DAndShaderPair = {
    mesh:Mesh3D,
    shader:IShader3D
}

class Entity3D extends EventDispatcher implements IEntity3D {
    public var meshes:Vector<Mesh3DAndShaderPair> = new Vector<Mesh3DAndShaderPair>();

    public var position:Position3D = new Position3D();
    public var name:String = null;

    // Keeping the typo name so existing code compiles.
    public var children:Vector<IEntity3D> = new Vector();

    // Final matrix passed to shader: world * view * projection
    private var _modelViewMatrix:Position3D = new Position3D();

    // This entity's WORLD matrix (parentWorld * local)
    private var _worldMatrix:Position3D = new Position3D();

    public var visible:Bool = true;

    public function new(?options:{ ?meshes:Vector<Mesh3DAndShaderPair> }) {
        super();

        if (options != null && options.meshes != null) {
            this.meshes = options.meshes;
        }
    }

    public static function uploadMeshes(engine:IRendererEngine, meshes:Vector<Mesh3DAndShaderPair>) {
        // Upload this entity's meshes
        if (meshes != null && meshes.length > 0) {
            for (i in 0...meshes.length) {
                var pair = meshes[i];
                if (pair == null) continue;
                if (pair.mesh != null) pair.mesh.upload(engine);
                if (pair.shader != null) pair.shader.upload(engine);
            }
        }
    }

    public function upload(engine:IRendererEngine):Void {
        uploadMeshes(engine, meshes);

        // Upload children as well
        if (children != null && children.length > 0) {
            for (i in 0...children.length) {
                var child = children[i];
                if (child != null) child.upload(engine);
            }
        }
    }

    /**
     * Renders this entity and all descendants.
     *
     * options is passed through to the shader; we also optionally
     * read/write options.parrentWorldMatrix to propagate the hierarchy.
     *
     * NOTE: options stays Dynamic on purpose.
     */
    public function render(engine:IRendererEngine, camera:Camera3D, ?options:Dynamic):Void {
        if (!visible) return;

        // 1) Make sure the local transform is up-to-date
        position.updateMatrix(); // assumes Position3D has a .matrix:Matrix3D

        // 2) Get parent world matrix from options (Dynamic is fine here)
        var parentWorld:Position3D = options?.parrentWorldMatrix;

        // 3) Compute THIS entity's world matrix: world = parentWorld * local
        _worldMatrix.identity();

        // First: local
        _worldMatrix.append(position); // <-- IMPORTANT: use the Matrix3D
        _worldMatrix.updateItterations = position.updateItterations;

        // Then: parent (if any)
        if (parentWorld != null) {
            _worldMatrix.append(parentWorld);
            _worldMatrix.updateItterations += parentWorld.updateItterations;
        }
        _worldMatrix.locked = true;

        // 4) Build MVP: projection * view * world
        _modelViewMatrix.identity();
        _modelViewMatrix.append(_worldMatrix);      // world
        _modelViewMatrix.append(camera.view);       // view
        _modelViewMatrix.append(camera.projection); // projection
        _modelViewMatrix.updateItterations = camera.updateItterations + _worldMatrix.updateItterations;
        _modelViewMatrix.locked = true;

        // 5) Render meshes
        if (meshes != null && meshes.length > 0) {
            var i = 0;
            var n = meshes.length;
            while (i < n) {
                var pair = meshes[i];
                if (pair != null && pair.mesh != null && pair.shader != null) {
                    pair.shader.render(engine, pair.mesh, _modelViewMatrix, options);
                }
                i++;
            }
        }

        // 6) Render children...
        if (children != null && children.length > 0) {
            for (child in children) {
                if (child == null) continue;

                var childOptions:Dynamic = options ?? {};
                childOptions.parrentWorldMatrix = _worldMatrix;

                child.render(engine, camera, childOptions);
            }
        }
    }

    public function dispose(engine:IRendererEngine):Void {
        for (m in meshes) {
            m.shader.dispose(engine);
            m.mesh.dispose(engine);
        }

        // Dispose children as well
        if (children != null) {
            for (c in children) {
                if (c != null) c.dispose(engine);
            }
        }
    }

    public function clone():Entity3D {
        // Reuse the same meshes Vector so all Mesh3D / Shader objects are shared.
        var copy = new Entity3D({ meshes: this.meshes });

        copy.position.copyFromPosition3D(this.position);

        // Copy simple fields
        copy.name = this.name;
        copy.visible = this.visible;

        copy.children.length = 0;
        for (child in this.children) {
            if (child != null) copy.children.push(child.clone());
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
                    dispatcher.dispatchEvent(event);
                }
            }
        }

        return result;
    }
}
