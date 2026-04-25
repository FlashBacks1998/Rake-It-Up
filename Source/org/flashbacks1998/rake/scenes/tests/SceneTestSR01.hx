package org.flashbacks1998.rake.scenes.tests;

import motion.Actuate;

import openfl.display.Shape;
import openfl.display.MovieClip;
import openfl.media.SoundChannel;
import org.flashbacks1998.rake.ui.HighScoresWindow;
import io.newgrounds.NGLite.LoginOutcome;
import openfl.utils.Promise;
import openfl.media.SoundTransform;
import org.flashbacks1998.world3d.engine.IRendererEngine.BasicRendererEngineType;
import org.flashbacks1998.world3d.engine.hardware.BasicHardwareEngine;
import org.flashbacks1998.debugger.DebuggerStats;
import org.flashbacks1998.world3d.shader.TextureShader;
import org.flashbacks1998.world3d.geom.primitives.PlaneMeshXZ3D;
import org.flashbacks1998.world3d.geom.primitives.PlaneMeshXY3D;
import org.flashbacks1998.world3d.shader.ShaderPipeline;
import org.flashbacks1998.world3d.shader.MtlShader;
import org.flashbacks1998.world3d.geom.primitives.SphereMesh3D;
import org.flashbacks1998.world3d.engine.software.BasicSoftwareEngine;
import haxe.ds.ObjectMap;

import openfl.media.Sound;
import openfl.Vector;
import openfl.Lib;
import openfl.Assets;
import openfl.events.Event;
import openfl.events.MouseEvent;
import openfl.display.Stage;
import openfl.display.Sprite;
import openfl.geom.Point;
import openfl.geom.Vector3D;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.text.TextFormatAlign;
import openfl.utils.Future;

import org.flashbacks1998.debugger.Debugger;
import org.flashbacks1998.scenes.Scene;
import org.flashbacks1998.util.MathUtil;
import org.flashbacks1998.util.FutureUtil;

import org.flashbacks1998.ui.sliders.SliderUI;
import haxe.ui.components.CheckBox;
import haxe.ui.containers.Absolute;
import haxe.ui.containers.Stack;
import haxe.ui.events.MouseEvent as HxUIMouseEvent;
import haxe.ui.events.UIEvent;
import org.flashbacks1998.rake.ui.HighScoresBtn;
import org.flashbacks1998.rake.ui.RakeBtn;
import org.flashbacks1998.rake.ui.SettingsBtn;
import org.flashbacks1998.rake.ui.SettingsTabs;

import org.flashbacks1998.world3d.World3D;
import org.flashbacks1998.world3d.postprocessing.PostProcessing;
import org.flashbacks1998.world3d.postprocessing.parts.DownscaleShaderPart;
import org.flashbacks1998.world3d.parsers.ObjParser;
import org.flashbacks1998.world3d.optimizers.Entity3DOptimizer;

import org.flashbacks1998.world3d.entity.IEntity3D;
import org.flashbacks1998.world3d.entity.Entity3D;

import org.flashbacks1998.world3d.geom.Mesh3D;
import org.flashbacks1998.world3d.geom.Position3D;

import org.flashbacks1998.world3d.camera.ThirdPersonCamera3D;
import org.flashbacks1998.world3d.camera.controllers.ThirdPersonCamera3DScreenController;

import org.flashbacks1998.world3d.shader.parts.TextureShaderPart;
import org.flashbacks1998.world3d.shader.parts.ColorIntensifierShaderPart;
import org.flashbacks1998.world3d.shader.parts.BayerishDitheringShaderPart;
import org.flashbacks1998.world3d.shader.parts.BayerishDitheringShaderPart.BayerishDitheringType;
import org.flashbacks1998.world3d.shader.parts.BayerishDitheringShaderPart.QuantizeMode;

import org.flashbacks1998.physics3d.Physics3D;
import org.flashbacks1998.physics3d.objects.Physics3DObjectBox;
import org.flashbacks1998.physics3d.objects.Physics3DObjectCylinder;
import org.flashbacks1998.physics3d.events.Physics3DEventReachedSensor;

import org.flashbacks1998.rake.systems.LeafsSystem;
import org.flashbacks1998.newgrounds.Newgrounds;

class SceneTestSR01 extends Scene {
	public var eTree:Entity3D;
	public var ePileOfLeaves:Entity3D;
	public var ePlane:IEntity3D;
	public var eNewRake:Entity3D;

    var world:World3D;
    final spDithering = new BayerishDitheringShaderPart(Sixteen, 4, PerChannel);
    final ppPipeline = new PostProcessing({ parts: Vector.ofArray(cast [new DownscaleShaderPart(.2875, .2875)]) });
    var softwareEngine:BasicSoftwareEngine;
    var hardwareEngine:BasicHardwareEngine;

