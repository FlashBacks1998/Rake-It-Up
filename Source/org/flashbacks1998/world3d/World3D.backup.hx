package org.flashbacks1998.world3d;

import org.flashbacks1998.world3d.engine.software.BasicSoftwareEngine;
import openfl.display.Sprite;
import openfl.Vector;
import org.flashbacks1998.world3d.events.World3DEvent;
import org.flashbacks1998.world3d.engine.IRendererEngine;
import org.flashbacks1998.world3d.engine.hardware.BasicHardwareEngine;
import org.flashbacks1998.world3d.postprocessing.PostProcessing;
import org.flashbacks1998.world3d.camera.Camera3D;
import org.flashbacks1998.world3d.entity.IEntity3D;
import openfl.display3D.Context3D;
import openfl.display3D.Context3DRenderMode;
import openfl.display.Stage3D;
import openfl.utils.Future;
import openfl.Lib;

// use our debugger
import org.flashbacks1998.debugger.Debugger;


class World3D {
    private var _backBufferWidth:Int;
    private var _backBufferHeight:Int;

    private var _engineSoftware:BasicSoftwareEngine;
    private var _engineHardware:BasicHardwareEngine;
    public var engine:IRendererEngine;
    public var backupEngines:Vector<IRendererEngine> = new Vector();

    public var engineType(default, set):BasicRendererEngineType;

    public var camera:Camera3D = null;
    public var entities:Array<IEntity3D> = [];
    public var width(get, set):Int;
    public var height(get, set):Int;

    public var future(get, null):Future<World3D>;
    public var context(get, null):Context3D;

    public var postProcessingEnabled(get, set):Bool;
    public var postProcessingPipeline(get, set):PostProcessing;

    public var bgColorR:Float = 0.0;
    public var bgColorG:Float = 0.5;
    public var bgColorB:Float = .75;

    public function new(?stage3d:Stage3D, ?options:{
        ?camera:Camera3D,
        ?mode:Context3DRenderMode,
        ?width:Int,
        ?height:Int,
        ?engineType:BasicRendererEngineType,
    }) {  
        Debugger.log("Creating new World3D instance");

        _backBufferWidth = options?.width ?? Lib.current.stage.stageWidth;
        _backBufferHeight = options?.height ?? Lib.current.stage.stageHeight;

        Debugger.log("Backbuffer size:", _backBufferWidth, "x", _backBufferHeight);

        camera = options?.camera ?? new Camera3D(45, Lib.current.stage.stageWidth / Lib.current.stage.stageHeight);

        //Hardware engine
        /*
        if (stage3d != null) {
            Debugger.log("Stage3D provided, creating BasicHardwareEngine…");
            final hw = new BasicHardwareEngine(stage3d, {
                mode: options?.mode,
                width: _backBufferWidth,
                height: _backBufferHeight,
            });
            hw.world = this;
            engine = hw;
        }
        */
        _engineHardware = new BasicHardwareEngine(stage3d ?? Lib.current.stage.stage3Ds[0], {
            mode: options?.mode,
            width: _backBufferWidth,
            height: _backBufferHeight,
        });
        _engineHardware.world = this; 

        //Software Engine
        _engineSoftware = new BasicSoftwareEngine(Lib.current.stage.stageWidth, Lib.current.stage.stageHeight);
        
        engineType = options?.engineType ?? BasicRendererEngineType.hardware;
    }

    public function addChild(e:IEntity3D) {
        Debugger.log("add child", e);

        entities.push(e);
        e.dispatchEvent(new World3DEvent(World3DEvent.ADDED_TO_STAGE, this));
        if (engine != null)
            engine.onEntityAdded(e);
        for (backup in backupEngines)
            backup.onEntityAdded(e);
    }

    public function removeChild(e:IEntity3D) {
        Debugger.log("remove child", e);

        entities.remove(e);
        e.dispatchEvent(new World3DEvent(World3DEvent.REMOVED_FROM_STAGE, this));
        if (engine != null)
            engine.onEntityRemoved(e);
        for (backup in backupEngines)
            backup.onEntityRemoved(e);
    }

    private function uploadToEngineOrDefer(eng:IRendererEngine, uploadFn:IRendererEngine->Void):Void {
        if (eng == null) return;
        if (eng.ready) {
            uploadFn(eng);
        } else if (Std.isOfType(eng, BasicHardwareEngine)) {
            final hw = cast(eng, BasicHardwareEngine);
            hw.future.onComplete(_ -> {
                if (hw.context != null)
                    uploadFn(eng);
            });
        }
    }

    public function uploadMesh(mesh:org.flashbacks1998.world3d.geom.Mesh3D):Void {
        final fn = (eng:IRendererEngine) -> eng.uploadMesh(mesh);
        uploadToEngineOrDefer(engine, fn);
        for (backup in backupEngines)
            uploadToEngineOrDefer(backup, fn);
    }

