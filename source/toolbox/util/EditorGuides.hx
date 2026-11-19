package toolbox.util;

import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxPoint;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import game.Character;

class GuideLine extends FlxSprite {
	public function new(?lineColor:FlxColor) {
		super(0, 0);

		makeGraphic(1, 1, FlxColor.WHITE);

		color = lineColor == null ? FlxColor.WHITE : lineColor;
		antialiasing = false;
		moves = false;
		active = false;

		origin.set(0, 0);
		offset.set(0, 0);
	}

	public inline function setRect(X:Float, Y:Float, Width:Float, Height:Float) {
		setPosition(X, Y);
		scale.set(Width <= 0 ? 0.01 : Width, Height <= 0 ? 0.01 : Height);
	}
}

class EditorGuides extends FlxTypedGroup<FlxSprite> {
	public var showAnchor:Bool = true;
	public var showLoadBox:Bool = true;
	public var showSpriteBox:Bool = true;
	public var showOffsetLink:Bool = true;
	public var showCamera:Bool = true;
	public var showGhostBox:Bool = false;
	public var showLabels:Bool = true;

	public static inline var ANCHOR_COLOR:FlxColor = 0xFFFF3B3B;
	public static inline var LOAD_COLOR:FlxColor = 0xFFFF8A3B;
	public static inline var SPRITE_COLOR:FlxColor = 0xFF3BFF7A;
	public static inline var OFFSET_COLOR:FlxColor = 0xFFFFE23B;
	public static inline var CAMERA_COLOR:FlxColor = 0xFF3BD5FF;
	public static inline var GHOST_COLOR:FlxColor = 0xFFB03BFF;

	var floorLine:GuideLine;
	var anchorV:GuideLine;
	var anchorCube:GuideLine;
	var anchorShifted:GuideLine;
	var posLinkX:GuideLine;
	var posLinkY:GuideLine;

	var loadBox:Array<GuideLine> = [];
	var spriteBox:Array<GuideLine> = [];
	var ghostBox:Array<GuideLine> = [];
	var camBox:Array<GuideLine> = [];

	var camCrossH:GuideLine;
	var camCrossV:GuideLine;

	var offsetLinkX:GuideLine;
	var offsetLinkY:GuideLine;

	var anchorLabel:FlxText;
	var camLabel:FlxText;
	var offsetLabel:FlxText;

	var lineSize:Float = 2;

	public function new() {
		super();

		floorLine = addLine(ANCHOR_COLOR, 0.35);
		anchorV = addLine(ANCHOR_COLOR, 0.35);

		loadBox = addBox(LOAD_COLOR, 0.75);
		spriteBox = addBox(SPRITE_COLOR, 0.9);
		ghostBox = addBox(GHOST_COLOR, 0.6);
		camBox = addBox(CAMERA_COLOR, 0.55);

		posLinkX = addLine(ANCHOR_COLOR, 0.8);
		posLinkY = addLine(ANCHOR_COLOR, 0.8);

		offsetLinkX = addLine(OFFSET_COLOR, 0.95);
		offsetLinkY = addLine(OFFSET_COLOR, 0.95);

		camCrossH = addLine(CAMERA_COLOR, 0.95);
		camCrossV = addLine(CAMERA_COLOR, 0.95);

		anchorCube = addLine(ANCHOR_COLOR, 0.85);
		anchorShifted = addLine(LOAD_COLOR, 0.85);

		anchorLabel = addLabel(ANCHOR_COLOR);
		camLabel = addLabel(CAMERA_COLOR);
		offsetLabel = addLabel(OFFSET_COLOR);
	}

	function addLine(color:FlxColor, alpha:Float = 1):GuideLine {
		var line = new GuideLine(color);
		line.alpha = alpha;
		add(line);
		return line;
	}

	function addBox(color:FlxColor, alpha:Float = 1):Array<GuideLine> {
		return [addLine(color, alpha), addLine(color, alpha), addLine(color, alpha), addLine(color, alpha)];
	}

	function addLabel(color:FlxColor):FlxText {
		var text = new FlxText(0, 0, 0, "", 14);
		text.font = Paths.font("vcr.ttf");
		text.color = color;
		text.borderStyle = OUTLINE;
		text.borderColor = FlxColor.BLACK;
		text.borderSize = 2;
		text.active = false;
		add(text);
		return text;
	}

	inline function setBox(box:Array<GuideLine>, X:Float, Y:Float, Width:Float, Height:Float, ?visible:Bool = true) {
		if (!visible) {
			for (line in box)
				line.visible = false;
			return;
		}

		for (line in box)
			line.visible = true;

		box[0].setRect(X, Y, Width, lineSize); // top
		box[1].setRect(X, Y + Height - lineSize, Width, lineSize); // bottom
		box[2].setRect(X, Y, lineSize, Height); // left
		box[3].setRect(X + Width - lineSize, Y, lineSize, Height); // right
	}

	public static function getDrawRect(character:Character):Array<Float> {
		var scaleX:Float = Math.abs(character.scale.x);
		var scaleY:Float = Math.abs(character.scale.y);

		var w:Float = character.frameWidth * scaleX;
		var h:Float = character.frameHeight * scaleY;

		if (w <= 0)
			w = character.width;
		if (h <= 0)
			h = character.height;

		var x:Float = character.x - character.offset.x + (character.origin.x * (1 - scaleX));
		var y:Float = character.y - character.offset.y + (character.origin.y * (1 - scaleY));

		return [x, y, w, h];
	}

