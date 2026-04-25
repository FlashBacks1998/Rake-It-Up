package org.flashbacks1998.ui.styles;

/**
 * TextboxStyle - simple style struct for UITextbox
 */
@:structInit
class TextboxStyle {
    public var width:Int;
    public var height:Int;
    public var fontName:String;
    public var fontSize:Int;
    public var fontColor:Int;
    public var bgColor:Int;
    public var borderColor:Int;
    public var borderThickness:Int;
    public var cornerRadius:Float;
    public var padding:Int;
    public var overflowX:Bool; // allow horizontal overflow (no wrap)
    public var overflowY:Bool; // allow vertical overflow (scroll)
    public var wrap:Bool;      // enable word wrap
    public var enabled:Bool;
    public var readOnly:Bool; 
    public var autoScroll:Bool;

    public static var defaultStyle:TextboxStyle = {
        width: 360,
        height: 44,
        fontName: "Arial",
        fontSize: 14,
        fontColor: 0x222222,   // dark text
        bgColor: 0xFFF4E8FF,     // warm light background (matches orange button palette)
        borderColor: 0xFFB06A, // same border vibe as button
        borderThickness: 2,
        cornerRadius: 14,
        padding: 10,
        overflowX: false,
        overflowY: true,
        wrap: true,
        enabled: true,
        readOnly: false,
        autoScroll: false
    }

    public function new(
        ?width:Int,
        ?height:Int,
        ?fontName:String,
        ?fontSize:Int,
        ?fontColor:Int,
        ?bgColor:Int,
        ?borderColor:Int,
        ?borderThickness:Int,
        ?cornerRadius:Float,
        ?padding:Int,
        ?overflowX:Bool,
        ?overflowY:Bool,
        ?wrap:Bool,
        ?enabled:Bool,
        ?readOnly:Bool,
        ?autoScroll:Bool
    ) {
        var def = defaultStyle;

        this.width           = width           ?? def.width;
        this.height          = height          ?? def.height;
        this.fontName        = fontName        ?? def.fontName;
        this.fontSize        = fontSize        ?? def.fontSize;
        this.fontColor       = fontColor       ?? def.fontColor;
        this.bgColor         = bgColor         ?? def.bgColor;
        this.borderColor     = borderColor     ?? def.borderColor;
        this.borderThickness = borderThickness ?? def.borderThickness;
        this.cornerRadius    = cornerRadius    ?? def.cornerRadius;
        this.padding         = padding         ?? def.padding;
        this.overflowX       = overflowX       ?? def.overflowX;
        this.overflowY       = overflowY       ?? def.overflowY;
        this.wrap            = wrap            ?? def.wrap;
        this.enabled         = enabled         ?? def.enabled;
        this.readOnly        = readOnly        ?? def.readOnly;
        this.autoScroll      = autoScroll      ?? def.autoScroll;
    }
}