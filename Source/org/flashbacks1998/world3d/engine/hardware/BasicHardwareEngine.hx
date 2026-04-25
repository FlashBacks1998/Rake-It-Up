package org.flashbacks1998.world3d.engine.hardware;

import haxe.Exception;
import haxe.ds.IntMap;
import openfl.display.BitmapData;
import openfl.display.Stage3D;
import openfl.display3D.Context3D;
import openfl.display3D.Context3DBlendFactor;
import openfl.display3D.Context3DCompareMode;
import openfl.display3D.Context3DProfile;
import openfl.display3D.Context3DProgramType;
import openfl.display3D.Context3DRenderMode;
import openfl.display3D.Context3DTextureFormat;
import openfl.display3D.Context3DVertexBufferFormat;
import openfl.display3D.Program3D;
import openfl.display3D.textures.TextureBase;
import openfl.events.Event;
import openfl.geom.Matrix3D;
import openfl.utils.Future;
import openfl.utils.Promise;
import openfl.Vector;

import org.flashbacks1998.debugger.Debugger;
import org.flashbacks1998.world3d.camera.Camera3D;
import org.flashbacks1998.world3d.engine.IRendererEngine;
import org.flashbacks1998.world3d.entity.IEntity3D;
import org.flashbacks1998.world3d.geom.Mesh3D;
import org.flashbacks1998.world3d.postprocessing.PostProcessing;
import org.flashbacks1998.world3d.postprocessing.IPostProcessingInterface.PostProcessingTexture;
import org.flashbacks1998.world3d.shader.IShader.IShader3D;
import org.flashbacks1998.world3d.shader.IShader.Shader3DPreviousContextState;
import org.flashbacks1998.world3d.shader.Shader3D;
import org.flashbacks1998.world3d.shader.ShaderPipeline;
import org.flashbacks1998.world3d.util.Constants;

class BasicHardwareEngine implements IRendererEngine {
    private var _context3d:Context3D = null;
    private var _stage3d:Stage3D = null;
    private var _backBufferWidth:Int;
    private var _backBufferHeight:Int;
    private var _textureToRenderTo:PostProcessingTexture;
    private var _cachedBackbuffer:IntMap<IntMap<PostProcessingTexture>> = new IntMap();

    private var _promise:Promise<BasicHardwareEngine> = new Promise();

    public var postProcessingEnabled:Bool = true;
    public var postProcessingPipeline(default, set):PostProcessing;

    public var context(get, null):Context3D;

    public var future(get, null):Future<BasicHardwareEngine>;

    // Pending entities to upload once context is ready
    private var _pendingEntities:Array<IEntity3D> = [];
    // All entities that have been uploaded (for re-upload on context recreation)
    private var _uploadedEntities:Array<IEntity3D> = [];
    // Queued program uploads waiting for context creation
    private var _pendingPrograms:Array<{ vertex:String, fragment:String, promise:Promise<Program3D> }> = [];

    private var _contextVersion:Int = 0;

	public var type:BasicRendererEngineType = BasicRendererEngineType.hardware;

    public function new(stage3d:Stage3D, ?options:{
        ?mode:Context3DRenderMode,
        ?width:Int,
        ?height:Int,
    }) {
        Debugger.log("Creating new BasicHardwareEngine");

        _backBufferWidth = options?.width ?? openfl.Lib.current.stage.stageWidth;
        _backBufferHeight = options?.height ?? openfl.Lib.current.stage.stageHeight;

        Debugger.log("Backbuffer size:", _backBufferWidth, "x", _backBufferHeight);

        _stage3d = stage3d;
        final mode = options?.mode ?? Context3DRenderMode.AUTO;

        _stage3d.addEventListener(Event.CONTEXT3D_CREATE, onContext3DCreate);
        _stage3d.requestContext3D(mode, Context3DProfile.STANDARD_EXTENDED);
    }

    // ------------------------------------------------------------------
    // IRendererEngine
    // ------------------------------------------------------------------

    public var ready(get, null):Bool;

    function get_ready():Bool {
        return _context3d != null;
    }

    public var contextVersion(get, null):Int;

    function get_contextVersion():Int { return _contextVersion; }

