package toolbox;

import flixel.FlxG;
import flixel.FlxCamera;
import flixel.FlxSprite;
import flixel.FlxSubState;
import flixel.text.FlxText;
import flixel.text.FlxInputText;
import flixel.ui.FlxButton;
import flixel.util.FlxColor;
import openfl.utils.Assets;
import ui.FlxScrollableDropDownMenu;
import game.Conductor;


class EventSubState extends FlxSubState {
	var uiCamera:FlxCamera;
	var strumTime:Float;
	var existingEvent:Array<Dynamic>;
	var onSaveCallback:Array<Dynamic>->Void;
	var onDeleteCallback:Void->Void;

	var overlayBG:FlxSprite;
	var windowBox:FlxSprite;
	var headerTxt:FlxText;
	var eventTypeLabel:FlxText;
	var val1Label:FlxText;
	var val2Label:FlxText;

	var eventDropDown:FlxScrollableDropDownMenu;
	var val1Input:FlxInputText;
	var val2Input:FlxInputText;

	var saveBtn:FlxButton;
	var deleteBtn:FlxButton;
	var cancelBtn:FlxButton;

	var eventTypes:Array<String> = [];
	var eventDataMap:Map<String, Array<String>> = new Map();

	public function new(strumTime:Float, existingEvent:Array<Dynamic>, onSave:Array<Dynamic>->Void, onDelete:Void->Void) {
		super();
		this.strumTime = strumTime;
		this.existingEvent = existingEvent;
		this.onSaveCallback = onSave;
		this.onDeleteCallback = onDelete;

		loadEventList();
	}

	function loadEventList():Void {
		eventTypes = [];
		eventDataMap = new Map();

		if (Assets.exists(Paths.txt("eventList"))) {
			var lines = CoolUtil.coolTextFile(Paths.txt("eventList"));
			for (line in lines) {
				if (line != null && StringTools.trim(line) != "") {
					var parts = line.split("~");
					var eventName = StringTools.trim(parts[0]);
					if (eventName != "") {
						if (!eventTypes.contains(eventName)) {
							eventTypes.push(eventName);
						}
						eventDataMap.set(eventName, parts);
					}
				}
			}
		}

		if (eventTypes.length == 0) {
			eventTypes = [
				"BPM Change",
				"Change Character",
				"Camera Flash",
				"Alt Anim Toggle",
				"Play Animation",
				"Set Scroll Speed",
				"Screen Shake",
				"Add Substate",
				"Custom Event"
			];
		}
	}

	function updateValueLabels(eventName:String):Void {
		var data = eventDataMap.get(eventName);
		if (data == null) {
			for (k in eventDataMap.keys()) {
				if (k == eventName || k.endsWith(eventName) || eventName.endsWith(k) || k.indexOf(eventName) != -1) {
					data = eventDataMap.get(k);
					break;
				}
			}
		}

		if (data != null && data.length >= 2 && data[1] != null && StringTools.trim(data[1]) != "") {
			val1Label.text = "Value 1: " + StringTools.trim(data[1]);
		} else {
			val1Label.text = "Value 1 / Parameter 1:";
		}

		if (data != null && data.length >= 3 && data[2] != null && StringTools.trim(data[2]) != "") {
			val2Label.text = "Value 2: " + StringTools.trim(data[2]);
		} else {
			val2Label.text = "Value 2 / Parameter 2:";
		}
	}

