shader_type canvas_item;
// Draws the wheat field from a tiny data texture (one texel per wheat cell):
//   R: state (0 standing, ~0.47 flattened, 1 part of a crop circle)
//   G: direction the stalks lie in (0..1 = 0..360 degrees)
//   B: standing -> golden wheat flag; circle -> circle slot (1..255)
//   A: growth (0 just regrowing .. 1 fully grown)
// circ_tex holds one texel per circle slot: R,G = centre cell, B = reveal
// radius in cells (255 = fully revealed), A = glow.

uniform sampler2D circ_tex : filter_nearest;
uniform vec2 size = vec2(190.0, 125.0);
uniform float night = 0.35;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 cell = floor(UV * size);
	vec4 d = texture(TEXTURE, (cell + 0.5) / size);
	float st = d.r;
	float h = hash(cell);

	// Standing wheat, swaying in waves of wind.
	float gust = noise(vec2(cell.x * 0.03 - TIME * 0.35, cell.y * 0.05 + TIME * 0.05));
	float w = sin(cell.x * 0.16 + cell.y * 0.07 - TIME * 1.7 + gust * 5.0);
	vec3 base = vec3(0.50, 0.37, 0.16);
	vec3 lit = vec3(0.82, 0.65, 0.32);
	vec3 dark = vec3(0.30, 0.20, 0.09);
	float crest = smoothstep(0.35, 1.0, w) * (0.35 + 0.65 * gust);
	vec3 standing = mix(base, lit, crest * 0.8 + h * 0.07);
	float furrow = mod(cell.y, 4.0) < 1.0 ? 0.22 : 0.0;
	standing = mix(standing, dark, step(0.9, h) * 0.3 + furrow * (1.0 - crest * 0.7));
	standing += vec3(0.10, 0.08, 0.03) * step(0.96, h) * (0.5 + 0.5 * w);
	if (d.b > 0.5 && st < 0.2) {
		float tw = 0.5 + 0.5 * sin(TIME * 6.0 + h * 30.0);
		standing = mix(vec3(1.0, 0.80, 0.25), vec3(1.0, 1.0, 0.75), tw * step(0.45, h));
	}

	// Flattened wheat: darker, with stripes along the way it was pushed.
	float ang = d.g * 6.2831853;
	vec2 dv = vec2(cos(ang), sin(ang));
	float along = dot(cell, vec2(-dv.y, dv.x));
	float stripe = step(0.5, fract(along / 3.0));
	vec3 flat_col = mix(vec3(0.27, 0.19, 0.09), vec3(0.34, 0.25, 0.12), stripe) * (0.96 + 0.06 * h);

	vec3 col;
	if (st < 0.2) {
		col = mix(flat_col, standing, d.a);
	} else if (st < 0.7) {
		col = flat_col;
	} else {
		float slot = floor(d.b * 255.0 + 0.5);
		vec4 c = texture(circ_tex, vec2((slot + 0.5) / 256.0, 0.5));
		vec2 center = floor(c.rg * 255.0 + 0.5);
		float reveal = c.b * 255.0;
		float glow = c.a;
		float dist = length(cell + 0.5 - center);
		if (dist > reveal) {
			col = flat_col;
		} else {
			// Moonlit swirl: pale, combed stalks spiralling round the centre.
			float swirl = step(0.5, fract(along / 2.0));
			vec3 lay = mix(vec3(0.66, 0.56, 0.34), vec3(0.84, 0.74, 0.48), swirl) * (0.97 + 0.05 * h);
			vec3 gcol = vec3(0.45, 1.0, 0.85);
			float shimmer = 0.5 + 0.5 * sin(dist * 0.6 - TIME * 3.5);
			col = mix(lay, lay * 0.55 + gcol * 0.55, glow * (0.25 + 0.35 * shimmer));
			if (d.a < 0.7) {
				// Rim of the circle.
				col = mix(col, vec3(0.85, 1.0, 0.92), 0.35 + 0.45 * glow);
			}
			if (reveal < 250.0) {
				col += gcol * smoothstep(3.0, 0.0, reveal - dist) * 0.9;
			}
		}
	}

	// Drifting cloud shadows and a cool moonlit grade.
	float cloud = noise(cell * 0.022 + vec2(TIME * 0.05, TIME * 0.02));
	col *= 0.82 + 0.22 * smoothstep(0.3, 0.8, cloud);
	col = mix(col, col * vec3(0.78, 0.86, 1.12), night);
	COLOR = vec4(col, 1.0);
}
