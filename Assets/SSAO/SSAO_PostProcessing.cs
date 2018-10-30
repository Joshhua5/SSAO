using System;
using System.Reflection;
using UnityEngine; 
using UnityEngine.Rendering.PostProcessing;

[Serializable]
[PostProcess(typeof(SSAO_Renderer), PostProcessEvent.AfterStack, "Custom/Screen Space Ambient Occlusion")]
public sealed class SSAO_PostProcessing : PostProcessEffectSettings
{ 
}

public class SSAO_Renderer : PostProcessEffectRenderer<SSAO_PostProcessing>
{

    private static readonly int DownRenderTargetID = Shader.PropertyToID("LBAO_Downsample");
    private static readonly int BlurRenderTargetID = Shader.PropertyToID("LBAO_Blur");
 
    private Material _material;
      
    public override void Init()
    {
        var shader = Shader.Find("Hidden/SSAO");
        _material = new Material(shader); 
         

        UpdateMaterialProperties();
        base.Init();
    } 

    public void UpdateMaterialProperties()
    { 
        /*
        _material.SetFloat("_Threshold", settings.threshold);
        _material.SetInt("_Samples", settings.samples);
        _material.SetFloat("_Radius", settings.radius);
        _material.SetFloat("_Intensity", settings.intensity);
        _material.SetFloat("_LumaProtect", 1f - settings.lumaProtect);
        _material.SetFloat("_BlurSpread", Mathf.Max(settings.radius / 16f, 1f));
        _material.SetVector("_Direction", settings.direction.value.normalized);

        if (settings.blur)
            _material.EnableKeyword(SKW_BLUR); 
        else
            _material.DisableKeyword(SKW_BLUR); 
        */
    }

    public override void Release()
    {
        base.Release();
    }

    public override void Render(PostProcessRenderContext ctx)
    {
        //UpdateMaterialProperties();
        var cmd = ctx.command;  

        cmd.BeginSample("Custom SSAO"); 
  
        // https://forum.unity.com/threads/solved-clip-space-to-world-space-in-a-vertex-shader.531492/
        // We use chriscummings solution for depth to worldspace
        var view = GL.GetGPUProjectionMatrix(ctx.camera.projectionMatrix, false).inverse; 
        var viewToWorld = ctx.camera.cameraToWorldMatrix;

        _material.SetMatrix("projToView", view);
        _material.SetMatrix("viewToWorld", viewToWorld);
   
        cmd.Blit(ctx.source, ctx.destination, _material);
  
        cmd.EndSample("Custom SSAO");
          
    }
}
