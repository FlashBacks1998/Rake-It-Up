package org.flashbacks1998.world3d;

// OpenFL
import openfl.display.BitmapData;
import openfl.display.Sprite;
import openfl.display.Stage3D;
import openfl.display3D.Context3D;
import openfl.display3D.Context3DRenderMode;
import openfl.utils.Future;
import openfl.Vector;
import openfl.Lib;

// Engine
import org.flashbacks1998.world3d.engine.IRendererEngine;
import org.flashbacks1998.world3d.engine.IRendererEngine.BasicRendererEngineType;
import org.flashbacks1998.world3d.engine.hardware.BasicHardwareEngine;
import org.flashbacks1998.world3d.engine.software.BasicSoftwareEngine;

// World3D internals
import org.flashbacks1998.world3d.camera.Camera3D;
import org.flashbacks1998.world3d.entity.IEntity3D;
import org.flashbacks1998.world3d.events.World3DEvent;
import org.flashbacks1998.world3d.geom.Mesh3D;
import org.flashbacks1998.world3d.postprocessing.PostProcessing;
import org.flashbacks1998.world3d.shader.IShader.IShader3D;

// Debugger
import org.flashbacks1998.debugger.Debugger;

/**
 * Central orchestrator for the 3D rendering pipeline.
 *
 * Owns the camera, entity list, and renderer engines (hardware + software).
 * Provides resource upload methods that distribute to all engines, and a
 * per-frame `render()` call that delegates to the currently active engine.
 */
class World3D {

    // -------------------------------------------------
    // Fields
    // -------------------------------------------------

    /** Internal backbuffer dimensions used for rendering and camera aspect. */
    private var _backBufferWidth:Int;
    private var _backBufferHeight:Int;

    /** The currently active renderer engine. */
    public var engine:IRendererEngine;

    /** Concrete engine references for direct access when needed. */
    private var _backupSoftwareEngine:BasicSoftwareEngine;
    private var _backupHardwareEngine:BasicHardwareEngine;

    /** All available engines (active is also in this list). Used for resource distribution. */
    public var backupEngines:Vector<IRendererEngine> = new Vector();

    /** The active engine type. Setting this switches the renderer and manages stage lifecycle. */
    public var engineType(get, set):BasicRendererEngineType;

    /** The perspective camera used for view/projection matrix computation. */
    public var camera:Camera3D = null;

    /** All entities currently in the world's scene graph. */
    public var entities:Array<IEntity3D> = [];

    /** Backbuffer width in pixels. Setting triggers a resize. */
    public var width(get, set):Int;

    /** Backbuffer height in pixels. Setting triggers a resize. */
    public var height(get, set):Int;

    /** Resolves when the active engine is ready (hardware: context created, software: immediate). */
    public var future(get, null):Future<World3D>;

    /** The hardware engine's Context3D, or null if software is active. */
    public var context(get, null):Context3D;

    /** Whether post-processing effects are enabled (hardware engine only). */
    public var postProcessingEnabled(get, set):Bool;

    /** The post-processing pipeline (hardware engine only). */
    public var postProcessingPipeline(get, set):PostProcessing;

    /** Background clear color (red channel, 0.0-1.0). */
    public var bgColorR:Float = 0.0;

    /** Background clear color (green channel, 0.0-1.0). */
    public var bgColorG:Float = 0.5;

    /** Background clear color (blue channel, 0.0-1.0). */
    public var bgColorB:Float = .75;

    // -------------------------------------------------
    // Constructor
    // -------------------------------------------------

    /**
     * Creates a new World3D instance with both hardware and software engines.
     *
     * @param stage3d  Optional Stage3D instance for the hardware engine. Defaults to stage3Ds[0].
     * @param options  Optional configuration:
     *                 - `camera`: Custom camera (default: 45-degree FOV perspective)
     *                 - `mode`: Context3D render mode (default: AUTO)
     *                 - `width`: Backbuffer width (default: stage width)
     *                 - `height`: Backbuffer height (default: stage height)
     *                 - `engineType`: Starting engine type (default: hardware)
     */
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

        // Hardware engine
        _backupHardwareEngine = new BasicHardwareEngine(stage3d ?? Lib.current.stage.stage3Ds[0], {
            mode: options?.mode,
            width: _backBufferWidth,
            height: _backBufferHeight,
        });
        backupEngines.push(_backupHardwareEngine);