    public final cameraDistanceMin:Float = 5;
    public final cameraDistanceMax:Float = 35;
    public var cameraDistance:Float = 10;
    public var cameraController:ThirdPersonCamera3DScreenController;
    public var camera:ThirdPersonCamera3D;

    public var score = 1000;
    var cloudSaveTimer:haxe.Timer;

    ///---PHYSICS 3D----------------------------------------------------------------
    public var bodyPileOfLeaves:Physics3DObjectCylinder;
    public var bodyTree:Physics3DObjectCylinder;
    public var physics:Physics3D;

    // Rake physics
    public var bodyRake:Physics3DObjectBox;
    private static final cursorW:Float = 4.0;
    private static final cursorH:Float = 1.0;
    private static final cursorL:Float = 1.0;

    // Rake mouse tracking
    private static var _lastMousePt = new Point();
    private static var _lastHitPos = new Vector3D();

    // Leaf resources
    public var leafsSystem:LeafsSystem;
    private var _mLeaf:Mesh3D;
    private var _spLeavesFalling:ShaderPipeline;
    private var _spLeavesColorOffset:ColorIntensifierShaderPart;
    private var _spPulsingLeavesShader:ShaderPipeline;

    // Spawn timing
    private var _leafSpawnAccum:Float = 0.0;
    private var _leafSpawnInterval:Float = 0.65;

    // Frame timing
    private var _lastTimer:Int = 0;
    private var _lastDt:Float = 0;

    //---STAGE----------------------------------------------------------------------
    public var btnRakeToggle:RakeBtn;
    public var btnSettingsToggle:SettingsBtn;
    public var btnHighScoresToggle:HighScoresBtn;
    var cameraSliderUI:SliderUI;
    private var sprMagnifier:Sprite;
    private var txtScore:TextField;
    private var sprTutorialBackground:Shape;
    private var mcButtons:MovieClip;
    private var mcMouse:MovieClip;
    private var mcZoom:MovieClip;
    // haxeui Stack: toggles between mainScreen (game HUD), settingsScreen
    // (settings panel), and highScoresScreen (leaderboard) via selectedId.
    // Replaces the old nonSettingsUIContainer Sprite + manual visibility.
    private var screenStack:Stack;
    private var tutorialContainer:Sprite;
    private var mainScreen:Absolute;
    private var settingsScreen:Absolute;
    private var highScoresScreen:Absolute;
    private var sprDebugStats:DebuggerStats;
    public var viewSettingsTab:SettingsTabs;
    public var viewHighScores:HighScoresWindow;

    private var _sBackgroundMusic:Sound;
    private var _scBackgroundMusic:SoundChannel;
    private var _sPoints:Array<Sound>;
    private var _stPoints:SoundTransform;

    public function new() {
        super();
    }

    public function initSounds():Future<Dynamic> {
        Debugger.log("initSounds: loading background music and point sounds");
        final futures:Array<Future<Dynamic>> = [];

        // Each load is wrapped in its own Promise that ALWAYS completes, even
        // on error, so a single missing/unsupported asset doesn't fail-fast
        // the whole `FutureUtil.all` chain and leave the scene stuck on the
        // loading screen. Flash rejects the 16kHz background music (needs
        // 11025/22050/44100), so loadSound errors — we log and proceed.
        inline function loadTolerant(id:String, onOk:Sound->Void):Future<Dynamic> {
            final p = new Promise<Dynamic>();
            Assets.loadSound(id)
                .onComplete(s -> {
                    try onOk(s) catch (e:Dynamic) Debugger.log("initSounds: onOk threw for " + id, e);
                    p.complete(null);
                })
                .onError(e -> {
                    Debugger.log("initSounds: load failed for " + id, e);
                    p.complete(null);
                });
            return p.future;
        }

        futures.push(loadTolerant("assets/music/autmn.mp3", s -> {
            Debugger.log("initSounds: background music loaded");
            _sBackgroundMusic = s;
        }));

        _stPoints = new SoundTransform();
        _stPoints.volume = .1;

        _sPoints = new Array<Sound>();
        for (i in 0...5)
            futures.push(loadTolerant("assets/sounds/pointsound" + (i + 1) + ".mp3", s -> {
                Debugger.log("initSounds: point sound loaded, total so far", _sPoints.length + 1);
                _sPoints.push(s);
            }));

        return FutureUtil.all(futures);
    }

    public function onAddedToStage(?e:openfl.events.Event) {
        Debugger.log("onAddedToStage: updating ui and playing background music");
        
        Actuate.tween (tutorialContainer, 1, { alpha: 0 }).delay (8);

        updateUIPosition(); 
 
        if (_sBackgroundMusic != null) 
            _scBackgroundMusic = _sBackgroundMusic.play(0, 0);
    }

