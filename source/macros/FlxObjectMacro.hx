package macros;

#if macro
import haxe.macro.Compiler;
import haxe.macro.Context;
import haxe.macro.Expr;
#end

class FlxObjectMacro {
    public static function removeScreenCenterInline() {
        #if macro
        var fields = Context.getBuildFields();
        var field:Field = [for (field in fields) if (field.name == 'screenCenter') field][0];
        switch (field.kind) {
            case FFun(f):
                field.access = [Access.APublic];
                field.kind = FFun({
                    args: [
                        {name: 'axes', type: (macro :flixel.util.FlxAxes), value: macro flixel.util.FlxAxes.XY}
                    ],
                    expr: macro {
                        if (axes.x)
                            this.x = (flixel.FlxG.width - this.width) / 2;

                        if (axes.y)
                            this.y = (flixel.FlxG.height - this.height) / 2;

                        return this;
                    }
                });
            default:
        }
        return fields;
        #end
    }
}