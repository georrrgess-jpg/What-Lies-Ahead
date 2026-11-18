shader_type spatial;
// World-themed static finishes (update 16), picked by `pattern`. Colours:
// shell_color (ground), color_b, color_c, color_d; the trim wears the same
// material on trim_color.
//   0 tooled leather   shell leather, color_b burnished stain, color_c brass thread
//   1 gold-vein ore    shell dark rock, color_b quartz, color_c gold (glints)
//   2 sailcloth        shell canvas, color_b navy stripe, color_c tar thread
//   3 sunken doubloons shell barnacle crust, color_b gold, color_c verdigris
//   4 heraldry         shell field one, color_b field two, color_c gold charges
//   5 chainmail        shell steel, color_b surcoat cloth, color_c gold hem
//   6 building blocks  shell, color_b, color_c, color_d: brick colours
//   7 tin toy          shell tin ground, color_b print, color_c yellow, color_d bare tin
//   8 glow bones       shell night, color_b bone glow (glows in the dark)
//   9 jack-o'-lantern  shell pumpkin, color_b carve shade, color_c candle, color_d vine
#include "res://art/shaders/finish_common.gdshaderinc"

uniform vec3 shell_color : source_color = vec3(0.55, 0.32, 0.15);
uniform vec3 trim_color : source_color = vec3(0.3, 0.17, 0.08);
uniform bool is_trim = false;
uniform int pattern = 0;
uniform vec3 color_b : source_color = vec3(0.3, 0.16, 0.07);
uniform vec3 color_c : source_color = vec3(0.9, 0.7, 0.3);
uniform vec3 color_d : source_color = vec3(0.8, 0.8, 0.8);
uniform float scale = 1.0;

varying vec3 lp;
varying vec3 ln;

void vertex() {
	lp = print_xform(VERTEX);
	ln = NORMAL;
}

