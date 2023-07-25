using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class GlitchPostProcessFeature : ScriptableRendererFeature
{
    public enum GlitchType
    {
        ImageBlockGlitch,
        ScanLineJitterGlitch,
        LineBlockGlitch
    }
    
    [System.Serializable]
    public class ImageBlockGlitch
    {
        public float Speed;
        public Vector2 BlockSize;
    }
    
    [System.Serializable]
    public class ScanLineJitterGlitch
    {
        public Vector2 ScanLineJitter;
    }
    
    [System.Serializable]
    public class LineBlockGlitch
    {
        public float TimeSpeed;
        public float Frequency;
        public float LinesWidth;
        public float Amount;
        public float Offset;
        public float Alpha;
    }
    
    [System.Serializable]
    public class MaterialProps
    {
        public ImageBlockGlitch ImageBlockGlitch;
        public ScanLineJitterGlitch ScanLineJitterGlitch;
        public LineBlockGlitch LineBlockGlitch;
    }

    public Shader PostProcessShader;
    public RenderPassEvent RenderPassEvent = RenderPassEvent.AfterRenderingTransparents;
    
    [Space]
    public GlitchType Type;
    public MaterialProps MaterialProperties;

    class CustomRenderPass : ScriptableRenderPass
    {
        private Material m_PostProcessMaterial;
        private GlitchType m_GlitchType;
        private MaterialProps m_MaterialProperties;
        private RenderTargetIdentifier m_Source;
        private RenderTargetHandle m_MiddleTempRtHandle;

        public CustomRenderPass(Shader shader)
        {
            m_PostProcessMaterial = new Material(shader);
            m_MiddleTempRtHandle.Init("MiddleTempRt");
        }

        // Every Frame Update
        public void Setup(RenderTargetIdentifier source, GlitchType type, MaterialProps props)
        {
            m_Source = source;
            m_GlitchType = type;
            m_MaterialProperties = props;
        }
        
        // This method is called before executing the render pass.
        // It can be used to configure render targets and their clear state. Also to create temporary render target textures.
        // When empty this render pass will render to the active camera render target.
        // You should never call CommandBuffer.SetRenderTarget. Instead call <c>ConfigureTarget</c> and <c>ConfigureClear</c>.
        // The render pipeline will ensure target setup and clearing happens in a performant manner.
        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
        }

        // Here you can implement the rendering logic.
        // Use <c>ScriptableRenderContext</c> to issue drawing commands or execute command buffers
        // https://docs.unity3d.com/ScriptReference/Rendering.ScriptableRenderContext.html
        // You don't have to call ScriptableRenderContext.submit, the render pipeline will call it at specific points in the pipeline.
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            switch (m_GlitchType)
            {
                case GlitchType.ImageBlockGlitch:
                    m_PostProcessMaterial.SetFloat("_Speed", m_MaterialProperties.ImageBlockGlitch.Speed);
                    m_PostProcessMaterial.SetVector("_BlockSize", m_MaterialProperties.ImageBlockGlitch.BlockSize);
                    break;
                case GlitchType.ScanLineJitterGlitch:
                    m_PostProcessMaterial.SetVector("_ScanLineJitter", m_MaterialProperties.ScanLineJitterGlitch.ScanLineJitter);
                    break;
                case GlitchType.LineBlockGlitch:
                    m_PostProcessMaterial.SetFloat("_TimeX", m_MaterialProperties.LineBlockGlitch.TimeSpeed);
                    m_PostProcessMaterial.SetFloat("_Frequency", m_MaterialProperties.LineBlockGlitch.Frequency);
                    m_PostProcessMaterial.SetFloat("_LinesWidth", m_MaterialProperties.LineBlockGlitch.LinesWidth);
                    m_PostProcessMaterial.SetFloat("_Amount", m_MaterialProperties.LineBlockGlitch.Amount);
                    m_PostProcessMaterial.SetFloat("_Offset", m_MaterialProperties.LineBlockGlitch.Offset);
                    m_PostProcessMaterial.SetFloat("_Alpha", m_MaterialProperties.LineBlockGlitch.Alpha);
                    break;
            }
            
            var cameraDesc = renderingData.cameraData.cameraTargetDescriptor;
            cameraDesc.depthBufferBits = 0;
            CommandBuffer cmd = CommandBufferPool.Get("Glitch Post Process");
            cmd.GetTemporaryRT(m_MiddleTempRtHandle.id, cameraDesc);
            cmd.Blit(m_Source, m_MiddleTempRtHandle.Identifier(), m_PostProcessMaterial, (int)m_GlitchType);
            cmd.Blit(m_MiddleTempRtHandle.Identifier(), m_Source);
            cmd.ReleaseTemporaryRT(m_MiddleTempRtHandle.id);
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }

        // Cleanup any allocated resources that were created during the execution of this render pass.
        public override void OnCameraCleanup(CommandBuffer cmd)
        {
        }
    }

    CustomRenderPass m_ScriptablePass;

    /// <inheritdoc/>
    public override void Create()
    {
        if (PostProcessShader == null) return;
        
        m_ScriptablePass = new CustomRenderPass(PostProcessShader)
        {
            renderPassEvent = RenderPassEvent
        };
    }

    // Here you can inject one or multiple render passes in the renderer.
    // This method is called when setting up the renderer once per-camera.
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (PostProcessShader == null) return;
        
        m_ScriptablePass.Setup(renderer.cameraColorTarget, Type, MaterialProperties);
        renderer.EnqueuePass(m_ScriptablePass);
    }
}


