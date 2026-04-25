// ShaderPart.hx
package org.flashbacks1998.world3d.shader.parts;

import org.flashbacks1998.world3d.engine.IRendererEngine;
import org.flashbacks1998.world3d.interfaces.IUploadable3D;
import openfl.display3D.textures.TextureBase;
import openfl.Vector;

class ShaderPart implements IUploadable3D {
    public var _vertexConstants:Vector<Vector<Float>> = new Vector();
    public var _fragmentConstants:Vector<Vector<Float>> = new Vector();
    public var _textures:Vector<TextureBase> = new Vector();

    public function new() {}

    public function upload(engine:IRendererEngine):Void {}

    public function getVertexConstants():Null<Vector<Vector<Float>>> {
        return _vertexConstants;
    }

    public function getVertexAGALCode(agalVersion:Int = -1, ?options:{ registerConstantOffset:UInt }):String {
        return null;
    }

    public function getFragmentTextures():Null<Vector<TextureBase>> {
        return _textures;
    }

    public function getFragmentConstants():Null<Vector<Vector<Float>>> {
        return _fragmentConstants;
    }

    public function getFragmentAGALCode(agalVersion:Int = -1, ?options:{
        registerConstantOffset:UInt,
        registerTextureOffset:UInt,
    }):String {
        return null;
    }

    public function isTheSame(part:ShaderPart) { return false; }

    public function prepair(?options:{
        ?backbufferWidth:UInt,
        ?backbufferHeight:UInt
    }) {}

    // ----------------- NEW: “push-once” helpers -----------------
    inline function pushFragmentConstOnce(v:Vector<Float>):Void {
        if (_fragmentConstants.indexOf(v) == -1) _fragmentConstants.push(v);
    }

    inline function pushVertexConstOnce(v:Vector<Float>):Void {
        if (_vertexConstants.indexOf(v) == -1) _vertexConstants.push(v);
    }

    inline function pushTextureOnce(t:TextureBase):Void {
        if (t != null && _textures.indexOf(t) == -1) _textures.push(t);
    }

    inline function removeTexture(t:TextureBase):Void {
        final i = _textures.indexOf(t);
        if(i >= 0 )
            _textures.removeAt(i);
    }

    public function dispose(engine:IRendererEngine):Void {

    }
}