	override public function create():Void {
		super.create();

		uiCamera = new FlxCamera(0, 0, FlxG.width, FlxG.height);
		uiCamera.bgColor = FlxColor.TRANSPARENT;
		FlxG.cameras.add(uiCamera, false);
		cameras = [uiCamera];

		overlayBG = new FlxSprite(0, 0).makeGraphic(FlxG.width, FlxG.height, 0xAA000000);
		overlayBG.scrollFactor.set(0, 0);
		overlayBG.cameras = [uiCamera];
		add(overlayBG);

		var winW:Int = 520;
		var winH:Int = 360;
		var winX:Float = (FlxG.width - winW) / 2;
		var winY:Float = (FlxG.height - winH) / 2;

		var outline:FlxSprite = new FlxSprite(winX - 2, winY - 2).makeGraphic(winW + 4, winH + 4, 0xFF444444);
		outline.scrollFactor.set(0, 0);
		outline.cameras = [uiCamera];
		add(outline);

		windowBox = new FlxSprite(winX, winY).makeGraphic(winW, winH, 0xFF222222);
		windowBox.scrollFactor.set(0, 0);
		windowBox.cameras = [uiCamera];
		add(windowBox);

		var stepNum:Int = Math.floor(Conductor.getStep(strumTime));
		var curEventName:String = eventTypes.length > 0 ? eventTypes[0] : "BPM Change";
		var initVal1:String = "";
		var initVal2:String = "";

		if (existingEvent != null && existingEvent.length > 0) {
			curEventName = Std.string(existingEvent[0]);
			if (existingEvent.length > 2 && existingEvent[2] != null) initVal1 = Std.string(existingEvent[2]);
			if (existingEvent.length > 3 && existingEvent[3] != null) initVal2 = Std.string(existingEvent[3]);
		}

		if (!eventTypes.contains(curEventName)) {
			eventTypes.push(curEventName);
		}

		headerTxt = new FlxText(winX, winY + 15, winW, existingEvent != null ? "EDIT EVENT (Step: " + stepNum + ")" : "ADD EVENT (Step: " + stepNum + ")", 16);
		headerTxt.setFormat(null, 16, FlxColor.YELLOW, CENTER, OUTLINE, FlxColor.BLACK);
		headerTxt.scrollFactor.set(0, 0);
		headerTxt.cameras = [uiCamera];
		add(headerTxt);

		eventTypeLabel = new FlxText(winX + 40, winY + 60, winW - 80, "Event Type:", 12);
		eventTypeLabel.setFormat(null, 12, FlxColor.WHITE, LEFT);
		eventTypeLabel.scrollFactor.set(0, 0);
		eventTypeLabel.cameras = [uiCamera];
		add(eventTypeLabel);

		eventDropDown = new FlxScrollableDropDownMenu(winX + 40, winY + 80, FlxScrollableDropDownMenu.makeStrIdLabelArray(eventTypes, true), function(selected:String) {
			var idx:Int = Std.parseInt(selected);
			if (idx >= 0 && idx < eventTypes.length) {
				curEventName = eventTypes[idx];
				updateValueLabels(curEventName);
			}
		});
		eventDropDown.selectedLabel = curEventName;
		eventDropDown.scrollFactor.set(0, 0);
		eventDropDown.cameras = [uiCamera];

		val1Label = new FlxText(winX + 40, winY + 140, winW - 80, "Value 1 / Parameter 1:", 12);
		val1Label.setFormat(null, 12, FlxColor.WHITE, LEFT);
		val1Label.scrollFactor.set(0, 0);
		val1Label.cameras = [uiCamera];
		add(val1Label);

		val1Input = new FlxInputText(winX + 40, winY + 160, winW - 80, initVal1, 12, FlxColor.WHITE, 0xFF333333);
		val1Input.scrollFactor.set(0, 0);
		val1Input.cameras = [uiCamera];
		add(val1Input);

		val2Label = new FlxText(winX + 40, winY + 200, winW - 80, "Value 2 / Parameter 2:", 12);
		val2Label.setFormat(null, 12, FlxColor.WHITE, LEFT);
		val2Label.scrollFactor.set(0, 0);
		val2Label.cameras = [uiCamera];
		add(val2Label);

		val2Input = new FlxInputText(winX + 40, winY + 220, winW - 80, initVal2, 12, FlxColor.WHITE, 0xFF333333);
		val2Input.scrollFactor.set(0, 0);
		val2Input.cameras = [uiCamera];
		add(val2Input);

		updateValueLabels(curEventName);

		saveBtn = new FlxButton(winX + 40, winY + 290, "Save Event", function() {
			var evName:String = eventDropDown.selectedLabel != null ? eventDropDown.selectedLabel : curEventName;
			var v1:String = val1Input != null ? val1Input.text : "";
			var v2:String = val2Input != null ? val2Input.text : "";
			unfocusInputs();
			if (onSaveCallback != null) {
				onSaveCallback([evName, strumTime, v1, v2]);
			}
			close();
		});
		saveBtn.scrollFactor.set(0, 0);
		saveBtn.color = 0xFF44AA44;
		saveBtn.label.color = FlxColor.WHITE;
		saveBtn.cameras = [uiCamera];
		add(saveBtn);

		deleteBtn = new FlxButton(winX + (winW / 2) - 40, winY + 290, "Delete Event", function() {
			unfocusInputs();
			if (onDeleteCallback != null) {
				onDeleteCallback();
			}
			close();
		});
		deleteBtn.scrollFactor.set(0, 0);
		deleteBtn.color = 0xFFAA4444;
		deleteBtn.label.color = FlxColor.WHITE;
		deleteBtn.cameras = [uiCamera];
		if (existingEvent == null) deleteBtn.visible = false;
		add(deleteBtn);

		cancelBtn = new FlxButton(winX + winW - 120, winY + 290, "Cancel", function() {
			unfocusInputs();
			close();
		});
		cancelBtn.scrollFactor.set(0, 0);
		cancelBtn.color = 0xFF666666;
		cancelBtn.label.color = FlxColor.WHITE;
		cancelBtn.cameras = [uiCamera];
		add(cancelBtn);

		add(eventDropDown); // Add dropdown last so it renders over inputs and buttons
	}

	function unfocusInputs():Void {
		if (val1Input != null) val1Input.endFocus();
		if (val2Input != null) val2Input.endFocus();
		if (FlxInputText.globalManager != null) FlxInputText.globalManager.setFocus(null);
	}

	override public function update(elapsed:Float):Void {
		super.update(elapsed);

		if (FlxG.keys.justPressed.ESCAPE) {
			unfocusInputs();
			close();
		}
	}

	override public function destroy():Void {
		unfocusInputs();
		if (uiCamera != null) {
			if (FlxG.cameras.list.contains(uiCamera))
				FlxG.cameras.remove(uiCamera, true);
			uiCamera = null;
		}
		super.destroy();
	}
}
