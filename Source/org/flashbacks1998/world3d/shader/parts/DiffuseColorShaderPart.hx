package org.flashbacks1998.world3d.shader.parts;

import openfl.display.BitmapData;

class DiffuseColorShaderPart extends ShaderPart {
    public function new(?bmpd:BitmapData) {
        super();
    }

    override public function getFragmentAGALCode(agalVersion:Int = -1, ?options:{
        registerConstantOffset:UInt,
        registerTextureOffset:UInt,
    }):String {
        return "mul ft0.xyz, ft0.xyz, v2.xyz\n";
    }
    
    public override function isTheSame(part:ShaderPart):Bool {
        return Std.isOfType(part, DiffuseColorShaderPart);
    }
}