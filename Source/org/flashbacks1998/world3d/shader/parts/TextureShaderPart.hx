package org.flashbacks1998.world3d.shader.parts;

import org.flashbacks1998.debugger.Debugger;
import org.flashbacks1998.world3d.engine.IRendererEngine;
import openfl.display3D.textures.TextureBase;
import openfl.display.BitmapData;
import openfl.Vector;

enum abstract TextureShaderPartSampler(String) {
    var repeat;
    var clamp;
}

/**
 * TextureShaderPart
 * - Samples a 2D texture into ft0 using v1 UVs.
 * - Optional alpha cutoff (alpha test) using AGAL `kil`:
 *   Discards pixels with alpha < cutoff so transparent holes don't write depth.
 *
 * Usage:
 *   var part = new TextureShaderPart(leafBmpd, clamp);
 *   part.alphaCutoff = 0.5; // enable cutout
 */
class TextureShaderPart extends ShaderPart {
    private static var _defaultBmpd:BitmapData = null;

    public var bitmapData:BitmapData;
    private var _texture:TextureBase;

    public var sampler:TextureShaderPartSampler = repeat;

    /**
     * Alpha cutoff for cutout textures.
     * < 0  => disabled (default)
     * 0..1 => enabled (discard alpha < cutoff)
     */
    public var alphaCutoff:Float = .5;

    // Fragment constant register for cutoff (stored locally so indexOf works)
    // fc: [cutoff, 0, 0, 0]
    private final _fragmentConstantCutoff:Vector<Float> =
        Vector.ofArray([0.0, 0.0, 0.0, 0.0]);

    public function new(?bmpd:BitmapData, sampler:TextureShaderPartSampler = repeat) {
        super();
        bitmapData = bmpd ?? getDefaultBitmapData();
        this.sampler = sampler;
    }

    override public function upload(engine:IRendererEngine):Void {
        if (engine == null) return;

        if (bitmapData == null) bitmapData = getDefaultBitmapData();

        final tex = engine.uploadTexture(bitmapData);
        if (tex != null) {
            _texture = tex;
            _textures[0] = _texture;
        }
        
        // Ensure this exact vector instance is registered (so indexOf works)
        
        if (alphaCutoff > 0){ 
            var c = alphaCutoff;
            if (c < 0) c = 0;
            if (c > 1) c = 1;

            _fragmentConstantCutoff[0] = c;
            _fragmentConstantCutoff[1] = 0.0;
            _fragmentConstantCutoff[2] = 0.0;
            _fragmentConstantCutoff[3] = 0.0;

            pushFragmentConstOnce(_fragmentConstantCutoff);
        }
    }

    public function replaceTexture(tex:TextureBase):Void {
        _texture = tex;
        _textures[0] = _texture;
    }

    public static function getDefaultBitmapData():BitmapData {
        if (_defaultBmpd == null) {
            _defaultBmpd = new BitmapData(256, 256, true, 0xFF0Aff00);
        }
        return _defaultBmpd;
    } 

    override public function getFragmentAGALCode(
        agalVersion:Int = -1,
        ?options:{?registerConstantOffset:UInt, ?registerTextureOffset:UInt}
    ):String {
        final fcOffset:UInt = options?.registerConstantOffset ?? 0;
        final ftOffset:UInt = options?.registerTextureOffset ?? 0;

        final fsTexture = "fs" + ftOffset;

        // Sample texture into ft0
        var code =
            "tex ft0, v1, " + fsTexture + " <2d,nearest," + sampler + ">\n";

        // Optional alpha test
        if (alphaCutoff >= 0) {
            // Find which constant register holds our cutoff within THIS part's _fragmentConstants
            // Then add ShaderPipeline's base offset for fragment constants.
            final localIndex = _fragmentConstants.indexOf(_fragmentConstantCutoff);
            final fcCut = "fc" + (fcOffset + localIndex);

            // sub ft1.w, ft0.w, fcCut.x
            // kil ft1.w  (kills fragment if ft1.w < 0 => alpha < cutoff)
            code += "sub ft1.w, ft0.w, " + fcCut + ".x\n";
            code += "kil ft1.w\n";
        }

        return code;
    }

    override public function isTheSame(part:ShaderPart):Bool {
        if (!Std.isOfType(part, TextureShaderPart)) return false;

        final p:TextureShaderPart = cast part;

        if (p.bitmapData != bitmapData) return false;
        if (p.sampler != sampler) return false;

        // Match cutoff enablement + value (so batching doesn't mix cutout/non-cutout)
        final e0 = alphaCutoff >= 0;
        final e1 = p.alphaCutoff >= 0;
        if (e0 != e1) return false;
        if (e0 && Math.abs(alphaCutoff - p.alphaCutoff) > 1e-6) return false;

        return true;
    }

    override public function dispose(engine:IRendererEngine):Void {
        Debugger.log("TextureShaderPart dispose");

        _texture = null;
        _textures[0] = null;

        super.dispose(engine);
    }
}