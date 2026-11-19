package game;

typedef FreeplaySong = {
    var name:String;
    @:optional var icon:Dynamic;

    var difficulties:Array<String>;
    var color:String;
    var week:Int;

    @:optional var isBlocked:Null<Bool>;

    @:optional var colorBG:Float;
    @:optional var bgs:Array<String>;
    @:optional var renders:Array<String>;

    @:optional var group:Int;
    @:optional var metadata:FreeplayMetadata;
    @:optional var menuConfig:FreeplayMenuConfig;
    @:optional var extraData:Dynamic;

    @:optional var intensity:Array<Float>;
}


typedef FreeplayMetadata = {
    @:optional var composer:Dynamic;
    @:optional var charter:Dynamic;
    @:optional var modcharter:Dynamic;
    @:optional var originalsong:Dynamic;
    @:optional var popupTime:Dynamic;
    @:optional var hue:Dynamic;
}

typedef FreeplayMenuConfig = {
    @:optional var canBeEntered:Bool;
    @:optional var showStats:Bool;
}

typedef SongTextExtraData = {
    @:optional var vipText:String;
    @:optional var createVipText:String;
    @:optional var letterSpacing:Int;
    @:optional var borderColor:Int;
    @:optional var borderSize:Float;
    @:optional var font:String;
    @:optional var opacity:Float;

    @:optional var outerBorderSize:Float;
    @:optional var midBorderSize:Float;
    @:optional var innerBorderSize:Float;

    @:optional var songFont:String;
    @:optional var songFontVIP:String;
    @:optional var songFontSize:String;
    @:optional var songFontSizeVIP:String;

    @:optional var outerBorderTop:String;
    @:optional var outerBorderBot:String;
    @:optional var midBorderTop:String;
    @:optional var midBorderBot:String;
    @:optional var innerBorderTop:String;
    @:optional var innerBorderBot:String;

    @:optional var outerBorderTopVIP:String;
    @:optional var outerBorderBotVIP:String;
    @:optional var midBorderTopVIP:String;
    @:optional var midBorderBotVIP:String;
    @:optional var innerBorderTopVIP:String;
    @:optional var innerBorderBotVIP:String;

    @:optional var vipOffsetX:Float;
    @:optional var vipOffsetY:Float;
    @:optional var vipLetterSpacing:Float;

    @:optional var mixGap:Float;
    @:optional var sobelStrength:Float;
    @:optional var sobelIntensity:Float;
}