float box_sd(vec2 p, vec2 b) {
	vec2 d = abs(p) - b;
	return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

float seg_sd(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}

vec2 rot2(vec2 p, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec2(c * p.x - s * p.y, s * p.x + c * p.y);
}

float fill(float d, float soft) {
	return smoothstep(soft, -soft, d);
}

// Voronoi on a jittered grid: x nearest distance, y second nearest, zw the
// nearest cell id.
vec4 voro(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	vec2 id = vec2(0.0);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = fh22(i + g) * 0.8 + 0.1;
			float d = length(g + o - f);
			if (d < d1) {
				d2 = d1;
				d1 = d;
				id = i + g;
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	return vec4(d1, d2, id);
}

// 0 --------------------------------------------------------------------------
vec3 leather(vec3 g, vec2 uv, out float h, out float rough, out float metal, out vec3 emit) {
	float grain = fnoise2(uv * 380.0) * 0.5 + fnoise2(uv * 90.0) * 0.5;
	vec2 cell = vec2(0.12, 0.1);
	vec2 id = floor(uv / cell);
	vec2 f = (fract(uv / cell) - 0.5) * vec2(1.1, 1.0);
	// An embossed rosette: petals around a boss, vines curling off its sides.
	float a = atan(f.y, f.x);
	float petal = length(f) - (0.2 + 0.07 * cos(a * 6.0 + fh21(id) * 3.0));
	float boss = length(f) - 0.07;
	float vine = abs(f.y - sin(f.x * 13.0) * 0.07) - 0.014;
	vine = max(vine, abs(f.x) - 0.48);
	vine = max(vine, -(length(f) - 0.26));
	float curl = abs(length(f - vec2(0.34, 0.2)) - 0.07) - 0.014;
	float relief = max(max(fill(abs(petal) - 0.018, 0.012), fill(boss, 0.015)), max(fill(vine, 0.012), fill(curl, 0.012)));
	// Burnished stain around the carving, as on stamped leather.
	float halo = smoothstep(0.1, 0.0, min(abs(petal), min(vine, curl)) - 0.02);
	vec3 col = g * (0.82 + 0.3 * grain);
	col = mix(col, color_b, clamp(halo * 0.75 + relief * 0.6, 0.0, 1.0));
	// Stitched seams along the cell rows, in brass-coloured thread.
	float row = abs(fract(uv.y / (cell.y * 3.0)) - 0.5) * cell.y * 3.0;
	float stitch = fill(row - 0.0035, 0.0012) * step(0.5, fract(uv.x / 0.014));
	col = mix(col, color_c, stitch * 0.9);
	h = relief * 0.6 + grain * 0.15 - halo * 0.2 + stitch * 0.2;
	rough = mix(0.62, 0.35, relief);
	metal = stitch * 0.4;
	emit = vec3(0.0);
	return col;
}

// 1 --------------------------------------------------------------------------
vec3 ore(vec3 g, vec3 p, vec3 n, vec3 r, out float h, out float rough, out float metal, out vec3 emit) {
	vec3 q = p * scale;
	float rock = ffbm3(q * 22.0);
	vec3 col = mix(g * 0.7, g * 1.35, rock);
	// Quartz seams (ridged noise) and thin gold veins inside them.
	float ridge = 1.0 - abs(ffbm3(q * 9.0 + 4.0) * 2.0 - 1.0);
	float quartz = smoothstep(0.972, 0.985, ridge);
	float vein = smoothstep(0.95, 0.965, 1.0 - abs(ffbm3(q * 7.0 + 11.0) * 2.0 - 1.0));
	col = mix(col, color_b, quartz * 0.85);
	// Nuggets: raised gold lumps scattered over the rock.
	vec4 v = voro(fplane(p, n) * scale / 0.045);
	float seed = fh21(v.zw);
	float nug = step(0.62, seed) * smoothstep(0.5 + seed * 0.2, 0.1, v.x);
	float gold = max(vein, nug);
	col = mix(col, color_c, gold);
	// Glints: flakes of gold that wink as the weapon turns.
	vec3 cell = floor(q * 420.0);
	vec3 dir = normalize(fh33(cell) - 0.5);
	float on = step(0.78, fh31(cell + 2.0)) * smoothstep(0.55, 0.2, length(fract(q * 420.0) - 0.5));
	float tw = pow(max(dot(dir, normalize(r + vec3(0.0, 0.0, 0.3))), 0.0), 14.0) * on;
	float glitter = on * (0.5 + 0.5 * sin(TIME * (1.5 + seed * 3.0) + fh31(cell) * 30.0));
	h = rock * 0.25 + nug * 0.5 + quartz * 0.1;
	rough = mix(0.82, 0.18, gold);
	metal = gold;
	emit = color_c * (tw * 3.0 + glitter * gold * 0.7) + fstudio(r, color_c) * gold * 0.55;
	return col;
}

// 2 --------------------------------------------------------------------------
vec3 sailcloth(vec3 g, vec2 uv, out float h, out float rough, out float metal, out vec3 emit) {
	// Canvas weave.
	float weave = 0.5 + 0.5 * sin(uv.x * 420.0) * sin(uv.y * 420.0);
	float stain = ffbm2(uv * 14.0);
	vec3 col = g * (0.88 + 0.16 * weave) * mix(0.82, 1.08, stain);
	// Faded navy stripes across the sail, soft edged.
	float t = uv.y / 0.06;
	float stripe = step(0.5, fract(t * 0.5)) * smoothstep(0.0, 0.06, abs(fract(t) - 0.5) + 0.02);
	col = mix(col, color_b * (0.85 + 0.2 * weave), stripe * 0.9);
	// Panel seams with a double row of tar-dark stitching.
	float pu = abs(fract(uv.x / 0.13) - 0.5) * 0.13;
	float seam = fill(pu - 0.0012, 0.0008);
	float stitch = (fill(abs(pu - 0.006) - 0.0011, 0.0008)) * step(0.5, fract(uv.y / 0.012));
	col = mix(col, color_c * 0.7, max(seam * 0.5, stitch));
	// A square patch sewn on in places, edges stitched.
	vec2 pc = floor(uv / vec2(0.13, 0.12));
	float on = step(0.78, fh21(pc + 5.0));
	vec2 pf = fract(uv / vec2(0.13, 0.12)) - 0.5;
	float patch = fill(box_sd(pf, vec2(0.22, 0.26)), 0.015) * on;
	float pst = fill(abs(box_sd(pf, vec2(0.19, 0.23))) - 0.012, 0.01) * step(0.5, fract(uv.x / 0.01 + uv.y / 0.01)) * on;
	col = mix(col, g * vec3(0.75, 0.68, 0.55), patch * 0.8);
	col = mix(col, color_c * 0.6, pst);
	h = weave * 0.15 + patch * 0.2 + seam * 0.1;
	rough = 0.88;
	metal = 0.0;
	emit = vec3(0.0);
	return col;
}

// 3 --------------------------------------------------------------------------
vec3 doubloons(vec3 g, vec2 uv, vec3 r, out float h, out float rough, out float metal, out vec3 emit) {
	float crust = ffbm2(uv * 70.0);
	vec3 col = mix(g * 0.6, g * 1.4, crust);
	// Barnacle domes and verdigris crust.
	vec4 bv = voro(uv / 0.014);
	float barn = smoothstep(0.42, 0.18, bv.x) * step(0.55, fh21(bv.zw));
	col = mix(col, color_c * (0.8 + 0.4 * crust), barn * 0.9);
	// Coins on a staggered lattice, each turned its own way.
	float s = 0.05;
	vec2 q = uv / s;
	q.x += mod(floor(q.y), 2.0) * 0.5;
	vec2 c = floor(q);
	vec2 f = fract(q) - 0.5;
	float hsh = fh21(c);
	float coin = step(0.12, hsh) * step(length(f), 0.46 + 0.04 * fh21(c + 1.0));
	// Coins are half buried: a noisy mask keeps some under the crust.
	coin *= smoothstep(0.35, 0.5, ffbm2(uv * 9.0 + 3.0) + 0.4 * hsh);
	vec2 fr = rot2(f, hsh * 6.28);
	float rim = smoothstep(0.34, 0.4, length(f)) * coin;
	// A tiny skull on the face: cranium, two eyes, a jaw.
	vec2 sk = fr * 2.2;
	float skull = fill(length(sk - vec2(0.0, 0.05)) - 0.34, 0.06) + fill(box_sd(sk - vec2(0.0, -0.3), vec2(0.17, 0.1)), 0.05);
	float eyes = fill(length(vec2(abs(sk.x) - 0.14, sk.y - 0.08)) - 0.07, 0.04);
	float mark = clamp(skull - eyes, 0.0, 1.0) * coin * (1.0 - rim);
	vec3 gold = color_b * (0.8 + 0.35 * fnoise2(uv * 300.0));
	gold = mix(gold, color_b * 0.45, 1.0 - smoothstep(0.0, 0.45, 0.5 - length(f)) * 0.7 + 0.2);
	col = mix(col, gold, coin);
	col = mix(col, color_b * 1.2, rim * 0.6);
	col = mix(col, color_b * 0.42, mark * 0.8);
	h = crust * 0.2 + barn * 0.35 + coin * 0.3 - mark * 0.1;
	rough = mix(0.8, 0.22, coin);
	metal = coin * 0.95;
	emit = fstudio(r, color_b) * coin * 0.5 + color_b * rim * 0.12;
	return col;
}

// 4 --------------------------------------------------------------------------
float fleur(vec2 p) {
	float centre = fill(length((p - vec2(0.0, 0.06)) * vec2(2.4, 0.9)) - 0.34, 0.04);
	vec2 sp = vec2(abs(p.x) - 0.2, p.y - 0.0);
	vec2 q = rot2(sp, 0.7 * sign(p.x));
	float side = fill(length(q * vec2(1.5, 2.6)) - 0.2, 0.05) * step(0.0, p.y + 0.12);
	float band = fill(box_sd(p - vec2(0.0, -0.13), vec2(0.27, 0.035)), 0.02);
	float base = fill(length(vec2(abs(p.x) - 0.1, p.y + 0.28)) - 0.06, 0.03);
	return max(max(centre, side), max(band, base));
}

float tower(vec2 p) {
	float body = fill(box_sd(p - vec2(0.0, -0.05), vec2(0.2, 0.24)), 0.02);
	float top = fill(box_sd(p - vec2(0.0, 0.25), vec2(0.27, 0.05)), 0.02);
	float merlon = fill(box_sd(vec2(mod(p.x + 0.27, 0.18) - 0.09, p.y - 0.34), vec2(0.045, 0.05)), 0.015) * step(abs(p.x), 0.27);
	float door = fill(max(box_sd(p - vec2(0.0, -0.16), vec2(0.07, 0.1)), -p.y - 0.28 + 0.0), 0.02);
	return clamp(max(max(body, top), merlon) - door * 0.85, 0.0, 1.0);
}

vec3 heraldry(vec3 g, vec2 uv, vec3 r, out float h, out float rough, out float metal, out vec3 emit) {
	float s = 0.11;
	vec2 q = uv / s;
	vec2 qc = floor(q);
	vec2 f = fract(q) - 0.5;
	float parity = mod(qc.x + qc.y, 2.0);
	vec3 field = parity < 0.5 ? g : color_b;
	// Damask: faint woven diamonds in the field.
	float dam = 0.5 + 0.5 * sin((uv.x + uv.y) * 220.0) * sin((uv.x - uv.y) * 220.0);
	field *= 0.9 + 0.1 * dam;
	float charge = parity < 0.5 ? fleur(f * 1.05) : tower(f * 1.05);
	// Gold fillet round each quarter.
	float fillet = fill(abs(box_sd(f, vec2(0.455))) - 0.012, 0.006);
	float gold = max(charge, fillet);
	vec3 col = mix(field, color_c, gold);
	h = charge * 0.3 + fillet * 0.2;
	rough = mix(0.34, 0.2, gold);
	metal = gold * 0.9;
	emit = fstudio(r, color_c) * gold * 0.55 + fstudio(r, field) * 0.08;
	return col;
}

// 5 --------------------------------------------------------------------------
vec3 chainmail(vec3 g, vec2 uv, vec3 p, vec3 n, vec3 r, out float h, out float rough, out float metal, out vec3 emit) {
	vec2 s = vec2(0.02, 0.0125);
	vec2 q = uv / s;
	float best = -1.0;
	float lit = 0.0;
	// Rings on a staggered lattice, each overlapping the next row.
	for (int k = 0; k < 4; k++) {
		float row = floor(q.y) + float(k / 2);
		float shift = 0.5 * mod(row, 2.0);
		vec2 c = vec2(floor(q.x - shift) + shift + float(k % 2) + 0.5, row + 0.5);
		vec2 d = (q - c) * vec2(1.0, 1.55);
		float len = length(d);
		float ring = smoothstep(0.56, 0.5, len) * smoothstep(0.1, 0.2, len);
		if (ring > 0.0 && row > best) {
			best = row;
			lit = ring * (0.55 + 0.6 * (0.5 - d.y));
		}
	}
	vec3 steel = g * (0.5 + 0.8 * lit);
	float hole = 1.0 - smoothstep(0.0, 0.2, lit);
	vec3 col = mix(steel, g * 0.3, hole * 0.8);
	// A surcoat band of cloth over the mail, with a gold hem.
	float side = fside(n);
	float band = side * smoothstep(0.012, 0.0, abs(p.y - 0.005) - 0.022);
	float hem = side * smoothstep(0.003, 0.0, abs(abs(p.y - 0.005) - 0.026) - 0.002);
	float cloth = 0.9 + 0.1 * sin(uv.x * 420.0) * sin(uv.y * 420.0);
	col = mix(col, color_b * cloth, band);
	col = mix(col, color_c, hem);
	h = lit * 0.6 * (1.0 - band);
	rough = mix(0.3, 0.85, band);
	metal = (1.0 - band) * 0.4 + hem * 0.5;
	emit = fstudio(r, vec3(0.8)) * (1.0 - band) * (0.12 + lit * 0.55) + fstudio(r, color_c) * hem * 0.5;
	return col;
}

// 6 --------------------------------------------------------------------------
vec3 blocks(vec3 g, vec2 uv, vec3 r, out float h, out float rough, out float metal, out vec3 emit) {
	float stud = 0.0225;
	vec2 q = uv / stud;
	// Bricks two studs high by two to four wide, in rows offset like a wall.
	float row = floor(q.y / 1.0);
	float span = 2.0 + floor(fh21(vec2(row, 1.0)) * 3.0);
	float bx = floor((q.x + fh21(vec2(row, 7.0)) * 8.0) / span);
	vec2 bid = vec2(bx, row);
	float pick = fh21(bid + 2.0);
	vec3 col = pick < 0.25 ? g : (pick < 0.5 ? color_b : (pick < 0.75 ? color_c : color_d));
	// Gaps between bricks.
	vec2 bf = vec2(fract((q.x + fh21(vec2(row, 7.0)) * 8.0) / span) * span, fract(q.y));
	float gap = smoothstep(0.05, 0.12, min(min(bf.x, span - bf.x), min(bf.y, 1.0 - bf.y)));
	// The stud: a round dome with a bright top edge and a soft shadow.
	vec2 sf = fract(q) - 0.5;
	float d = length(sf);
	float dome = smoothstep(0.34, 0.3, d);
	float shade = clamp(0.5 - (sf.x * 0.55 + sf.y * 0.8), 0.0, 1.0);
	float hi = smoothstep(0.2, 0.0, length(sf - vec2(-0.1, -0.12))) * 0.45;
	col *= 0.9 + 0.2 * dome * shade;
	col = mix(col, vec3(1.0), hi * dome);
	col *= 1.0 - smoothstep(0.34, 0.46, d) * (1.0 - dome) * 0.3;
	col *= mix(0.45, 1.0, gap);
	h = dome * 0.8;
	rough = 0.22;
	metal = 0.0;
	emit = fstudio(r, vec3(0.9)) * dome * 0.12;
	return col;
}

// 7 --------------------------------------------------------------------------
vec3 tintoy(vec3 g, vec2 uv, vec3 p, vec3 n, vec3 r, out float h, out float rough, out float metal, out vec3 emit) {
	vec2 cell = vec2(0.12, 0.09);
	vec2 id = floor(uv / cell);
	vec2 f = fract(uv / cell) - 0.5;
	float kind = fh21(id + 3.0);
	vec3 col = g;
	vec3 lamp = vec3(0.0);
	// Panel types: stripes, a star burst, a speaker grille, a round dial.
	if (kind < 0.25) {
		col = mix(col, color_b, step(0.5, fract(f.x * 5.0 + 0.5)));
		col = mix(col, color_c, smoothstep(0.03, 0.0, abs(abs(f.y) - 0.38) - 0.03));
	} else if (kind < 0.5) {
		float a = atan(f.y, f.x);
		float star = length(f) - (0.16 + 0.17 * pow(0.5 + 0.5 * cos(a * 5.0 + 1.57), 2.0));
		col = mix(col, color_c, fill(star, 0.02));
		col = mix(col, color_b, fill(abs(star + 0.03) - 0.01, 0.01));
	} else if (kind < 0.75) {
		float slot = step(0.5, fract(f.y * 6.0));
		col = mix(col, color_d * 0.35, slot * step(abs(f.x), 0.34) * step(abs(f.y), 0.36));
		col = mix(col, color_b, fill(abs(box_sd(f, vec2(0.38, 0.4))) - 0.015, 0.008));
	} else {
		float dial = length(f * vec2(1.0, 1.1));
		col = mix(col, color_d, fill(dial - 0.3, 0.02));
		col = mix(col, color_b, fill(abs(dial - 0.3) - 0.025, 0.015));
		float ang = sin(TIME * 0.9 + fh21(id) * 6.0) * 1.1;
		float need = fill(seg_sd(f, vec2(0.0), vec2(sin(ang), -cos(ang)) * 0.24) - 0.012, 0.008);
		col = mix(col, color_b * 0.8, need);
		// A little lamp that blinks.
		float on = step(0.5, fract(TIME * 0.6 + fh21(id + 9.0) * 4.0));
		float l = fill(length(f - vec2(0.3, 0.3)) - 0.06, 0.02);
		col = mix(col, mix(color_b * 0.4, color_c, on), l);
		lamp = color_c * on * l * 1.2;
	}
	// Rivets at the cell corners and printed panel lines.
	vec2 rc = abs(f) - 0.465;
	float rivet = fill(length(rc) - 0.022, 0.01);
	col = mix(col, color_d, rivet);
	float line = fill(abs(box_sd(f, vec2(0.485))) - 0.008, 0.006);
	col *= 1.0 - line * 0.35;
	// Wear: the lithograph rubbed through to bare tin at the edges.
	float wear = smoothstep(0.64, 0.82, ffbm2(uv * 40.0) + (1.0 - fside(n)) * 0.12 + smoothstep(0.4, 0.5, max(abs(f.x), abs(f.y))) * 0.12);
	col = mix(col, color_d * (0.8 + 0.3 * fnoise2(uv * 500.0)), wear);
	h = rivet * 0.4 + line * 0.2;
	rough = mix(0.28, 0.32, wear);
	metal = mix(0.15, 0.9, wear);
	emit = fstudio(r, vec3(0.9)) * (0.12 + wear * 0.35) + lamp;
	return col;
}

// 8 --------------------------------------------------------------------------
float bone_sd(vec2 p, vec2 a, vec2 b) {
	float shaft = seg_sd(p, a, b) - 0.0075;
	vec2 d = normalize(b - a);
	vec2 n = vec2(-d.y, d.x);
	float ka = min(length(p - a - n * 0.0085), length(p - a + n * 0.0085)) - 0.0095;
	float kb = min(length(p - b - n * 0.0085), length(p - b + n * 0.0085)) - 0.0095;
	return min(shaft, min(ka, kb));
}

vec3 glowbones(vec3 g, vec2 uv, vec3 r, out float h, out float rough, out float metal, out vec3 emit) {
	vec2 cell = vec2(0.05, 0.045);
	vec2 id = floor(uv / cell);
	vec2 f = (fract(uv / cell) - 0.5) * cell * 2.0;
	float hs = fh21(id);
	vec3 col = g * (0.85 + 0.3 * fnoise2(uv * 60.0));
	float bone;
	if (hs < 0.4) {
		// Crossbones.
		float d1 = bone_sd(f, vec2(-0.034, -0.026), vec2(0.034, 0.026));
		float d2 = bone_sd(f, vec2(-0.034, 0.026), vec2(0.034, -0.026));
		bone = fill(min(d1, d2), 0.0015);
	} else if (hs < 0.7) {
		// A skull: cranium, jaw, eye sockets and a nose.
		vec2 s = f / 0.036;
		float cr = fill(length(s - vec2(0.0, 0.2)) - 0.85, 0.08);
		float jaw = fill(box_sd(s - vec2(0.0, -0.62), vec2(0.5, 0.3)), 0.08);
		float eye = fill(length(vec2(abs(s.x) - 0.38, s.y - 0.18)) - 0.22, 0.06);
		float nose = fill(length(vec2(s.x, s.y + 0.18) * vec2(1.4, 0.8)) - 0.12, 0.06);
		float teeth = step(0.5, fract(s.x * 3.0 + 0.5)) * fill(box_sd(s - vec2(0.0, -0.66), vec2(0.45, 0.1)), 0.04);
		bone = clamp(max(cr, jaw) - eye - nose - teeth * 0.6, 0.0, 1.0);
	} else {
		// A single bone at a random angle.
		float an = fh21(id + 4.0) * 3.14;
		vec2 dir = vec2(cos(an), sin(an)) * 0.036;
		bone = fill(bone_sd(f, -dir, dir), 0.0015);
	}
	// A slow, uneven flicker per cell, like cold fire.
	float pulse = 0.72 + 0.28 * sin(TIME * (0.9 + hs * 1.3) + hs * 40.0) * sin(TIME * 0.37 + hs * 11.0 + 2.0);
	col = mix(col, color_b * 0.85, bone);
	h = bone * 0.3;
	rough = mix(0.7, 0.45, bone);
	metal = 0.0;
	emit = color_b * bone * pulse * 1.35 + color_b * 0.04 + fstudio(r, vec3(0.4)) * 0.05;
	return col;
}

// 9 --------------------------------------------------------------------------
float jack_face(vec2 f, float kind) {
	float eyes;
	float mouth;
	if (kind < 0.5) {
		// Triangle eyes, a wide jagged grin.
		vec2 e = vec2(abs(f.x) - 0.2, f.y - 0.12);
		eyes = fill(max(abs(e.x) * 0.9 + e.y * 0.5, -e.y) - 0.11, 0.015);
		float zig = abs(fract(f.x * 7.0) - 0.5) * 0.06;
		mouth = fill(max(abs(f.x) - 0.38, abs(f.y + 0.2 - zig + 0.03) - 0.07), 0.015);
	} else {
		// Round surprised eyes, a toothy mouth with one fang.
		eyes = fill(length(vec2(abs(f.x) - 0.2, (f.y - 0.12) * 1.3)) - 0.1, 0.015);
		float m = fill(length(vec2(f.x, (f.y + 0.2) * 1.6)) - 0.3, 0.015);
		float fang = fill(box_sd(vec2(f.x - 0.12, f.y + 0.06), vec2(0.04, 0.08)), 0.01);
		mouth = clamp(m - fang, 0.0, 1.0);
	}
	return max(eyes, mouth);
}

vec3 jack(vec3 g, vec2 uv, vec3 p, vec3 r, out float h, out float rough, out float metal, out vec3 emit) {
	// Pumpkin ribs: smooth grooves running across the weapon.
	float rib = 0.5 + 0.5 * cos(uv.y / 0.03 * 6.2832);
	float grain = fnoise2(uv * vec2(40.0, 400.0));
	vec3 col = g * (0.62 + 0.45 * rib) * (0.92 + 0.12 * grain);
	col = mix(col, color_b * 0.5, smoothstep(0.1, 0.0, rib) * 0.6);
	vec2 cell = vec2(0.065, 0.06);
	vec2 id = floor(uv / cell);
	vec2 f = fract(uv / cell) - 0.5;
	float hs = fh21(id);
	float face = jack_face(f * 1.1, fh21(id + 1.0)) * step(0.18, hs);
	float flick = 0.8 + 0.2 * sin(TIME * 9.0 + hs * 30.0) * sin(TIME * 5.3 + hs * 9.0) + 0.06 * sin(TIME * 23.0 + hs * 50.0);
	col = mix(col, color_c, face);
	h = -face * 0.5 + rib * 0.25;
	rough = mix(0.4, 0.2, face);
	metal = 0.0;
	emit = color_c * face * flick * 1.6 + vec3(1.0, 0.45, 0.1) * face * face * 0.3 + g * 0.05 * rib;
	return col;
}

void fragment() {
	vec3 r = reflect(-VIEW, NORMAL);
	float fres = ffres(NORMAL, VIEW, 3.0);
	vec2 uv = fplane(lp, ln) * scale;
	vec3 ground = is_trim ? trim_color : shell_color;
	float h = 0.0;
	float rough = 0.5;
	float metal = 0.0;
	vec3 emit = vec3(0.0);
	vec3 col;
	if (pattern == 0) {
		col = leather(ground, uv, h, rough, metal, emit);
	} else if (pattern == 1) {
		col = ore(ground, lp, ln, r, h, rough, metal, emit);
	} else if (pattern == 2) {
		col = sailcloth(ground, uv, h, rough, metal, emit);
	} else if (pattern == 3) {
		col = doubloons(ground, uv, r, h, rough, metal, emit);
	} else if (pattern == 4) {
		col = heraldry(ground, uv, r, h, rough, metal, emit);
	} else if (pattern == 5) {
		col = chainmail(ground, uv, lp, ln, r, h, rough, metal, emit);
	} else if (pattern == 6) {
		col = blocks(ground, uv, r, h, rough, metal, emit);
	} else if (pattern == 7) {
		col = tintoy(ground, uv, lp, ln, r, h, rough, metal, emit);
	} else if (pattern == 8) {
		col = glowbones(ground, uv, r, h, rough, metal, emit);
	} else {
		col = jack(ground, uv, lp, r, h, rough, metal, emit);
	}
	ALBEDO = col;
	METALLIC = metal;
	ROUGHNESS = rough;
	NORMAL = fbump(VERTEX, NORMAL, h, 0.004);
	EMISSION = emit + vec3(1.0) * pow(fres, 4.0) * 0.06 * (1.0 - rough);
	PRINT_LAYER
}
