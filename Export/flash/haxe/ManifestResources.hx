package;

import haxe.io.Bytes;
import haxe.io.Path;
import lime.utils.AssetBundle;
import lime.utils.AssetLibrary;
import lime.utils.AssetManifest;
import lime.utils.Assets;

#if sys
import sys.FileSystem;
#end

#if disable_preloader_assets
@:dox(hide) class ManifestResources {
	public static var preloadLibraries:Array<Dynamic>;
	public static var preloadLibraryNames:Array<String>;
	public static var rootPath:String;

	public static function init (config:Dynamic):Void {
		preloadLibraries = new Array ();
		preloadLibraryNames = new Array ();
	}
}
#else
@:access(lime.utils.Assets)


@:keep @:dox(hide) class ManifestResources {


	public static var preloadLibraries:Array<AssetLibrary>;
	public static var preloadLibraryNames:Array<String>;
	public static var rootPath:String;


	public static function init (config:Dynamic):Void {

		preloadLibraries = new Array ();
		preloadLibraryNames = new Array ();

		rootPath = null;

		if (config != null && Reflect.hasField (config, "rootPath")) {

			rootPath = Reflect.field (config, "rootPath");

			if(!StringTools.endsWith (rootPath, "/")) {

				rootPath += "/";

			}

		}

		if (rootPath == null) {

			#if (ios || tvos || webassembly)
			rootPath = "assets/";
			#elseif android
			rootPath = "";
			#elseif (console || sys)
			rootPath = lime.system.System.applicationDirectory;
			#else
			rootPath = "./";
			#end

		}

		#if (openfl && !flash && !display)
		openfl.text.Font.registerFont (__ASSET__OPENFL__assets_fonts_freebooterupdated_ttf);
		openfl.text.Font.registerFont (__ASSET__OPENFL__assets_fonts_pixeltactical_awox_otf);
		openfl.text.Font.registerFont (__ASSET__OPENFL__assets_fonts_pixeltactical_awox_ttf);
		
		#end

		var data, manifest, library, bundle;

		data = '{"name":null,"assets":"aoy4:sizei1956y4:typey6:BINARYy9:classNamey27:__ASSET__assets_buttons_swfy2:idy20:assets%2Fbuttons.swfgoR0i102764R1y4:FONTR3y43:__ASSET__assets_fonts_freebooterupdated_ttfR5y38:assets%2Ffonts%2FFreebooterUpdated.ttfgoR0i14608R1R7R3y44:__ASSET__assets_fonts_pixeltactical_awox_otfR5y39:assets%2Ffonts%2FPixelTactical-AWOx.otfgoR0i21036R1R7R3y44:__ASSET__assets_fonts_pixeltactical_awox_ttfR5y39:assets%2Ffonts%2FPixelTactical-AWOx.ttfgoR0i1820380R1y5:MUSICR3y31:__ASSET__assets_music_autmn_mp3R5y26:assets%2Fmusic%2Fautmn.mp3goR0i4368R1R2R3y27:__ASSET__assets_ng_logo_swfR5y20:assets%2Fng_logo.swfgoR0i586R1y4:TEXTR3y34:__ASSET__assets_objects_grably_mtlR5y29:assets%2Fobjects%2Fgrably.mtlgoR0i59078R1R19R3y34:__ASSET__assets_objects_grably_objR5y29:assets%2Fobjects%2Fgrably.objgoR0i177R1R19R3y53:__ASSET__assets_objects_green_maple_leaf_low_poly_mtlR5y48:assets%2Fobjects%2Fgreen_maple_leaf_low-poly.mtlgoR0i2409R1R19R3y53:__ASSET__assets_objects_green_maple_leaf_low_poly_objR5y48:assets%2Fobjects%2Fgreen_maple_leaf_low-poly.objgoR0i549R1R19R3y41:__ASSET__assets_objects_low_poly_rake_mtlR5y36:assets%2Fobjects%2Flow-poly_rake.mtlgoR0i33263R1R19R3y41:__ASSET__assets_objects_low_poly_rake_objR5y36:assets%2Fobjects%2Flow-poly_rake.objgoR0i589R1R19R3y32:__ASSET__assets_objects_rake_mtlR5y27:assets%2Fobjects%2Frake.mtlgoR0i37639R1R19R3y32:__ASSET__assets_objects_rake_objR5y27:assets%2Fobjects%2Frake.objgoR0i318R1R19R3y33:__ASSET__assets_objects_treed_mtlR5y28:assets%2Fobjects%2FTreed.mtlgoR0i24611R1R19R3y33:__ASSET__assets_objects_treed_objR5y28:assets%2Fobjects%2FTreed.objgoR0i3328R1R14R3y38:__ASSET__assets_sounds_pointsound1_mp3R5y33:assets%2Fsounds%2Fpointsound1.mp3goR0i2494R1R14R3y38:__ASSET__assets_sounds_pointsound2_mp3R5y33:assets%2Fsounds%2Fpointsound2.mp3goR0i3328R1R14R3y38:__ASSET__assets_sounds_pointsound3_mp3R5y33:assets%2Fsounds%2Fpointsound3.mp3goR0i2546R1R14R3y38:__ASSET__assets_sounds_pointsound4_mp3R5y33:assets%2Fsounds%2Fpointsound4.mp3goR0i4163R1R14R3y38:__ASSET__assets_sounds_pointsound5_mp3R5y33:assets%2Fsounds%2Fpointsound5.mp3goR0i782R1y5:IMAGER3y36:__ASSET__assets_textures_default_pngR5y31:assets%2Ftextures%2Fdefault.pnggoR0i11266R1R50R3y34:__ASSET__assets_textures_floor_pngR5y29:assets%2Ftextures%2Ffloor.pnggoR0i591R1R50R3y49:__ASSET__assets_textures_icons8_directions_64_pngR5y44:assets%2Ftextures%2Ficons8-directions-64.pnggoR0i1422R1R50R3y55:__ASSET__assets_textures_icons8_magnifying_glass_64_pngR5y50:assets%2Ftextures%2Ficons8-magnifying-glass-64.pnggoR0i1582R1R50R3y37:__ASSET__assets_textures_lambert1_gifR5y32:assets%2Ftextures%2Flambert1.gifgoR0i1351R1R50R3y33:__ASSET__assets_textures_leaf_gifR5y28:assets%2Ftextures%2Fleaf.gifgoR0i562R1R50R3y40:__ASSET__assets_textures_palletcolor_pngR5y35:assets%2Ftextures%2FpalletColor.pnggoR0i8988R1R50R3y41:__ASSET__assets_textures_pileovleaves_pngR5y36:assets%2Ftextures%2Fpileovleaves.pnggoR0i960R1R50R3y33:__ASSET__assets_textures_rake_gifR5y28:assets%2Ftextures%2Frake.gifgoR0i1923R1R50R3y37:__ASSET__assets_textures_settings_gifR5y32:assets%2Ftextures%2Fsettings.gifgoR0i4527R1R50R3y37:__ASSET__assets_textures_settings_pngR5y32:assets%2Ftextures%2Fsettings.pnggoR0i104116R1R50R3y39:__ASSET__assets_textures_treeleaves_jpgR5y34:assets%2Ftextures%2Ftreeleaves.jpggoR0i1405R1R50R3y35:__ASSET__assets_textures_trophy_pngR5y30:assets%2Ftextures%2Ftrophy.pnggoR0i20197R1R50R3y65:__ASSET__assets_textures_tr_01_stem_autumn_001_mat_base_color_gifR5y60:assets%2Ftextures%2FTr_01_Stem_autumn_001_mat_Base_color.gifgoR0i10603R1R2R3y23:__ASSET__assets_tut_swfR5y16:assets%2Ftut.swfgh","rootPath":null,"version":2,"libraryArgs":[],"libraryType":null}';
		manifest = AssetManifest.parse (data, rootPath);
		library = AssetLibrary.fromManifest (manifest);
		Assets.registerLibrary ("default", library);
		

		library = Assets.getLibrary ("default");
		if (library != null) preloadLibraries.push (library);
		else preloadLibraryNames.push ("default");
		

	}


}

