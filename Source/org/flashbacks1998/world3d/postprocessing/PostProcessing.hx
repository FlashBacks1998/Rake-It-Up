package org.flashbacks1998.world3d.postprocessing;

import org.flashbacks1998.world3d.postprocessing.IPostProcessingInterface.PostProcessingTexture;
import haxe.Json;
import org.flashbacks1998.debugger.Debugger;
import openfl.Vector;
import org.flashbacks1998.world3d.shader.parts.ShaderPart;
import org.flashbacks1998.world3d.postprocessing.parts.DownscaleShaderPart;
import org.flashbacks1998.world3d.shader.ShaderPipeline;
import org.flashbacks1998.world3d.geom.Mesh3D;
import org.flashbacks1998.world3d.engine.IRendererEngine;
import openfl.geom.Matrix3D;
import org.flashbacks1998.world3d.geom.primitives.PostProcessingMesh3D;
import org.flashbacks1998.world3d.shader.parts.TextureShaderPart;
import org.flashbacks1998.world3d.postprocessing.parts.PostProcessingShaderPart;

class PostProcessing extends ShaderPipeline implements IPostProcessingInterface {
    private var mesh:PostProcessingMesh3D;
    private var firstTexturePart = new TextureShaderPart(null, clamp);
      
    public static final SHADER_PREFIX_DEFAULT_VERTEX_SHADER =
        "mov op, va0\n" +   // va0 is clip-space position (-1..1) to the output
        "mov vt0, va0\n" +

        "mov v0, va0\n" +   // pass position if parts care (in this case clip space)
        "mov v1, va1\n" +   // pass uv
        "mov v2, va2\n" ;   // pass kdrgb


    public function new(?options:{
        ?parts:Vector<ShaderPart>
    }) {
        super();
        
        mesh = new PostProcessingMesh3D();
        
        parts.push(firstTexturePart); 
        
        if(options?.parts != null)
            for(p in options.parts)
                parts.push(p);

    }

    public override function getShaderVertexPrefixAgal():String {
        return SHADER_PREFIX_DEFAULT_VERTEX_SHADER;
    }

    /** Compile shader & build quad */
    override public function upload(engine:IRendererEngine):Void {
        Debugger.log("Uploading pipeline", mesh, parts.length, parts);
        mesh.upload(engine);

        super.upload(engine);
    }

    /** Render a fullscreen pass sampling the given source texture (render target). */
    public function renderPost(engine:IRendererEngine, src:PostProcessingTexture, ?eopt:Dynamic):Void {
        if (src == null) return;

        final srcTexture = src.texture;
        firstTexturePart.replaceTexture(srcTexture);

        // Draw with the fullscreen quad mesh
        super.render(engine, mesh, null, {
            previousContextState: eopt,
            backbufferWidth: src.width,
            backbufferHeight: src.height,
            forceCleanup: true
        });
    }
 
    var i:Int;
    public function onBeginRender(engine:IRendererEngine):Void {
        i = 0;
        while(i < parts.length) {
            if(Std.isOfType(parts[i], PostProcessingShaderPart))
                cast(parts[i], PostProcessingShaderPart).onBeginRender(engine);
            i++;
        }
    }

    public function onEndRender(engine:IRendererEngine):Void {
        i = 0;
        while(i < parts.length) {
            if(Std.isOfType(parts[i], PostProcessingShaderPart))
                cast(parts[i], PostProcessingShaderPart).onEndRender(engine);
            i++;
        }
    }

    public override function dispose(engine:IRendererEngine) {
        if(mesh != null)
            mesh.dispose(engine);

        super.dispose(engine);
    }
}