    public function uploadTexture(bitmapData:openfl.display.BitmapData):Void {
        final fn = (eng:IRendererEngine) -> eng.uploadTexture(bitmapData);
        uploadToEngineOrDefer(engine, fn);
        for (backup in backupEngines)
            uploadToEngineOrDefer(backup, fn);
    }

    public function uploadProgram(vertexAGAL:String, fragmentAGAL:String):Void {
        final fn = (eng:IRendererEngine) -> eng.uploadProgram(vertexAGAL, fragmentAGAL);
        uploadToEngineOrDefer(engine, fn);
        for (backup in backupEngines)
            uploadToEngineOrDefer(backup, fn);
    }

    public function render():Void {
        if (engine == null || !engine.ready) return;

        // Update camera matrices once per frame
        if (camera != null) {
            camera.updateMatrices();
        } else {
            Debugger.log("[World3D render] Warning: camera is null");
        }

        engine.render(camera, entities, {
            bgColorR: bgColorR,
            bgColorG: bgColorG,
            bgColorB: bgColorB,
            width: _backBufferWidth,
            height: _backBufferHeight,
        });
    }

    public function resize(width:Int, height:Int):Void {
        // Ignore bogus resizes
        if (width <= 0 || height <= 0) {
            Debugger.log("World3D.resize: ignoring invalid size", width, "x", height);
            return;
        }

        _backBufferWidth  = width;
        _backBufferHeight = height;

        // Critical: update camera aspect so the projection matches the new backbuffer
        if (camera != null) {
            camera.aspect = width / height;
        }

        if (engine != null) {
            engine.resize(width, height);
        }
    }

    // -------------------------------------------------
    // Cleanup / dispose
    // -------------------------------------------------
    public function dispose():Void {
        Debugger.log("World3D.dispose");

        if (engine != null) {
            // Dispose all entities via the engine-appropriate path
            for (e in entities)
                e.dispose(engine);

            engine.dispose();
            engine = null;
        }

        // Drop references so GC can clean up
        camera = null;
        entities = [];
    }

    // -------------------------------------------------
    // Property accessors
    // -------------------------------------------------

    function set_width(value:Int):Int {
        resize(value, _backBufferHeight);
        return value;
    }

    function get_width():Int {
        return _backBufferWidth;
    }

    function set_height(value:Int):Int {
        resize(_backBufferWidth, value);
        return value;
    }

    function get_height():Int {
        return _backBufferHeight;
    }

    function set_engineType(type:BasicRendererEngineType):BasicRendererEngineType {
        backupEngines = new Vector();
        if (type == BasicRendererEngineType.hardware) {
            if (Lib.current.stage.contains(_engineSoftware.container))
                Lib.current.stage.removeChild(_engineSoftware.container);
            engine = _engineHardware;
            backupEngines.push(_engineSoftware);
        } else {
            if (!Lib.current.stage.contains(_engineSoftware.container)) {
                Lib.current.stage.addChild(_engineSoftware.container);
                Lib.current.stage.setChildIndex(_engineSoftware.container, 0);
            }
            engine = _engineSoftware;
            backupEngines.push(_engineHardware);
        }
        render();
        return engineType = type;
    }

    // -------------------------------------------------
    // Backward-compat accessors (delegate to hardware engine)
    // -------------------------------------------------

    function get_future():Future<World3D> {
        if (Std.isOfType(engine, BasicHardwareEngine)) {
            return cast(engine, BasicHardwareEngine).future.then(_ -> Future.withValue(this));
        }
        // Non-hardware engines are ready immediately
        return Future.withValue(this);
    }

    function get_context():Context3D {
        if (Std.isOfType(engine, BasicHardwareEngine))
            return cast(engine, BasicHardwareEngine).context;
        return null;
    }

    function get_postProcessingPipeline():PostProcessing {
        if (Std.isOfType(engine, BasicHardwareEngine))
            return cast(engine, BasicHardwareEngine).postProcessingPipeline;
        return null;
    }

    function set_postProcessingPipeline(pp:PostProcessing):PostProcessing {
        if (Std.isOfType(engine, BasicHardwareEngine))
            cast(engine, BasicHardwareEngine).postProcessingPipeline = pp;
        return pp;
    }

    function get_postProcessingEnabled():Bool {
        if (Std.isOfType(engine, BasicHardwareEngine))
            return cast(engine, BasicHardwareEngine).postProcessingEnabled;
        return false;
    }

    function set_postProcessingEnabled(value:Bool):Bool {
        if (Std.isOfType(engine, BasicHardwareEngine))
            cast(engine, BasicHardwareEngine).postProcessingEnabled = value;
        return value;
    }
}
