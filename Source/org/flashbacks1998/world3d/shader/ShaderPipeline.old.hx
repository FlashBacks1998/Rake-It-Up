package org.flashbacks1998.world3d.shader;

import org.flashbacks1998.world3d.util.Constants;
import org.flashbacks1998.util.MathUtil;
import haxe.Json;
import org.flashbacks1998.world3d.shader.IShader.Shader3DPreviousContextState;
import org.flashbacks1998.world3d.shader.IShader.IShader3D;
import org.flashbacks1998.debugger.Debugger;
import org.flashbacks1998.world3d.shader.parts.ShaderPart;
import openfl.display3D.Context3DTextureFormat;
import openfl.display.Bitmap;
import openfl.display3D.textures.TextureBase;
import openfl.display.BitmapData;
import openfl.display3D.Context3DVertexBufferFormat;
import openfl.display3D.Context3DCompareMode;
import openfl.display3D.Context3DBlendFactor;
import openfl.Vector;
import openfl.geom.Matrix3D;
import org.flashbacks1998.world3d.geom.Mesh3D;
import openfl.display3D.Program3D;
import openfl.display3D.Context3DProgramType;
import openfl.utils.AGALMiniAssembler;
import openfl.display3D.Context3D;

import org.flashbacks1998.world3d.shader.Shader3D;

class ShaderPipeline implements IShader3D{
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

    private var _program:Program3D;

    public function new(?options:{?parts:Vector<ShaderPart>}) { 
        parts = options?.parts ?? new Vector();

        Debugger.log("Created ShaderPipeline instance");
    }
    
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

    public function upload(context:Context3D) {
        Debugger.log("Uploading parts and building AGAL");

        if(_program != null) {
            Debugger.log("Already uploaded, skipping...");
            return;
        }

        // Use indexed loop instead of for-in to avoid iterator allocations
        for (i in 0...parts.length) {
            var part = parts[i];
            Debugger.log("calling part.upload for " + Std.string(part));
            try {
                part.upload(context);
            } catch(e:Dynamic) {
                Debugger.log("ERROR in part.upload: " + Std.string(e) + " - part=" + Std.string(part));
            }
        }        

        final totalShaderAGALVertexCode = getVertexAGALCode();
        final totalShaderAGALFragmentCode = getFragmentAGALCode();

        Debugger.log("Final AGAL lengths: vertex=" + totalShaderAGALVertexCode.length + " fragment=" + totalShaderAGALFragmentCode.length);
        Debugger.log("Allocating base texture from BitmapData");

        try {
            _program = Shader3D.uploadAGAL(context, totalShaderAGALVertexCode, totalShaderAGALFragmentCode);
            Debugger.log("Program created and stored");
        } catch(e:Dynamic) {
            Debugger.log("ERROR creating program: " + Std.string(e));
            _program = null;
        }

        getProgramConstants();
    }

    public function reupload(context:Context3D) {
        _program = null;
        upload(context);
    }

    private var _textures:Vector<Vector<TextureBase>> = new Vector();
    private var _vertexConstants:Vector<Vector<Float>> = new Vector();
    private var _fragmentConstants:Vector<Vector<Float>> = new Vector();
    
    private function getProgramConstants() {
        _textures.length = 0;
        _vertexConstants.length = 0;
        _fragmentConstants.length = 0;

            for (pi in 0...parts.length) {
            final part = parts[pi];

            final vertexConstants = part.getVertexConstants();           // Vector<Vector<Float>> or null
            final fragmentConstants = part.getFragmentConstants();      // Vector<Vector<Float>> or null
            final textures = part.getFragmentTextures();                // Array<Texture> or null

            // Vertex constants: write at registers totalVertexConstantsUsed + vi
            final vcCount = vertexConstants?.length ?? 0;
            for (vi in 0...vcCount) {
                final vc = vertexConstants.get(vi); 

                if(vc != null) _vertexConstants.push(vc);
 
            } 

            // Fragment constants: same idea, at registers starting at totalFragmentConstantsUsed
            final fcCount = fragmentConstants?.length ?? 0;
            for (fi in 0...fcCount) {
                final fc = fragmentConstants.get(fi); 

                if(fc != null) _fragmentConstants.push(fc);

            } 

            if(textures != null) _textures.push(textures);
 
        }
    }
    
    
    // Drop-in optimized version of your render() + fixes for the TODOs.
    // Goals:
    // - Remove `options?.` (null-safe operators generate extra temps on Flash)
    // - Replace all `for (i in 0...n)` / `for (i in a...b)` with while loops (cuts iterator/closure allocs on Flash)
    // - Cache repeated property chains (mesh.vertexBuffer.buffer etc.)
    // - Avoid duplicate "clear trailing samplers" loops
    // - Avoid allocating blendFactors/depthTest objects every frame (still best handled by NOT nulling them in prevState reset)
    // - Avoid allocating prevState.textures (allocate once in prevState init/reset, but we keep a safe fallback here)

    static var totalVertexConstantsUsed = 4;
    static var totalFragmentConstantsUsed = 0;
    static var totalFragmentTexturesUsed = 0;

    // Reusable prepair options object (you already did this - good)
    static var prepairCache = {
        backbufferWidth: cast(0, Null<UInt>),
        backbufferHeight: cast(0, Null<UInt>),
    };