    public function initWorld():Future<Any> {
        camera = new ThirdPersonCamera3D(new Position3D(0, 1, 0), cameraDistance, cameraDistance, cameraDistance);
        cameraController = new ThirdPersonCamera3DScreenController(camera);
        cameraController.enabled = true;
        camera.lookAt(0, 0, 0);

        world = new World3D(null, { camera: camera, engineType: software });
        world.postProcessingEnabled = true;
        world.postProcessingPipeline = ppPipeline;

		// Pile of leaves
		final meshObjPOL:Mesh3DAndShaderPair = {
			mesh: new SphereMesh3D(2, 1, 100, 50),
			shader: new MtlShader({bmpData: Assets.getBitmapData("assets/textures/pileovleaves.png")})
		};
        cast(meshObjPOL.shader, MtlShader).parts.push(spDithering);

		ePileOfLeaves = new Entity3D({meshes: Vector.ofArray([meshObjPOL])});
		ePileOfLeaves.position.scaleX = ePileOfLeaves.position.scaleZ = 4;
		ePileOfLeaves.position.x = -8.5;
		ePileOfLeaves.position.z = 8.5;
		world.addChild(ePileOfLeaves);

		// Floor
		final mFloor = new PlaneMeshXZ3D();
        mFloor.renderAttributes = {forceToBack: true};
		final eFloor = new Entity3D({
			meshes: Vector.ofArray(cast [
				{
					mesh: mFloor,
					shader: new TextureShader({
						bmpData: Assets.getBitmapData("assets/textures/floor.png")
					})
				}
			])
		});

		eFloor.position.scaleX = eFloor.position.scaleZ = 15;
		world.addChild(eFloor);

        // Load tree OBJ
        Debugger.log("Loading Treed.obj...");
        final fTreePipeline = Assets.loadText("assets/objects/Treed.obj").then(c -> {
            Debugger.log("Treed.obj loaded ", (c != null ? c.length : -1));
            var parserTree = new ObjParser(c);
            Debugger.log("ObjParser created for Treed.obj, starting parse");
            parserTree.start();
            return parserTree.future;
        }).then(e -> {
            final entities:Vector<IEntity3D> = cast e;

            final eOpt = Entity3DOptimizer.optimizeEntity3Ds(entities, { combineEntity3DMeshes: true });
            eTree = cast eOpt[0];
            cast(eTree.meshes[0].shader, ShaderPipeline).parts.push(spDithering);
            world.addChild(eTree);

            //center physics cylinder for tree collision
            final btree = new Physics3DObjectCylinder(new Position3D(), 3, 1, true);
            physics.addObject(btree);

            return Future.withValue(eTree);
        });

        Debugger.log("Loading Treed.obj...");
        final fTreePipeline = Assets.loadText("assets/objects/rake.obj").then(c -> {
            Debugger.log("Treed.obj loaded ", (c != null ? c.length : -1));
            var parserRake = new ObjParser(c);
            Debugger.log("ObjParser created for Treed.obj, starting parse");
            parserRake.start();
            return parserRake.future;
        }).then(e -> {
            final entities:Vector<IEntity3D> = cast e;

            final eOpt = Entity3DOptimizer.optimizeEntity3Ds(entities, { combineEntity3DMeshes: true });
            eNewRake = cast eOpt[0];
            eNewRake.visible = false; // start hidden until we enter rake mode
            eNewRake.position = bodyRake.position; // share the same Position3D for easy syncing of visual + physics
            eNewRake.position.scaleX = eNewRake.position.scaleY = eNewRake.position.scaleZ = 3;
            world.addChild(eNewRake);

            return Future.withValue(eNewRake);
        });

        // Load rake OBJ
        Debugger.log("Loading rake.obj...");
        
        return FutureUtil.all([fTreePipeline]).then(_ -> Future.withValue(0));
    }

