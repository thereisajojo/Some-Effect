using UnityEngine;
using UnityEngine.Experimental.Rendering.Universal;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class RenderFurFeature : ScriptableRendererFeature
{
    [System.Serializable]
    public class PassSettings
    {
        [Range(0, 50)] public int PassLayerNum = 20;

        [Range(1000, 5000)] public int QueueMin = 2000;
        [Range(1000, 5000)] public int QueueMax = 5000;
        public RenderPassEvent PassEvent = RenderPassEvent.BeforeRenderingTransparents;

        public LayerMask LayerMask = ~0;
        public RenderQueueType RenderQueueType = RenderQueueType.Transparent;
    }

    class RenderFurPass : ScriptableRenderPass
    {
        private const string profilerTag = "Fur Layers Pass";
        private static readonly ShaderTagId furLayerTagId = new("FurRendererLayer");
        
        private PassSettings settings;
        private FilteringSettings filter;

        public RenderFurPass(PassSettings passSettings)
        {
            settings = passSettings;

            //过滤设定
            RenderQueueRange queue = new RenderQueueRange
            {
                lowerBound = settings.QueueMin,
                upperBound = settings.QueueMax
            };
            filter = new FilteringSettings(queue, settings.LayerMask);
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
            SortingCriteria sortingCriteria = 
                settings.RenderQueueType == RenderQueueType.Transparent ?
                SortingCriteria.CommonTransparent : renderingData.cameraData.defaultOpaqueSortFlags;

            CommandBuffer cmd = CommandBufferPool.Get(profilerTag);

            var layerDrawingSettings = CreateDrawingSettings(furLayerTagId, ref renderingData, sortingCriteria);
            float inter = 1.0f / settings.PassLayerNum;
            for (int i = 1; i <= settings.PassLayerNum; i++)
            {
                cmd.SetGlobalFloat("_FUR_OFFSET", i * inter);
                context.ExecuteCommandBuffer(cmd);
                context.DrawRenderers(renderingData.cullResults, ref layerDrawingSettings, ref filter);
                cmd.Clear();
            }
            
            CommandBufferPool.Release(cmd);
        }

        // Cleanup any allocated resources that were created during the execution of this render pass.
        public override void OnCameraCleanup(CommandBuffer cmd)
        {
            // 渲染完后将_FUR_OFFSET还原为0, 使得下一帧最内层不透明皮毛正确渲染
            cmd.SetGlobalFloat("_FUR_OFFSET", 0);
        }
    }

    RenderFurPass m_FurPass;
    public PassSettings Settings = new PassSettings();

    /// <inheritdoc/>
    public override void Create()
    {
        m_FurPass = new RenderFurPass(Settings);

        // Configures where the render pass should be injected.
        m_FurPass.renderPassEvent = Settings.PassEvent;
    }

    // Here you can inject one or multiple render passes in the renderer.
    // This method is called when setting up the renderer once per-camera.
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(m_FurPass);
    }
}