    public var width(get, set):Int;
    public var height(get, set):Int;

    function get_width():Int {
        return _backBufferWidth;
    }

    function set_width(width:Int):Int {
        resize(width, _backBufferHeight);
        return this._backBufferWidth = width;
    }

    function get_height() {
        return _backBufferHeight;
    }

    function set_height(height:Int):Int {
        resize(_backBufferWidth, height);
        return this._backBufferHeight = height;
    }

    // ------------------------------------------------------------------
    // Resource upload methods
    // ------------------------------------------------------------------

    public function uploadMesh(mesh:Mesh3D):Void {
        if (_context3d != null) {
            mesh.uploadToContext(_context3d);
        }
    }

    public function uploadTexture(bitmapData:BitmapData):TextureBase {
        if (_context3d == null) return null;
        return Shader3D.uploadTexture(bitmapData, _context3d);
    }

    public function uploadProgram(vertexAGAL:String, fragmentAGAL:String):Future<Program3D> {
        if (_context3d != null) {
            // Context ready — compile immediately
            final prog = Shader3D.uploadAGAL(_context3d, vertexAGAL, fragmentAGAL);
            return Future.withValue(prog);
        }

        // Context not ready — queue and return a deferred Future
        final promise = new Promise<Program3D>();
        _pendingPrograms.push({ vertex: vertexAGAL, fragment: fragmentAGAL, promise: promise });
        return promise.future;
    }

    // ------------------------------------------------------------------
    // drawMesh — absorbs the old ShaderPipeline.render() Context3D body
    // ------------------------------------------------------------------

