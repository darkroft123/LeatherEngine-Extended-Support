package game;

import toolbox.ChartingState;
import flixel.util.FlxColor;
import flixel.text.FlxText;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteContainer;

class EventSprite extends FlxSpriteContainer {
	public var name(default, null):String;
	public var strumTime(default, null):Float;
	public var value1(default, null):String;
	public var value2(default, null):String;
	public var eventData(default, null):Array<Dynamic>;

	public var tooltipText(default, null):FlxText;
	public var eventSprite(default, null):FlxSprite;

	public function new(event:Array<Dynamic>, x:Float = 0.0, y:Float = 0.0) {
		super(x, y);
		this.eventData = event;
		eventSprite = new FlxSprite().loadGraphic(Paths.gpuBitmap("charter/eventSprite", "shared"));
		eventSprite.setGraphicSize(ChartingState.GRID_SIZE, ChartingState.GRID_SIZE);
		eventSprite.updateHitbox();
		add(eventSprite);

		this.name = event[0];
		this.strumTime = event[1];
		this.value1 = event[2];
		this.value2 = event[3];

		tooltipText = new FlxText();
		tooltipText.color = FlxColor.WHITE;
		tooltipText.borderColor = FlxColor.BLACK;
		tooltipText.borderSize = 1;
		tooltipText.borderStyle = OUTLINE;
		tooltipText.size = 12;
		tooltipText.font = Paths.font("vcr.ttf");
		tooltipText.graphic.destroyOnNoUse = false;
		tooltipText.visible = false;
		add(tooltipText);
	}

	override function update(elapsed:Float):Void {
		super.update(elapsed);
		tooltipText.visible = FlxG.mouse.overlaps(eventSprite);
		if (tooltipText.visible) {
			tooltipText.text = 'Name: $name\nPosition: $strumTime\nValue 1: $value1\nValue 2: $value2';
			var cursorW:Float = (FlxG.mouse.cursor != null) ? FlxG.mouse.cursor.width : 15;
			tooltipText.setPosition(FlxG.mouse.x + cursorW, FlxG.mouse.y);
		}
	}
}
