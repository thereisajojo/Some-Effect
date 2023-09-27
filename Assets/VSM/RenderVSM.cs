using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class RenderVSM : ScriptableRendererFeature
{
    class DrawVSMPass : ScriptableRenderPass
    {
        private int rtid = Shader.PropertyToID("_VSM");
        private ShaderTagId shaderTagId = new ShaderTagId("VarianceShadowCaster");
        private FilteringSettings m_FilterSettings = new(RenderQueueRange.opaque, LayerMask.GetMask("Default"));

        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            var settings = CreateDrawingSettings(shaderTagId, ref renderingData, SortingCriteria.CommonOpaque);
            context.DrawRenderers(renderingData.cullResults, ref settings, ref m_FilterSettings);
        }

        // Cleanup any allocated resources that were created during the execution of this render pass.
        public override void OnCameraCleanup(CommandBuffer cmd)
        {
        }
    }

    DrawVSMPass m_ScriptablePass;

    /// <inheritdoc/>
    public override void Create()
    {
        m_ScriptablePass = new DrawVSMPass();

        m_ScriptablePass.renderPassEvent = RenderPassEvent.BeforeRenderingOpaques;
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(m_ScriptablePass);
    }
}


