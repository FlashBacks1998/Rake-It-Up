package org.flashbacks1998.world3d.shader;

import org.flashbacks1998.world3d.shader.parts.TextureShaderPart;
import openfl.display3D.Context3DTextureFormat;
import openfl.geom.Rectangle;
import openfl.geom.Matrix;
import openfl.Assets;
import openfl.display3D.textures.TextureBase;
import openfl.display.BitmapData;  

class TextureShader extends ShaderPipeline {
    private static var _defaultBitmapData:BitmapData;
    
    private var _bitmapData:BitmapData;
    private var _texture:TextureBase;

    public function new(?options:{ ?bmpData:BitmapData }) {
        super();

        _bitmapData = options?.bmpData ?? _defaultBitmapData;

        parts.push(new TextureShaderPart(_bitmapData));
    } 
}
