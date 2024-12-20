#ifdef GL_ES
precision mediump float;
#endif

// Phong related variables
uniform sampler2D uSampler;
uniform vec3 uKd;
uniform vec3 uKs;
uniform vec3 uLightPos;
uniform vec3 uCameraPos;
uniform vec3 uLightIntensity;

varying highp vec2 vTextureCoord;
varying highp vec3 vFragPos;
varying highp vec3 vNormal;

// Shadow map related variables
#define NUM_SAMPLES 100
#define BLOCKER_SEARCH_NUM_SAMPLES NUM_SAMPLES
#define PCF_NUM_SAMPLES NUM_SAMPLES
#define NUM_RINGS 10

#define SHADOW_BISA 0.0002
#define EPS 1e-3
#define PI 3.141592653589793
#define PI2 6.283185307179586

uniform sampler2D uShadowMap;

varying vec4 vPositionFromLight;

highp float rand_1to1(highp float x ) { 
  // -1 -1
  return fract(sin(x)*10000.0);
}

highp float rand_2to1(vec2 uv ) { 
  // 0 - 1
	const highp float a = 12.9898, b = 78.233, c = 43758.5453;
	highp float dt = dot( uv.xy, vec2( a,b ) ), sn = mod( dt, PI );
	return fract(sin(sn) * c);
}

float unpack(vec4 rgbaDepth) {
    const vec4 bitShift = vec4(1.0, 1.0/256.0, 1.0/(256.0*256.0), 1.0/(256.0*256.0*256.0));
    return dot(rgbaDepth, bitShift);
}

vec2 poissonDisk[NUM_SAMPLES];

void poissonDiskSamples( const in vec2 randomSeed ) {

  float ANGLE_STEP = PI2 * float( NUM_RINGS ) / float( NUM_SAMPLES );
  float INV_NUM_SAMPLES = 1.0 / float( NUM_SAMPLES );

  float angle = rand_2to1( randomSeed ) * PI2;
  float radius = INV_NUM_SAMPLES;
  float radiusStep = radius;

  for( int i = 0; i < NUM_SAMPLES; i ++ ) {
    poissonDisk[i] = vec2( cos( angle ), sin( angle ) ) * pow( radius, 0.75 );
    radius += radiusStep;
    angle += ANGLE_STEP;
  }
}

void uniformDiskSamples( const in vec2 randomSeed ) {

  float randNum = rand_2to1(randomSeed);
  float sampleX = rand_1to1( randNum ) ;
  float sampleY = rand_1to1( sampleX ) ;

  float angle = sampleX * PI2;
  float radius = sqrt(sampleY);

  for( int i = 0; i < NUM_SAMPLES; i ++ ) {
    poissonDisk[i] = vec2( radius * cos(angle) , radius * sin(angle)  );

    sampleX = rand_1to1( sampleY ) ;
    sampleY = rand_1to1( sampleX ) ;

    angle = sampleX * PI2;
    radius = sqrt(sampleY);
  }
}

float findBlocker( sampler2D shadowMap,  vec2 uv, float zReceiver ) {
  vec2 dir = vec2(1.0 / 2048.0);
  poissonDiskSamples(uv.xy);
  float sum = .0; float num = .0;
  for( int i = 0; i < BLOCKER_SEARCH_NUM_SAMPLES; i++ ) {
    vec2 uv1 = vec2(poissonDisk[i] * dir * 48.0 + uv.xy);
    float block_depth = unpack(texture2D(shadowMap, uv1)) + SHADOW_BISA;
    float is_block = step(block_depth, zReceiver);
    num += is_block;
    sum += is_block * block_depth;
  }
  if(num < 0.1) return zReceiver;
  else return sum / num;
}

float useShadowMap(sampler2D shadowMap, vec4 coords){
  float sd = unpack(texture2D(shadowMap, coords.xy)) + SHADOW_BISA;
  return sd > coords.z ? 1.0 : 0.0;
}

float PCF(sampler2D shadowMap, vec4 coords) {
  float wsize = 4.0;
  vec2 dir = vec2(1.0 / 2048.0);
  poissonDiskSamples(coords.xy);
  float sum = .0;
  for( int i = 0; i < NUM_SAMPLES; i ++ ) {
    vec4 uv1 = vec4(poissonDisk[i] * dir * 3.0 + coords.xy, coords.z, 1.0);
    sum += (1.0 - useShadowMap(shadowMap, uv1));
  }

  return 1.0 - (sum / float(NUM_SAMPLES));
}

float PCFW(sampler2D shadowMap, vec4 coords, float wsize) {
  vec2 dir = vec2(1.0 / 2048.0);
  poissonDiskSamples(coords.xy);
  float sum = .0;
  for( int i = 0; i < NUM_SAMPLES; i ++ ) {
    vec4 uv1 = vec4(poissonDisk[i] * dir * wsize + coords.xy, coords.z, 1.0);
    sum += (1.0 - useShadowMap(shadowMap, uv1));
  }

  return 1.0 - (sum / float(NUM_SAMPLES));
}

float PCSS(sampler2D shadowMap, vec4 coords){

  // STEP 1: avgblocker depth
  float block_depth = findBlocker(shadowMap, coords.xy, coords.z);
  float dis  = coords.z - block_depth;
  if(dis < 0.0001) return 1.0;
  // return dis * 10.0;


  float w = dis / block_depth * 1.0 * 80.0;
  w = clamp(w, 0.0, 64.0);
  // return w / 16.0;
  return PCFW(shadowMap, coords, w); 
}


vec3 blinnPhong() {
  vec3 color = texture2D(uSampler, vTextureCoord).rgb;
  color = pow(color, vec3(2.2));
  color = vec3(0.23, 0.23, 0.23);
  vec3 ambient = 0.05 * color;

  vec3 lightDir = normalize(uLightPos);
  vec3 normal = normalize(vNormal);
  float diff = max(dot(lightDir, normal), 0.0);
  vec3 light_atten_coff =
      uLightIntensity / pow(length(uLightPos - vFragPos), 2.0);
      light_atten_coff = vec3(1.0);
  vec3 diffuse = diff * light_atten_coff * color;

  vec3 viewDir = normalize(uCameraPos - vFragPos);
  vec3 halfDir = normalize((lightDir + viewDir));
  float spec = pow(max(dot(halfDir, normal), 0.0), 32.0);
  vec3 specular = uKs * light_atten_coff * spec;
  specular = vec3(0.0, .0, .0);

  vec3 radiance = (ambient + diffuse + specular);
  vec3 phongColor = pow(radiance, vec3(1.0 / 2.2));
  return phongColor;
}

void main(void) {
  uniformDiskSamples(vTextureCoord.xy);
  vec4 pos =  vPositionFromLight / vPositionFromLight.w;
  pos.xyz = (pos.xyz + 1.0) * 0.5;

  float visibility;
  // visibility = useShadowMap(uShadowMap, pos);
  visibility = PCSS(uShadowMap, pos);
  vec3 phongColor = blinnPhong();
  gl_FragColor = vec4(phongColor * visibility, 1.0);
}