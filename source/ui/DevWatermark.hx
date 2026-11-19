package ui;

import openfl.display.Sprite;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.text.TextFormatAlign;

class DevWatermark extends Sprite
{
	public static var instance:DevWatermark;
	private var textField:TextField;

	public function new()
	{
		super();

		mouseEnabled = false;
		mouseChildren = false;

		textField = new TextField();
		textField.selectable = false;
		textField.mouseEnabled = false;
		textField.wordWrap = false;
		textField.multiline = true;

		var format = new TextFormat("_sans", 28, 0xFFFFFF, true);
		format.align = TextFormatAlign.CENTER;
		format.leading = 12;
		textField.defaultTextFormat = format;

		textField.alpha = 0.1;

		addChild(textField);
	}

	public static function show(username:String):Void
	{
		if (utilities.Options.getData("showDevWatermark") == false)
		{
			hide();
			return;
		}

		if (Main.instance == null) return;

		if (instance == null)
		{
			instance = new DevWatermark();
			Main.instance.addChild(instance);
		}

		var dispName = (username != null && username != "") ? username.toUpperCase() : "DEVELOPER";
		
		var rowList1:Array<String> = [];
		var rowList2:Array<String> = [];
		for (i in 0...16) {
			rowList1.push(dispName);
			rowList2.push(dispName);
		}
		var rowText1 = rowList1.join("     ");
		var rowText2 = "   " + rowList2.join("     ");

		var fullText = "";
		for (r in 0...32)
		{
			fullText += (r % 2 == 0 ? rowText1 : rowText2) + "\n";
		}
		instance.textField.text = fullText;

		var stageW:Float = openfl.Lib.current.stage != null ? openfl.Lib.current.stage.stageWidth : 1920;
		var stageH:Float = openfl.Lib.current.stage != null ? openfl.Lib.current.stage.stageHeight : 1080;

		instance.textField.width = stageW;
		instance.textField.height = stageH;
		instance.textField.x = 0;
		instance.textField.y = 10;
		instance.visible = true;

		if (openfl.Lib.current.stage != null) {
			openfl.Lib.current.stage.removeEventListener(openfl.events.Event.RESIZE, instance.onStageResize);
			openfl.Lib.current.stage.addEventListener(openfl.events.Event.RESIZE, instance.onStageResize);
		}
	}

	private function onStageResize(e:openfl.events.Event):Void {
		if (textField != null && openfl.Lib.current.stage != null) {
			textField.width = openfl.Lib.current.stage.stageWidth;
			textField.height = openfl.Lib.current.stage.stageHeight;
		}
	}

	public static function hide():Void
	{
		if (instance != null)
		{
			instance.visible = false;
		}
	}
}
