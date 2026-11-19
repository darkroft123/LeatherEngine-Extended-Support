package utilities;

import sys.FileSystem;
import sys.io.File;
import haxe.xml.Access;
import openfl.utils.Assets;

class Localization {
    public static var languages:Array<String> = ["english", "español", "português"];

    private static var currentLang:String = "";
    private static var strings:Map<String, String> = new Map<String, String>();

    public static function normalizeLang(lang:String):String {
        if (lang == null) return "english";
        var l:String = lang.toLowerCase();
        if (l == "spanish" || l == "es" || l == "español" || l == "espanol") return "español";
        if (l == "portuguese" || l == "pt" || l == "português" || l == "portugues" || l == "pt-br") return "português";
        return "english";
    }

    public static function getLanguage():String {
        var lang:String = Options.getData("language");
        if (lang == null || lang == "") lang = "english";
        return normalizeLang(lang);
    }

    public static function setLanguage(lang:String):Void {
        var normalized = normalizeLang(lang);
        Options.setData(normalized, "language");
        loadLanguage(normalized, true);
    }

    public static function loadLanguage(?lang:String, forceReload:Bool = false):Void {
        if (lang == null || lang == "") lang = getLanguage();
        lang = normalizeLang(lang);

        if (!forceReload && currentLang == lang && strings.keys().hasNext()) return;

        strings.clear();
        currentLang = lang;

        var altLang:String = lang == "español" ? "espanol" : (lang == "português" ? "portugues" : lang);
        var langFileNames:Array<String> = [lang, altLang];

        var curMod:String = Options.getData("curMod");
        var filePaths:Array<String> = [];

        for (fname in langFileNames) {
            #if MODDING_ALLOWED
            if (curMod != null && curMod != "") {
                filePaths.push('mods/$curMod/data/languages/$fname.xml');
            }
            #end
            filePaths.push('assets/preload/data/languages/$fname.xml');
            filePaths.push('assets/data/languages/$fname.xml');
            filePaths.push('data/languages/$fname.xml');
        }

        var xmlString:String = "";

        // 1. Try direct FileSystem reading first
        for (p in filePaths) {
            try {
                if (FileSystem.exists(p)) {
                    xmlString = File.getContent(p);
                    if (xmlString != null && xmlString.length > 0) break;
                }
            } catch (e:Dynamic) {}
        }

        // 2. Fallback to OpenFL Assets API (both with assets/ and assets/preload/ prefixes)
        if (xmlString == null || xmlString == "") {
            var assetKeys:Array<String> = [];
            for (fname in langFileNames) {
                assetKeys.push('assets/data/languages/$fname.xml');
                assetKeys.push('assets/preload/data/languages/$fname.xml');
                assetKeys.push('data/languages/$fname.xml');
                assetKeys.push(Paths.file('data/languages/$fname.xml'));
            }

            for (ak in assetKeys) {
                try {
                    if (Assets.exists(ak)) {
                        xmlString = Assets.getText(ak);
                        if (xmlString != null && xmlString.length > 0) break;
                    }
                } catch (e:Dynamic) {}
            }
        }

        if (xmlString != null && xmlString.length > 0) {
            try {
                var rawXml:Xml = Xml.parse(xmlString);
                var access:Access = new Access(rawXml.firstElement());
                for (str in access.nodes.string) {
                    if (str.has.id) {
                        strings.set(str.att.id, str.innerData);
                    }
                }
            } catch (e:Dynamic) {
                trace("Error parsing language XML (" + lang + "): " + e);
            }
        } else {
            trace("Warning: Could not locate language XML file for: " + lang);
        }
    }

    public static function getString(id:String, defaultText:String = "", ?args:Array<Dynamic>):String {
        loadLanguage();
        var text:String = strings.exists(id) ? strings.get(id) : defaultText;
        if (args != null && args.length > 0) {
            for (i in 0...args.length) {
                text = StringTools.replace(text, "{" + i + "}", Std.string(args[i]));
            }
        }
        return text;
    }

    public static function getOptionName(key:String, defaultName:String):String {
        return getString(key + "_name", defaultName);
    }

    public static function getOptionDesc(key:String, defaultDesc:String):String {
        return getString(key + "_desc", defaultDesc);
    }
}
