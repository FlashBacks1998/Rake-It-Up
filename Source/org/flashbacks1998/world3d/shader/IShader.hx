package org.flashbacks1998.world3d.shader;

import flash.display3D.Context3DCompareMode;
import openfl.display3D.Context3DBlendFactor;
import openfl.display3D.textures.TextureBase;
import openfl.Vector;
import openfl.display3D.Program3D;
import org.flashbacks1998.world3d.engine.IRendererEngine;
import org.flashbacks1998.world3d.interfaces.IUploadable3D;
import org.flashbacks1998.world3d.geom.Mesh3D;
import openfl.geom.Matrix3D;

// purely a structural type (no default values here)
typedef Shader3DPreviousContextState = {
    var program:Program3D;
    var blendFactors:{
        sourceFactor:Context3DBlendFactor,
        destinationFactor:Context3DBlendFactor
    };
    var depthTest:{
        depthMask:Null<Bool>, passCompareMode:Context3DCompareMode
    };

    var textures:Vector<TextureBase>;
    var vertexBuffer:Mesh3DVertexBuffer;
    var indicesBuffer:Mesh3DIndexBuffer;
    var vertexConstants:Null<Vector<Vector<Float>>>;
    var fragmentConstVersion:Null<Vector<Vector<Float>>>;
}

/**
 * Interface for all shaders in the 3D world.
 */
interface IShader3D extends IUploadable3D {
    /**
     * Returns the compiled program for the given engine, or null if not yet uploaded / stale.
     */
    public function getProgram(engine:IRendererEngine):Program3D;

    /**
     * Renders a Mesh3D with this shader using the provided transformation matrix.
     */
    public function render(engine:IRendererEngine, mesh:Mesh3D, ?matrix:Matrix3D, ?options: {
        ?backbufferWidth:UInt,
		?backbufferHeight:UInt,
		?previousContextState:Shader3DPreviousContextState,
        ?forceCleanup:Bool,
    }):Void;

    public function dispose(engine:IRendererEngine):Void;
}
