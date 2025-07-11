Shader "Custom/AccumulateShader"
{
    Properties
    {
	    _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            struct v2f {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            v2f vert(appdata_img v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = v.texcoord;
                return o;
            };

            sampler2D _MainTex;
			sampler2D _PrevFrame;
			int _Frame;

            fixed4 frag (v2f i) : SV_Target
            {
                float4 col = tex2D(_MainTex, i.uv);
                float4 colPrev = tex2D(_PrevFrame,i.uv);
                float weight = 1.0 / (_Frame + 1);
                float4 accumulatedCol = saturate(colPrev * (1 - weight) + col * weight);

                return accumulatedCol;
            }
            ENDCG
        }
    }
}