    public function initPhysics():Future<Any> {
        physics = new Physics3D();

        physics.maxWorldX = 15;
        physics.minWorldX = -15;
        physics.maxWorldZ = 15;
        physics.minWorldZ = -15;
        physics.minWorldY = 0;

        // Rake physics body (must exist before rake OBJ future resolves)
        bodyRake = new Physics3DObjectBox(new Position3D(), cursorW, cursorH, cursorL, true);
        bodyRake.isStatic = true;

        // Leaf mesh
        _mLeaf = new PlaneMeshXZ3D();
        _mLeaf.upload(world.engine);

        // Leaf shaders
        final bmpdLeaves = Assets.getBitmapData("assets/textures/leaf.gif");
        final spLeaves = new TextureShaderPart(bmpdLeaves);

        _spLeavesColorOffset = new ColorIntensifierShaderPart(1, 1, 1);

        _spPulsingLeavesShader = new ShaderPipeline({
            parts: Vector.ofArray(cast [spLeaves, _spLeavesColorOffset])
        });
        world.uploadShader(_spPulsingLeavesShader);

        _spLeavesFalling = new ShaderPipeline({
            parts: Vector.ofArray(cast [new TextureShaderPart(bmpdLeaves)])
        });
        world.uploadShader(_spLeavesFalling);

        // Pile of leaves sensor
        bodyPileOfLeaves = new Physics3DObjectCylinder(ePileOfLeaves?.position ?? new Position3D(-8.5, 0, 8.5), 3.5, 15, true);
        bodyPileOfLeaves.isStatic = true;
        bodyPileOfLeaves.isKinematic = false;
        bodyPileOfLeaves.isSensor = true;
        bodyPileOfLeaves.addEventListener(Physics3DEventReachedSensor.TYPE, onLeafSensorReached);
        bodyPileOfLeaves.ignoreGroup.push(bodyRake);
        physics.addObject(bodyPileOfLeaves);

        // Tree body
        bodyTree = new Physics3DObjectCylinder(new Position3D(), 1, 15, true);
        physics.addObject(bodyTree);

        // Build leaf system
        leafsSystem = new LeafsSystem(world, physics, _mLeaf, bodyPileOfLeaves, _spPulsingLeavesShader, _spLeavesFalling, _spLeavesColorOffset);

        // Spawn starter batch
        for (i in 0...10)
            leafsSystem.spawnNewLeaf();

        Debugger.log("LeafsSystem initialized + initial leaves spawned");

        return Future.withValue(physics);
    }

