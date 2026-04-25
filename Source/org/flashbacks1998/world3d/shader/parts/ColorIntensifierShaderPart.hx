package org.flashbacks1998.world3d.shader.parts;

import openfl.Vector;
import org.flashbacks1998.world3d.engine.IRendererEngine;

class ColorIntensifierShaderPart extends ShaderPart {
    /**
     * Single fragment constant register (vec4):
     * [ rMultiplier, gMultiplier, bMultiplier, unused ]
     *
     * NOTE: This vector is mutated in-place when properties change.
     * Your pipeline currently skips uploads if the *reference* didn't change.
     * Consider adjusting the pipeline to compare contents or mark-dirty.
     */
    public final _fragmentColorVars:Vector<Float> = Vector.ofArray([1.0, 1.0, 1.0, 0.0]);

    // Public API: per-channel *deltas*, where multiplier = 1 + delta
    public var red(default, set):Float   = 0.0;
    public var green(default, set):Float = 0.0;
    public var blue(default, set):Float  = 0.0;

    public function new(r:Float, g:Float, b:Float) {
        super();
        // Initialize properties through setters so the constant vector is kept in sync
        set_red(r);
        set_green(g);
        set_blue(b);
    }

    // --- Property setters -----------------------------------------------------

    public function set_red(v:Float):Float {
        // Optional clamp (commented out):
        // v = Math.max(-1.0, v); // prevent negative multipliers beyond zero if desired
        red = v; // store the delta for direct reads (default getter)
        _fragmentColorVars[0] = 1.0 + v; // update GPU constant multiplier
        return red; // setters must return assigned/stored value
    }

    public function set_green(v:Float):Float {
        green = v;
        _fragmentColorVars[1] = 1.0 + v;
        return green;
    }

    public function set_blue(v:Float):Float {
        blue = v;
        _fragmentColorVars[2] = 1.0 + v;
        return blue;
    }

    // --- ShaderPart integration ----------------------------------------------

    /**
     * Push our vec4 into the fragment constants exactly once.
     * Mirrors the pattern used by your other parts.
     */
    // ColorIntensifierShaderPart.hx (minimal tidy)
    override public function upload(engine:IRendererEngine):Void {
        // push once
        pushFragmentConstOnce(_fragmentColorVars);
    }

    /**
     * Multiply current fragment color by our per-channel multipliers.
     * We resolve the absolute fc register index from the pipeline-provided offset.
     */
    override public function getFragmentAGALCode(agalVersion:Int = -1, ?options:{
        registerConstantOffset:UInt,
        registerTextureOffset:UInt,
    }):String {
        final fcOffset = options?.registerConstantOffset ?? 0;
        final localIdx = _fragmentConstants.indexOf(_fragmentColorVars);
        if (localIdx < 0) return null; // upload() not called yet; fail safe

        final fcName = "fc" + (fcOffset + localIdx);
        // ft0.xyz *= fcN.xyz
        return "mul ft0.xyz, ft0.xyz, " + fcName + ".xyz\n";
    }

    /**
     * Structural equality: two intensifiers are "the same" if their
     * multipliers match (within epsilon).
     */
    override public function isTheSame(part:ShaderPart):Bool {
        if (!Std.isOfType(part, ColorIntensifierShaderPart)) return false;
        final p:ColorIntensifierShaderPart = cast part;
        return
            Math.abs((1.0 + p.red)   - _fragmentColorVars[0]) < 1e-6 &&
            Math.abs((1.0 + p.green) - _fragmentColorVars[1]) < 1e-6 &&
            Math.abs((1.0 + p.blue)  - _fragmentColorVars[2]) < 1e-6;
    }
}
