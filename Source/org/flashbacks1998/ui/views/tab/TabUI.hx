package org.flashbacks1998.ui.views.tab;

import openfl.display.Sprite;
import org.flashbacks1998.ui.styles.TabStyle;

class TabUI {
    public var title:String;
    public var container:Sprite;
    public var style:TabStyle;

    // built by TabViewUI
    public var header:TabHeaderUI;

    public function new(title:String, ?container:Sprite = null, ?style:TabStyle = null) {
        this.title = title;
        this.container = (container == null) ? new Sprite() : container;
        this.style = (style == null) ? TabStyle.defaultStyle : style;
    }
}