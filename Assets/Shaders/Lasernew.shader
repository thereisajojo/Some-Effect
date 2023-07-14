Shader "Custom/Bubble"
{
    Properties
    {
        _NormalTex ("NormalTex", 2D) = "bump" {}
        _FlowTex("_FlowTex", 2D) = "white"{}
        _TimeSpeed("_TimeSpeed", float) = 1
        _FlowSpeed("_FlowSpeed", float) = 1
        _FlowUVDir("flow UV Dir", vector) = (1,1,1,1)
        _RampTex ("RampTex", 2D) = "white" {}
        _RampXAxisOffset ("X Axis_Offset", Range(0,1))=0.2
        _RampXAxisNoiseStrength("Ramp Tex X Axis Noise Strength", float) = 2

        _ColorReflectIntensity("薄膜干涉亮度", Range(0,20)) = 2
        _EnvCube("Reflection Cubemap", Cube) = "_Skybox" {}
        _ReflectAmount("反射的强度", Range(0, 1)) = 0.5
        _BubbleAlpha("泡泡透明度", Range(0, 2)) = 1

        _FresnelPow("菲尼尔 对比度", float) = 3
        _FresnelIntensity("菲尼尔 亮度", float) = 0.2

    }
    SubShader
    {
        Tags
        {
            "RenderType" = "Transparent"
        }
        LOD 100

        Pass
        {
            Tags
            {
                "LightMode" = "ForwardBase"
            }

            ZWrite off
            Blend SrcAlpha OneMinusSrcAlpha

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float4 normal : NORMAL;
                float4 tangent : TANGENT;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 tDirWS : TEXCOORD1;
                float3 nDirWS : TEXCOORD2;
                float3 bDirWS : TEXCOORD3;
                float4 posWS : TEXCOORD4;
                float3 rDirWS : TEXCOORD5;
            };

            sampler2D _NormalTex;
            sampler2D _FlowTex;
            float4 _FlowTex_ST;
            sampler2D _RampTex;
            float _FlowSpeed;
            float _TimeSpeed;
            float2 _FlowUVDir;
            float _RampXAxisOffset;
            float _RampXAxisNoiseStrength;

            //反射
            samplerCUBE _EnvCube;
            float _ReflectAmount;

            float _BubbleAlpha;

            float _ColorReflectIntensity;

            float _FresnelPow;
            float _FresnelIntensity;

            v2f vert(appdata v)
            {
                v2f o;

                o.uv = v.uv;

                o.posWS = mul(unity_ObjectToWorld, v.vertex);
                o.vertex = UnityObjectToClipPos(v.vertex);

                o.tDirWS = normalize(mul(unity_ObjectToWorld, float4(v.tangent.xyz, 0.0)).xyz);
                o.nDirWS = UnityObjectToWorldNormal(v.normal);
                o.bDirWS = normalize(cross(o.nDirWS, o.tDirWS) * v.tangent.w);
                o.rDirWS = reflect(-UnityWorldSpaceViewDir(o.posWS), o.nDirWS);

                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                //TBN
                half3x3 TBN = float3x3(i.tDirWS, i.bDirWS, i.nDirWS);

                //采样 FLowMap
                float2 flowUV = (i.uv + _Time * 0.1 * _FlowUVDir) * _FlowTex_ST.xy;
                float3 flowDir = tex2D(_FlowTex, flowUV) * 2 - 1;
                flowDir *= _FlowSpeed;

                //控制时间周期
                float phase0 = frac(_Time * 0.1 * _TimeSpeed);
                float phase1 = frac(_Time * 0.1 * _TimeSpeed + 0.5);

                float4 tex0 = tex2D(_NormalTex, i.uv - flowDir.xy * phase0);
                float4 tex1 = tex2D(_NormalTex, i.uv - flowDir.xy * phase1);

                float flowLerp = abs((0.5 - phase0) / 0.5);
                float4 packedNormal = lerp(tex0, tex1, flowLerp);
                float3 normalTS = UnpackNormal(packedNormal);

                //计算Ndir
                half3 nDirWS = normalize(mul(normalTS, TBN));

                half3 vDirWS = normalize(_WorldSpaceCameraPos.xyz - i.posWS);
                //引入波控制
                float wave = lerp(flowDir.xy * phase0, flowDir.xy * phase1, flowLerp);
                //减弱菲尼尔效果 对泡泡影响
                float nDotv = saturate(dot(nDirWS, vDirWS));
                float nDotv2 = saturate(dot(i.nDirWS, vDirWS));
                float RampYAxis = saturate((nDotv - nDotv2 * 0.95) + 0.4 - wave * 0.8);
                float RampXAxis = _RampXAxisOffset + packedNormal.r * _RampXAxisNoiseStrength;
                float2 rampTexUV = float2(RampXAxis, RampYAxis);
                float3 rampColor = tex2D(_RampTex, rampTexUV) * _ColorReflectIntensity; 
                //反射效果
                float3 NegaReflectDir = float3(-i.rDirWS.x, -i.rDirWS.y, i.rDirWS.z);
                //计算两个反射 然后混合
                float3 reflectCol1 = texCUBE(_EnvCube, i.rDirWS) * _ReflectAmount;
                float3 reflectCol2 = texCUBE(_EnvCube, NegaReflectDir) * _ReflectAmount;
                float3 reflectCol = reflectCol1 + reflectCol2;

                //菲尼尔效果 
                float fresnel = pow(1 - nDotv2, _FresnelPow);

                //开始混合 
                //获取明度
                float reflectLumin = dot(reflectCol, float3(0.22, 0.707, 0.071));
                //Ramp颜色受反射图像明度影响很大
                float3 finalRampCol = rampColor * (pow(reflectLumin, 1.5) + 0.05);
                finalRampCol = pow(finalRampCol, 1.4);
                float3 finalCol = finalRampCol + fresnel * _FresnelIntensity * finalRampCol * reflectLumin + reflectCol
                    * reflectCol;
                //透明度受反射图像明度 边缘厚度影响
                float finalAlpha = _BubbleAlpha * (reflectLumin * 0.5 + 0.5) + fresnel * 0.2;

                return float4(finalCol, finalAlpha);
            }
            ENDCG
        }
    }
}