	public function updateGuides(character:Character, basePoint:FlxPoint, camTarget:FlxPoint, gameZoom:Float, editorZoom:Float, ?ghost:Character) {
		if (character == null)
			return;

		lineSize = 2 / Math.max(editorZoom, 0.1);
		if (lineSize < 1)
			lineSize = 1;

		var labelScale:Float = 1 / Math.max(editorZoom, 0.1);

		// --- floor + stage anchor ---
		var anchorX:Float = basePoint.x;
		var anchorY:Float = basePoint.y;

		var shiftedX:Float = anchorX + character.positioningOffset[0];
		var shiftedY:Float = anchorY + character.positioningOffset[1];

		floorLine.visible = anchorV.visible = anchorCube.visible = anchorShifted.visible = showAnchor;
		posLinkX.visible = posLinkY.visible = showAnchor;
		anchorLabel.visible = showAnchor && showLabels;

		if (showAnchor) {
			floorLine.setRect(anchorX - 1400, anchorY - (lineSize * 0.5), 2800, lineSize);
			anchorV.setRect(anchorX - (lineSize * 0.5), anchorY - 900, lineSize, 1800);

			var cube:Float = 16 * labelScale;
			anchorCube.setRect(anchorX - (cube * 0.5), anchorY - (cube * 0.5), cube, cube);
			anchorShifted.setRect(shiftedX - (cube * 0.35), shiftedY - (cube * 0.35), cube * 0.7, cube * 0.7);

			posLinkX.setRect(Math.min(anchorX, shiftedX), anchorY - (lineSize * 0.5), Math.abs(shiftedX - anchorX), lineSize);
			posLinkY.setRect(shiftedX - (lineSize * 0.5), Math.min(anchorY, shiftedY), lineSize, Math.abs(shiftedY - anchorY));

			anchorLabel.scale.set(labelScale, labelScale);
			anchorLabel.text = "load: " + Std.int(anchorX) + ", " + Std.int(anchorY);
			anchorLabel.setPosition(anchorX + (10 * labelScale), anchorY + (6 * labelScale));
		}

		setBox(loadBox, character.x, character.y, character.width, character.height, showLoadBox);

		// --- actual sprite box ---
		var rect:Array<Float> = getDrawRect(character);
		setBox(spriteBox, rect[0], rect[1], rect[2], rect[3], showSpriteBox);

		var showLink:Bool = showOffsetLink && showLoadBox && showSpriteBox;
		offsetLinkX.visible = offsetLinkY.visible = showLink;
		offsetLabel.visible = showLink && showLabels;

		if (showLink) {
			var deltaX:Float = rect[0] - character.x;
			var deltaY:Float = rect[1] - character.y;

			offsetLinkX.setRect(Math.min(character.x, rect[0]), character.y - (lineSize * 0.5), Math.abs(deltaX), lineSize);
			offsetLinkY.setRect(rect[0] - (lineSize * 0.5), Math.min(character.y, rect[1]), lineSize, Math.abs(deltaY));

			offsetLabel.scale.set(labelScale, labelScale);
			offsetLabel.text = "offset: " + Std.int(-character.offset.x) + ", " + Std.int(-character.offset.y);
			offsetLabel.setPosition(character.x + (8 * labelScale), character.y - (22 * labelScale));
		}

		// --- ghost box ---
		if (ghost != null && showGhostBox && ghost.visible) {
			var ghostRect:Array<Float> = getDrawRect(ghost);
			setBox(ghostBox, ghostRect[0], ghostRect[1], ghostRect[2], ghostRect[3], true);
		} else {
			setBox(ghostBox, 0, 0, 0, 0, false);
		}

		// --- camara ---
		camCrossH.visible = camCrossV.visible = showCamera;
		camLabel.visible = showCamera && showLabels;

		if (showCamera) {
			var zoom:Float = gameZoom <= 0 ? 1 : gameZoom;
			var viewWidth:Float = flixel.FlxG.width / zoom;
			var viewHeight:Float = flixel.FlxG.height / zoom;

			setBox(camBox, camTarget.x - (viewWidth * 0.5), camTarget.y - (viewHeight * 0.5), viewWidth, viewHeight, true);

			var cross:Float = 30 * labelScale;
			camCrossH.setRect(camTarget.x - cross, camTarget.y - (lineSize * 0.5), cross * 2, lineSize);
			camCrossV.setRect(camTarget.x - (lineSize * 0.5), camTarget.y - cross, lineSize, cross * 2);

			camLabel.scale.set(labelScale, labelScale);
			camLabel.text = "camera";
			camLabel.setPosition(camTarget.x + (10 * labelScale), camTarget.y - (24 * labelScale));
		} else {
			setBox(camBox, 0, 0, 0, 0, false);
		}
	}

	public function toggleAll(value:Bool) {
		showAnchor = showLoadBox = showSpriteBox = showOffsetLink = showCamera = value;

		if (!value)
			showGhostBox = false;
	}
}
