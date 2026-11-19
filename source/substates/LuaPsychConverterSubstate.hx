package substates;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import openfl.utils.ByteArray;
import openfl.net.FileReference;
import toolbox.LuaToPsychConverter;

#if sys
import sys.FileSystem;
import sys.io.File;
#end


class LuaPsychConverterSubstate extends MusicBeatSubstate {
	// VS Code Dark Modern Color Palette
	static final COLOR_BG:Int = 0xFF1E1E1E;
	static final COLOR_TITLEBAR:Int = 0xFF252526;
	static final COLOR_GUTTER:Int = 0xFF181818;
	static final COLOR_LINE_NUM:Int = 0xFF858585;
	static final COLOR_TAB_ACTIVE:Int = 0xFF1E1E1E;
	static final COLOR_TAB_INACTIVE:Int = 0xFF2D2D2D;
	static final COLOR_BORDER:Int = 0xFF3C3C3C;
	static final COLOR_ACCENT:Int = 0xFF007ACC; // VS Code Blue
	static final COLOR_CURSOR:Int = 0xFF528BFF;

	// VS Code Indent Rainbow Palette (Guide bars and tint)
	static final RAINBOW_GUIDES:Array<Int> = [
		0xFFE06C75, // Red / Coral
		0xFFE5C07B, // Yellow / Gold
		0xFF98C379, // Green
		0xFF56B6C2, // Cyan / Teal
		0xFF61AFEF, // Blue
		0xFFC678DD  // Purple / Violet
	];
	static final RAINBOW_TINTS:Array<Int> = [
		0x20E06C75,
		0x20E5C07B,
		0x2098C379,
		0x2056B6C2,
		0x2061AFEF,
		0x20C678DD
	];

	var songName:String = "";
	var modchartHint:String = "";

	var originalCode:String = "";
	var convertedCode:String = "";
	var conversionResult:ConversionResult;

	// Files list in current song/modcharts
	var foundFiles:Array<{name:String, path:String}> = [];
	var curFileIndex:Int = 0;

	// UI Elements
	var bgDim:FlxSprite;
	var editorBg:FlxSprite;
	var titleBar:FlxSprite;
	var titleTxt:FlxText;
	var fileInfoTxt:FlxText;
	var tabButtons:Array<{spr:FlxSprite, txt:FlxText}> = [];
	var gutterBg:FlxSprite;
	var gutterTxt:FlxText;
	var rainbowCanvas:FlxSprite;
	var codeTxt:FlxText;
	var cursorSpr:FlxSprite;
	var statusBar:FlxSprite;
	var statusTxt:FlxText;
	var toastTxt:FlxText;

	var btnExport:FlxSprite;
	var btnExportTxt:FlxText;
	var btnCopy:FlxSprite;
	var btnCopyTxt:FlxText;
	var btnPrevFile:FlxSprite;
	var btnPrevFileTxt:FlxText;
	var btnNextFile:FlxSprite;
	var btnNextFileTxt:FlxText;
	var btnClose:FlxSprite;
	var btnCloseTxt:FlxText;

	var curTab:Int = 0; // 0 = Converted, 1 = Original, 2 = Log
	var scrollY:Int = 0;
	var maxScrollY:Int = 0;
	var visibleLines:Int = 24;

	var linesCache:Array<String> = [];

	// Code Editing Cursor State
	var cursorLine:Int = 0;
	var cursorCol:Int = 0;
	var cursorTimer:Float = 0;
	var cursorVisible:Bool = true;

	var codeAreaX:Float = 0;
	var codeAreaY:Float = 0;
	var codeAreaW:Int = 0;
	var codeAreaH:Int = 0;
	var lineHeight:Float = 17.5;
	var charWidth:Float = 7.2;

	public function new(songName:String = "", modchartHint:String = "") {
		super();
		this.songName = (songName != null && songName != "") ? songName.toLowerCase() : "unknown";
		this.modchartHint = modchartHint;
	}

