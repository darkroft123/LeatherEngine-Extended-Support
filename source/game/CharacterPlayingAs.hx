package game;

enum abstract CharacterPlayingAs(Int) to Int from Int {
    var BF:Int = 0;
    var OPPONENT:Int = 1;
    var BOTH:Int = -1;
}