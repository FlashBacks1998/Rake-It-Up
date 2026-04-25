package org.flashbacks1998.debugger;

import org.flashbacks1998.ui.text.TextboxUI;
import org.flashbacks1998.ui.styles.TextboxStyle;
import org.flashbacks1998.debugger.DebuggerLog;

import openfl.events.Event;
import openfl.display.Sprite;

/**
 * DebuggerConsole
 * - Displays incoming Debugger logs in a read-only TextboxUI.
 * - Now includes pause()/resume() so heavy text updates can be disabled during transitions.
 */
class DebuggerConsole extends Sprite {
    private var _textbox:TextboxUI;
    private var _style:TextboxStyle;

    private var _listening:Bool = false;

    public function new(?style:TextboxStyle) {
        super();

        if (style == null) {
            var ds = TextboxStyle.defaultStyle;
            _style = {
                width: ds.width,
                height: ds.height,
                fontName: ds.fontName,
                fontSize: ds.fontSize,
                fontColor: ds.fontColor,
                bgColor: ds.bgColor,
                borderColor: ds.borderColor,
                borderThickness: ds.borderThickness,
                cornerRadius: ds.cornerRadius,
                padding: ds.padding,
                overflowX: true,
                overflowY: true,
                wrap: false,
                enabled: true,
                readOnly: true,
                autoScroll: true,
            };
        } else {
            _style = {
                width: style.width,
                height: style.height,
                fontName: style.fontName,
                fontSize: style.fontSize,
                fontColor: style.fontColor,
                bgColor: style.bgColor,
                borderColor: style.borderColor,
                borderThickness: style.borderThickness,
                cornerRadius: style.cornerRadius,
                padding: style.padding,
                overflowX: true,
                overflowY: true,
                wrap: false,
                enabled: style.enabled,
                readOnly: true,
                autoScroll: true,
            };
        }

        _textbox = new TextboxUI("", _style.width, _style.height, _style);
        addChild(_textbox);

        addEventListener(Event.ADDED_TO_STAGE, onAddedToStage);
        addEventListener(Event.REMOVED_FROM_STAGE, onRemovedFromStage);
    }

    public function setSize(w:Int, h:Int):Void {
        _style.width = w;
        _style.height = h;
        if (_textbox != null) _textbox.setSize(w, h);
    }

    public function pause():Void {
        if (!_listening) return;
        try {
            Debugger.instance.removeEventListener(DebuggerEventNewLogs.NEW_LOGS, onNewLogs);
        } catch (_:Dynamic) {}
        _listening = false;
    }

    public function resume():Void {
        if (_listening) return;
        try {
            Debugger.instance.addEventListener(DebuggerEventNewLogs.NEW_LOGS, onNewLogs);
            _listening = true;
        } catch (_:Dynamic) {}
    }

    private function onAddedToStage(e:Event):Void {
        removeEventListener(Event.ADDED_TO_STAGE, onAddedToStage);
        resume();
    }

    private function onRemovedFromStage(e:Event):Void {
        removeEventListener(Event.REMOVED_FROM_STAGE, onRemovedFromStage);

        if (stage != null) {
            stage.removeEventListener(Event.RESIZE, onStageResize);
        }

        pause();
    }

    private function onStageResize(e:Event):Void {
        if (stage == null) return;
        setSize(stage.stageWidth, stage.stageHeight);
    }

    private function onNewLogs(e:Event):Void {
        var ev = cast(e, DebuggerEventNewLogs);
        if (ev == null || ev.logs == null || ev.logs.length == 0) return;
        if (_textbox == null) return;

        var existing = _textbox.text;
        var parts:Array<String> = [];
        if (existing != null && existing.length > 0) parts.push(existing);

        for (log in ev.logs) {
            var dl:DebuggerLog = cast log;
            var m = (dl == null || dl.msg == null) ? "" : dl.msg;
            if (m.length > 0) parts.push(m);
        }

        _textbox.text = parts.join("\n");
    }
}