	override public function create():Void {
		super.create();

		// Dim background
		bgDim = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0x88000000);
		bgDim.scrollFactor.set(0, 0);
		add(bgDim);

		// Editor main window (VS Code styling)
		var winWidth = 1160;
		var winHeight = 640;
		var winX = (FlxG.width - winWidth) / 2;
		var winY = (FlxG.height - winHeight) / 2;

		// Outer border
		var border = new FlxSprite(winX - 2, winY - 2).makeGraphic(winWidth + 4, winHeight + 4, COLOR_BORDER);
		border.scrollFactor.set(0, 0);
		add(border);

		// Main editor background
		editorBg = new FlxSprite(winX, winY).makeGraphic(winWidth, winHeight, COLOR_BG);
		editorBg.scrollFactor.set(0, 0);
		add(editorBg);

		// Top title bar
		titleBar = new FlxSprite(winX, winY).makeGraphic(winWidth, 42, COLOR_TITLEBAR);
		titleBar.scrollFactor.set(0, 0);
		add(titleBar);

		titleTxt = new FlxText(winX + 16, winY + 6, winWidth - 32, "VS CODE LUA CONVERTER & EDITOR - Leather to Psych Format", 15);
		titleTxt.setFormat(Paths.font("vcr.ttf"), 15, FlxColor.WHITE, LEFT);
		titleTxt.scrollFactor.set(0, 0);
		add(titleTxt);

		fileInfoTxt = new FlxText(winX + 16, winY + 24, winWidth - 32, 'Song: ${songName}', 12);
		fileInfoTxt.setFormat(Paths.font("vcr.ttf"), 12, 0xFF9CDCFE, LEFT);
		fileInfoTxt.scrollFactor.set(0, 0);
		add(fileInfoTxt);

		// Tab buttons
		var tabNames = ["[ CONVERTED (PSYCH) ]", "[ ORIGINAL (LEATHER) ]", "[ CONVERSION LOG ]"];
		var tabX = winX + 14;
		var tabY = winY + 46;
		var tabW = 200;
		var tabH = 30;

		for (i in 0...tabNames.length) {
			var tabSpr = new FlxSprite(tabX + (i * (tabW + 6)), tabY).makeGraphic(tabW, tabH, (i == 0 ? COLOR_TAB_ACTIVE : COLOR_TAB_INACTIVE));
			tabSpr.scrollFactor.set(0, 0);
			add(tabSpr);

			var tabTxt = new FlxText(tabSpr.x, tabSpr.y + 6, tabW, tabNames[i], 12);
			tabTxt.setFormat(Paths.font("vcr.ttf"), 12, (i == 0 ? FlxColor.WHITE : 0xFFCCCCCC), CENTER);
			tabTxt.scrollFactor.set(0, 0);
			add(tabTxt);

			tabButtons.push({spr: tabSpr, txt: tabTxt});
		}

		// Code viewing & editing area
		codeAreaY = tabY + tabH + 6;
		codeAreaH = Std.int(winHeight - (codeAreaY - winY) - 46);

		// Line number gutter
		var gutterW:Int = 60;
		gutterBg = new FlxSprite(winX + 14, codeAreaY).makeGraphic(gutterW, codeAreaH, COLOR_GUTTER);
		gutterBg.scrollFactor.set(0, 0);
		add(gutterBg);

		gutterTxt = new FlxText(winX + 16, codeAreaY + 6, gutterW - 10, "", 12);
		gutterTxt.setFormat(Paths.font("vcr.ttf"), 12, COLOR_LINE_NUM, RIGHT);
		gutterTxt.scrollFactor.set(0, 0);
		add(gutterTxt);

		// Code text area
		codeAreaX = winX + 14 + gutterW + 8;
		codeAreaW = Std.int(winWidth - (gutterW + 36));

		var codeInnerBg = new FlxSprite(codeAreaX - 4, codeAreaY).makeGraphic(codeAreaW + 4, codeAreaH, COLOR_BG);
		codeInnerBg.scrollFactor.set(0, 0);
		add(codeInnerBg);

