#version 330

// options
const vec3 sunCol = vec3(255, 202, 159) / 255.0 * 10.0;

const float irradianceStrength = 1.5;
const float prefilterStrength = 0.5;

const int shadowSamples = 16;
const float shadowBlur = 0.0015;


in vec2 uv;
in vec3 fragPos;
in vec3 normal;
in vec3 camPos;
in vec4 shad;

out vec4 fragColor;

uniform struct {
    vec4 position;
    vec3 color;
    vec3 attenuation;
    vec3 spotDirection;
    float spotCosCutoff;
    float spotExponent;
    sampler2DShadow shadowMap;
    mat4 shadowViewMatrix;
} p3d_LightSource[1];


uniform sampler2D p3d_Texture0;
uniform sampler2D p3d_Texture2;
uniform sampler2D p3d_Texture1;

uniform samplerCube cubemap;
uniform sampler2D brdfLUT;

uniform vec3 sunDir;


const float PI = 3.14159265359;


vec3 getNormalFromMap()
{
    vec3 tangentNormal = texture(p3d_Texture2, uv).xyz * 2.0 - 1.0;

    vec3 Q1  = dFdx(fragPos);
    vec3 Q2  = dFdy(fragPos);
    vec2 st1 = dFdx(uv);
    vec2 st2 = dFdy(uv);

    vec3 N   = normalize(normal);
    vec3 T  = normalize(Q1*st2.t - Q2*st1.t);
    vec3 B  = -normalize(cross(N, T));
    mat3 TBN = mat3(T, B, N);

    return normalize(TBN * tangentNormal);
}
// ----------------------------------------------------------------------------
float DistributionGGX(vec3 N, vec3 H, float roughness)
{
    float a = roughness*roughness;
    float a2 = a*a;
    float NdotH = max(dot(N, H), 0.0);
    float NdotH2 = NdotH*NdotH;

    float nom   = a2;
    float denom = (NdotH2 * (a2 - 1.0) + 1.0);
    denom = PI * denom * denom;

    return nom / denom;
}
// ----------------------------------------------------------------------------
float GeometrySchlickGGX(float NdotV, float roughness)
{
    float r = (roughness + 1.0);
    float k = (r*r) / 8.0;

    float nom   = NdotV;
    float denom = NdotV * (1.0 - k) + k;

    return nom / denom;
}
// ----------------------------------------------------------------------------
float GeometrySmith(vec3 N, vec3 V, vec3 L, float roughness)
{
    float NdotV = max(dot(N, V), 0.0);
    float NdotL = max(dot(N, L), 0.0);
    float ggx2 = GeometrySchlickGGX(NdotV, roughness);
    float ggx1 = GeometrySchlickGGX(NdotL, roughness);

    return ggx1 * ggx2;
}
// ----------------------------------------------------------------------------
vec3 fresnelSchlick(float cosTheta, vec3 F0)
{
    return F0 + (1.0 - F0) * pow(clamp(1.0 - cosTheta, 0.0, 1.0), 5.0);
}
// ----------------------------------------------------------------------------
vec3 fresnelSchlickRoughness(float cosTheta, vec3 F0, float roughness)
{
    return F0 + (max(vec3(1.0 - roughness), F0) - F0) * pow(clamp(1.0 - cosTheta, 0.0, 1.0), 5.0);
} 
// ---------------------------------------------------------------------------- 
float rand(vec2 seed)
{
    return fract(sin(dot(seed, vec2(12.9898, 78.233)))*43758.5453);
}
// ---------------------------------------------------------------------------- 
float textureProjSoft(sampler2DShadow tex, vec4 uv, float blur)
{
    float result = 0.0;
    float a = rand(uv.xy);
    for (int i = 0; i < shadowSamples; i++) {
        vec2 offs = vec2(sin(a), cos(a)) * blur;

        float d = rand(i + uv.xy);
        d = sqrt(d);
        offs *= d;

        result += textureProj(tex, vec4(uv.xy + offs, uv.zw));

        a++;
    }
    result /= float(shadowSamples);

    return result;
}  
// ----------------------------------------------------------------------------
vec3 aces(vec3 x)
{
    const float a = 2.51;
    const float b = 0.03;
    const float c = 2.43;
    const float d = 0.59;
    const float e = 0.14;
    return clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0.0, 1.0);
}
// ----------------------------------------------------------------------------
float distanceSQ(vec2 p1, vec2 p2) {
    float d1 = abs(p1.x - p2.x);
    float d2 = abs(p1.y - p2.y);

    return max(d1, d2);
}

void main()
{		
    vec4 mainTex = texture(p3d_Texture0, uv);
    vec3 albedo = pow(mainTex.xyz, vec3(2.2));
    float metallic = texture(p3d_Texture1, uv).b;
    float roughness = texture(p3d_Texture1, uv).g;
    float ao = 1.0;
       
    vec3 N = getNormalFromMap();
    vec3 V = normalize(camPos - fragPos);
    vec3 R = reflect(-V, N); 

    vec3 F0 = vec3(0.04); 
    F0 = mix(F0, albedo, metallic);

    vec3 Lo = vec3(0.0);

    // ------------------ sun --------------------------
        
    vec3 L = normalize(-sunDir);
    vec3 H = normalize(V + L);
    vec3 radiance = sunCol;

    float NDF = DistributionGGX(N, H, roughness);   
    float G   = GeometrySmith(N, V, L, roughness);    
    vec3 F    = fresnelSchlick(max(dot(H, V), 0.0), F0);        
    
    vec3 numerator    = NDF * G * F;
    float denominator = 4.0 * max(dot(N, V), 0.0) * max(dot(N, L), 0.0) + 0.0001;
    vec3 specular = numerator / denominator;
    
    vec3 kS = F;

    vec3 kD = vec3(1.0) - kS;

    kD *= 1.0 - metallic;
        
    float NdotL = max(dot(N, L), 0.0);        

    Lo += (kD * albedo / PI + specular) * radiance * NdotL;
    
    // ---------------------------------------------------
    
    F = fresnelSchlickRoughness(max(dot(N, V), 0.0), F0, roughness);
    
    kS = F;
    kD = 1.0 - kS;
    kD *= 1.0 - metallic;	

    vec2 lvalc = vec2((fragPos.x - 3.0) * 0.4, (fragPos.z + 0.4) * 0.9);
    float lval = 1.0 - clamp(distanceSQ(vec2(0.0), lvalc) * 0.13, 0.2, 1.0);

    vec3 irridiance = max(dot(N, vec3(0, -1, 0)), 0.5) * sunCol * 0.2;
    
    vec3 diffuse = albedo * irradianceStrength * lval * irridiance;
    
    const float MAX_REFLECTION_LOD = 8.0;
    vec3 prefilteredColor = textureLod(cubemap, R, pow(roughness, 0.5) * MAX_REFLECTION_LOD).rgb;
    vec2 brdf  = texture(brdfLUT, vec2(clamp(dot(N, V), 0.0, 0.99), 0.0)).rg;
    specular = prefilteredColor * prefilterStrength * (F * brdf.x + brdf.y);

    vec3 ambient = (kD * diffuse + specular * clamp(metallic, 0.4, 1.0)) * ao;

    float shadowValue = textureProjSoft(p3d_LightSource[0].shadowMap, shad, shadowBlur);
    
    vec3 color = ambient + Lo * shadowValue;

    // ACES tonemapping
    color = aces(color);
    // HDR tonemapping
    color = color / (color + vec3(1.0));
    // gamma correct
    color = pow(color, vec3(1.0/2.2));

    fragColor = vec4(color, mainTex.a);
}