package org.flashbacks1998.world3d.shader;

import haxe.ds.ObjectMap;
import org.flashbacks1998.world3d.engine.IRendererEngine;
import org.flashbacks1998.world3d.interfaces.IUploadable3D;
import org.flashbacks1998.world3d.shader.IShader.Shader3DPreviousContextState;
import org.flashbacks1998.world3d.shader.IShader.IShader3D;
import org.flashbacks1998.debugger.Debugger;
import org.flashbacks1998.world3d.shader.parts.ShaderPart;
import openfl.display3D.textures.TextureBase;
import openfl.Vector;
import openfl.geom.Matrix3D;
import org.flashbacks1998.world3d.geom.Mesh3D;
import openfl.display3D.Program3D;

class ShaderPipeline implements IShader3D implements IUploadable3D {
    public static final SHADER_PREFIX_DEFAULT_VERTEX_SHADER =
        "m44 vt0, va0, vc0\n" +         // vt0 = clip-space (x,y,z,w)
        "mov op, vt0\n" +               // set clip-space output

        "mov v0, va0\n" +               // pass position if needed (this case clip space)
        "mov v1, va1\n" +               // pass uv
        "mov v2, va2\n" ;               // pass kdrgb

    public static final SHADER_PREFIX_DEFAULT_FRAGMENT_SHADER =
        "";

    public static final SHADER_SUFFIX_DEFAULT_FRAGMENT_SHADER =
        "mov oc, ft0\n";

    public var parts:Vector<ShaderPart>;

    // Per-engine compiled programs with context version for staleness detection
    private var _programs:ObjectMap<IRendererEngine, { program:Program3D, contextVersion:Int }> = new ObjectMap();

    // Exposed for engine to read during drawMesh
    public var textures:Vector<Vector<TextureBase>> = new Vector();
    public var vertexConstants:Vector<Vector<Float>> = new Vector();
    public var fragmentConstants:Vector<Vector<Float>> = new Vector();

    public function new(?options:{?parts:Vector<ShaderPart>}) {
        parts = options?.parts ?? new Vector();

        Debugger.log("Created ShaderPipeline instance");
    }

    // -------------------------------------------------
    // Per-engine program management
    // -------------------------------------------------

    public function getProgram(engine:IRendererEngine):Program3D {
        final entry = _programs.get(engine);
        if (entry == null) return null;

        // Stale? Context was recreated since we compiled
        if (entry.contextVersion != engine.contextVersion) {
            _programs.remove(engine);
            return null;
        }

        return entry.program;
    }

    // -------------------------------------------------
    // AGAL code generation
    // -------------------------------------------------

    public function getShaderVertexPrefixAgal():String {
        return SHADER_PREFIX_DEFAULT_VERTEX_SHADER;
    }

    public function getShaderFragmentPrefixAgal():String {
        return SHADER_PREFIX_DEFAULT_FRAGMENT_SHADER;
    }

    public function getShaderFragmentSuffixAgal():String {
        return SHADER_SUFFIX_DEFAULT_FRAGMENT_SHADER;
    }

    public function getFragmentAGALCode():String {
        Debugger.log("Building fragment AGAL code from parts, count=" + parts.length);
        var code = getShaderFragmentPrefixAgal();
        var toffset = 0;
        var coffset = 0;
        // Use indexed loop to avoid VectorDataIterator allocations
        for (i in 0...parts.length) {
            var part = parts[i];
            Debugger.log("processing part: " + Type.typeof(part), part, toffset, coffset);

            final cpart = part.getFragmentAGALCode(-1, {
                registerTextureOffset: toffset,
                registerConstantOffset: coffset
            });

            if(cpart != null) {
                Debugger.log("append part fragment code: " + Type.typeof(part));
                code += cpart;

                toffset += part.getFragmentTextures()?.length ?? 0;
                coffset += part.getFragmentConstants()?.length ?? 0;
            }
        }
        code += getShaderFragmentSuffixAgal();
        Debugger.log("Final fragment AGAL length=" + code.length);
        return code;
    }

    public function getVertexAGALCode():String {
        Debugger.log("Building vertex AGAL code from parts, count=" + parts.length);
        var code = getShaderVertexPrefixAgal();
        var coffset = 4; // vc0-vc3 reserved for matrix
        // Use indexed loop to avoid VectorDataIterator allocations
        for (i in 0...parts.length) {
            var part = parts[i];
            final cpart = part.getVertexAGALCode(-1, {
                registerConstantOffset: coffset
            });
            if(cpart != null) {
                Debugger.log("append part vertex code: " + Type.typeof(part));
                code += cpart;

                coffset += part.getVertexConstants()?.length ?? 0;
            }
        }
        Debugger.log("Final vertex AGAL length=" + code.length);
        return code;
    }