    public function render(
        context:Context3D,
        mesh:Mesh3D,
        ?matrix:Matrix3D,
        ?options:{
            ?backbufferWidth:UInt,
            ?backbufferHeight:UInt,
            ?previousContextState:Shader3DPreviousContextState,
            ?forceCleanup:Bool
        }
    ):Void {
        try {
            final opts = options;
            final prevState:Shader3DPreviousContextState =
                (opts != null) ? opts.previousContextState : null;

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
                (opts != null && opts.forceCleanup != null) ? opts.forceCleanup : (prevState == null);

            if (_program == null) return;

            // 1) Blend
            final desiredBlendSrc = Context3DBlendFactor.SOURCE_ALPHA;
            final desiredBlendDst = Context3DBlendFactor.ONE_MINUS_SOURCE_ALPHA;
            if (prevBlend == null || prevBlend.sourceFactor != desiredBlendSrc || prevBlend.destinationFactor != desiredBlendDst) {
                context.setBlendFactors(desiredBlendSrc, desiredBlendDst);
            }

            // 2) Depth
            final desiredDepthMask = true;
            final desiredDepthFunc = Context3DCompareMode.LESS;
            if (prevDepth == null || prevDepth.depthMask != desiredDepthMask || prevDepth.passCompareMode != desiredDepthFunc) {
                context.setDepthTest(desiredDepthMask, desiredDepthFunc);
            }

            // 3) Program
            if (prevProgram != _program) context.setProgram(_program);

            // 4) Vertex attributes (cache chains)
            final vb = mesh.vertexBuffer;
            final vbbuf = vb.buffer;
            final attrs = vb.attributes;

            context.setVertexBufferAt(0, vbbuf, attrs.pos3,   Context3DVertexBufferFormat.FLOAT_3);
            context.setVertexBufferAt(1, vbbuf, attrs.uv2,    Context3DVertexBufferFormat.FLOAT_2);
            context.setVertexBufferAt(2, vbbuf, attrs.kdrgb3, Context3DVertexBufferFormat.FLOAT_3);

            // 5) Matrix -> vc0..vc3
            if (matrix != null)
                 context.setProgramConstantsFromMatrix(Context3DProgramType.VERTEX, 0, matrix, true);
            else 
                context.setProgramConstantsFromMatrix(Context3DProgramType.VERTEX, 0, Constants.MATRIX_IDENTITY, true);

            // 6) Prepare parts (reused object)
            prepairCache.backbufferWidth  = (opts != null) ? opts.backbufferWidth  : 0;
            prepairCache.backbufferHeight = (opts != null) ? opts.backbufferHeight : 0;

            var pi = 0;
            var pn = parts.length;
            while (pi < pn) {
                parts[pi].prepair(prepairCache);
                pi++;
            }

            // 7) Constants (while loops)
            var vcBase = 4;
            var fcBase = 0;

            var vcCount = (_vertexConstants != null) ? _vertexConstants.length : 0;
            var vi = 0;
            while (vi < vcCount) {
                final reg = vcBase + vi;
                final vc = _vertexConstants.get(vi);
                final prevVc = (prevVertexConstants != null && reg < prevVertexConstants.length)
                    ? prevVertexConstants.get(reg)
                    : null;

                if (vc != null && vc != prevVc) {
                    context.setProgramConstantsFromVector(Context3DProgramType.VERTEX, reg, vc);
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
                    context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, reg, fc);
                }
                fi++;
            }

            // 8) Textures (bind + update prevState.textures in ONE PASS)
            var samplerIndex = 0;
            final prevTotal = (prevTextures != null) ? prevTextures.length : 0;

            // Ensure prevState.textures exists once (preferably never null if you fix resetPrevContextState)
            var flat:Vector<TextureBase> = null;
            if (prevState != null) {
                flat = prevState.textures;
                if (flat == null) {
                    flat = new Vector<TextureBase>();
                    prevState.textures = flat;
                }
                // don't clear it here; we’ll set indices and then set length at the end
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

                            if (prevTex != tex) context.setTextureAt(samplerIndex, tex);

                            // update cached prev textures without a second flatten loop
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

            // Clear any previously-bound samplers beyond current count (ONCE)
            var pti = samplerIndex;
            while (pti < prevTotal) {
                context.setTextureAt(pti, null);
                if (flat != null && pti < flat.length) flat.set(pti, null);
                pti++;
            }

            // If we’re tracking flat, truncate it to current used count
            if (flat != null) flat.length = samplerIndex;

            // 9) Draw
            context.drawTriangles(mesh.indexBuffer);
            Debugger.meshesRendered++;
            Debugger.trianglesRendered += cast (mesh.indexData.indices.length / 3);

            // Cleanup textures if prevTextures missing or forced
            if (prevTextures == null || forceCleanup) {
                var ti = 0;
                while (ti < samplerIndex) {
                    context.setTextureAt(ti, null);
                    ti++;
                }
            }

            // 10) Update prevState (avoid re-allocating subobjects if you stop nulling them in reset)
            if (prevState != null) {
                prevState.program = _program;

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
            Debugger.error("ERROR during render: " + Std.string(e));
        }
    }

    public function clone() {
        final cloned = new ShaderPipeline({
            parts: parts.copy()
        });
        return cloned;
    }

    public function dispose(context:Context3D) {
        Debugger.log("dispose");
        
        _program = null;

        for(p in parts)
            p.dispose(context);
    }
}
