package game;

typedef FreeplayGroupData = {
    var id:Int;
    @:optional var name:String;
    
    @:optional var image:String;
    @:optional var font:String;
    @:optional var size:Null<Int>;
    @:optional var offsets:Array<Float>; // [x, y]
    
    @:optional var hue:Null<Float>;
    @:optional var contrast:Null<Float>;
    @:optional var brightness:Null<Float>;
    
    // Song text styles in FreeplayState (groupStyles)
    @:optional var songFont:String;
    @:optional var songFontSize:Null<Int>;
    @:optional var bordersize:Null<Float>;
    @:optional var outerBorderTop:String;
    @:optional var outerBorderBot:String;
    @:optional var midBorderTop:String;
    @:optional var midBorderBot:String;
    @:optional var innerBorderTop:String;
    @:optional var innerBorderBot:String;
    @:optional var mixGap:Null<Float>;
    @:optional var outerBorderSize:Null<Float>;
}
