package org.flashbacks1998.scenes;

import openfl.display.Sprite;

class Scene extends Sprite implements IScene {

    public function new() {
        super();
    }

    public function init():openfl.utils.Future<IScene> {
        return openfl.utils.Future.withValue(cast this);
    }

    public function dispose():openfl.utils.Future<IScene> {
        return openfl.utils.Future.withValue(cast this);
    }

    public function asSprite():Sprite {
        return this;
    }
}