    public function initStage():Future<Stage> {
        // Frame-stack: Stack picks one of two Absolute "frames" at a time via
        // selectedId. `mainScreen` holds the game HUD, `settingsScreen` holds
        // the settings panel. Toggling visibility becomes a 1-line `selectedId`
        // change instead of juggling two Sprite.visible flags.
        screenStack = new Stack();
        screenStack.id = "screenStack";
        addChild(screenStack);

        tutorialContainer = new Sprite(); 

        mainScreen = new Absolute();
        mainScreen.id = "mainScreen";
        mainScreen.percentWidth = 100;
        mainScreen.percentHeight = 100;
        
        mainScreen.addChild(tutorialContainer);

        settingsScreen = new Absolute();
        settingsScreen.id = "settingsScreen";
        settingsScreen.percentWidth = 100;
        settingsScreen.percentHeight = 100;

        highScoresScreen = new Absolute();
        highScoresScreen.id = "highScoresScreen";
        highScoresScreen.percentWidth = 100;
        highScoresScreen.percentHeight = 100;

        // Rake button
        btnRakeToggle = new RakeBtn();
        btnRakeToggle.registerEvent(HxUIMouseEvent.CLICK, onRakeToggleClick);
        mainScreen.addComponent(btnRakeToggle);

        // Settings button
        btnSettingsToggle = new SettingsBtn();
        btnSettingsToggle.registerEvent(HxUIMouseEvent.CLICK, onSettingsToggleClick);
        mainScreen.addComponent(btnSettingsToggle);

        // High scores button
        btnHighScoresToggle = new HighScoresBtn();
        btnHighScoresToggle.registerEvent(HxUIMouseEvent.CLICK, onHighScoresToggleClick);
        mainScreen.addComponent(btnHighScoresToggle);

        // Score text
        txtScore = new TextField();
        txtScore.embedFonts = true;
        txtScore.cacheAsBitmap = true;
        txtScore.mouseEnabled = false;

        var txtScoreTextFormat:TextFormat = new TextFormat();
        txtScoreTextFormat.align = TextFormatAlign.RIGHT;
        txtScoreTextFormat.font = Assets.getFont("assets/fonts/PixelTactical-AWOx.ttf").fontName;
        txtScoreTextFormat.color = 0xFFFFFF;
        txtScoreTextFormat.size = 24;

        txtScore.defaultTextFormat = txtScoreTextFormat;
        txtScore.text = "Score: " + score;
        txtScore.cacheAsBitmap = true;
        // Raw openfl TextField — Absolute is a Sprite so addChild works.
        mainScreen.addChild(txtScore);

        // DebuggerStats overlay (added/removed via settings checkbox)
        sprDebugStats = new DebuggerStats();

        // Camera zoom slider
        cameraSliderUI = new SliderUI(260, 18);
        cameraSliderUI.minValue = cameraDistanceMin;
        cameraSliderUI.maxValue = cameraDistanceMax;
        cameraSliderUI.step = .1;
        cameraSliderUI.value = cameraDistance;
        cameraSliderUI.addEventListener(Event.CHANGE, onSliderValueChange);
        mainScreen.addChild(cameraSliderUI);

        sprMagnifier = new Sprite();
        var mgBmp = new openfl.display.Bitmap(Assets.getBitmapData("assets/textures/icons8-magnifying-glass-64.png"));
        mgBmp.smoothing = true;
        mgBmp.width = mgBmp.height = 50;
        sprMagnifier.addChild(mgBmp);
        mainScreen.addChild(sprMagnifier);

        // Settings tab view
        viewSettingsTab = new SettingsTabs();
        viewSettingsTab.onClose = onSettingsClose;
        // Defaults-on: set selected = true AND update label to match the
        // Enabled/Disabled convention the SettingsTabs change-handler uses.
        viewSettingsTab.enableLeavesPulsingShader.selected = true;
        viewSettingsTab.enableLeavesPulsingShader.text = "Enabled";
        viewSettingsTab.enableTreeDitheringShader.selected = true;
        viewSettingsTab.enableTreeDitheringShader.text = "Enabled";
        viewSettingsTab.enableFPSDebugWindow.registerEvent(UIEvent.CHANGE, onSettingsDebugFPSToggle);
        viewSettingsTab.enableLeavesPulsingShader.registerEvent(UIEvent.CHANGE, onSettingsToggleShaderLeaves);
        viewSettingsTab.enableTreeDitheringShader.registerEvent(UIEvent.CHANGE, onSettingsToggleShaderTree);
        viewSettingsTab.enableHardwareRendering.registerEvent(UIEvent.CHANGE, onSettingsToggleHardwareRendering);
        viewSettingsTab.onBgMusicVolumeChange = onBgMusicVolumeChange;
        viewSettingsTab.onSfxVolumeChange = onSfxVolumeChange;
        settingsScreen.addComponent(viewSettingsTab);

        // High scores window — close button routes back to mainScreen via
        // the same onClose callback pattern SettingsTabs uses.
        viewHighScores = new HighScoresWindow();
        viewHighScores.onClose = onHighScoresClose;
        highScoresScreen.addComponent(viewHighScores);

        // Tutorial Library
        sprTutorialBackground = new Shape();
        tutorialContainer.addChild(sprTutorialBackground);
        tutorialContainer.mouseEnabled = false; // let mouse events pass through to the stage (for rake dragging) while tutorial is visible
        final fAssetsTutorial = Assets.loadLibrary("tutorial").then(_->{ 
            Debugger.log("Tutorial library loaded, instantiating movie clips");
            final fButtons = Assets.loadMovieClip("tutorial:mcTutorialButtons").then(mc->{
                mcButtons = cast mc;
                tutorialContainer.addChild(mcButtons);
                Debugger.log("mcTutorialButtons loaded and added to tutorialContainer");
                return Future.withValue(mcButtons);
            });

            final fMouse = Assets.loadMovieClip("tutorial:mcTutorialMouse").then(mc->{
                mcMouse = cast mc;
                tutorialContainer.addChild(mcMouse);
                Debugger.log("mcTutorialMouse loaded and added to tutorialContainer");
                return Future.withValue(mcMouse);
            });

            final fZoom = Assets.loadMovieClip("tutorial:mcTutorialZoom").then(mc->{
                mcZoom = cast mc;
                tutorialContainer.addChild(mcZoom);
                Debugger.log("mcTutorialZoom loaded and added to tutorialContainer");
                return Future.withValue(mcZoom);
            });

            return FutureUtil.all([fButtons, fMouse, fZoom]).then(_->Future.withValue(tutorialContainer));
        });

        // Wire frames into the stack — main shows first. 
        screenStack.addComponent(mainScreen);
        screenStack.addComponent(settingsScreen);
        screenStack.addComponent(highScoresScreen);
        screenStack.selectedId = "mainScreen";

        //updateUIPosition();

        addEventListener(Event.ADDED_TO_STAGE, onAddedToStage);
        addEventListener(Event.ENTER_FRAME, onEnterFrame);
        Lib.current.stage.addEventListener(Event.RESIZE, onStageResize);
        Lib.current.stage.addEventListener(MouseEvent.MOUSE_WHEEL, onMouseScrollToZoomCamera);

        return FutureUtil.all([fAssetsTutorial]).then(_ -> Future.withValue(Lib.current.stage));
    }

