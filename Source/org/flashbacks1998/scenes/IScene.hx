package org.flashbacks1998.scenes;

import openfl.display.Sprite;
import openfl.utils.Future;

interface IScene {
    public function init():Future<IScene>;
    public function dispose():Future<IScene>;
    public function asSprite():Sprite;
}
