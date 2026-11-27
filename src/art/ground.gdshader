// The field's ground as crayon on paper: slanted strokes whose pressure rises and falls along them, and a grain per
// screen pixel. Sprites, the HUD and the words stay pixel art; only this one rectangle under them is drawn finer than
// a game pixel. src/main.gd puts it under the field and sets day from Painter.daylight() every frame.
shader_type canvas_item;

// The ground's colour for each game pixel (Painter.ground_map): grass, and the bare earth round the torch.
uniform sampler2D ground : filter_nearest, repeat_disable;
uniform vec4 paper : source_color = vec4(1.0, 0.957, 0.863, 1.0);
uniform float slant = -0.55; // radians the strokes lean
uniform float stroke = 1.0; // game pixels a stroke is wide
uniform float stroke_length = 3.0; // game pixels over which the pressure changes along a stroke
uniform float rough = 1.0; // game pixels the ground's colour is looked up within, so the earth's edge is not stepped
uniform float skip = 0.3; // by day, how far toward the paper the gaps between strokes go
// By night the gaps go dark instead, like scratch art: black under the colour. Strokes are lighter than the ground
// and gaps darker by about as much, so the ground keeps its colour on average and the night is as dark as before.
uniform float day = 1.0;
uniform float gap_dark = 0.6; // a gap at night: the ground colour times this
uniform float stroke_light = 1.4; // a stroke at night: the ground colour times this

// Dave Hoskins' hash12, which has no sin in it: fract(sin(x) * 43758.5) comes out in bands on some phone GPUs.
float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float pressure(float t, float band) {
	float i = floor(t);
	return mix(hash(vec2(i, band)), hash(vec2(i + 1.0, band)), smoothstep(0.0, 1.0, t - i));
}

void fragment() {
	// fwidth(UV) is how much UV one screen pixel covers, so the grain is one screen pixel at any window size and
	// nobody has to tell the shader how big the window is.
	vec2 px = floor(UV / fwidth(UV));
	vec2 size = vec2(textureSize(ground, 0));
	vec2 at = UV * size; // in game pixels
	float along = at.x * cos(slant) + at.y * sin(slant);
	float across = -at.x * sin(slant) + at.y * cos(slant);
	float band = floor(across / stroke);
	float p = pressure(along / stroke_length + band * 7.31, band);
	float grain = hash(px);
	float cover = clamp(0.45 + 0.6 * p - 0.5 * grain, 0.0, 1.0);
	vec2 nudge = (vec2(hash(px + 17.0), hash(px + 59.0)) - 0.5) * rough;
	vec3 base = texture(ground, (at + nudge) / size).rgb;
	vec3 by_day = mix(mix(base, paper.rgb, skip), base * (p > 0.8 ? 0.9 : 1.0), cover);
	vec3 by_night = mix(base * gap_dark, base * stroke_light, cover);
	COLOR = vec4(mix(by_night, by_day, day), 1.0);
}