    public function initNewgrounds():Future<Dynamic> {
        Debugger.log("initNewgrounds: initializing Newgrounds");
        final promise:Promise<Dynamic> = new Promise();

        // NG bootstrap is fire-and-forget — scene loading must never hang on
        // it. If the player has no session AND the local runtime has no net
        // access, parts of the NG lib (e.g. `NGLite.getSessionId()` reading
        // `loaderInfo.parameters`) can throw synchronously, which would skip
        // `promise.complete(null)` and leave `FutureUtil.all(...)` waiting
        // forever. Try/catch guarantees the outer future always resolves.
        try {
            Newgrounds.init();
            Newgrounds.login(false, outcome -> {
                if (outcome != SUCCESS) {
                    Debugger.log("initNewgrounds: login failed or skipped, outcome=", outcome);
                    return;
                }
                Debugger.log("initNewgrounds: login successful, loading core data");
                try {
                    Newgrounds.loadCoreData(function() {
                        Debugger.log("initNewgrounds: core data loaded, fetching cloud score");
                        Newgrounds.loadCloudScoreWithCallback(function(savedScore) {
                            Debugger.log("initNewgrounds: cloud score loaded:", savedScore);
                            if (savedScore > score) score = savedScore;
                            if (txtScore != null) txtScore.text = "Score: " + score;

                            if (cloudSaveTimer == null) {
                                Debugger.log("initNewgrounds: starting 5s cloud-save timer");
                                cloudSaveTimer = new haxe.Timer(5000);
                                cloudSaveTimer.run = function() {
                                    Newgrounds.saveBestCloudScore(score);
                                };
                            }
                        });
                    });
                } catch (e:Dynamic) {
                    Debugger.log("initNewgrounds: loadCoreData chain threw", e);
                }
            });
        } catch (e:Dynamic) {
            Debugger.log("initNewgrounds: NG bootstrap threw", e);
        }

        promise.complete(null);

        return promise.future;
    }

    public override function init() {
        Debugger.log("Setting up the rake game thingy i havent named it yet");

        final futureWorld = initWorld();
        final futurePhysics = initPhysics();
        final futureStage = initStage();
        final futureSounds = initSounds();
        final futureNG = initNewgrounds();
        final futures:Array<Future<Any>> = [super.init(), futureWorld, futurePhysics, futureStage, futureSounds, futureNG];

        return FutureUtil.all(futures).then(_ -> Future.withValue(cast this));
    }

    public function updateUIPosition() {
        // Size the frame-stack to fill the stage so mainScreen / settingsScreen
        // (percentWidth/Height = 100) follow the stage through resize.
        screenStack.width  = Lib.current.stage.stageWidth;
        screenStack.height = Lib.current.stage.stageHeight;

        // Inside an Absolute container, haxeui components position via .left/.top.
        // Setting .x/.y directly gets overridden by the Absolute's layout pass
        // (which reads the internal _left/_top — defaults to 0 if we didn't set them).
        btnRakeToggle.left = 8;
        btnRakeToggle.top  = 16;

        btnSettingsToggle.left = 8;
        btnSettingsToggle.top  = 16 + 72 + 16;

        // High scores button — same margin pattern, stacked below settings.
        // top = rake.top + (rake.height + gap) + (settings.height + gap)
        //     = 16 + 88 + 88 = 192
        btnHighScoresToggle.left = 8;
        btnHighScoresToggle.top  = 16 + 72 + 16 + 72 + 16;

        txtScore.width = 250;
        txtScore.x = Lib.current.stage.stageWidth - txtScore.width - 8;
        txtScore.y = 4;

        sprDebugStats.x = 8;
        sprDebugStats.y = Lib.current.stage.stageHeight - sprDebugStats.height - 8;

        cameraSliderUI.x = Lib.current.stage.stageWidth - cameraSliderUI.barWidth - 12;
        cameraSliderUI.y = (Lib.current.stage.stageHeight - cameraSliderUI.barHeight) - 24;

        sprMagnifier.x = cameraSliderUI.x - sprMagnifier.width - 12;
        sprMagnifier.y = cameraSliderUI.y + (cameraSliderUI.barHeight - sprMagnifier.height) / 2;

        viewSettingsTab.width = Lib.current.stage.stageWidth * .9;
        viewSettingsTab.height = Lib.current.stage.stageHeight * .9;
        // .left/.top (not .x/.y): viewSettingsTab is inside the settingsScreen
        // Absolute container; same layout-override issue as the buttons above.
        viewSettingsTab.left = (Lib.current.stage.stageWidth  - viewSettingsTab.width)  / 2;
        viewSettingsTab.top  = (Lib.current.stage.stageHeight - viewSettingsTab.height) / 2;
        // No viewSettingsTab.hidden = true here — Stack.selectedId="mainScreen"
        // in initStage already hides the settingsScreen frame (which contains
        // viewSettingsTab) until the user opens settings.

        // High scores window — same centered-90%-of-stage layout.
        viewHighScores.width  = Lib.current.stage.stageWidth  * .9;
        viewHighScores.height = Lib.current.stage.stageHeight * .9;
        viewHighScores.left = (Lib.current.stage.stageWidth  - viewHighScores.width)  / 2;
        viewHighScores.top  = (Lib.current.stage.stageHeight - viewHighScores.height) / 2;


        sprTutorialBackground.graphics.clear();
        sprTutorialBackground.graphics.beginFill(0xDBDBDB, 0.75);
        sprTutorialBackground.graphics.drawRect(0, 0, Lib.current.stage.stageWidth, Lib.current.stage.stageHeight);
        sprTutorialBackground.graphics.endFill();

        // Jeesus i need a better layout system 
        mcButtons.x = 96;
        mcButtons.y = 16;
        mcButtons.scaleX = mcButtons.scaleY = 0.8;

        mcZoom.x = sprMagnifier.x;
        mcZoom.y = sprMagnifier.y - 90;
        mcZoom.scaleX = mcZoom.scaleY = 0.83;

        mcMouse.x = (Lib.current.stage.stageWidth - mcMouse.width) / 2;
        mcMouse.y = (Lib.current.stage.stageHeight - mcMouse.height) / 2;
    }

