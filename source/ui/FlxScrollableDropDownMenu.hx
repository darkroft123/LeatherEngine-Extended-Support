package ui;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.ui.FlxUI9SliceSprite;
import flixel.addons.ui.FlxUIButton;
import flixel.addons.ui.FlxUIDropDownMenu;
import flixel.addons.ui.StrNameLabel;
import flixel.math.FlxMath;
import flixel.util.FlxColor;

/**
 * A FlxUIDropDownMenu that is extended to have scrolling capabilities and a visible scrollbar.
 * Based on code by larsiusprime
 */
class FlxScrollableDropDownMenu extends FlxUIDropDownMenu {
	public var currentScroll:Int = 0; // Handles the scrolling
	public var visibleItems:Int = 8; // Number of items shown in viewport

	public var canScroll:Bool = true;

	public var isOpen(get, never):Bool;
	inline function get_isOpen() return dropPanel != null && dropPanel.visible;

	public var scrollTrack:FlxSprite;
	public var scrollThumb:FlxSprite;

	private var isDraggingScroll:Bool = false;
	private var scrollDragOffsetY:Float = 0;
	private var justOpened:Bool = false;

	public function new(X:Float = 0, Y:Float = 0, DataList:Array<StrNameLabel>, ?Callback:String->Void, ?Header:FlxUIDropDownHeader,
			?DropPanel:FlxUI9SliceSprite, ?ButtonList:Array<FlxUIButton>, ?UIControlCallback:(Bool, FlxUIDropDownMenu) -> Void) {
		super(X, Y, DataList, Callback, Header, DropPanel, ButtonList, UIControlCallback);
		this.dropDirection = FlxUIDropDownMenuDropDirection.Down;

		scrollTrack = new FlxSprite();
		scrollTrack.makeGraphic(6, 1, FlxColor.fromRGB(35, 35, 45), true);
		scrollTrack.visible = false;
		scrollTrack.scrollFactor.set(0, 0);
		add(scrollTrack);

		scrollThumb = new FlxSprite();
		scrollThumb.makeGraphic(6, 1, FlxColor.fromRGB(130, 130, 150), true);
		scrollThumb.visible = false;
		scrollThumb.scrollFactor.set(0, 0);
		add(scrollThumb);

		updateButtonPositions();
	}

	public inline function getMaxScroll():Int {
		return (list.length > visibleItems) ? (list.length - visibleItems) : 0;
	}

	override private function getPanelHeight():Float {
		var count = (list.length > visibleItems) ? visibleItems : list.length;
		if (count < 1) count = 1;
		var h = (header != null && header.background != null) ? header.background.height : 20.0;
		return count * h;
	}

	override private function set_dropDirection(dropDirection):FlxUIDropDownMenuDropDirection {
		this.dropDirection = dropDirection;
		updateButtonPositions();
		return dropDirection;
	}

