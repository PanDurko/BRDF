Shader "PBR/GGX"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Color ("Color", Color) = (1,1,1,1)
        _SpecularColor ("Specular Color", Color) = (1,1,1,1)
        _Metallic ("Metallic", Range(0, 1)) = 0.5
        _Roughness ("Roughness", Range(0, 1)) = 0.5
    }
    SubShader
    {
        Tags { "LightMode"="UniversalForward" "RenderPipeline"="UniversalRenderPipeline" }
        LOD 100

        Pass
        {
            Name "Unlit"

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL; 
                float4 tangent : TANGENT;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 worldPos : TEXCOORD1; 
                float3 normal : NORMAL; 
                float3 tangent : TANGENT; 
                float3 binormal : BINORMAL;
            };


            float _Metallic; 
            float _Roughness; 
            half4 _Color;
            half4 _SpecularColor;

            Texture2D _MainTex;
            SamplerState sampler_MainTex;
            float4 _MainTex_ST;

            #define Pi 3.1415926535897932384626433832795

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);
                o.normal = TransformObjectToWorldNormal(v.normal);

                return o;
            }

            float3 D_ggx(float alpha, float NoH) 
            {
                float alpha2 = alpha * alpha; 
                float cos2 = NoH * NoH; 

                return alpha2 / (Pi * pow(cos2 * (alpha2 - 1) + 1, 2));
            }   

            float3 G1(float X, float alpha) 
            {
                float k = alpha / 2; 

                return X / (X * (1 - k) + k); 
            }

            float3 G_smith(float alpha, float NoL, float NoV) 
            {
                return G1(NoL, alpha) * G1(NoV, alpha);
            }

            float3 F_schlick(float HoV) 
            {
                return _Metallic + (1 - _Metallic) * pow(1 - HoV, 5);
            }

            float3 Cook_Torrance(float alpha, float NoV, float NoL, float NoH, float HoV) 
            {
                float3 D = D_ggx(alpha, NoH);
                float3 G = G_smith(alpha, NoL, NoV);
                float3 F = F_schlick(HoV);

                return (D * G * F) / (4 * NoV * NoL);  
            }

            half4 frag (v2f i) : SV_Target
            {
                float3 normal = normalize(i.normal);

                float3 albedo = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv).rgb * _Color.rgb;

                float3 lightDir = normalize(GetMainLight().direction);
                float3 viewDir = GetWorldSpaceNormalizeViewDir(i.worldPos);

                float3 halfVec = normalize(lightDir + viewDir);

                float NoV = saturate(dot(normal, viewDir));
                float NoL = saturate(dot(normal, lightDir));
                float NoH = saturate(dot(normal, halfVec));
                float HoV = saturate(dot(halfVec, viewDir));

                float alpha = _Roughness * _Roughness; 

                float3 fSpecular = Cook_Torrance(alpha, NoV, NoL, NoH, HoV) * _SpecularColor;
                float3 kDiffuse = 1 - F_schlick(HoV);
                float3 fDiffuse = (albedo / Pi) * kDiffuse; 

                float3 brdf = normalize(fDiffuse + fSpecular) * Pi * NoL;

                return float4(brdf, 1);
            }
            ENDHLSL
        }
    }
}