    public function updateCameraDistance(distance:Float) {
        cameraDistance = MathUtil.clamp(distance, cameraDistanceMin, cameraDistanceMax);
        camera.radiusX = camera.radiusY = camera.radiusZ = cameraDistance;
    }

    public function onSliderValueChange(event:Event) {
        updateCameraDistance(cameraSliderUI.value);
    }

    public function onMouseScrollToZoomCamera(e:MouseEvent) {
        final delta = e.delta;
        cameraDistance -= delta * 0.1;
        cameraDistance = MathUtil.clamp(cameraDistance, cameraDistanceMin, cameraDistanceMax);
        cameraSliderUI.value = cameraDistance;
        updateCameraDistance(cameraDistance);
    }

    public function onRakeToggleClick(e:HxUIMouseEvent) {
        final rakeMode = (btnRakeToggle.state != Rake);

        Debugger.log("Rake mode toggled, new state: ", rakeMode);

        cameraController.enabled = !rakeMode;

        // De-dupe listener
        Lib.current.stage.removeEventListener(MouseEvent.MOUSE_MOVE, onMouseMoveToUpdateRakePosition);

        if (rakeMode) {
            Debugger.log("Enabling rake mode: showing rake and adding physics body");

            physics.addObject(bodyRake);

            if (world != null && eNewRake != null)
                eNewRake.visible = true;

            Lib.current.stage.addEventListener(MouseEvent.MOUSE_MOVE, onMouseMoveToUpdateRakePosition);
        } else {
            Debugger.log("Disabling rake mode: hiding rake and removing physics body");
            physics.removeObject(bodyRake);

            if (world != null && eNewRake != null)
                eNewRake.visible = false;
        }
    }

    public function onMouseMoveToUpdateRakePosition(e:Event) {
        final mx = Lib.current.stage.mouseX;
        final my = Lib.current.stage.mouseY;

        // Early out if the mouse hasn't moved
        if (_lastMousePt.x == mx && _lastMousePt.y == my)
            return;

        // Build ray from cursor and intersect with ground plane (y = 0)
        final vw = (world != null) ? world.width : Lib.current.stage.stageWidth;
        final vh = (world != null) ? world.height : Lib.current.stage.stageHeight;

        final ray = Physics3D.getCursorRaycastInWorldspace(mx, my, vw, vh, camera);
        final hit = Physics3D.getIntersectionWithPlaneY(ray, 0);
        if (hit == null) {
            _lastMousePt.setTo(mx, my);
            return;
        }

        // Clamp inside physics world bounds (keeping the box fully within)
        final halfW = cursorW * 0.5;
        final halfL = cursorL * 0.5;

        final newX = MathUtil.clamp(hit.x, physics.minWorldX + halfW, physics.maxWorldX - halfW);
        final newZ = MathUtil.clamp(hit.z, physics.minWorldZ + halfL, physics.maxWorldZ - halfL);

        // Move the shared Position3D (visual + physics)
        final p = bodyRake.position;
        p.x = newX;
        p.y = cursorH * 0.5; // sit on ground
        p.z = newZ;

        // Smoothly rotate to face movement direction
        final dx = _lastHitPos.x - newX;
        final dz = _lastHitPos.z - newZ;
        final move2 = dx * dx + dz * dz;
        if (move2 > 1e-6) {
            final desiredYaw = Math.atan2(dx, dz) * 180.0 / Math.PI;
            final currYaw = p.yaw;
            final delta = MathUtil.wrap180(desiredYaw - currYaw);

            var maxTurnPerFrame = 12.0;
            p.yaw = MathUtil.wrap180(currYaw + MathUtil.clamp(delta, -maxTurnPerFrame, maxTurnPerFrame));
        }

        _lastHitPos.setTo(newX, hit.y, newZ);
        _lastMousePt.setTo(mx, my);
    }

    public function onSettingsViewToggle(visible:Bool) {
        if (visible == true) {
            cameraController.enabled = false;
        } else {
            cameraController.enabled = true;
        }

        screenStack.selectedId = visible ? "settingsScreen" : "mainScreen";
    }

