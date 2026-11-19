@echo off
echo ===================================================
echo Installing Dark's Collection Custom Dependencies (Pinned)
echo ===================================================

REM haxelib --global update haxelib
REM haxelib fixrepo

REM Toolchain & Core
haxelib git hxcpp https://github.com/FunkinCrew/hxcpp 450d112e50acff57b1bc9d584dcf1374c9e33995
haxelib install format
haxelib install hxp
haxelib install hxgamejolt-api

REM Darkroft Custom Engine Forks (Pinned)
haxelib --skip-dependencies git lime https://github.com/darkroft123/lime.git b792310922f0781858fdc245ef375cd3d2e0c637
haxelib --skip-dependencies git openfl https://github.com/darkroft123/openfl.git cf469f6d23d72c5586ff7d67fde96c7f8577faf3
haxelib --skip-dependencies git flixel https://github.com/darkroft123/flixel.git 6ca907b0b483ffbb929b60926bd836aa4c2ce2ca
haxelib --skip-dependencies git flxanimate https://github.com/darkroft123/flxanimate.git 5ee9de4694d7d1f3ad246ad4e39ace8114170deb

REM Flixel Ecosystem Addons (Pinned)
haxelib --skip-dependencies git flixel-addons https://github.com/swordcubes-grave-of-shite/flixel-addons 3933851d9a0ae07a5e91850a3d4b74fce9658a10
haxelib --skip-dependencies git flixel-ui https://github.com/HaxeFlixel/flixel-ui ff2f30148cb1a7c9b10373aa89cf1e0d7aafb648

REM Scripting & Modding Runtimes (Pinned)
haxelib git linc_luajit https://github.com/Leather128/linc_luajit.git 4809042f225c347365e379a2f09ec25b4a6ccc5b
haxelib git hscript-improved https://github.com/CodenameCrew/hscript-improved fe673c21b278819805aaa730216ec527c2507443
haxelib git scriptless-polymod https://github.com/Vortex2Oblivion/scriptless-polymod 6894bc2e405b4a5e3990c6e319a601ed3389904f

REM Media, Shaders, Modcharting & Tools (Pinned)
haxelib git hxNoise https://github.com/whuop/hxNoise 80eee9f6ff8c6aa3e1fa51b12827d34916730abb
haxelib git hxvlc https://github.com/Vortex2Oblivion/hxvlc ad39b1dd6e3bdf29622161fda760641df4c824ce
haxelib --skip-dependencies install hxdiscord_rpc
haxelib git foxlite https://github.com/dwdvIl/foxlite 287cc98b653cbfde01ae2e5da572ba7364abfd96
haxelib git fnf-modcharting-tools https://github.com/darkroft123/FNF-Modcharting-Tools.git 001775c2b1032488ecaacff7dff5d3aeb8db678e
haxelib git camera-utilities-dc https://github.com/darkroft123/Camera-utilities-dc.git 53095bdce9bd5c3cf36d29574bfb7e9c1ec99813
haxelib git grig.audio https://gitlab.com/haxe-grig/grig.audio 57f5d47f2533fd0c3dcd025a86cb86c0dfa0b6d2
haxelib git funkin.vis https://github.com/FunkinCrew/funkVis 1966f8fbbbc509ed90d4b520f3c49c084fc92fd6
haxelib git flixel-perspective https://github.com/Blossomical/flixel-perspective 2472b460b69074e1d7d4859d8348d8ef84e313b3

REM Project XML Required Utilities
haxelib install hxWindowColorMode 0.2.1
haxelib install kotoba 1.0.0
haxelib install hxcpp-debug-server

REM Rebuild Lime & CFFI binaries
haxelib --always set lime 8.2.2
haxelib run lime rebuild hxcpp
haxelib --always set lime git
haxelib --always run lime rebuild windows
haxelib --always run lime setup

echo ===================================================
echo Finished installing Dark's Collection dependencies.
echo ===================================================
