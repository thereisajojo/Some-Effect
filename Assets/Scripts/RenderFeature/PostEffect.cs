using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class PostEffect : ScriptableRendererFeature
{
    public RenderPassEvent RenderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing;
    public Material Material;
    public string PassName = "Custom Post Effect";
    
    class CustomRenderPass : ScriptableRenderPass
    {
        private RenderTargetIdentifier m_target;
        private Material m_material;
        private string m_passName;
        private int m_rtID;

        public CustomRenderPass(Material mat, string name)
        {
            m_material = mat;
            m_passName = name;
            m_rtID = Shader.PropertyToID("_CustomTempRT");
        }

        public void Setup(RenderTargetIdentifier target)
        {
            m_target = target;
        }
        
        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            if (!m_material) return;
            
            var cmd = CommandBufferPool.Get(m_passName);
            RenderTextureDescriptor opaqueDesc = renderingData.cameraData.cameraTargetDescriptor;
            opaqueDesc.depthBufferBits = 0;
            cmd.GetTemporaryRT(m_rtID, opaqueDesc);
            cmd.Blit(m_target, m_rtID, m_material);
            cmd.Blit(m_rtID, m_target);
            cmd.ReleaseTemporaryRT(m_rtID);
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }

        public override void OnCameraCleanup(CommandBuffer cmd)
        {
        }
    }

    CustomRenderPass m_ScriptablePass;

    /// <inheritdoc/>
    public override void Create()
    {
        m_ScriptablePass = new CustomRenderPass(Material, PassName);

        m_ScriptablePass.renderPassEvent = RenderPassEvent;
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        m_ScriptablePass.Setup(renderer.cameraColorTarget);
        renderer.EnqueuePass(m_ScriptablePass);
    }
}


