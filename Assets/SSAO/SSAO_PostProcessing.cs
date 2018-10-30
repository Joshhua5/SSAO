using System;
using System.Reflection;
using UnityEngine;
using UnityEngine.Rendering.PostProcessing;
using UnityEngine.Experimental.Rendering;

[Serializable]
[PostProcess(typeof(SSAO_Renderer), PostProcessEvent.AfterStack, "Custom/Screen Space Ambient Occlusion")]
public sealed class SSAO_PostProcessing : PostProcessEffectSettings
{
    [Range(0.01f, 2)]
    public FloatParameter _Range = new FloatParameter { value = 0.1f };
}

public class SSAO_Renderer : PostProcessEffectRenderer<SSAO_PostProcessing>
{

    private static readonly int DownRenderTargetID = Shader.PropertyToID("LBAO_Downsample");
    private static readonly int BlurRenderTargetID = Shader.PropertyToID("LBAO_Blur");
 
    private Material _material;
    private Texture2D _randomTexture;
      
    public override void Init()
    {
        var shader = Shader.Find("Hidden/SSAO");
        _material = new Material(shader);
         

        _randomTexture = new Texture2D(128, 128, TextureFormat.RGB24, false, true);
        for (int x = 0; x < 128; ++x)
            for (int y = 0; y < 128; ++y)
                _randomTexture.SetPixel(x, y, UnityEngine.Random.ColorHSV());

        _randomTexture.Apply(); 

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

        _material.SetTexture(Shader.PropertyToID("_RandomTex"), _randomTexture); 
        _material.SetMatrix("projToView", view);
        _material.SetMatrix("viewToWorld", viewToWorld); 
        _material.SetFloat("_Range", settings._Range.value);
   
        cmd.Blit(ctx.source, ctx.destination, _material);
  
        cmd.EndSample("Custom SSAO");
          
    }
}
