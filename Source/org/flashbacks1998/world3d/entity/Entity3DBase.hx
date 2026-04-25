package org.flashbacks1998.world3d.entity;

import openfl.Vector;
import openfl.utils.Future; 
import org.flashbacks1998.world3d.engine.IRendererEngine;
import org.flashbacks1998.world3d.entity.Entity3D;
import haxe.ds.StringMap;
import org.flashbacks1998.debugger.Debugger;  
  
class Entity3DBase extends Entity3D
{
    private static final _groups:StringMap<Array<Entity3DBase>> = new StringMap();
    private final _meshesBase:Array<Vector<Mesh3DAndShaderPair>> = [];
    private var _defaultMeshBase:Mesh3DAndShaderPair;

    public function new(group:String = null)
    {
        super();

        Debugger.log(
            Std.string(Type.getClassName(Type.getClass(this))) + " new() - constructing entity."
        );

        if(group != null) {
            addToGroup(group, this);
        } 
    }

    public static function addToGroup(group:String, base:Entity3DBase) {
        var entities = _groups.get(group);

        if (entities == null) {
            Debugger.log(
                 "[Entity3DBase] addToGroup() - creating new group."
            );
            entities = [];
        } else {
            if(entities.indexOf(base) != -1) {
                Debugger.log(
                     "[Entity3DBase] addToGroup() - entity already in group; skipping add."
                );
                return;
            }
        }

        for(e in entities)
            if(Type.getClass(e) == Type.getClass(base))
                return;

        entities.push(base);
        _groups.set(group, entities);

        Debugger.log(
             "[Entity3DBase] addToGroup() - added entity to group " +
            "groupSize=" + entities.length
        );
    }

    public function preloadEntityResources(?options: {
        ?engine:IRendererEngine
    }):Future<Entity3DBase> {
        Debugger.log(
             "[Entity3DBase] preloadEntityResources() - start. " +
            "engineProvided=" + (options != null && options.engine != null)
        );

        if (options != null && options.engine != null) {
            Debugger.log(
                 "[Entity3DBase] preloadEntityResources() - uploading meshes via upload()."
            );
            upload(options.engine);
        } else {
            Debugger.log(
                 "[Entity3DBase] preloadEntityResources() - no engine provided; " +
                "skipping upload()."
            );
        }

        Debugger.log(
             "[Entity3DBase] preloadEntityResources() - completed. Returning Future.withValue(this)."
        );

        return Future.withValue(cast this);
    }

    public static function preloadResources(group:String, ?options: {
        ?engine:IRendererEngine
    }):Array<Future<Entity3DBase>> {
        Debugger.log(
            "[Entity3DBase] preloadResources(group) - start. group=\"" + group + "\""
        );

        final entity = _groups.get(group);
        final futures:Array<Future<Entity3DBase>> = [];

        if (entity != null) {
            Debugger.log(
                "[Entity3DBase] preloadResources(group) - found " + entity.length +
                " entity(ies) in group \"" + group + "\"."
            );

            for (i in 0...entity.length) {
                final e = entity[i];
                Debugger.log(
                    "[Entity3DBase] preloadResources(group) - scheduling preloadEntityResources() " +
                    "for entity index " + i + "."
                );

                final future = e.preloadEntityResources(options);
                futures.push(future);
            }
        } else {
            Debugger.log(
                "[Entity3DBase] preloadResources(group) - no entities registered for group \"" +
                group + "\"."
            );
        }

        Debugger.log(
            "[Entity3DBase] preloadResources(group) - returning " + futures.length +
            " future(s) for group \"" + group + "\"."
        );

        return futures;
    }

    public override function upload(engine:IRendererEngine):Void {
        Debugger.log(
            Std.string(Type.getClassName(Type.getClass(this))) + " upload() - uploading " + _meshesBase.length + " mesh(es)."
        );

        for(meshes in _meshesBase)
            Entity3D.uploadMeshes(engine, meshes);

        Debugger.log(
            Std.string(Type.getClassName(Type.getClass(this))) + " upload() - calling super.upload(engine)."
        );
        super.upload(engine);
    }
}
