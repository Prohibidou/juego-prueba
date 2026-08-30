shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

// Oleaje por DESPLAZAMIENTO de vertices. Va sobre MarOlas -un plano
// subdividido-, no sobre la malla "Mar" del mapa, que son 14 vertices y no
// tiene nada que ondular.
//
// La forma de la ola esta duplicada a proposito en scripts/mar.gd: alli la
// leen las chapas para flotar. Las constantes de abajo TIENEN que ser las
// mismas que las de ese script. Y el tiempo llega por uniform, no por TIME:
// con dos relojes distintos las chapas flotaban a destiempo de su propia ola.

uniform vec3 color_profundo : source_color = vec3(0.02, 0.13, 0.26);
uniform vec3 color_superficie : source_color = vec3(0.18, 0.58, 0.66);
uniform float amplitud = 0.16;
uniform float largo_ola = 11.0;
uniform float velocidad = 0.8;
uniform float espuma = 0.35;
uniform float rugosidad = 0.06;
uniform float tiempo = 0.0;     // lo pone mar.gd; el mismo que usan las chapas

const vec2 DIRS[4] = {vec2(1.0, 0.25), vec2(-0.4, 1.0),
	vec2(0.75, -0.6), vec2(-0.9, -0.45)};
const float PESOS[4] = {0.50, 0.28, 0.14, 0.08};
const float K_MUL[4] = {1.0, 2.1, 3.7, 6.3};
const float W_MUL[4] = {1.0, 1.3, 0.85, 1.6};

varying vec3 v_mundo;
varying float v_altura;   // -1..1

float altura_ola(vec2 p) {
	float k = 6.2831853 / max(largo_ola, 0.001);
	float h = 0.0;
	for (int i = 0; i < 4; i++) {
		vec2 d = normalize(DIRS[i]);
		h += sin(dot(p, d) * k * K_MUL[i] + tiempo * velocidad * k * W_MUL[i]) * PESOS[i];
	}
	return h * amplitud;
}

void vertex() {
	vec3 mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = altura_ola(mundo.xz);
	mundo.y += h;
	v_mundo = mundo;
	v_altura = h / max(amplitud, 0.0001);
	VERTEX = (inverse(MODEL_MATRIX) * vec4(mundo, 1.0)).xyz;

	// normal analitica de la MISMA funcion: con la del plano no se marca ni
	// una cresta por mucha luz que le pongas
	float d = max(largo_ola, 0.001) * 0.08;
	float hx = altura_ola(mundo.xz + vec2(d, 0.0)) - altura_ola(mundo.xz - vec2(d, 0.0));
	float hz = altura_ola(mundo.xz + vec2(0.0, d)) - altura_ola(mundo.xz - vec2(0.0, d));
	NORMAL = normalize(vec3(-hx, 2.0 * d, -hz));
}

void fragment() {
	// el color va con la PENDIENTE ademas de la altura: los valles se ven mas
	// hondos y el agua deja de parecer una chapa pintada
	float pend = 1.0 - clamp(NORMAL.y, 0.0, 1.0);
	float mezcla = clamp(v_altura * 0.5 + 0.5, 0.0, 1.0);
	vec3 color = mix(color_profundo, color_superficie, mezcla);
	color = mix(color, color_superficie * 1.15, clamp(pend * 3.0, 0.0, 1.0) * 0.5);

	// espuma: solo en lo alto de la cresta Y donde la ola esta inclinada, que
	// es donde rompe de verdad. Solo por altura salian anillos planos.
	float cresta = smoothstep(0.45, 0.95, v_altura) * smoothstep(0.02, 0.12, pend);
	color = mix(color, vec3(1.0), cresta * espuma);

	float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 5.0);
	color = mix(color, vec3(0.85, 0.92, 1.0), fresnel * 0.45);

	ALBEDO = color;
	ROUGHNESS = clamp(rugosidad + cresta * 0.5, 0.0, 1.0);  // la espuma no brilla
	METALLIC = 0.0;
	SPECULAR = 0.7;
}