#if !display
#if flash

@:keep @:bind @:noCompletion #if display private #end class __ASSET__assets_buttons_swf extends flash.utils.ByteArray { }
@:keep @:bind @:noCompletion #if display private #end class __ASSET__assets_fonts_freebooterupdated_ttf extends flash.text.Font { }
@:keep @:bind @:noCompletion #if display private #end class __ASSET__assets_fonts_pixeltactical_awox_otf extends flash.text.Font { }
@:keep @:bind @:noCompletion #if display private #end class __ASSET__assets_fonts_pixeltactical_awox_ttf extends flash.text.Font { }
@:keep @:bind @:noCompletion #if display private #end class __ASSET__assets_music_autmn_mp3 extends flash.media.Sound { }
@:keep @:bind @:noCompletion #if display private #end class __ASSET__assets_ng_logo_swf extends flash.utils.ByteArray { }
@:keep @:bind @:noCompletion #if display private #end class __ASSET__assets_objects_grably_mtl extends flash.utils.ByteArray { }
@:keep @:bind @:noCompletion #if display private #end class __ASSET__assets_objects_grably_obj extends flash.utils.ByteArray { }
@:keep @:bind @:noCompletion #if display private #end class __ASSET__assets_objects_green_maple_leaf_low_poly_mtl extends flash.utils.ByteArray { }
@:keep @:bind @:noCompletion #if display private #end class __ASSET__assets_objects_green_maple_leaf_low_poly_obj extends flash.utils.ByteArray { }
@:keep @:bind @:noCompletion #if display private #end class __ASSET__assets_objects_low_poly_rake_mtl extends flash.utils.ByteArray { }
@:keep @:bind @:noCompletion #if display private #end class __ASSET__assets_objects_low_poly_rake_obj extends flash.utils.ByteArray { }
@:keep @:bind @:noCompletion #if display private #end class __ASSET__assets_objects_rake_mtl extends flash.utils.ByteArray { }
@:keep @:bind @:noCompletion #if display private #end class __ASSET__assets_objects_rake_obj extends flash.utils.ByteArray { }
@:keep @:bind @:noCompletion #if display private #end class __ASSET__assets_objects_treed_mtl extends flash.utils.ByteArray { }
@:keep @:bind @:noCompletion #if display private #end class __ASSET__assets_objects_treed_obj extends flash.utils.ByteArray { }
@:keep @:bind @:noCompletion #if display private #end class __ASSET__assets_sounds_pointsound1_mp3 extends flash.media.Sound { }
@:keep @:bind @:noCompletion #if display private #end class __ASSET__assets_sounds_pointsound2_mp3 extends flash.media.Sound { }
@:keep @:bind @:noCompletion #if display private #end class __ASSET__assets_sounds_pointsound3_mp3 extends flash.media.Sound { }
@:keep @:bind @:noCompletion #if display private #end class __ASSET__assets_sounds_pointsound4_mp3 extends flash.media.Sound { }
@:keep @:bind @:noCompletion #if display private #end class __ASSET__assets_sounds_pointsound5_mp3 extends flash.media.Sound { }
@:keep @:bind @:noCompletion #if display private #end class __ASSET__assets_textures_default_png extends flash.display.BitmapData { public function new () { super (0, 0, true, 0); } }
@:keep @:bind @:noCompletion #if display private #end class __ASSET__assets_textures_floor_png extends flash.display.BitmapData { public function new () { super (0, 0, true, 0); } }
@:keep @:bind @:noCompletion #if display private #end class __ASSET__assets_textures_icons8_directions_64_png extends flash.display.BitmapData { public function new () { super (0, 0, true, 0); } }
@:keep @:bind @:noCompletion #if display private #end class __ASSET__assets_textures_icons8_magnifying_glass_64_png extends flash.display.BitmapData { public function new () { super (0, 0, true, 0); } }
@:keep @:bind @:noCompletion #if display private #end class __ASSET__assets_textures_lambert1_gif extends flash.display.BitmapData { public function new () { super (0, 0, true, 0); } }
@:keep @:bind @:noCompletion #if display private #end class __ASSET__assets_textures_leaf_gif extends flash.display.BitmapData { public function new () { super (0, 0, true, 0); } }
@:keep @:bind @:noCompletion #if display private #end class __ASSET__assets_textures_palletcolor_png extends flash.display.BitmapData { public function new () { super (0, 0, true, 0); } }
@:keep @:bind @:noCompletion #if display private #end class __ASSET__assets_textures_pileovleaves_png extends flash.display.BitmapData { public function new () { super (0, 0, true, 0); } }
@:keep @:bind @:noCompletion #if display private #end class __ASSET__assets_textures_rake_gif extends flash.display.BitmapData { public function new () { super (0, 0, true, 0); } }
@:keep @:bind @:noCompletion #if display private #end class __ASSET__assets_textures_settings_gif extends flash.display.BitmapData { public function new () { super (0, 0, true, 0); } }
@:keep @:bind @:noCompletion #if display private #end class __ASSET__assets_textures_settings_png extends flash.display.BitmapData { public function new () { super (0, 0, true, 0); } }
@:keep @:bind @:noCompletion #if display private #end class __ASSET__assets_textures_treeleaves_jpg extends flash.display.BitmapData { public function new () { super (0, 0, true, 0); } }
@:keep @:bind @:noCompletion #if display private #end class __ASSET__assets_textures_trophy_png extends flash.display.BitmapData { public function new () { super (0, 0, true, 0); } }
@:keep @:bind @:noCompletion #if display private #end class __ASSET__assets_textures_tr_01_stem_autumn_001_mat_base_color_gif extends flash.display.BitmapData { public function new () { super (0, 0, true, 0); } }
@:keep @:bind @:noCompletion #if display private #end class __ASSET__assets_tut_swf extends flash.utils.ByteArray { }
@:keep @:bind @:noCompletion #if display private #end class __ASSET__manifest_default_json extends flash.utils.ByteArray { }