    public function onSettingsToggleClick(e:HxUIMouseEvent) {
        onSettingsViewToggle(true);
    }

    public function onSettingsClose():Void {
        onSettingsViewToggle(false);
    }

    public function onHighScoresViewToggle(visible:Bool) {
        if (visible == true) {
            cameraController.enabled = false;
            // Refresh on every open so a late-arriving login / loadCoreData
            // response shows up without re-instantiating the window.
            viewHighScores.update();
        } else {
            cameraController.enabled = true;
        }

        screenStack.selectedId = visible ? "highScoresScreen" : "mainScreen";
    }

    public function onHighScoresToggleClick(e:HxUIMouseEvent) {
        onHighScoresViewToggle(true);
    }

    public function onHighScoresClose():Void {
        onHighScoresViewToggle(false);
    }

    public function onSettingsDebugFPSToggle(event:UIEvent) {
        final selected = cast(event.target, CheckBox).selected;
        if (selected == true && !Lib.current.stage.contains(sprDebugStats)) {
            Lib.current.stage.addChild(sprDebugStats);
        } else if (selected == false && Lib.current.stage.contains(sprDebugStats)) {
            Lib.current.stage.removeChild(sprDebugStats);
        }
    }

    public function onSettingsToggleShaderTree(event:UIEvent) {
        // TODO: implement tree dithering shader toggle
    }

    public function onSettingsToggleHardwareRendering(event:UIEvent) {
        final selected = cast(event.target, CheckBox).selected;
        if (selected == true) {
            world.engineType = BasicRendererEngineType.hardware;
        } else {
            world.engineType = BasicRendererEngineType.software;
        }
    }

    public function onSettingsToggleShaderLeaves(event:UIEvent) {
        // TODO: implement leaves pulsing shader toggle
    }

    public function onBgMusicVolumeChange(volume:Float):Void {
        if (_scBackgroundMusic == null) return;
        // SoundChannel.soundTransform is a snapshot — must reassign to apply.
        final t = _scBackgroundMusic.soundTransform;
        t.volume = volume;
        _scBackgroundMusic.soundTransform = t;
    }

    public function onSfxVolumeChange(volume:Float):Void {
        if (_stPoints == null) return;
        _stPoints.volume = volume;
    }

    public function onLeafSensorReached(e:Physics3DEventReachedSensor) {
        score += 100;
        txtScore.text = "Score: " + score;
        Debugger.log("onLeafSensorReached: score now", score);

        if (_sPoints != null && _sPoints.length > 0) {
            final rand = Math.floor(Math.random() * _sPoints.length);
            _sPoints[rand].play(0,0,_stPoints);
        }
    }

    public function updateWorldBackgroundColor():Void {
        if (world == null)
            return;

        final t = Lib.getTimer() / 1000.0;
        final factor = (Math.sin(t) + 1.0) / 2.0;

        final color1r = 99;
        final color1g = 58;
        final color1b = 0;
        final color2r = 147;
        final color2g = 78;
        final color2b = 0;

        world.bgColorR = (color1r + (color2r - color1r) * factor) / 255.0;
        world.bgColorG = (color1g + (color2g - color1g) * factor) / 255.0;
        world.bgColorB = (color1b + (color2b - color1b) * factor) / 255.0;
    }

    public function onStageResize(e:Event) {
        updateUIPosition();
        world.resize(Lib.current.stage.stageWidth, Lib.current.stage.stageHeight);
    }

    public function onEnterFrame(e:Event) {
        Debugger.reset();

        // Frame dt
        var now = Lib.getTimer();
        _lastDt = (_lastTimer == 0) ? 0 : (now - _lastTimer) / 1000.0;
        _lastTimer = now;

        // Update falling leaves + physics — timed separately so the overlay
        // can distinguish leaf system work from actual physics step cost.
        if (_lastDt > 0) {
            final leavesStart = Lib.getTimer();
            if (leafsSystem != null) {
                _leafSpawnAccum += _lastDt;
                var guard = 0;
                final fps = 1.0 / _lastDt;
                while (_leafSpawnAccum >= _leafSpawnInterval && guard < 3) {
                    _leafSpawnAccum -= _leafSpawnInterval;
                    if (fps >= 16) leafsSystem.spawnNewLeaf(true);
                    guard++;
                }

                leafsSystem.update(_lastDt);
                leafsSystem.updateColor();
            }
            Debugger.leavesTTR = Lib.getTimer() - leavesStart;

            final physicsStart = Lib.getTimer();
            if (physics != null) {
                physics.step(_lastDt);
            }
            Debugger.physicsTTR = Lib.getTimer() - physicsStart;
        }

        var wtrstart = Lib.getTimer();
        updateWorldBackgroundColor();

        world.render();
        var wtrend = Lib.getTimer();
        Debugger.worldTTR = wtrend - wtrstart;
    }
}
