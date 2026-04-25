package org.flashbacks1998.world3d.postprocessing.parts;

import org.flashbacks1998.world3d.engine.IRendererEngine;

class DownscaleShaderPart extends PostProcessingShaderPart {
    public var sx:Float;
    public var sy:Float;
    public function new(sx:Float, sy:Float) {
        super();

        this.sx = sx;
        this.sy = sy;
    }

    var _origWidth = 0;
    var _origHeight = 0;
    public override function onBeginRender(engine:IRendererEngine):Void {
        _origWidth = engine.width;
        _origHeight = engine.height;

        engine.resize(Std.int(_origWidth * sx), Std.int(_origHeight * sy));

        super.onBeginRender(engine);
    }

    public override function onEndRender(engine:IRendererEngine):Void {
        engine.resize(_origWidth, _origHeight);

        super.onEndRender(engine);
    }
}