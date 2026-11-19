package ui;

import flixel.FlxG;
import toolbox.CharacterCreator;
import haxe.Json;
import lime.utils.Assets;

class HealthIcon extends TrackerSprite {
	public var isPlayer:Bool = false;

	public var animatedIcon:Bool = false;

	public var offsetX:Float = 0.0;
	public var offsetY:Float = 0.0;

	public var startSize:Float = 1;

	public var char(default, null):String = "placeholder";
	public var slot:Int = -1;

	public function new(char:String = 'placeholder', isPlayer:Bool = false) {
		super(null, 10, -30, RIGHT);

		this.isPlayer = isPlayer;

		setupIcon(this.char = char);
		scrollFactor.set();
	}

	static function resolveIconAssetPath(char:String):{path:String, xmlPath:String, jsonPath:String, txtPath:String} {
		var iconPath:String = 'placeholder-icons';
		var cleanChar:String = char != null ? (StringTools.startsWith(char.toLowerCase(), "icon-") ? char.substr(5) : char) : "placeholder";

		for (path in [char, cleanChar, '$char-icons', '$cleanChar-icons', 'icon-$char', 'icon-$cleanChar']) {
			if (Assets.exists(Paths.image('icons/$path'))) {
				iconPath = path;
				break;
			}
		}

		return {
			path: iconPath,
			xmlPath: Paths.file('images/icons/$iconPath.xml'),
			jsonPath: Paths.file('images/icons/$iconPath.json'),
			txtPath: Paths.file('images/icons/$iconPath.txt')
		};
	}

	static function loadIconConfig(iconPath:String, jsonPath:String, txtPath:String):HealthIconConfig {
		var config:HealthIconConfig = {
			offset: [0, 0],
			scale: 1,
			fps: 24,
			antialiasing: true
		};

		if (Assets.exists(jsonPath)) {
			config = cast Json.parse(Assets.getText(jsonPath));
		} else if (Assets.exists(txtPath)) {
			var textArray:Array<String> = Assets.getText(txtPath).split(" ");
			config.offset = [Std.parseFloat(textArray[0]), Std.parseFloat(textArray[1])];
			config.scale = Std.parseFloat(textArray[2]);
		}

		return config;
	}

	function setupAnimatedIcon(iconPath:String, iconConfig:HealthIconConfig, xmlPath:String):Void {
		frames = Paths.getSparrowAtlas('icons/$iconPath', null, FlxG.state is CharacterCreator);
		if (frames == null || frames.frames == null || frames.frames.length == 0) {
			makeGraphic(150, 150, flixel.util.FlxColor.TRANSPARENT);
			animation.add('neutral', [0], 0, false, isPlayer);
			return;
		}

		var hasNeutral:Bool = false;
		var hasLose:Bool = false;
		var hasWin:Bool = false;

		for (frame in frames.frames) {
			if (frame.name != null) {
				if (StringTools.startsWith(frame.name, '${char}0'))
					hasNeutral = true;
				else if (StringTools.startsWith(frame.name, '${char}-lose'))
					hasLose = true;
				else if (StringTools.startsWith(frame.name, '${char}-win'))
					hasWin = true;
			}
		}

		if (hasNeutral)
			animation.addByPrefix('neutral', '${char}0', iconConfig.fps, true, isPlayer);

		if (hasLose)
			animation.addByPrefix('lose', '${char}-lose0', iconConfig.fps, true, isPlayer);

		if (hasWin)
			animation.addByPrefix('win', '${char}-win0', iconConfig.fps, true, isPlayer);
	}

	function setupBitmapIcon(iconPath:String, iconConfig:HealthIconConfig):Void {
		var asset = Paths.gpuBitmap('icons/$iconPath', null, FlxG.state is CharacterCreator);
		if (asset == null) {
			makeGraphic(150, 150, flixel.util.FlxColor.TRANSPARENT);
			animation.add('neutral', [0], 0, false, isPlayer);
			return;
		}

		loadGraphic(asset, false);
		if (graphic == null) {
			makeGraphic(150, 150, flixel.util.FlxColor.TRANSPARENT);
			animation.add('neutral', [0], 0, false, isPlayer);
			return;
		}

		var gWidth:Int = graphic.width;
		var gHeight:Int = graphic.height;

		var frameWidth:Int = 150;
		var frameHeight:Int = 150;

		if (gHeight == 32) {
			frameWidth = 32;
			frameHeight = 32;
		} else if (gHeight != 150) {
			frameWidth = Std.int(gWidth / 2);
			frameHeight = gHeight;
		}

		system.OptimizedAssets.sanitizeGraphicFrameCollections(graphic);
		loadGraphic(graphic, true, frameWidth, frameHeight);

		var winFrame:Int = (gWidth >= gHeight * 3 ? 2 : 0);
		var loseFrame:Int = (gWidth >= gHeight * 2 ? 1 : 0);

		if (frames != null && frames.frames != null) {
			if (winFrame >= frames.frames.length) winFrame = 0;
			if (loseFrame >= frames.frames.length) loseFrame = 0;
		}

		animation.add('win', [winFrame], 0, false, isPlayer);
		animation.add('lose', [loseFrame], 0, false, isPlayer);
		animation.add('neutral', [0], 0, false, isPlayer);
	}

	function applyIconConfig(iconConfig:HealthIconConfig):Void {
		scale.set(iconConfig.scale, iconConfig.scale);
		offsetX = iconConfig.offset[0];
		offsetY = iconConfig.offset[1];
		antialiasing = iconConfig.antialiasing;

		if (char.endsWith('-pixel'))
			antialiasing = false;

		startSize = scale.x;
		updateHitbox();
		centerOffsets();
	}

	function playDefaultAnimation():Void {
		if (frames == null || frames.frames == null || frames.frames.length == 0) return;
		if (animation.getByName('neutral') != null)
			animation.play('neutral');
		else if (animation.getByName('win') != null)
			animation.play('win');
		else if (animation.getByName('lose') != null)
			animation.play('lose');
	}

	public function setupIcon(char:String = 'placeholder') {
		var paths = resolveIconAssetPath(char);
		var iconConfig = loadIconConfig(paths.path, paths.jsonPath, paths.txtPath);

		animatedIcon = Assets.exists(paths.xmlPath);

		if (animatedIcon)
			setupAnimatedIcon(paths.path, iconConfig, paths.xmlPath);
		else
			setupBitmapIcon(paths.path, iconConfig);

		playDefaultAnimation();
		applyIconConfig(iconConfig);
	}

	override public function destroy():Void {
		flixel.tweens.FlxTween.cancelTweensOf(this);
		if (scale != null) flixel.tweens.FlxTween.cancelTweensOf(scale);
		_frame = null; // Prevent destroying shared FlxFrame in cached collections
		super.destroy();
	}
}

typedef HealthIconConfig = {
	var offset:Array<Float>;
	var scale:Float;
	var fps:Int;
	var antialiasing:Bool;
}
