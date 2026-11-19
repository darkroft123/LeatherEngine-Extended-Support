package toolbox;

import toolbox.util.NewModState;
import ui.Option;
import states.PlayState;
import states.OptionsMenu;
import toolbox.RTXDebug;
import utilities.Localization;
#if CAMERA_TOOLS
import pages.ModchartEditor;
#end

class ToolboxState extends OptionsMenu {
	#if MODDING_ALLOWED override inline function addModOptions() {}#end

	override private function initPages():Void {
		pages = [
			"Categories" => [
				#if MODDING_ALLOWED
				new GameStateOption(Localization.getOptionName("New Mod", "New Mod"), NewModState, Localization.getOptionDesc("New Mod", "Create a new mod")),
				#end
				new PageOption(Localization.getOptionName("Tools", "Tools"), "Tools", Localization.getOptionDesc("Tools", " Show tools like character creator and chart editor.")),
				new PageOption(Localization.getOptionName("Documentation", "Documentation"), "Documentation", Localization.getOptionDesc("Documentation", "View the documentation"))
			],
			"Tools" => [
				new PageOption(Localization.getOptionName("Back", "Back"), "Categories", Localization.getOptionDesc("Back", "Go back to the main menu.")),
				new GameStateOption(Localization.getOptionName("Charter", "Charter"), CharterSelectionState, Localization.getOptionDesc("Charter", "Open the chart editor.")),
				new GameStateOption(Localization.getOptionName("RTX Debug", "RTX Debug"), () -> new RTXDebug("dad"), Localization.getOptionDesc("RTX Debug", "Open the RTX editor")),
				new CharacterCreatorOption(Localization.getOptionName("Character Creator", "Character Creator"), () -> new CharacterCreator("dad", "stage"), Localization.getOptionDesc("Character Creator", "Open the character creator.")),
				new GameStateOption(Localization.getOptionName("Stage Editor", "Stage Editor"), () -> new StageMakingState("stage"), Localization.getOptionDesc("Stage Editor", "Open the stage editor.")),
				#if MODCHARTING_TOOLS
				new GameStateOption(Localization.getOptionName("Modchart Editor", "Modchart Editor"), modcharting.ModchartEditorState, Localization.getOptionDesc("Modchart Editor", "Open the modchart editor.")),
				#end
				#if CAMERA_TOOLS
				new GameStateOption(Localization.getOptionName("Camera Editor", "Camera Editor"), ModchartEditor, Localization.getOptionDesc("Camera Editor", "Open the camera modchart editor."))
				#end
			],
			"Documentation" => [
				new PageOption(Localization.getOptionName("Back", "Back"), "Categories", Localization.getOptionDesc("Back", "Go back to the main menu")),
				new OpenUrlOption(Localization.getOptionName("Wiki", "Wiki"), "Wiki", "https://github.com/Leather128/LeatherEngine/wiki", Localization.getOptionDesc("Wiki", "View the Wiki.")),
				new OpenUrlOption(Localization.getOptionName("HScript Api", "HScript Api"), "HScript Api", "https://github.com/Vortex2Oblivion/LeatherEngine/wiki/HScript-api-documentation-(WIP)",
					Localization.getOptionDesc("HScript Api", "View the HScript API.")),
				new OpenUrlOption(Localization.getOptionName("Lua Api", "Lua Api"), "Lua Api", "https://github.com/Vortex2Oblivion/LeatherEngine/wiki/Lua-api-documentation-(WIP)",
					Localization.getOptionDesc("Lua Api", "View the Lua API.")),
				new OpenUrlOption(Localization.getOptionName("Classes List", "Classes List"), "Classes List", "https://vortex2oblivion.github.io/LeatherEngine/", Localization.getOptionDesc("Classes List", "View the classes list.")),
				new OpenUrlOption(Localization.getOptionName("Polymod Docs", "Polymod Docs"), "Polymod Docs", "https://polymod.io/docs/", Localization.getOptionDesc("Polymod Docs", "View the Polymod docs."))
			]
		];
		if (PlayState.instance == null) {
			pages["Tools"][5] = null;
			#if CAMERA_TOOLS
			pages["Tools"][6] = null;
			#end
		}
	}

	override function create() {
		super.create();
	}
}
