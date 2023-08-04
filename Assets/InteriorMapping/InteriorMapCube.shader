Shader "Custom/InteriorMapCube"
{
    Properties
    {
        _RoomTex("Texture", 2D) = "white" {}
        
        [Space]
        [Toggle] _RandomRoom("Random Room", Float) = 0.0
        _Rooms("Room Atlas Rows&Cols (XY)", Vector) = (1,1,0,0)
        
        [Space]
        [Toggle] _AlphaDepth("Depth is Texture Alpha", Float) = 0.0
        _RoomDepth("Room Depth",range(0.001,0.999)) = 0.5
        
        _WindowShadow("Window Shadow", 2D) = "white" {}
        _Wall("Wall", 2D) = "white" {}
        
        _ShadowStrength("ShadowStrength", FLoat) = 0.5
        _ShadowRange("ShadowRange", Float) = 0.2
        _ShadowSoft("ShadowSoft", Float) = 0.1
    }
    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque" "RenderPipeline" = "UniversalRenderPipeline"
        }

        Pass
        {
            Tags
            {
                "LightMode" = "UniversalForward"
            }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #pragma shader_feature_local_fragment _RANDOMROOM_ON
            #pragma shader_feature_local_fragment _ALPHADEPTH_ON

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct appdata
            {
                float4 vertex          : POSITION;
                float2 uv              : TEXCOORD0;
                float3 normal          : NORMAL;
                float4 tangent         : TANGENT;
            };

            struct v2f
            {
                float4 uv              : TEXCOORD0;
                float3 tangentViewDir  : TEXCOORD1;
                float3 tangentLightDir : TEXCOORD2;
                float4 pos             : SV_POSITION;
            };

            CBUFFER_START(UnityPerMaterial)
            float4 _RoomTex_ST;
            float4 _WindowShadow_ST;
            float4 _Rooms;
            float _RoomDepth;
            float _ShadowStrength;
            float _ShadowRange;
            float _ShadowSoft;
            CBUFFER_END

            TEXTURE2D(_RoomTex);
            SAMPLER(sampler_RoomTex);
            TEXTURE2D(_WindowShadow);
            SAMPLER(sampler_WindowShadow);
            TEXTURE2D(_Wall);
            SAMPLER(sampler_Wall);

            // psuedo random 伪随机
            float2 rand2(float co)
            {
                return frac(sin(co * float2(10.9898, 78.233)) * 43758.5453);
            }

            float3 rand3(float co)
            {
                return frac(sin(co * float3(12.9898, 78.233, 43.2316)) * 43758.5453);
            }

            v2f vert(appdata v)
            {
                v2f o;
                o.pos = TransformObjectToHClip(v.vertex);
                o.uv.xy = TRANSFORM_TEX(v.uv, _RoomTex);
                o.uv.zw = TRANSFORM_TEX(v.uv, _WindowShadow);

                // get tangent space camera vector
                float4 objCam = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos, 1.0));
                float3 viewDir = v.vertex.xyz - objCam.xyz;
                float tangentSign = v.tangent.w * unity_WorldTransformParams.w;
                float3 bitangent = cross(v.normal.xyz, v.tangent.xyz) * tangentSign;
                // o.tangentViewDir = float3(
                //     dot(viewDir, v.tangent.xyz),
                //     dot(viewDir, bitangent),
                //     dot(viewDir, v.normal)
                // );
                float3x3 tbn = float3x3(v.tangent.xyz, bitangent, v.normal);
                o.tangentViewDir = mul(viewDir, tbn);
                o.tangentViewDir *= _RoomTex_ST.xyx;

                float3 lightDir = -normalize(_MainLightPosition.xyz);
                lightDir = TransformWorldToObjectDir(lightDir);
                o.tangentLightDir = mul(lightDir, tbn);
                return o;
            }

            half4 frag(v2f i) : SV_Target
            {
                // room uvs
                float2 roomUV = frac(i.uv.xy);
                float2 roomIndexUV = floor(i.uv.xy);

            #ifdef _RANDOMROOM_ON
                // randomize the room
                float2 n = floor(rand2(roomIndexUV.x + roomIndexUV.y * (roomIndexUV.x + 1)) * _Rooms.xy);
            #else
                float2 n = floor(_Rooms.xy);
            #endif
                
                roomIndexUV += n;

            #ifdef _ALPHADEPTH_ON
                // get room depth from room atlas alpha
                half farFrac = SAMPLE_TEXTURE2D(_RoomTex, sampler_RoomTex, (roomIndexUV + 0.5) / _Rooms).a;
            #else
                // Specify depth manually
                half farFrac = _RoomDepth;
            #endif

                //remap [0,1] to [+inf,0]
                //->if input _RoomDepth = 0    -> depthScale = 0      (inf depth room)
                //->if input _RoomDepth = 0.5  -> depthScale = 1
                //->if input _RoomDepth = 1    -> depthScale = +inf   (0 volume room)
                float depthScale = 1.0 / (1.0 - farFrac) - 1.0;

                // raytrace box from view dir
                // normalized box space's ray start pos is on trinagle surface, where z = -1
                float3 pos = float3(roomUV * 2 - 1, -1);
                // transform input ray dir from tangent space to normalized box space
                i.tangentViewDir.z *= -depthScale;

                // 预先处理倒数  t=(1-p)/view=1/view-p/view
                float3 id = 1.0 / i.tangentViewDir;
                float3 k = abs(id) - pos * id;
                float kMin = min(min(k.x, k.y), k.z);
                pos += kMin * i.tangentViewDir;

                // remap from [-1,1] to [0,1] room depth
                float interpolation = pos.z * 0.5 + 0.5;

                // account for perspective in "room" textures
                // assumes camera with an fov of 53.13 degrees (atan(0.5))
                // visual result = transform nonlinear depth back to linear
                float realZ = saturate(interpolation) / depthScale + 1;
                interpolation = 1.0 - (1.0 / realZ);
                interpolation *= depthScale + 1.0;

                // interpolate from wall back to near wall
                float2 interiorUV = pos.xy * lerp(1.0, farFrac, interpolation);

                interiorUV = interiorUV * 0.5 + 0.5;

                // sample room atlas texture
                half4 room = SAMPLE_TEXTURE2D(_RoomTex, sampler_RoomTex, (roomIndexUV + interiorUV.xy) / _Rooms);

                // self shadow
                float3 lightDir = normalize(half3(i.tangentLightDir.xy, -i.tangentLightDir.z)); // 上面集体将切线空间的z轴反向了
                float t = (-1 - pos.z) / lightDir.z;
                float2 sPos = (pos + t * lightDir.xyz).xy * 0.5 + 0.5;
                sPos = saturate(sPos);
                half shadow = SAMPLE_TEXTURE2D(_WindowShadow, sampler_WindowShadow, sPos).g;
                shadow = smoothstep(_ShadowRange, _ShadowRange + _ShadowSoft, shadow);
                shadow = lerp(_ShadowStrength, 1, shadow);

                half window =  SAMPLE_TEXTURE2D(_WindowShadow, sampler_WindowShadow, i.uv.zw).r;
                half4 wall = SAMPLE_TEXTURE2D(_Wall, sampler_Wall, i.uv.zw);

                half4 color = room * shadow * window + wall * (half(1.0) - window);
                
                return color;
            }
            ENDHLSL
        }
    }
}