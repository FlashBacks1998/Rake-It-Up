package org.flashbacks1998.scenes.transitions;

import openfl.display.Shape;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.Lib;

import org.flashbacks1998.scenes.ISceneTransition;
import org.flashbacks1998.debugger.Debugger;
 

//OLD
class FadeTransition implements ISceneTransition {

    /** Overlay fill color. Default: black. */
    public var color:Int;

    /** Cover animation duration in milliseconds. */
    public var coverMs:Int;

    /** Reveal animation duration in milliseconds. */
    public var revealMs:Int;

    private var _overlay:Shape;
    private var _startMs:Float;
    private var _container:Sprite;
    private var _onComplete:Void->Void;
    private var _revealing:Bool = false;

    public function new(color:Int = 0x000000, coverMs:Int = 400, revealMs:Int = 400) {
        this.color   = color;
        this.coverMs = coverMs;
        this.revealMs = revealMs;
    }
 

    public function coverOut(container:Sprite, onComplete:Void->Void):Void {
        Debugger.log("FadeTransition.coverOut start");

        _container  = container;
        _onComplete = onComplete;
        _revealing  = false;

        _overlay = _buildOverlay(container);
        _overlay.alpha = 0;
        container.addChild(_overlay);

        _startMs = Lib.getTimer();
        container.addEventListener(Event.ENTER_FRAME, _onCoverFrame);
    }

    private function _onCoverFrame(e:Event):Void {
        var t:Float = (Lib.getTimer() - _startMs) / coverMs;
        if (t > 1) t = 1;

        _overlay.alpha = t;

        if (t >= 1) {
            _container.removeEventListener(Event.ENTER_FRAME, _onCoverFrame);
            Debugger.log("FadeTransition.coverOut complete");
            var cb = _onComplete;
            _onComplete = null;
            if (cb != null) cb();
        }
    }
 
    public function onLoadProgress(progress:Float):Void {}
 
    public function revealIn(container:Sprite, onComplete:Void->Void):Void {
        Debugger.log("FadeTransition.revealIn start");

        _container  = container;
        _onComplete = onComplete;
        _revealing  = true;

        // If no overlay exists (e.g. instant-swap fallback), create one at full alpha
        if (_overlay == null || _overlay.parent == null) {
            _overlay = _buildOverlay(container);
            _overlay.alpha = 1;
            container.addChild(_overlay);
        }

        _startMs = Lib.getTimer();
        container.addEventListener(Event.ENTER_FRAME, _onRevealFrame);
    }

    private function _onRevealFrame(e:Event):Void {
        var t:Float = (Lib.getTimer() - _startMs) / revealMs;
        if (t > 1) t = 1;

        _overlay.alpha = 1 - t;

        if (t >= 1) {
            _container.removeEventListener(Event.ENTER_FRAME, _onRevealFrame);
            _removeOverlay();
            Debugger.log("FadeTransition.revealIn complete");
            var cb = _onComplete;
            _onComplete = null;
            if (cb != null) cb();
        }
    }


    private function _buildOverlay(container:Sprite):Shape {
        var s = new Shape();
        var sw = (container.stage != null) ? container.stage.stageWidth  : 1280;
        var sh = (container.stage != null) ? container.stage.stageHeight : 800;
        s.graphics.beginFill(color, 1);
        s.graphics.drawRect(0, 0, sw, sh);
        s.graphics.endFill();
        //s.mouseEnabled = false;
        return s;
    }

    private function _removeOverlay():Void {
        if (_overlay != null) {
            if (_overlay.parent != null) _overlay.parent.removeChild(_overlay);
            _overlay = null;
        }
    }
}