    // -------------------------------------------------
    // Upload / reupload
    // -------------------------------------------------

    public function upload(engine:IRendererEngine):Void {
        // Already uploaded for this engine with matching context? Skip.
        final existing = _programs.get(engine);
        if (existing != null && existing.contextVersion == engine.contextVersion) return;

        Debugger.log("Uploading parts and building AGAL");

        // Sentinel entry — prevents duplicate uploads while Future is pending
        _programs.set(engine, { program: null, contextVersion: engine.contextVersion });

        // Upload parts (pushOnce guards prevent duplicates)
        for (i in 0...parts.length) {
            var part = parts[i];
            try {
                part.upload(engine);
            } catch(e:Dynamic) {
                Debugger.log("ERROR in part.upload: " + Std.string(e));
            }
        }

        final totalShaderAGALVertexCode = getVertexAGALCode();
        final totalShaderAGALFragmentCode = getFragmentAGALCode();

        // uploadProgram returns a Future — program may resolve now (context ready)
        // or later (context deferred via onContext3DCreate)
        final futureProgram = engine.uploadProgram(totalShaderAGALVertexCode, totalShaderAGALFragmentCode);

        futureProgram.onComplete(function(prog) {
            // Store with contextVersion at resolve time (not upload time).
            // For deferred uploads, version increments in onContext3DCreate
            // BEFORE the pending queue is processed.
            _programs.set(engine, { program: prog, contextVersion: engine.contextVersion });
        });

        getProgramConstants();
    }

    public function reupload(engine:IRendererEngine):Void {
        _programs.remove(engine);
        upload(engine);
    }

    // -------------------------------------------------
    // Constants collection
    // -------------------------------------------------

    private function getProgramConstants() {
        textures.length = 0;
        vertexConstants.length = 0;
        fragmentConstants.length = 0;

            for (pi in 0...parts.length) {
            final part = parts[pi];

            final vc = part.getVertexConstants();           // Vector<Vector<Float>> or null
            final fc = part.getFragmentConstants();      // Vector<Vector<Float>> or null
            final tex = part.getFragmentTextures();                // Array<Texture> or null

            // Vertex constants: write at registers totalVertexConstantsUsed + vi
            final vcCount = vc?.length ?? 0;
            for (vi in 0...vcCount) {
                final v = vc.get(vi);

                if(v != null) vertexConstants.push(v);

            }

            // Fragment constants: same idea, at registers starting at totalFragmentConstantsUsed
            final fcCount = fc?.length ?? 0;
            for (fi in 0...fcCount) {
                final f = fc.get(fi);

                if(f != null) fragmentConstants.push(f);

            }

            if(tex != null) textures.push(tex);

        }
    }

    // -------------------------------------------------
    // Render
    // -------------------------------------------------

    // Reusable prepair options object
    static var prepairCache = {
        backbufferWidth: cast(0, Null<UInt>),
        backbufferHeight: cast(0, Null<UInt>),
    };

    public function render(
        engine:IRendererEngine,
        mesh:Mesh3D,
        ?matrix:Matrix3D,
        ?options:{
            ?backbufferWidth:UInt,
            ?backbufferHeight:UInt,
            ?previousContextState:Shader3DPreviousContextState,
            ?forceCleanup:Bool
        }
    ):Void {
        // Prepare parts with backbuffer info
        prepairCache.backbufferWidth  = (options != null) ? options.backbufferWidth  : 0;
        prepairCache.backbufferHeight = (options != null) ? options.backbufferHeight : 0;

        var pi = 0;
        var pn = parts.length;
        while (pi < pn) {
            parts[pi].prepair(prepairCache);
            pi++;
        }

        // Refresh constants from parts (they may have changed in prepair)
        getProgramConstants();

        // Delegate actual GPU/CPU draw call to the engine
        engine.drawMesh(mesh, this, matrix, options);
    }

    // -------------------------------------------------
    // Clone / dispose
    // -------------------------------------------------

    public function clone() {
        final cloned = new ShaderPipeline({
            parts: parts.copy()
        });
        for (eng in _programs.keys())
            cloned._programs.set(eng, _programs.get(eng));
        return cloned;
    }

    public function dispose(engine:IRendererEngine):Void {
        Debugger.log("dispose");

        _programs = new ObjectMap();

        for(p in parts)
            p.dispose(engine);
    }
}