#elseif (desktop || cpp)

@:keep @:file("Assets/buttons.swf") @:noCompletion #if display private #end class __ASSET__assets_buttons_swf extends haxe.io.Bytes {}
@:keep @:font("Assets/fonts/FreebooterUpdated.ttf") @:noCompletion #if display private #end class __ASSET__assets_fonts_freebooterupdated_ttf extends lime.text.Font {}
@:keep @:font("Assets/fonts/PixelTactical-AWOx.otf") @:noCompletion #if display private #end class __ASSET__assets_fonts_pixeltactical_awox_otf extends lime.text.Font {}
@:keep @:font("Assets/fonts/PixelTactical-AWOx.ttf") @:noCompletion #if display private #end class __ASSET__assets_fonts_pixeltactical_awox_ttf extends lime.text.Font {}
@:keep @:file("Assets/music/autmn.mp3") @:noCompletion #if display private #end class __ASSET__assets_music_autmn_mp3 extends haxe.io.Bytes {}
@:keep @:file("Assets/ng_logo.swf") @:noCompletion #if display private #end class __ASSET__assets_ng_logo_swf extends haxe.io.Bytes {}
@:keep @:file("Assets/objects/grably.mtl") @:noCompletion #if display private #end class __ASSET__assets_objects_grably_mtl extends haxe.io.Bytes {}
@:keep @:file("Assets/objects/grably.obj") @:noCompletion #if display private #end class __ASSET__assets_objects_grably_obj extends haxe.io.Bytes {}
@:keep @:file("Assets/objects/green_maple_leaf_low-poly.mtl") @:noCompletion #if display private #end class __ASSET__assets_objects_green_maple_leaf_low_poly_mtl extends haxe.io.Bytes {}
@:keep @:file("Assets/objects/green_maple_leaf_low-poly.obj") @:noCompletion #if display private #end class __ASSET__assets_objects_green_maple_leaf_low_poly_obj extends haxe.io.Bytes {}
@:keep @:file("Assets/objects/low-poly_rake.mtl") @:noCompletion #if display private #end class __ASSET__assets_objects_low_poly_rake_mtl extends haxe.io.Bytes {}
@:keep @:file("Assets/objects/low-poly_rake.obj") @:noCompletion #if display private #end class __ASSET__assets_objects_low_poly_rake_obj extends haxe.io.Bytes {}
@:keep @:file("Assets/objects/rake.mtl") @:noCompletion #if display private #end class __ASSET__assets_objects_rake_mtl extends haxe.io.Bytes {}
@:keep @:file("Assets/objects/rake.obj") @:noCompletion #if display private #end class __ASSET__assets_objects_rake_obj extends haxe.io.Bytes {}
@:keep @:file("Assets/objects/Treed.mtl") @:noCompletion #if display private #end class __ASSET__assets_objects_treed_mtl extends haxe.io.Bytes {}
@:keep @:file("Assets/objects/Treed.obj") @:noCompletion #if display private #end class __ASSET__assets_objects_treed_obj extends haxe.io.Bytes {}
@:keep @:file("Assets/sounds/pointsound1.mp3") @:noCompletion #if display private #end class __ASSET__assets_sounds_pointsound1_mp3 extends haxe.io.Bytes {}
@:keep @:file("Assets/sounds/pointsound2.mp3") @:noCompletion #if display private #end class __ASSET__assets_sounds_pointsound2_mp3 extends haxe.io.Bytes {}
@:keep @:file("Assets/sounds/pointsound3.mp3") @:noCompletion #if display private #end class __ASSET__assets_sounds_pointsound3_mp3 extends haxe.io.Bytes {}
@:keep @:file("Assets/sounds/pointsound4.mp3") @:noCompletion #if display private #end class __ASSET__assets_sounds_pointsound4_mp3 extends haxe.io.Bytes {}
@:keep @:file("Assets/sounds/pointsound5.mp3") @:noCompletion #if display private #end class __ASSET__assets_sounds_pointsound5_mp3 extends haxe.io.Bytes {}
@:keep @:image("Assets/textures/default.png") @:noCompletion #if display private #end class __ASSET__assets_textures_default_png extends lime.graphics.Image {}
@:keep @:image("Assets/textures/floor.png") @:noCompletion #if display private #end class __ASSET__assets_textures_floor_png extends lime.graphics.Image {}
@:keep @:image("Assets/textures/icons8-directions-64.png") @:noCompletion #if display private #end class __ASSET__assets_textures_icons8_directions_64_png extends lime.graphics.Image {}
@:keep @:image("Assets/textures/icons8-magnifying-glass-64.png") @:noCompletion #if display private #end class __ASSET__assets_textures_icons8_magnifying_glass_64_png extends lime.graphics.Image {}
@:keep @:image("Assets/textures/lambert1.gif") @:noCompletion #if display private #end class __ASSET__assets_textures_lambert1_gif extends lime.graphics.Image {}
@:keep @:image("Assets/textures/leaf.gif") @:noCompletion #if display private #end class __ASSET__assets_textures_leaf_gif extends lime.graphics.Image {}
@:keep @:image("Assets/textures/palletColor.png") @:noCompletion #if display private #end class __ASSET__assets_textures_palletcolor_png extends lime.graphics.Image {}
@:keep @:image("Assets/textures/pileovleaves.png") @:noCompletion #if display private #end class __ASSET__assets_textures_pileovleaves_png extends lime.graphics.Image {}
@:keep @:image("Assets/textures/rake.gif") @:noCompletion #if display private #end class __ASSET__assets_textures_rake_gif extends lime.graphics.Image {}
@:keep @:image("Assets/textures/settings.gif") @:noCompletion #if display private #end class __ASSET__assets_textures_settings_gif extends lime.graphics.Image {}
@:keep @:image("Assets/textures/settings.png") @:noCompletion #if display private #end class __ASSET__assets_textures_settings_png extends lime.graphics.Image {}
@:keep @:image("Assets/textures/treeleaves.jpg") @:noCompletion #if display private #end class __ASSET__assets_textures_treeleaves_jpg extends lime.graphics.Image {}
@:keep @:image("Assets/textures/trophy.png") @:noCompletion #if display private #end class __ASSET__assets_textures_trophy_png extends lime.graphics.Image {}
@:keep @:image("Assets/textures/Tr_01_Stem_autumn_001_mat_Base_color.gif") @:noCompletion #if display private #end class __ASSET__assets_textures_tr_01_stem_autumn_001_mat_base_color_gif extends lime.graphics.Image {}
@:keep @:file("Assets/tut.swf") @:noCompletion #if display private #end class __ASSET__assets_tut_swf extends haxe.io.Bytes {}
@:keep @:file("") @:noCompletion #if display private #end class __ASSET__manifest_default_json extends haxe.io.Bytes {}



