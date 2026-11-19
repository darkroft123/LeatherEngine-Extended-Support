#pragma header
uniform vec2 uBlocksize;

void main()
{
	vec2 blocks = openfl_TextureSize / uBlocksize;
	ofl_FragColor = flixel_texture2D(bitmap, floor(openfl_TextureCoordv * blocks) / blocks);
}
