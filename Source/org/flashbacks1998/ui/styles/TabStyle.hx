package org.flashbacks1998.ui.styles;

@:structInit
class TabStyle {
    public var height:Int;
    public var paddingX:Int;
    public var paddingY:Int;

    public var cornerRadius:Float;
    public var borderColor:Int;
    public var borderThickness:Int;

    public var colorTop:Int;
    public var colorBottom:Int;

    // active colors (selected tab)
    public var activeColorTop:Int;
    public var activeColorBottom:Int;

    public var glossAlpha:Float;

    public var fontName:String;
    public var fontSize:Int;
    public var fontColor:Int;
    public var bold:Bool;

    public var pressMove:Float;

    public static var defaultStyle:TabStyle = {
        height: 40,
        paddingX: 16,
        paddingY: 8,

        cornerRadius: 14,
        borderColor: 0x3B2416,
        borderThickness: 1,

        colorTop: 0x5C3A21,
        colorBottom: 0x3F2615,

        activeColorTop: 0xA6784E,
        activeColorBottom: 0x7E5332,

        glossAlpha: 0.45,

        fontName: "Arial",
        fontSize: 16,
        fontColor: 0xFFFFFF,
        bold: true,

        pressMove: 2
    };
}