package org.flashbacks1998.util;


/**
 * StyleUtil - safe integer color helpers
 */
class StyleUtil {
    public static function clamp(v:Int, a:Int, b:Int):Int {
        if (v < a) return a;
        if (v > b) return b;
        return v;
    }

    public static function lighten(hex:Int, amount:Float):Int {
        var r = ((hex >> 16) & 0xFF);
        var g = ((hex >> 8) & 0xFF);
        var b = (hex & 0xFF);
        r = clamp(Math.round(r + (255 - r) * amount), 0, 255);
        g = clamp(Math.round(g + (255 - g) * amount), 0, 255);
        b = clamp(Math.round(b + (255 - b) * amount), 0, 255);
        return (r << 16) | (g << 8) | b;
    }

    public static function darken(hex:Int, amount:Float):Int {
        var r = ((hex >> 16) & 0xFF);
        var g = ((hex >> 8) & 0xFF);
        var b = (hex & 0xFF);
        r = clamp(Math.round(r * (1 - amount)), 0, 255);
        g = clamp(Math.round(g * (1 - amount)), 0, 255);
        b = clamp(Math.round(b * (1 - amount)), 0, 255);
        return (r << 16) | (g << 8) | b;
    }

    public static function fadeToGray(hex:Int, factor:Float):Int {
        var r = ((hex >> 16) & 0xFF);
        var g = ((hex >> 8) & 0xFF);
        var b = (hex & 0xFF);
        var gray = Math.round((r + g + b) / 3);
        r = clamp(Math.round(r * (1 - factor) + gray * factor), 0, 255);
        g = clamp(Math.round(g * (1 - factor) + gray * factor), 0, 255);
        b = clamp(Math.round(b * (1 - factor) + gray * factor), 0, 255);
        return (r << 16) | (g << 8) | b;
    }
}
