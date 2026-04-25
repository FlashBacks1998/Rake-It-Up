package org.flashbacks1998.world3d.engine;

import openfl.display.BitmapData;
import openfl.display3D.Program3D;
import openfl.display3D.textures.TextureBase;
import openfl.geom.Matrix3D;
import openfl.utils.Future;
import org.flashbacks1998.world3d.camera.Camera3D;
import org.flashbacks1998.world3d.entity.IEntity3D;
import org.flashbacks1998.world3d.geom.Mesh3D;
import org.flashbacks1998.world3d.shader.IShader.IShader3D;

typedef RendererOptions = {
    var bgColorR:Float;
    var bgColorG:Float;
    var bgColorB:Float;
    var width:Int;
    var height:Int;
}

enum BasicRendererEngineType {
    software;
    hardware;
}

interface IRendererEngine {
    public var ready(get, null):Bool;
    public var type:BasicRendererEngineType;
    public var contextVersion(get, null):Int;

    public var width(get, set):Int;
    public var height(get, set):Int;

    // post processing TODO
    // public var postProcessingPipeline(get, set):IPostProcessingInterface;
    // public var postProcessingEnabled(get, set):Bool;

    public function render(camera:Camera3D, entities:Array<IEntity3D>, options:RendererOptions):Void;
    public function onAddedToStage():Void;
    public function onRemovedFromStage():Void;
    public function onEntityAdded(entity:IEntity3D):Void;
    public function onEntityRemoved(entity:IEntity3D):Void;
    public function resize(width:Int, height:Int):Void;
    // TODO public function scale(scaleX:Float, scaleY:Float):Void;
    public function dispose():Void;

    // Resource upload
    public function uploadMesh(mesh:Mesh3D):Void;
    public function uploadTexture(bitmapData:BitmapData):TextureBase;
    public function uploadProgram(vertexAGAL:String, fragmentAGAL:String):Future<Program3D>;

    // Draw call
    public function drawMesh(mesh:Mesh3D, shader:IShader3D, ?matrix:Matrix3D, ?options:Dynamic):Void;
}