#else

@:keep @:expose('__ASSET__assets_fonts_freebooterupdated_ttf') @:noCompletion #if display private #end class __ASSET__assets_fonts_freebooterupdated_ttf extends lime.text.Font { public function new () { #if !html5 __fontPath = "assets/fonts/FreebooterUpdated.ttf"; #else ascender = null; descender = null; height = null; numGlyphs = null; underlinePosition = null; underlineThickness = null; unitsPerEM = null; #end name = "Freebooter"; super (); }}
@:keep @:expose('__ASSET__assets_fonts_pixeltactical_awox_otf') @:noCompletion #if display private #end class __ASSET__assets_fonts_pixeltactical_awox_otf extends lime.text.Font { public function new () { #if !html5 __fontPath = "assets/fonts/PixelTactical-AWOx.otf"; #else ascender = null; descender = null; height = null; numGlyphs = null; underlinePosition = null; underlineThickness = null; unitsPerEM = null; #end name = "Pixel Tactical"; super (); }}
@:keep @:expose('__ASSET__assets_fonts_pixeltactical_awox_ttf') @:noCompletion #if display private #end class __ASSET__assets_fonts_pixeltactical_awox_ttf extends lime.text.Font { public function new () { #if !html5 __fontPath = "assets/fonts/PixelTactical-AWOx.ttf"; #else ascender = null; descender = null; height = null; numGlyphs = null; underlinePosition = null; underlineThickness = null; unitsPerEM = null; #end name = "Pixel Tactical"; super (); }}


