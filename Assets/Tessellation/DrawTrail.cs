using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class DrawTrail : MonoBehaviour
{
    public Camera TrailCam;
    public float TrailRange = 5f;
    
    public RenderTexture rt1;
    public RenderTexture rt2;
    private Vector3 lastFramePos;

    private void RecordLastFramePos()
    {
        lastFramePos = TrailCam.transform.position;
    }
    
    void Start()
    {
        rt1 = new RenderTexture(512, 512, 32, RenderTextureFormat.RFloat);
        rt2 = new RenderTexture(rt1.descriptor);
        
        Texture2D black = Texture2D.blackTexture;
        Graphics.Blit(black, rt1);
        Graphics.Blit(black, rt2);

        TrailCam.enabled = false;
        TrailCam.orthographicSize = TrailRange / 2f;
        TrailCam.targetTexture = rt1;
        RecordLastFramePos();
    }
    
    void Update()
    {
        RenderTexture target;
        RenderTexture other;
        if (TrailCam.targetTexture == rt1)
        {
            target = rt1;
            other = rt2;
        }
        else
        {
            target = rt2;
            other = rt1;
        }

        var offset = TrailCam.transform.position - lastFramePos;
        RecordLastFramePos();
        float ratio = 512 / TrailRange;
        Vector2Int offsetPixel = new Vector2Int((int)(offset.x * ratio), (int)(offset.z * ratio));
        
        int srcX;
        int srcY;
        int dstX;
        int dstY;
        int width = target.width - Mathf.Abs(offsetPixel.x);
        int height = target.height - Mathf.Abs(offsetPixel.y);
        
        if (offsetPixel.x >= 0)
        {
            srcX = offsetPixel.x;
            dstX = 0;
        }
        else
        {
            srcX = 0;
            dstX = -offsetPixel.x;
        }

        if (offsetPixel.y >= 0)
        {
            srcY = offsetPixel.y;
            dstY = 0;
        }
        else
        {
            srcY = 0;
            dstY = -offsetPixel.y;
        }

        Graphics.CopyTexture(target, 0, 0, srcX, srcY, width, height, other, 0, 0, dstX, dstY);
        TrailCam.targetTexture = other;
        TrailCam.Render();
    }
}
