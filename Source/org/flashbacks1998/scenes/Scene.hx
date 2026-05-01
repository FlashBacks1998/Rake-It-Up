package org.flashbacks1998.scenes;

import openfl.Lib;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.utils.Future;

class Scene extends Sprite implements IScene {

    public function new() {
        super();
 
        addEventListener(Event.ADDED_TO_STAGE, _onAddedToStage);
        addEventListener(Event.REMOVED_FROM_STAGE, _onRemovedFromStage);
    }
 
    private function _onAddedToStage(e:Event):Void {
        Lib.current.stage.addEventListener(Event.RESIZE, _onStageResize);
        onAddedToStage(e);
    }

    private function _onRemovedFromStage(e:Event):Void { 
        if (Lib.current.stage != null) Lib.current.stage.removeEventListener(Event.RESIZE, _onStageResize);
        onRemovedFromStage(e);
    }

    private function _onStageResize(e:Event):Void {
        onStageResize(e);
    }
 
    public function onAddedToStage(e:Event):Void {}
    public function onRemovedFromStage(e:Event):Void {}
    public function onStageResize(e:Event):Void {}
 
    public function init():Future<IScene> {
        return Future.withValue(cast this);
    }

    public function dispose():Future<IScene> {
        return Future.withValue(cast this);
    }

    public function asSprite():Sprite {
        return this;
    }
}
