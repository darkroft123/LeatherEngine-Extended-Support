package game;

import lime.utils.Assets;
import haxe.Json;

typedef Cutscene = {
	@:optional var type:String;
	@:optional var cutsceneAfter:Null<String>;
	@:optional var scriptPath:String;
	@:optional var videoPath:String;
	@:optional var videoExt:String;
	@:optional var bgFade:Null<Bool>;
	@:optional var animations:Null<Bool>;
	@:optional var bgFadeTime:Null<Float>;
	@:optional var bgColor:Null<String>;
	@:optional var dialogueSections:Array<DialogueSection>;
	@:optional var dialogueMusic:String;
	@:optional var dialogueBox:String;
	@:optional var dialogueBoxSize:Null<Float>;
	@:optional var dialogueBoxFlips:Null<Bool>;
	@:optional var introSound:String;
}

typedef DialogueSection = {
	@:optional var side:String;
	@:optional var showOtherPortrait:Bool;
	@:optional var leftPortrait:DialogueObject;
	@:optional var rightPortrait:DialogueObject;
	@:optional var dialogue:DialogueText;
	@:optional var box_Anim:Null<String>;
	@:optional var box_Open:Null<String>;
	@:optional var box_FPS:Null<Int>;
	@:optional var open_Box:Null<Bool>;
	@:optional var box_Antialiased:Null<Bool>;
	@:optional var has_Hand:Bool;
	@:optional var hand_Sprite:DialogueObject;
	@:optional var dialogueBoxLeft:String;
	@:optional var dialogueBoxRight:String;
	@:optional var box_OffsetLeft:Array<Float>;
	@:optional var box_OffsetRight:Array<Float>;
}

typedef DialogueObject = {
	@:optional var sprite:String;
	@:optional var x:Float;
	@:optional var y:Float;
	@:optional var scale:Null<Float>;
	@:optional var antialiased:Null<Bool>;
	@:optional var animated:Bool;
	@:optional var anim_Name:String;
	@:optional var fps:Null<Int>;
}

typedef DialogueText = {
	@:optional var text:String;
	@:optional var font:String;
	@:optional var sound:String;
	@:optional var color:String;
	@:optional var shadowColor:String;
	@:optional var hasShadow:Bool;
	@:optional var shadowOffset:Float;
	@:optional var size:Int;
	@:optional var offset:Null<Array<Float>>;
	@:optional var alignment:Null<String>;
	@:optional var textWidth:Null<Int>;
	@:optional var alphabet:Null<Bool>;
	@:optional var bold:Null<Bool>;
	@:optional var text_Delay:Null<Float>;
}




class CutsceneUtil {
	public static function loadFromJson(jsonPath:String):Cutscene
		return parseJSONshit(Assets.getText(Paths.json("cutscenes/" + jsonPath)).trim());

	public static function parseJSONshit(rawJson:String):Cutscene
		return cast Json.parse(rawJson);
}
