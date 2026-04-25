package;

import haxe.ui.Toolkit;
import org.flashbacks1998.rake.scenes.tests.SceneTestSR01;
import openfl.events.Event;
import openfl.net.URLRequest;
import openfl.media.Sound;
import openfl.Assets; 
import org.flashbacks1998.debugger.DebuggerConsole;
import org.flashbacks1998.scenes.SceneManager;
import org.flashbacks1998.debugger.Debugger;
import openfl.display.Sprite;

class Main extends Sprite
{
	public function new()
	{
		super();

		// haxeui setup — must run before constructing any haxeui component.
		// Scenes instantiate RakeBtn / SettingsBtn / SettingsTabs, all of which
		// extend haxeui Button / Absolute.
		Toolkit.init();
		Toolkit.theme = "fall";

		SceneManager.homescene = new SceneTestSR01();
		SceneManager.registerScene("RakeGameMain", SceneManager.homescene);
		SceneManager.gotoHomeScene();
		addChild(SceneManager.instance);

	}
}
