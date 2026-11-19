package modding;

typedef CharacterConfig =
{
	var imagePath:String;
	var animations:Array<CharacterAnimation>;
	var defaultFlipX:Bool;

	@:optional
	var defaultFlipY:Bool;

	var dancesLeftAndRight:Bool;
	var graphicsSize:Null<Float>;
	var graphicSize:Null<Float>;
	var barColor:Array<Int>;
	var positionOffset:Array<Float>;
	var cameraOffset:Array<Float>;
	var singDuration:Null<Float>;

	var offsetsFlipWhenPlayer:Null<Bool>;
	var offsetsFlipWhenEnemy:Null<Bool>;
	var swapDirectionSingWhenPlayer:Null<Bool>;
	var trail:Null<Bool>;
	var trailLength:Null<Int>;
	var trailDelay:Null<Int>;
	var trailStalpha:Null<Float>;
	var trailDiff:Null<Float>;
	var deathCharacter:Null<String>;
	var deathCharacterName:Null<String>;

	// When dying while playing as the opponent, the death sprite is mirrored (flipped) by
	// default. Set this to false on a death sprite that is already authored facing the
	// opponent so it doesn't get flipped again.
	var flipDeath:Null<Bool>;

	var characters:Array<CharacterData>;
	var healthIcon:Dynamic;

	@:optional
	var icons:Array<IconData>;

	var antialiased:Null<Bool>;
	var antialiasing:Null<Bool>;
	var mainCharacterID:Null<Int>;
	var followMainCharacter:Null<Bool>;
	var followAllCharacter:Null<Bool>;

	@:optional
	var extraSheets:Array<String>;
}

typedef CharacterData =
{
	var name:String;
	var positionOffset:Array<Float>;
	@:optional var layer:Null<Int>;
	@:optional var alpha:Null<Float>;
}

typedef IconData =
{
	@:optional var offset:Array<Float>;
	@:optional var layer:Null<Int>;
}

typedef CharacterAnimation =
{
	var name:String;
	var animation_name:String;
	var fps:Int;
	var looped:Bool;
	@:optional
	var indices:Null<Array<Int>>;
}