    public function drawMesh(mesh:Mesh3D, shader:IShader3D, ?matrix:Matrix3D, ?options:Dynamic):Void {
        if (_context3d == null) return;

        // We expect a ShaderPipeline so we can read its exposed state
        final pipeline:ShaderPipeline = Std.isOfType(shader, ShaderPipeline) ? cast shader : null;
        if (pipeline == null) return;
        final currentProgram = pipeline.getProgram(this);
        if (currentProgram == null) return;

        try {
            final prevState:Shader3DPreviousContextState =
                (options != null) ? options.previousContextState : null;

            final prevProgram:Program3D =
                (prevState != null) ? prevState.program : null;

            final prevBlend =
                (prevState != null) ? prevState.blendFactors : null;

            final prevDepth =
                (prevState != null) ? prevState.depthTest : null;

            final prevTextures:Vector<TextureBase> =
                (prevState != null) ? prevState.textures : null;

            final prevVertexConstants =
                (prevState != null) ? prevState.vertexConstants : null;

            final prevFragmentConstants =
                (prevState != null) ? prevState.fragmentConstVersion : null;

            final forceCleanup:Bool =
                (options != null && options.forceCleanup != null) ? options.forceCleanup : (prevState == null);

            // 1) Blend
            final desiredBlendSrc = Context3DBlendFactor.SOURCE_ALPHA;
            final desiredBlendDst = Context3DBlendFactor.ONE_MINUS_SOURCE_ALPHA;
            if (prevBlend == null || prevBlend.sourceFactor != desiredBlendSrc || prevBlend.destinationFactor != desiredBlendDst) {
                _context3d.setBlendFactors(desiredBlendSrc, desiredBlendDst);
            }

            // 2) Depth
            final desiredDepthMask = true;
            final desiredDepthFunc = Context3DCompareMode.LESS;
            if (prevDepth == null || prevDepth.depthMask != desiredDepthMask || prevDepth.passCompareMode != desiredDepthFunc) {
                _context3d.setDepthTest(desiredDepthMask, desiredDepthFunc);
            }

            // 3) Program
            if (prevProgram != currentProgram) _context3d.setProgram(currentProgram);

            // 4) Vertex attributes (cache chains)
            final vb = mesh.vertexBuffer;
            final vbbuf = vb.buffer;
            final attrs = vb.attributes;

            _context3d.setVertexBufferAt(0, vbbuf, attrs.pos3,   Context3DVertexBufferFormat.FLOAT_3);
            _context3d.setVertexBufferAt(1, vbbuf, attrs.uv2,    Context3DVertexBufferFormat.FLOAT_2);
            _context3d.setVertexBufferAt(2, vbbuf, attrs.kdrgb3, Context3DVertexBufferFormat.FLOAT_3);

            // 5) Matrix -> vc0..vc3
            if (matrix != null)
                 _context3d.setProgramConstantsFromMatrix(Context3DProgramType.VERTEX, 0, matrix, true);
            else
                _context3d.setProgramConstantsFromMatrix(Context3DProgramType.VERTEX, 0, Constants.MATRIX_IDENTITY, true);

            // 6) Constants (while loops)
            var vcBase = 4;
            var fcBase = 0;

            final _vertexConstants = pipeline.vertexConstants;
            final _fragmentConstants = pipeline.fragmentConstants;
            final _textures = pipeline.textures;

            var vcCount = (_vertexConstants != null) ? _vertexConstants.length : 0;
            var vi = 0;
            while (vi < vcCount) {
                final reg = vcBase + vi;
                final vc = _vertexConstants.get(vi);
                final prevVc = (prevVertexConstants != null && reg < prevVertexConstants.length)
                    ? prevVertexConstants.get(reg)
                    : null;

                if (vc != null && vc != prevVc) {
                    _context3d.setProgramConstantsFromVector(Context3DProgramType.VERTEX, reg, vc);
                }
                vi++;
            }

            var fcCount = (_fragmentConstants != null) ? _fragmentConstants.length : 0;
            var fi = 0;
            while (fi < fcCount) {
                final reg = fcBase + fi;
                final fc = _fragmentConstants.get(fi);
                final prevFc = (prevFragmentConstants != null && reg < prevFragmentConstants.length)
                    ? prevFragmentConstants.get(reg)
                    : null;

                if (fc != null && fc != prevFc) {
                    _context3d.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, reg, fc);
                }
                fi++;
            }

            // 7) Textures (bind + update prevState.textures in ONE PASS)
            var samplerIndex = 0;
            final prevTotal = (prevTextures != null) ? prevTextures.length : 0;

            var flat:Vector<TextureBase> = null;
            if (prevState != null) {
                flat = prevState.textures;
                if (flat == null) {
                    flat = new Vector<TextureBase>();
                    prevState.textures = flat;
                }
            }

            if (_textures != null) {
                var oi = 0;
                var on = _textures.length;
                while (oi < on) {
                    final row = _textures.get(oi);
                    if (row != null) {
                        var ii = 0;
                        var in_ = row.length;
                        while (ii < in_) {
                            final tex = row.get(ii);

                            final prevTex:TextureBase =
                                (prevTextures != null && samplerIndex < prevTotal) ? prevTextures.get(samplerIndex) : null;

                            if (prevTex != tex) _context3d.setTextureAt(samplerIndex, tex);

                            if (flat != null) {
                                if (samplerIndex >= flat.length) flat.length = samplerIndex + 1;
                                flat.set(samplerIndex, tex);
                            }

                            samplerIndex++;
                            ii++;
                        }
                    }
                    oi++;
                }
            }

            // Clear any previously-bound samplers beyond current count
            var pti = samplerIndex;
            while (pti < prevTotal) {
                _context3d.setTextureAt(pti, null);
                if (flat != null && pti < flat.length) flat.set(pti, null);
                pti++;
            }

            if (flat != null) flat.length = samplerIndex;

            // 8) Draw
            _context3d.drawTriangles(mesh.indexBuffer);
            Debugger.meshesRendered++;
            Debugger.trianglesRendered += cast (mesh.indexData.indices.length / 3);

            // Cleanup textures if prevTextures missing or forced
            if (prevTextures == null || forceCleanup) {
                var ti = 0;
                while (ti < samplerIndex) {
                    _context3d.setTextureAt(ti, null);
                    ti++;
                }
            }

            // 9) Update prevState
            if (prevState != null) {
                prevState.program = currentProgram;

                if (prevState.blendFactors == null) prevState.blendFactors = { sourceFactor: desiredBlendSrc, destinationFactor: desiredBlendDst };
                else { prevState.blendFactors.sourceFactor = desiredBlendSrc; prevState.blendFactors.destinationFactor = desiredBlendDst; }

                if (prevState.depthTest == null) prevState.depthTest = { depthMask: desiredDepthMask, passCompareMode: desiredDepthFunc };
                else { prevState.depthTest.depthMask = desiredDepthMask; prevState.depthTest.passCompareMode = desiredDepthFunc; }

                prevState.vertexBuffer = mesh.vertexBuffer;
                prevState.indicesBuffer = mesh.indexBuffer;

                prevState.vertexConstants = _vertexConstants;
                prevState.fragmentConstVersion = _fragmentConstants;
            }
        } catch (e:Dynamic) {
            Debugger.error("ERROR during drawMesh: " + Std.string(e));
        }
    }

    // ------------------------------------------------------------------
    // Cached context state for ShaderPipeline
    // ------------------------------------------------------------------
    private static var _prevContextState:Shader3DPreviousContextState = {
        program: null,
        blendFactors: {
            sourceFactor: null,
            destinationFactor: null
        },
        depthTest: {
            depthMask: null,
            passCompareMode: null
        },
        textures: null,
        vertexBuffer: null,
        indicesBuffer: null,
        vertexConstants: null,
        fragmentConstVersion: null
    };

    private static inline function resetPrevContextState():Void {
        _prevContextState = {
            program: null,
            blendFactors: {
                sourceFactor: null,
                destinationFactor: null
            },
            depthTest: {
                depthMask: null,
                passCompareMode: null
            },
            textures: null,
            vertexBuffer: null,
            indicesBuffer: null,
            vertexConstants: null,
            fragmentConstVersion: null
        };
    }

    var ttr:PostProcessingTexture;
    final eopt = {
        backbufferWidth:  0,
        backbufferHeight: 0,
        previousContextState: _prevContextState,
        forceCleanup: false
    };

    public function render(camera:Camera3D, entities:Array<IEntity3D>, options:RendererOptions):Void {
        if (_context3d == null) return;

        // Reset cached GPU state at the start of every frame
        resetPrevContextState();
        eopt.previousContextState = _prevContextState;

        // Are we doing an off-screen pass + post-processing?
        final postp = postProcessingEnabled && (postProcessingPipeline != null);

        if (postp) {
            postProcessingPipeline.onBeginRender(this);

            // Make sure we have a render target (in case of resize/context loss)
            if (_textureToRenderTo == null) {
                configureContext3DBackbuffer();
            }

            // Render the 3D world into the off-screen texture
            _context3d.setRenderToTexture(_textureToRenderTo.texture, true, 0, 0);
            ttr = _textureToRenderTo;

            eopt.backbufferWidth  = ttr.width;
            eopt.backbufferHeight = ttr.height;
        } else {
            // Render directly to the backbuffer
            eopt.backbufferWidth  = options.width;
            eopt.backbufferHeight = options.height;
        }

        // Clear current target (RT or backbuffer)
        _context3d.clear(options.bgColorR, options.bgColorG, options.bgColorB);

        // Render all entities
        eopt.forceCleanup = false;

        if (entities != null && entities.length > 0) {
            for (i in 0...entities.length) {
                try {
                    final e = entities[i];
                    if (e.visible) {
                        e.render(this, camera, eopt);
                    }
                } catch (ex:Exception) {
                    Debugger.log("[BasicHardwareEngine render] ERROR:", ex.message);
                }
            }
        }

        eopt.forceCleanup = true;

        // If post-processing is enabled, run the fullscreen pass now
        if (postp) {
            postProcessingPipeline.onEndRender(this);

            // Back to the backbuffer, clear, then draw the quad sampling ttr.texture
            _context3d.setRenderToBackBuffer();
            _context3d.clear(options.bgColorR, options.bgColorG, options.bgColorB);

            postProcessingPipeline.renderPost(this, ttr, eopt?.previousContextState);
        }

        eopt.forceCleanup = false;

        // Present composed frame once per frame
        _context3d.present();
    }

    public function onAddedToStage():Void {}
    public function onRemovedFromStage():Void {}

    public function onEntityAdded(entity:IEntity3D):Void {
        if (_context3d != null) {
            entity.upload(this);
            _uploadedEntities.push(entity);
        } else {
            _pendingEntities.push(entity);
        }
    }

    public function onEntityRemoved(entity:IEntity3D):Void {
        _pendingEntities.remove(entity);
        _uploadedEntities.remove(entity);
    }

    public function resize(width:Int, height:Int):Void {
        if (width <= 0 || height <= 0) {
            Debugger.log("BasicHardwareEngine.resize: ignoring invalid size", width, "x", height);
            return;
        }

        _backBufferWidth  = width;
        _backBufferHeight = height;

        if (_context3d != null) {
            configureContext3DBackbuffer();
        }
    }

    public function dispose():Void {
        Debugger.log("BasicHardwareEngine.dispose");

        // Stop listening for context creation
        if (_stage3d != null) {
            _stage3d.removeEventListener(Event.CONTEXT3D_CREATE, onContext3DCreate);
        }

        if (postProcessingPipeline != null)
            postProcessingPipeline.dispose(this);

        // Dispose any cached backbuffer textures
        clearCachedBuffers();
        _textureToRenderTo = null;

        // Clear shader cache while we still have the context reference
        Shader3D.clearCache(_context3d);

        // Dispose the Stage3D context
        if (_context3d != null) {
            try {
                _context3d.dispose();
            } catch (e:Dynamic) {
                Debugger.log("Error disposing Context3D:", e);
            }
            _context3d = null;
        }

        _stage3d = null;
        _pendingEntities = [];
        _uploadedEntities = [];
        _pendingPrograms = [];
    }

    // ------------------------------------------------------------------
    // Internal
    // ------------------------------------------------------------------

    private function configureContext3DBackbuffer():Void {
        if (_context3d == null) return;

        _context3d.configureBackBuffer(_backBufferWidth, _backBufferHeight, 0, true);

        final cache = _cachedBackbuffer.get(_backBufferWidth)?.get(_backBufferHeight);
        if (cache == null) {
            _textureToRenderTo = {
                texture: _context3d.createRectangleTexture(_backBufferWidth, _backBufferHeight, Context3DTextureFormat.BGRA, true),
                width: _backBufferWidth,
                height: _backBufferHeight,
            };

            final map = _cachedBackbuffer.get(_backBufferWidth) ?? new IntMap();
            map.set(_backBufferHeight, _textureToRenderTo);
            _cachedBackbuffer.set(_backBufferWidth, map);
        } else {
            _textureToRenderTo = cache;
        }
    }

    public function onContext3DCreate(e:Event):Void {
        var s3d = cast(e.target, Stage3D);
        _stage3d = s3d;

        // Clear old context's cached programs/textures before switching
        if (_context3d != null)
            Shader3D.clearCache(_context3d);

        _context3d = s3d.context3D;
        _contextVersion++;
        if (_context3d == null) return;

        _context3d.enableErrorChecking = true;

        configureContext3DBackbuffer();

        // Re-upload all previously uploaded entities (stale after context recreation)
        for (ent in _uploadedEntities)
            ent.upload(this);

        // Upload pending entities (added before context was ready)
        for (ent in _pendingEntities) {
            ent.upload(this);
            _uploadedEntities.push(ent);
        }
        _pendingEntities = [];

        // Process queued program uploads (from uploadProgram calls before context was ready)
        for (pending in _pendingPrograms) {
            final prog = Shader3D.uploadAGAL(_context3d, pending.vertex, pending.fragment);
            pending.promise.complete(prog);
        }
        _pendingPrograms = [];

        if (postProcessingPipeline != null)
            postProcessingPipeline.upload(this);

        _promise.complete(this);
    }

    public function clearCachedBuffers():Void {
        for (i in _cachedBackbuffer)
            for (j in i)
                j.texture.dispose();

        _cachedBackbuffer.clear();
    }

    function get_context():Context3D {
        return _context3d;
    }

    function get_future():Future<BasicHardwareEngine> {
        return _promise.future;
    }

    function set_postProcessingPipeline(pp:PostProcessing):PostProcessing {
        if (_context3d != null && pp != null) {
            pp.upload(this);
        }

        return this.postProcessingPipeline = pp;
    }
}
