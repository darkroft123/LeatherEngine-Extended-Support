package utilities;

class DevList
{
    public static function isBlocked(id:String):Bool
    {
        return false;
    }

    public static function getBlockReason(id:String):String
    {
        return null;
    }

    public static function isCurrentUserDev(?checkUser:String):Bool
    {
        return Options.getData("developer") == true;
    }

    public static function isDevVersion():Bool
    {
        return false;
    }

    public static function getByName(name:String):Dynamic
    {
        return null;
    }
}
