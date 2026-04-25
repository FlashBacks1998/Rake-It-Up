package org.flashbacks1998.world3d.shader;

import org.flashbacks1998.world3d.shader.parts.DiffuseColorShaderPart;
import org.flashbacks1998.world3d.shader.parts.TextureShaderPart;
import openfl.display.BitmapData;

class MtlShader extends ShaderPipeline { 
    private var _defaultBmpd = new BitmapData(4, 4, true, 0xffffffff);

    public function new(?options:{ bmpData:BitmapData }) {
        super();

        parts.push(new TextureShaderPart(options?.bmpData ?? _defaultBmpd));
        parts.push(new DiffuseColorShaderPart());
    }
}