		// Rainbow indent canvas (Indent Rainbow plugin visual effect)
		rainbowCanvas = new FlxSprite(codeAreaX, codeAreaY).makeGraphic(codeAreaW, codeAreaH, FlxColor.TRANSPARENT, true);
		rainbowCanvas.scrollFactor.set(0, 0);
		add(rainbowCanvas);

		codeTxt = new FlxText(codeAreaX, codeAreaY + 6, codeAreaW, "", 12);
		codeTxt.setFormat(Paths.font("vcr.ttf"), 12, 0xFFD4D4D4, LEFT);
		codeTxt.scrollFactor.set(0, 0);
		add(codeTxt);

		// Blinking VS Code Cursor
		cursorSpr = new FlxSprite(codeAreaX, codeAreaY + 6).makeGraphic(2, 14, COLOR_CURSOR);
		cursorSpr.scrollFactor.set(0, 0);
		cursorSpr.visible = false;
		add(cursorSpr);

		// Bottom Status Bar
		var statusY = winY + winHeight - 36;
		statusBar = new FlxSprite(winX, statusY).makeGraphic(winWidth, 36, COLOR_TITLEBAR);
		statusBar.scrollFactor.set(0, 0);
		add(statusBar);

		statusTxt = new FlxText(winX + 16, statusY + 8, 480, "Ready | Lua 5.1 | UTF-8", 12);
		statusTxt.setFormat(Paths.font("vcr.ttf"), 12, 0xFFCCCCCC, LEFT);
		statusTxt.scrollFactor.set(0, 0);
		add(statusTxt);

		toastTxt = new FlxText(winX + 460, statusY + 8, 240, "", 12);
		toastTxt.setFormat(Paths.font("vcr.ttf"), 12, FlxColor.LIME, CENTER);
		toastTxt.scrollFactor.set(0, 0);
		add(toastTxt);

		// Bottom Action Buttons
		var bx = winX + winWidth - 440;

		// Export Button
		btnExport = new FlxSprite(bx, statusY + 5).makeGraphic(120, 26, COLOR_ACCENT);
		btnExport.scrollFactor.set(0, 0);
		add(btnExport);

		btnExportTxt = new FlxText(btnExport.x, btnExport.y + 5, 120, "EXPORT PSYCH", 11);
		btnExportTxt.setFormat(Paths.font("vcr.ttf"), 11, FlxColor.WHITE, CENTER);
		btnExportTxt.scrollFactor.set(0, 0);
		add(btnExportTxt);

		// Copy Button
		btnCopy = new FlxSprite(bx + 130, statusY + 5).makeGraphic(100, 26, 0xFF388A34);
		btnCopy.scrollFactor.set(0, 0);
		add(btnCopy);

		btnCopyTxt = new FlxText(btnCopy.x, btnCopy.y + 5, 100, "COPY CODE", 11);
		btnCopyTxt.setFormat(Paths.font("vcr.ttf"), 11, FlxColor.WHITE, CENTER);
		btnCopyTxt.scrollFactor.set(0, 0);
		add(btnCopyTxt);

		// Prev / Next file buttons
		btnPrevFile = new FlxSprite(winX + 630, tabY).makeGraphic(70, tabH, 0xFF3A3D41);
		btnPrevFile.scrollFactor.set(0, 0);
		add(btnPrevFile);

		btnPrevFileTxt = new FlxText(btnPrevFile.x, btnPrevFile.y + 6, 70, "< PREV", 11);
		btnPrevFileTxt.setFormat(Paths.font("vcr.ttf"), 11, FlxColor.WHITE, CENTER);
		btnPrevFileTxt.scrollFactor.set(0, 0);
		add(btnPrevFileTxt);

		btnNextFile = new FlxSprite(winX + 706, tabY).makeGraphic(70, tabH, 0xFF3A3D41);
		btnNextFile.scrollFactor.set(0, 0);
		add(btnNextFile);

