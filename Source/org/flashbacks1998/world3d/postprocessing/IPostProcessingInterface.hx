package org.flashbacks1998.world3d.postprocessing;

import openfl.display3D.Context3D;
import openfl.display3D.textures.TextureBase;
import openfl.display3D.textures.RectangleTexture;
import openfl.Vector;
import org.flashbacks1998.world3d.engine.IRendererEngine;

typedef PostProcessingTexture = {
    texture: TextureBase,
    width:UInt,    
    height:UInt
};


interface IPostProcessingInterface {
    public function onBeginRender(engine:IRendererEngine):Void;
    public function onEndRender(engine:IRendererEngine):Void;
}