	override public function update(elapsed:Float) {
		#if FLX_MOUSE
		var mouseCam = (cameras != null && cameras.length > 0) ? cameras[0] : FlxG.camera;

		// Prevent checkClickOff in super.update from prematurely closing when user interacts with scrollbar
		var clickingScroll = dropPanel != null && dropPanel.visible && FlxG.mouse.justPressed && scrollTrack != null && scrollTrack.visible && (FlxG.mouse.overlaps(scrollTrack, mouseCam) || FlxG.mouse.overlaps(scrollThumb, mouseCam));
		if (clickingScroll) {
			dropPanel.visible = false;
		}
		#end

		super.update(elapsed);

		#if FLX_MOUSE
		if (clickingScroll && dropPanel != null) {
			dropPanel.visible = true;
		}

		if (dropPanel != null && dropPanel.visible) {
			if (justOpened) {
				justOpened = false;
			} else {
				var maxScroll = getMaxScroll();
				var hasScroll = maxScroll > 0;

				// Mouse wheel & keyboard scroll
				if (hasScroll && canScroll) {
					var overPanel = FlxG.mouse.overlaps(dropPanel, mouseCam) || FlxG.mouse.overlaps(header, mouseCam) || (scrollTrack != null && FlxG.mouse.overlaps(scrollTrack, mouseCam));

					if (overPanel && FlxG.mouse.wheel != 0) {
						currentScroll -= FlxG.mouse.wheel;
						if (currentScroll < 0) currentScroll = 0;
						if (currentScroll > maxScroll) currentScroll = maxScroll;
						updateButtonPositions();
					} else if (FlxG.keys.justPressed.UP) {
						if (currentScroll > 0) {
							currentScroll--;
							updateButtonPositions();
						}
					} else if (FlxG.keys.justPressed.DOWN) {
						if (currentScroll < maxScroll) {
							currentScroll++;
							updateButtonPositions();
						}
					}
				}

				// Scrollbar click & drag interaction
				if (scrollTrack != null && scrollTrack.visible) {
					var mouseOverThumb = FlxG.mouse.overlaps(scrollThumb, mouseCam);
					var mouseOverTrack = FlxG.mouse.overlaps(scrollTrack, mouseCam);
					var mouseWorldPos = FlxG.mouse.getWorldPosition(mouseCam);

					if (FlxG.mouse.justPressed && mouseOverThumb) {
						isDraggingScroll = true;
						scrollDragOffsetY = mouseWorldPos.y - scrollThumb.y;
					} else if (FlxG.mouse.justPressed && mouseOverTrack) {
						isDraggingScroll = true;
						var trackH = getPanelHeight();
						var thumbH = scrollThumb.height;
						var travel = trackH - thumbH;
						scrollDragOffsetY = thumbH * 0.5;
						if (travel > 0) {
							var relY = (mouseWorldPos.y - scrollTrack.y) - scrollDragOffsetY;
							var pct = FlxMath.bound(relY / travel, 0, 1);
							currentScroll = Math.round(pct * maxScroll);
							updateButtonPositions();
						}
					}

					if (isDraggingScroll) {
						if (FlxG.mouse.pressed) {
							var trackH = getPanelHeight();
							var thumbH = scrollThumb.height;
							var travel = trackH - thumbH;
							if (travel > 0) {
								var targetThumbY = (mouseWorldPos.y - scrollDragOffsetY) - scrollTrack.y;
								var pct = FlxMath.bound(targetThumbY / travel, 0, 1);
								var newScroll = Math.round(pct * maxScroll);
								if (newScroll != currentScroll) {
									currentScroll = newScroll;
									updateButtonPositions();
								}
							}
						} else {
							isDraggingScroll = false;
						}
					}
				}

				// Click outside to close (extra safety check)
				if (FlxG.mouse.justPressed && !isDraggingScroll && !FlxG.mouse.overlaps(this, mouseCam) && !FlxG.mouse.overlaps(header, mouseCam) && !FlxG.mouse.overlaps(dropPanel, mouseCam)) {
					showList(false);
				}
			}
		}
		#end
	}

	override private function showList(b:Bool):Void {
		var wasHidden = (dropPanel == null || !dropPanel.visible);
		super.showList(b);
		if (b) {
			if (wasHidden) {
				justOpened = true;
				// Auto-scroll to currently selected item if applicable
				var selectedIdx = 0;
				for (i in 0...list.length) {
					if (list[i] != null && (list[i].name == selectedId || (list[i].label != null && list[i].label.text == selectedLabel))) {
						selectedIdx = i;
						break;
					}
				}
				var maxScroll = getMaxScroll();
				if (selectedIdx >= visibleItems) {
					currentScroll = selectedIdx - Math.floor(visibleItems / 2);
					if (currentScroll > maxScroll) currentScroll = maxScroll;
					if (currentScroll < 0) currentScroll = 0;
				} else {
					currentScroll = 0;
				}
			}
			updateButtonPositions();
		} else {
			isDraggingScroll = false;
			if (scrollTrack != null) scrollTrack.visible = false;
			if (scrollThumb != null) scrollThumb.visible = false;
		}
	}