		btnNextFileTxt = new FlxText(btnNextFile.x, btnNextFile.y + 6, 70, "NEXT >", 11);
		btnNextFileTxt.setFormat(Paths.font("vcr.ttf"), 11, FlxColor.WHITE, CENTER);
		btnNextFileTxt.scrollFactor.set(0, 0);
		add(btnNextFileTxt);

		// Close button
		btnClose = new FlxSprite(bx + 240, statusY + 5).makeGraphic(90, 26, 0xFFD71526);
		btnClose.scrollFactor.set(0, 0);
		add(btnClose);

		btnCloseTxt = new FlxText(btnClose.x, btnClose.y + 5, 90, "CLOSE (ESC)", 11);
		btnCloseTxt.setFormat(Paths.font("vcr.ttf"), 11, FlxColor.WHITE, CENTER);
		btnCloseTxt.scrollFactor.set(0, 0);
		add(btnCloseTxt);

		// Hook interactive text input
		if (FlxG.stage != null && FlxG.stage.window != null) {
			FlxG.stage.window.onTextInput.add(onTextInput);
		}

		scanSongLuaFiles();
		loadCurrentFile();
	}

	override public function destroy():Void {
		if (FlxG.stage != null && FlxG.stage.window != null) {
			FlxG.stage.window.onTextInput.remove(onTextInput);
		}
		super.destroy();
	}

	function scanSongLuaFiles():Void {
		foundFiles = [];
		#if sys
		var curMod:String = Options.getData("curMod");
		var searchDirs:Array<String> = [
			'mods/$curMod/data/song data/$songName/',
			'data/song data/$songName/',
			'mods/$curMod/data/$songName/',
			'data/$songName/',
			'mods/$curMod/modcharts/',
			'data/modcharts/',
			'mods/$curMod/scripts/',
			'data/scripts/'
		];

		for (dir in searchDirs) {
			if (FileSystem.exists(dir) && FileSystem.isDirectory(dir)) {
				for (file in FileSystem.readDirectory(dir)) {
					if (file.toLowerCase().endsWith(".lua")) {
						var fullPath = dir + file;
						var alreadyIn = false;
						for (f in foundFiles) {
							if (f.path == fullPath) {
								alreadyIn = true;
								break;
							}
						}
						if (!alreadyIn) {
							foundFiles.push({name: file, path: fullPath});
						}
					}
				}
			}
		}
		#end

		if (foundFiles.length == 0) {
			foundFiles.push({
				name: 'sample-$songName.lua',
				path: ""
			});
		}
	}

	function loadCurrentFile():Void {
		if (foundFiles.length == 0) return;
		if (curFileIndex < 0) curFileIndex = 0;
		if (curFileIndex >= foundFiles.length) curFileIndex = foundFiles.length - 1;

		var cur = foundFiles[curFileIndex];
		fileInfoTxt.text = 'File [${curFileIndex + 1}/${foundFiles.length}]: ${cur.name} | Path: ${cur.path != "" ? cur.path : "(Template / Sample)"}';

		#if sys
		if (cur.path != "" && FileSystem.exists(cur.path)) {
			try {
				originalCode = File.getContent(cur.path);
			} catch (e:Dynamic) {
				originalCode = '-- Error reading file: $e\n';
			}
		} else {
			originalCode = getSampleCode();
		}
		#else
		originalCode = getSampleCode();
		#end

		// Perform conversion
		conversionResult = LuaToPsychConverter.convert(originalCode);
		convertedCode = conversionResult.convertedCode;

		// Update tab 3 text with conversion count
		tabButtons[2].txt.text = '[ CHANGES LOG (${conversionResult.totalChanges}) ]';

		scrollY = 0;
		cursorLine = 0;
		cursorCol = 0;
		updateDisplayContent();
	}

	function getSampleCode():String {
		return '-- Leather Engine Lua Sample for: ' + songName + '\n'
			+ 'function start(song)\n'
			+ '    initShader("glitch", "glitch")\n'
			+ '    setActorShader("boyfriend", "glitch")\n'
			+ '    makeSprite("stageBack", "stages/stageback", 0, 0)\n'
			+ '    setActorScroll(0.8, 0.8, "stageBack")\n'
			+ '    setActorScaleXY(1.2, 1.2, "stageBack")\n'
			+ '    setActorAlpha(0.75, "stageBack")\n'
			+ '    setActorX(100, "stageBack")\n'
			+ '    playCharAnim("dad", "singUP", true)\n'
			+ '    screenShake(0.04, 4)\n'
			+ '    flashCamera("hud", "#FFFFFF", 1)\n'
			+ '    -- Function that has no Psych equivalent (auto-handled via runHaxeCode polyfill!):\n'
			+ '    setActorColorTrans("boyfriend", 255, 100, 50)\n'
			+ 'end\n\n'
			+ 'function stepHit(step)\n'
			+ '    if step == 64 then\n'
			+ '        setCustomShaderFloat("glitch", "uTime", 1.5)\n'
			+ '        tweenActorColorTrans("dad", 0, 0, 0, 255, 255, 255, 1.0, "")\n'
			+ '    end\n'
			+ 'end\n';
	}

	function updateDisplayContent():Void {
		var content:String = "";
		switch (curTab) {
			case 0:
				content = convertedCode;
			case 1:
				content = originalCode;
			case 2:
				var logLines:Array<String> = [];
				logLines.push('-- === CONVERSION LOG: ' + conversionResult.totalChanges + ' replacements made ===');
				if (conversionResult.entries.length == 0) {
					logLines.push('-- No functions needed conversion (already Psych compatible or unmapped).');
				} else {
					for (e in conversionResult.entries) {
						logLines.push('Line ' + e.line + ': ' + e.original + ' -> ' + e.converted + ' (' + e.description + ')');
					}
				}
				content = logLines.join("\n");
		}

		linesCache = content.split("\n");
		if (linesCache.length == 0) linesCache = [""];

		maxScrollY = Math.floor(Math.max(0, linesCache.length - visibleLines));
		if (scrollY > maxScrollY) scrollY = maxScrollY;
		if (cursorLine >= linesCache.length) cursorLine = linesCache.length - 1;
		if (cursorLine < 0) cursorLine = 0;

		var curLineStr = linesCache[cursorLine];
		if (cursorCol > curLineStr.length) cursorCol = curLineStr.length;
		if (cursorCol < 0) cursorCol = 0;

		renderVisibleLines();
	}

	function renderVisibleLines():Void {
		var displayedLines:Array<String> = [];
		var lineNumbers:Array<String> = [];

		var endLine = Std.int(Math.min(linesCache.length, scrollY + visibleLines));
		for (i in scrollY...endLine) {
			lineNumbers.push(Std.string(i + 1));
			displayedLines.push(linesCache[i]);
		}

		gutterTxt.text = lineNumbers.join("\n");
		codeTxt.text = displayedLines.join("\n");

		// Draw VS Code Indent Rainbow Guides on canvas
		drawIndentRainbow(scrollY, endLine);

		// Update cursor position and visibility
		updateCursorGraphic();

		var total = linesCache.length;
		statusTxt.text = 'Ln ${cursorLine + 1}, Col ${cursorCol + 1} | Total: $total | Changes: ${conversionResult.totalChanges} | UTF-8 | Indent: 4 spaces';
	}

	/**
	 * Draws colored indentation guides and background bars (Indent Rainbow effect)
	 */
	function drawIndentRainbow(startLine:Int, endLine:Int):Void {
		if (rainbowCanvas == null || rainbowCanvas.pixels == null) return;

		var pixels = rainbowCanvas.pixels;
		pixels.lock();
		pixels.fillRect(pixels.rect, 0x00000000);

		var indentStepPx:Float = 4 * charWidth; // 4 spaces per indent level

		for (i in startLine...endLine) {
			var lineStr = linesCache[i];
			var leadingSpaces = countLeadingSpaces(lineStr);
			var indentLevels = Std.int(leadingSpaces / 4);

			var lineY:Int = Std.int((i - startLine) * lineHeight) + 6;

			for (level in 0...indentLevels) {
				var guideColor = RAINBOW_GUIDES[level % RAINBOW_GUIDES.length];
				var tintColor = RAINBOW_TINTS[level % RAINBOW_TINTS.length];

				var guideX:Int = Std.int(level * indentStepPx);
				var bandW:Int = Std.int(indentStepPx);

				// Draw soft colored indent background band
				var bandRect = new openfl.geom.Rectangle(guideX, lineY, bandW, Std.int(lineHeight));
				pixels.fillRect(bandRect, tintColor);

				// Draw vertical guide line
				var guideRect = new openfl.geom.Rectangle(guideX, lineY, 1, Std.int(lineHeight));
				pixels.fillRect(guideRect, guideColor);
			}
		}

		pixels.unlock();
	}

	static function countLeadingSpaces(str:String):Int {
		if (str == null) return 0;
		var count = 0;
		for (i in 0...str.length) {
			var char = str.charAt(i);
			if (char == " ") {
				count++;
			} else if (char == "\t") {
				count += 4;
			} else {
				break;
			}
		}
		return count;
	}

	function updateCursorGraphic():Void {
		if (curTab == 2) {
			cursorSpr.visible = false;
			return;
		}

		if (cursorLine >= scrollY && cursorLine < scrollY + visibleLines) {
			var screenLine = cursorLine - scrollY;
			cursorSpr.x = codeAreaX + (cursorCol * charWidth);
			cursorSpr.y = codeAreaY + (screenLine * lineHeight) + 6;
			cursorSpr.visible = cursorVisible;
		} else {
			cursorSpr.visible = false;
		}
	}

	function onTextInput(text:String):Void {
		if (curTab == 2 || text == null || text.length == 0) return;

		// Insert typed character at cursor position
		var curLineStr = linesCache[cursorLine];
		var before = curLineStr.substring(0, cursorCol);
		var after = curLineStr.substring(cursorCol);

		linesCache[cursorLine] = before + text + after;
		cursorCol += text.length;

		saveCurrentTabContent();
		renderVisibleLines();
	}

	function saveCurrentTabContent():Void {
		var newContent = linesCache.join("\n");
		if (curTab == 0) {
			convertedCode = newContent;
		} else if (curTab == 1) {
			originalCode = newContent;
			// Re-run conversion if original was edited
			conversionResult = LuaToPsychConverter.convert(originalCode);
			convertedCode = conversionResult.convertedCode;
			tabButtons[2].txt.text = '[ CHANGES LOG (${conversionResult.totalChanges}) ]';
		}
	}

	override public function update(elapsed:Float):Void {
		super.update(elapsed);

		// Cursor blinking timer
		cursorTimer += elapsed;
		if (cursorTimer >= 0.5) {
			cursorTimer = 0;
			cursorVisible = !cursorVisible;
			updateCursorGraphic();
		}

		// Handle mouse scrolling
		if (FlxG.mouse.wheel != 0) {
			scrollY -= FlxG.mouse.wheel * 3;
			if (scrollY < 0) scrollY = 0;
			if (scrollY > maxScrollY) scrollY = maxScrollY;
			renderVisibleLines();
		}

		// Mouse click inside code editor area to position cursor
		if (FlxG.mouse.justPressed && curTab != 2) {
			if (FlxG.mouse.x >= codeAreaX && FlxG.mouse.x <= codeAreaX + codeAreaW
				&& FlxG.mouse.y >= codeAreaY && FlxG.mouse.y <= codeAreaY + codeAreaH) {
				var clickedLine = scrollY + Std.int((FlxG.mouse.y - codeAreaY - 6) / lineHeight);
				if (clickedLine >= 0 && clickedLine < linesCache.length) {
					cursorLine = clickedLine;
					var curStr = linesCache[cursorLine];
					var clickedCol = Std.int(Math.round((FlxG.mouse.x - codeAreaX) / charWidth));
					cursorCol = Std.int(Math.max(0, Math.min(curStr.length, clickedCol)));
					cursorVisible = true;
					cursorTimer = 0;
					renderVisibleLines();
				}
			}
		}

		// Interactive editing keyboard shortcuts
		if (curTab != 2) {
			handleEditorKeys();
		} else {
			// Tab 2 (Log viewer navigation)
			if (FlxG.keys.justPressed.UP) {
				scrollY = Std.int(Math.max(0, scrollY - 1));
				renderVisibleLines();
			} else if (FlxG.keys.justPressed.DOWN) {
				scrollY = Std.int(Math.min(maxScrollY, scrollY + 1));
				renderVisibleLines();
			}
		}

		// Close substate
		if (FlxG.keys.justPressed.ESCAPE || (FlxG.mouse.justPressed && FlxG.mouse.overlaps(btnClose))) {
			close();
			return;
		}

		// Tab clicks
		if (FlxG.mouse.justPressed) {
			for (i in 0...tabButtons.length) {
				if (FlxG.mouse.overlaps(tabButtons[i].spr)) {
					curTab = i;
					for (j in 0...tabButtons.length) {
						tabButtons[j].spr.makeGraphic(200, 30, (j == curTab ? COLOR_TAB_ACTIVE : COLOR_TAB_INACTIVE));
						tabButtons[j].txt.color = (j == curTab ? FlxColor.WHITE : 0xFFCCCCCC);
					}
					scrollY = 0;
					updateDisplayContent();
					break;
				}
			}

			// Copy to clipboard
			if (FlxG.mouse.overlaps(btnCopy)) {
				var codeToCopy = (curTab == 1) ? originalCode : convertedCode;
				lime.system.Clipboard.text = codeToCopy;
				showToast("COPIED TO CLIPBOARD!");
			}

			// Export file
			if (FlxG.mouse.overlaps(btnExport)) {
				exportPsychLua();
			}

			// Prev file
			if (FlxG.mouse.overlaps(btnPrevFile)) {
				curFileIndex--;
				if (curFileIndex < 0) curFileIndex = foundFiles.length - 1;
				loadCurrentFile();
			}

			// Next file
			if (FlxG.mouse.overlaps(btnNextFile)) {
				curFileIndex++;
				if (curFileIndex >= foundFiles.length) curFileIndex = 0;
				loadCurrentFile();
			}
		}
	}

	function handleEditorKeys():Void {
		var curLineStr = linesCache[cursorLine];
		var changed = false;

		// Backspace
		if (FlxG.keys.justPressed.BACKSPACE) {
			if (cursorCol > 0) {
				var before = curLineStr.substring(0, cursorCol - 1);
				var after = curLineStr.substring(cursorCol);
				linesCache[cursorLine] = before + after;
				cursorCol--;
				changed = true;
			} else if (cursorLine > 0) {
				// Merge with previous line
				var prevLineStr = linesCache[cursorLine - 1];
				cursorCol = prevLineStr.length;
				linesCache[cursorLine - 1] = prevLineStr + curLineStr;
				linesCache.splice(cursorLine, 1);
				cursorLine--;
				changed = true;
			}
		}
		// Delete
		else if (FlxG.keys.justPressed.DELETE) {
			if (cursorCol < curLineStr.length) {
				var before = curLineStr.substring(0, cursorCol);
				var after = curLineStr.substring(cursorCol + 1);
				linesCache[cursorLine] = before + after;
				changed = true;
			} else if (cursorLine < linesCache.length - 1) {
				// Merge with next line
				linesCache[cursorLine] = curLineStr + linesCache[cursorLine + 1];
				linesCache.splice(cursorLine + 1, 1);
				changed = true;
			}
		}
		// Enter (with auto-indent)
		else if (FlxG.keys.justPressed.ENTER) {
			var indentSpaces = "";
			var leadingCount = countLeadingSpaces(curLineStr);
			for (_ in 0...leadingCount) indentSpaces += " ";

			var before = curLineStr.substring(0, cursorCol);
			var after = curLineStr.substring(cursorCol);

			linesCache[cursorLine] = before;
			linesCache.insert(cursorLine + 1, indentSpaces + after);

			cursorLine++;
			cursorCol = indentSpaces.length;
			changed = true;
		}
		// Tab key (insert 4 spaces)
		else if (FlxG.keys.justPressed.TAB) {
			var before = curLineStr.substring(0, cursorCol);
			var after = curLineStr.substring(cursorCol);
			linesCache[cursorLine] = before + "    " + after;
			cursorCol += 4;
			changed = true;
		}
		// Arrow Navigation
		else if (FlxG.keys.justPressed.LEFT) {
			if (cursorCol > 0) {
				cursorCol--;
			} else if (cursorLine > 0) {
				cursorLine--;
				cursorCol = linesCache[cursorLine].length;
			}
			resetCursorBlink();
		} else if (FlxG.keys.justPressed.RIGHT) {
			if (cursorCol < curLineStr.length) {
				cursorCol++;
			} else if (cursorLine < linesCache.length - 1) {
				cursorLine++;
				cursorCol = 0;
			}
			resetCursorBlink();
		} else if (FlxG.keys.justPressed.UP) {
			if (cursorLine > 0) {
				cursorLine--;
				var targetLen = linesCache[cursorLine].length;
				if (cursorCol > targetLen) cursorCol = targetLen;
			}
			resetCursorBlink();
		} else if (FlxG.keys.justPressed.DOWN) {
			if (cursorLine < linesCache.length - 1) {
				cursorLine++;
				var targetLen = linesCache[cursorLine].length;
				if (cursorCol > targetLen) cursorCol = targetLen;
			}
			resetCursorBlink();
		} else if (FlxG.keys.justPressed.HOME) {
			cursorCol = 0;
			resetCursorBlink();
		} else if (FlxG.keys.justPressed.END) {
			cursorCol = curLineStr.length;
			resetCursorBlink();
		}

		// Keep cursor in view vertically
		if (cursorLine < scrollY) {
			scrollY = cursorLine;
		} else if (cursorLine >= scrollY + visibleLines) {
			scrollY = cursorLine - visibleLines + 1;
		}

		maxScrollY = Math.floor(Math.max(0, linesCache.length - visibleLines));
		if (scrollY > maxScrollY) scrollY = maxScrollY;
		if (scrollY < 0) scrollY = 0;

		if (changed) {
			saveCurrentTabContent();
			resetCursorBlink();
		}

		renderVisibleLines();
	}

	function resetCursorBlink():Void {
		cursorVisible = true;
		cursorTimer = 0;
	}

	function showToast(msg:String):Void {
		toastTxt.text = msg;
		new FlxTimer().start(2.5, function(_) {
			toastTxt.text = "";
		});
	}

	function exportPsychLua():Void {
		var cur = foundFiles[curFileIndex];
		var rawName = (cur != null && cur.name != "") ? cur.name : '$songName.lua';
		if (!rawName.startsWith("psych-")) rawName = "psych-" + rawName;

		#if sys
		var curMod:String = Options.getData("curMod");
		var outDir:String = 'mods/$curMod/data/song data/$songName/';
		if (!FileSystem.exists(outDir)) {
			FileSystem.createDirectory(outDir);
		}
		var fullOut = outDir + rawName;
		try {
			File.saveContent(fullOut, convertedCode);
			showToast('SAVED TO: $rawName');
		} catch (e:Dynamic) {
			showToast('SAVE ERROR: $e');
		}
		#else
		var f = new FileReference();
		f.save(convertedCode.trim(), rawName);
		showToast('EXPORTING: $rawName');
		#end
	}
}
