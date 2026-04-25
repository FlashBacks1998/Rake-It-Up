package org.flashbacks1998.ui.styles;

@:structInit
class CheckboxStyle {
    public var boxSize:Int;
    public var spacing:Int;
    public var paddingX:Int;
    public var paddingY:Int;

    public var fontName:String;
    public var fontSize:Int;
    public var fontColor:Int;
    public var bold:Bool;

    public var checkColor:Int;
    public var checkThickness:Int;

    public static var defaultStyle:CheckboxStyle = {
        boxSize: 24,
        spacing: 10,
        paddingX: 6,
        paddingY: 4,

        // dark text to the right (as requested)
        fontName: "Arial",
        fontSize: 16,
        fontColor: 0xFFFFFFFF,
        bold: true,

        checkColor: 0x222222,
        checkThickness: 3
    };
}