	override function updateButtonPositions():Void {
		if (header == null || header.background == null || dropPanel == null) return;

		var buttonHeight = header.background.height;
		var panelH = getPanelHeight();
		dropPanel.resize(header.background.width, panelH);
		dropPanel.x = header.background.x;
		dropPanel.y = header.background.y;
		if (dropsUp())
			dropPanel.y -= panelH;
		else
			dropPanel.y += buttonHeight;

		var maxScroll = getMaxScroll();
		if (currentScroll < 0) currentScroll = 0;
		if (currentScroll > maxScroll) currentScroll = maxScroll;

		var hasScroll = list.length > visibleItems;
		var trackW:Int = 6;
		var btnW = hasScroll ? Std.int(header.background.width - trackW - 3) : Std.int(header.background.width - 2);

		for (i in 0...list.length) {
			var button:FlxUIButton = list[i];
			if (button == null) continue;

			if (i >= currentScroll && i < currentScroll + visibleItems) {
				button.visible = dropPanel.visible;
				button.active = dropPanel.visible;
				button.x = dropPanel.x + 1;
				button.y = dropPanel.y + ((i - currentScroll) * buttonHeight);
				button.resize(btnW, buttonHeight - 1);
			} else {
				button.visible = false;
				button.active = false;
				button.x = dropPanel.x + 1;
				button.y = dropPanel.y;
			}
		}

		if (scrollTrack != null && scrollThumb != null) {
			if (hasScroll && dropPanel.visible) {
				var trackH = panelH;
				scrollTrack.cameras = this.cameras;
				scrollThumb.cameras = this.cameras;

				scrollTrack.visible = true;
				scrollTrack.x = dropPanel.x + dropPanel.width - trackW - 1;
				scrollTrack.y = dropPanel.y;
				scrollTrack.makeGraphic(trackW, Std.int(Math.max(1, trackH)), FlxColor.fromRGB(40, 40, 50), true);

				var thumbH = Math.max(14, (visibleItems / list.length) * trackH);
				scrollThumb.visible = true;
				scrollThumb.x = scrollTrack.x;
				var travel = trackH - thumbH;
				var pct = maxScroll > 0 ? (currentScroll / maxScroll) : 0;
				scrollThumb.y = scrollTrack.y + (pct * travel);
				scrollThumb.makeGraphic(trackW, Std.int(Math.max(1, thumbH)), FlxColor.fromRGB(140, 140, 160), true);
			} else {
				scrollTrack.visible = false;
				scrollThumb.visible = false;
			}
		}
	}

	override function get_width():Float {
		if (header != null && header.background != null)
			return header.background.width;
		return super.get_width();
	}

	override function get_height():Float {
		if (header != null && header.background != null) {
			var h:Float = header.background.height;
			if (dropPanel != null && dropPanel.visible)
				h += getPanelHeight();
			return h;
		}
		return super.get_height();
	}

	override public function destroy():Void {
		scrollTrack = null;
		scrollThumb = null;
		super.destroy();
	}

	/**
	 * Helper function to easily create a data list for a dropdown menu from an array of strings.
	 *
	 * @param	StringArray		The strings to use as data - used for both label and string ID.
	 * @param	UseIndexID		Whether to use the integer index of the current string as ID.
	 * @return	The StrIDLabel array ready to be used in FlxUIDropDownMenuCustom's constructor
	 */
	public static function makeStrIdLabelArray(StringArray:Array<String>, UseIndexID:Bool = false):Array<StrNameLabel> {
		var strIdArray:Array<StrNameLabel> = [];
		for (i in 0...StringArray.length) {
			var ID:String = StringArray[i];
			if (UseIndexID) {
				ID = Std.string(i);
			}
			strIdArray[i] = new StrNameLabel(ID, StringArray[i]);
		}
		return strIdArray;
	}
}