        // Software engine
        _backupSoftwareEngine = new BasicSoftwareEngine(Lib.current.stage.stageWidth, Lib.current.stage.stageHeight);
        backupEngines.push(_backupSoftwareEngine);

        engineType = options?.engineType ?? BasicRendererEngineType.hardware;
    }

    // -------------------------------------------------
    // Entity management
    // -------------------------------------------------

    /**
     * Adds an entity to the world. Dispatches `ADDED_TO_STAGE`, then uploads
     * the entity's resources to the active engine and all backup engines.
     *
     * @param e  The entity to add.
     */
    public function addChild(e:IEntity3D):Void {
        Debugger.log("add child", e);

        entities.push(e);
        e.dispatchEvent(new World3DEvent(World3DEvent.ADDED_TO_STAGE, this));

        if (engine != null)
            engine.onEntityAdded(e);

        for (backup in backupEngines)
            backup.onEntityAdded(e);
    }

    /**
     * Removes an entity from the world. Dispatches `REMOVED_FROM_STAGE`
     * and notifies all engines.
     *
     * @param e  The entity to remove.
     */
    public function removeChild(e:IEntity3D):Void {
        Debugger.log("remove child", e);

        entities.remove(e);
        e.dispatchEvent(new World3DEvent(World3DEvent.REMOVED_FROM_STAGE, this));

        if (engine != null)
            engine.onEntityRemoved(e);

        for (backup in backupEngines)
            backup.onEntityRemoved(e);
    }

    // -------------------------------------------------
    // Resource upload (distributed to all engines)
    // -------------------------------------------------

    /**
     * Uploads a resource to an engine, deferring if the engine isn't ready yet.
     * For hardware engines, the upload is queued until the Context3D is created.
     *
     * @param eng       The target engine.
     * @param uploadFn  The upload function to call with the engine.
     */
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

    /**
     * Uploads a mesh's vertex/index buffers to all engines.
     *
     * @param mesh  The mesh to upload.
     */
    public function uploadMesh(mesh:Mesh3D):Void {
        final fn = (eng:IRendererEngine) -> eng.uploadMesh(mesh);
        uploadToEngineOrDefer(engine, fn);
        for (backup in backupEngines)
            uploadToEngineOrDefer(backup, fn);
    }

    /**
     * Uploads a texture (BitmapData) to all engines.
     *
     * @param bitmapData  The source bitmap to upload as a GPU texture.
     */
    public function uploadTexture(bitmapData:BitmapData):Void {
        final fn = (eng:IRendererEngine) -> eng.uploadTexture(bitmapData);
        uploadToEngineOrDefer(engine, fn);
        for (backup in backupEngines)
            uploadToEngineOrDefer(backup, fn);
    }

    /**
     * Compiles and uploads an AGAL shader program to all engines.
     *
     * @param vertexAGAL    Vertex shader AGAL source.
     * @param fragmentAGAL  Fragment shader AGAL source.
     */
    public function uploadProgram(vertexAGAL:String, fragmentAGAL:String):Void {
        final fn = (eng:IRendererEngine) -> eng.uploadProgram(vertexAGAL, fragmentAGAL);
        uploadToEngineOrDefer(engine, fn);
        for (backup in backupEngines)
            uploadToEngineOrDefer(backup, fn);
    }

    /**
     * Uploads a shader (compiles its program and part resources) to all engines.
     * Use this instead of `shader.upload(world.engine)` to ensure the shader
     * is available on all engines (active + backups).
     *
     * @param shader  The shader to upload.
     */
    public function uploadShader(shader:IShader3D):Void {
        final fn = (eng:IRendererEngine) -> shader.upload(eng);
        uploadToEngineOrDefer(engine, fn);
        for (backup in backupEngines)
            uploadToEngineOrDefer(backup, fn);
    }

    // -------------------------------------------------
    // Rendering
    // -------------------------------------------------

    /**
     * Renders one frame. Updates camera matrices, then delegates to the
     * active engine's `render()` with the current entities and background color.
     * No-op if the engine isn't ready or is null.
     */
    public function render():Void {
        if (engine == null || !engine.ready) return;

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

    /**
     * Resizes the backbuffer and updates the camera aspect ratio.
     * Ignores invalid (zero or negative) dimensions.
     *
     * @param width   New width in pixels.
     * @param height  New height in pixels.
     */
    public function resize(width:Int, height:Int):Void {
        if (width <= 0 || height <= 0) {
            Debugger.log("World3D.resize: ignoring invalid size", width, "x", height);
            return;
        }

        _backBufferWidth  = width;
        _backBufferHeight = height;

        if (camera != null) {
            camera.aspect = width / height;
        }

        if (engine != null) {
            engine.resize(width, height);
        }

        for (backup in backupEngines) {
            backup.resize(width, height);
        }
    }

    // -------------------------------------------------
    // Lifecycle
    // -------------------------------------------------

    /**
     * Disposes all entities, the active engine, and clears references for GC.
     */
    public function dispose():Void {
        Debugger.log("World3D.dispose");

        if (engine != null) {
            for (e in entities)
                e.dispose(engine);

            engine.dispose();
            engine = null;
        }

        camera = null;
        entities = [];
    }

    // -------------------------------------------------
    // Property accessors: dimensions
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

    // -------------------------------------------------
    // Property accessors: engine type
    // -------------------------------------------------

    /**
     * Switches the active renderer engine. Calls `onRemovedFromStage()` on the
     * old engine and `onAddedToStage()` on the new one (e.g., software engine
     * adds/removes its container Sprite from the OpenFL display list).
     */
    function set_engineType(type:BasicRendererEngineType):BasicRendererEngineType {
        if (engine != null && engine.type == type) {
            return type;
        }

        if (engine != null)
            engine.onRemovedFromStage();

        for (backup in backupEngines) {
            if (backup.type == type) {
                engine = backup;
                break;
            }
        }

        if (engine == null || engine.type != type) {
            throw "Requested engine type " + type + " not found in backup engines.";
        }

        engine.onAddedToStage();

        render();
        return type;
    }

    function get_engineType():BasicRendererEngineType {
        return engine.type;
    }

    // -------------------------------------------------
    // Property accessors: hardware-engine delegates
    // -------------------------------------------------

    /** Resolves when the hardware engine's Context3D is ready, or immediately for software. */
    function get_future():Future<World3D> {
        if (Std.isOfType(engine, BasicHardwareEngine)) {
            return cast(engine, BasicHardwareEngine).future.then(_ -> Future.withValue(this));
        }

        for(backup in backupEngines) {
            if (Std.isOfType(backup, BasicHardwareEngine)) {
                return cast(backup, BasicHardwareEngine).future.then(_ -> Future.withValue(this));
            }
        }

        return Future.withValue(this);
    }

    /** Returns the hardware engine's Context3D, or null if software is active. */
    function get_context():Context3D {
        if (Std.isOfType(engine, BasicHardwareEngine))
            return cast(engine, BasicHardwareEngine).context;
        return null;
    }

    function get_postProcessingPipeline():PostProcessing {
        if (Std.isOfType(engine, BasicHardwareEngine))
            return cast(engine, BasicHardwareEngine).postProcessingPipeline;

        for(backup in backupEngines) 
            if (Std.isOfType(backup, BasicHardwareEngine))
                return cast(backup, BasicHardwareEngine).postProcessingPipeline;

        return null;
    }

    function set_postProcessingPipeline(pp:PostProcessing):PostProcessing {
        if (Std.isOfType(engine, BasicHardwareEngine))
            cast(engine, BasicHardwareEngine).postProcessingPipeline = pp;

        for(backup in backupEngines) 
            if (Std.isOfType(backup, BasicHardwareEngine))
                cast(backup, BasicHardwareEngine).postProcessingPipeline = pp;

        return pp;
    }

    function get_postProcessingEnabled():Bool {
        if (Std.isOfType(engine, BasicHardwareEngine))
            return cast(engine, BasicHardwareEngine).postProcessingEnabled;

        for(backup in backupEngines) 
            if (Std.isOfType(backup, BasicHardwareEngine))
                return cast(backup, BasicHardwareEngine).postProcessingEnabled;

        return false;
    }

    function set_postProcessingEnabled(value:Bool):Bool {
        if (Std.isOfType(engine, BasicHardwareEngine))
            cast(engine, BasicHardwareEngine).postProcessingEnabled = value;

        for(backup in backupEngines)
            if (Std.isOfType(backup, BasicHardwareEngine))
                cast(backup, BasicHardwareEngine).postProcessingEnabled = value;

        return value;
    }
}
