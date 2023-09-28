Shader "Hidden/BoxFilter"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        // No culling or depth
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            int _SampleCount;

            sampler2D _MainTex;
            float4 _MainTex_TexelSize;

            float4 frag (v2f i) : SV_Target
            {
                float total = (_SampleCount * 2 + 1) * (_SampleCount * 2 + 1);
                float4 averageDepth = 0;
                for(int x = -_SampleCount; x <= _SampleCount; x++)
                {
                    for(int y = -_SampleCount; y <= _SampleCount; y++)
                    {
                        float2 uv = i.uv + _MainTex_TexelSize.xy * float2(x, y);
                        float4 d = tex2D(_MainTex, uv);
                        averageDepth += d / total;
                    }
                }
                
                return averageDepth;
            }
            ENDCG
        }
    }
}
