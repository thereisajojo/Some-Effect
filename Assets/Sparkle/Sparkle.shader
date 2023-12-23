Shader "Unlit/Sparkle"
{
    Properties
    {
        _NoiseTex ("Noise Map", 2D) = "white" {}
        _ParallaxMap("Parallax Map", 2D) = "white" {}
        _SparkleOffset("Sparkle Offset", Float) = 0.6
        _HeightFactor("Height Factor", Float) = 0.1
    }
    SubShader
    {
        Tags
        {
            "RenderType"="Opaque"
        }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

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
                UNITY_FOG_COORDS(1)
                float3 lightDirTS : TEXCOORD2;
                float3 viewDirTS : TEXCOORD3;
                float3 positionWS : TEXCOORD4;
                float3 viewDirWS : TEXCOORD5;
                float3 centerTS : TEXCOORD6;
                float4 vertex : SV_POSITION;
            };

            float _HeightFactor;
            float _SparkleOffset;

            sampler2D _NoiseTex;
            float4 _NoiseTex_ST;

            sampler2D _ParallaxMap;
            float4 _ParallaxMap_ST;

            float3 Hue_Degrees(float3 In, float Offset)
            {
                // RGB to HSV
                float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
                float4 P = lerp(float4(In.bg, K.wz), float4(In.gb, K.xy), step(In.b, In.g));
                float4 Q = lerp(float4(P.xyw, In.r), float4(In.r, P.yzx), step(P.x, In.r));
                
                float D = Q.x - min(Q.w, Q.y);
                float E = 1e-10;
                float V = (D == 0) ? Q.x : (Q.x + E);

                float3 hsv = float3(abs(Q.z + (Q.w - Q.y) / (6.0 * D + E)), D / (Q.x + E), V);

                float hue = hsv.x + Offset / 360;

                hsv.x = (hue < 0) ? hue + 1 : (hue > 1) ? hue - 1 : hue;
                 
                // HSV to RGB
                float4 K2 = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
                float3 P2 = abs(frac(hsv.xxx + K2.xyz) * 6.0 - K2.www);

                return hsv.z * lerp(K2.xxx, saturate(P2 - K2.xxx), hsv.y);
            }

            inline float2 ParallaxUV(v2f i, float heightMulti)
            {
                float height = tex2D(_ParallaxMap, i.uv).r;
                // normalize view Dir
                float3 viewDir = normalize(i.viewDirTS);
                // 偏移值 = 切线空间的视线方向.xy（uv空间下的视线方向）* height * 控制系数
                float2 offset = viewDir.xy * height * _HeightFactor * heightMulti;
                return offset;
            }

            inline float3 BaseSparkle(float2 uv, float3 viewDirWS)
            {
                half3 noise = tex2D(_NoiseTex, uv);
                half3 hue = Hue_Degrees(noise, _Time.y) - _SparkleOffset;
                hue = normalize(hue);

                half3 sparkle = dot(hue, viewDirWS);
                sparkle = saturate(sparkle);
                return sparkle;
            }

            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _NoiseTex);

                TANGENT_SPACE_ROTATION;
                o.lightDirTS = normalize(mul(rotation, ObjSpaceLightDir(v.vertex)));
                o.viewDirTS = normalize(mul(rotation, ObjSpaceViewDir(v.vertex)));

                o.positionWS = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.viewDirWS = normalize(_WorldSpaceCameraPos.xyz - o.positionWS);
                
                UNITY_TRANSFER_FOG(o, o.vertex);
                return o;
            }

            half4 frag(v2f i) : SV_Target
            {
                float2 uvOffset = ParallaxUV(i, 1);
                float3 viewDirWS = normalize(i.viewDirWS);
                float3 sparkle1 = BaseSparkle(i.uv + uvOffset, viewDirWS);

                // uvOffset = ParallaxUV(i, 2);
                // float3 sparkle2 = BaseSparkle(i.uv + uvOffset, i.viewDirWS);
                //
                // uvOffset = ParallaxUV(i, 3);
                // float3 sparkle3 = BaseSparkle(i.uv + uvOffset, i.viewDirWS);

                return half4(sparkle1, 1);
            }
            ENDCG
        }
    }
}