#end

#if (openfl && !flash)

#if html5
@:keep @:expose('__ASSET__OPENFL__assets_fonts_freebooterupdated_ttf') @:noCompletion #if display private #end class __ASSET__OPENFL__assets_fonts_freebooterupdated_ttf extends openfl.text.Font { public function new () { __fromLimeFont (new __ASSET__assets_fonts_freebooterupdated_ttf ()); super (); }}
@:keep @:expose('__ASSET__OPENFL__assets_fonts_pixeltactical_awox_otf') @:noCompletion #if display private #end class __ASSET__OPENFL__assets_fonts_pixeltactical_awox_otf extends openfl.text.Font { public function new () { __fromLimeFont (new __ASSET__assets_fonts_pixeltactical_awox_otf ()); super (); }}
@:keep @:expose('__ASSET__OPENFL__assets_fonts_pixeltactical_awox_ttf') @:noCompletion #if display private #end class __ASSET__OPENFL__assets_fonts_pixeltactical_awox_ttf extends openfl.text.Font { public function new () { __fromLimeFont (new __ASSET__assets_fonts_pixeltactical_awox_ttf ()); super (); }}

#else
@:keep @:expose('__ASSET__OPENFL__assets_fonts_freebooterupdated_ttf') @:noCompletion #if display private #end class __ASSET__OPENFL__assets_fonts_freebooterupdated_ttf extends openfl.text.Font { public function new () { __fromLimeFont (new __ASSET__assets_fonts_freebooterupdated_ttf ()); super (); }}
@:keep @:expose('__ASSET__OPENFL__assets_fonts_pixeltactical_awox_otf') @:noCompletion #if display private #end class __ASSET__OPENFL__assets_fonts_pixeltactical_awox_otf extends openfl.text.Font { public function new () { __fromLimeFont (new __ASSET__assets_fonts_pixeltactical_awox_otf ()); super (); }}
@:keep @:expose('__ASSET__OPENFL__assets_fonts_pixeltactical_awox_ttf') @:noCompletion #if display private #end class __ASSET__OPENFL__assets_fonts_pixeltactical_awox_ttf extends openfl.text.Font { public function new () { __fromLimeFont (new __ASSET__assets_fonts_pixeltactical_awox_ttf ()); super (); }}

#end

#end
#end

#end