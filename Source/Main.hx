package;

import haxe.ui.Toolkit;
import org.flashbacks1998.rake.scenes.tests.SceneTestSR01;
import org.flashbacks1998.scenes.SceneManager;
import org.flashbacks1998.scenes.transitions.FadeTransition;
import org.flashbacks1998.debugger.Debugger;
import openfl.display.Sprite;

class Main extends Sprite
{
	public function new()
	{
		super();
 
		Toolkit.init();
		Toolkit.theme = "fall";
 
		addChild(SceneManager.instance);
 
		SceneManager.defaultTransition = new FadeTransition();

		SceneManager.homescene = new SceneTestSR01();
		SceneManager.registerScene("RakeGameMain", SceneManager.homescene);
		SceneManager.gotoHomeScene();
	}
}
