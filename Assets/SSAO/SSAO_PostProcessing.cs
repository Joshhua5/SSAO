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
    public FloatParameter Range = new FloatParameter { value = 0.2f };

    [Range(0.5f, 10)]
    public FloatParameter Intensity = new FloatParameter { value = 0.6f };
     
    [Range(1, 64)]
    public IntParameter Samples = new IntParameter { value = 32 };

    [Range(1, 10)]
    public IntParameter DropOff = new IntParameter { value = 3 };

    public BoolParameter Blur = new BoolParameter { value = true };
}

[ExecuteInEditMode]
public class SSAO_Renderer : PostProcessEffectRenderer<SSAO_PostProcessing>
{

    private static readonly int DownRenderTargetID = Shader.PropertyToID("LBAO_Downsample");
    private static readonly int BlurRenderTargetID = Shader.PropertyToID("LBAO_Blur");
 
    private Material _material;
    private Texture2D _randomTexture;
    private Texture2D _occlusionFunction;
      
    public override void Init()
    {
        var shader = Shader.Find("Hidden/SSAO");
        _material = new Material(shader);
        var random = new System.Random();
         
        _randomTexture = new Texture2D(256, 256, TextureFormat.RGBAHalf, false, true);
        for (int x = 0; x < 256; ++x)
        {
            var rand = new Vector3();
            for (int y = 0; y < 256; ++y)
            {
                rand.Set(
                    (float)random.NextDouble() * 2f - 1f,
                    (float)random.NextDouble()* 2f - 1f,
                    (float)random.NextDouble() * 2f - 1f);

                rand.Normalize();

                _randomTexture.SetPixel(x, y, new Color
                {
                    r = rand.x,
                    g = rand.y,
                    b = rand.z,
                    a = 1
                });
            }
        }
        _randomTexture.Apply();

        _occlusionFunction = new Texture2D(32, 1, TextureFormat.RHalf, false, true);
        _occlusionFunction.SetPixel(0, 0, Color.black);
        for(int x = 0; x < 31; ++x)
        {
            // Linear function
            _occlusionFunction.SetPixel(1 + x, 0, new Color(1f - (x / 31f), 0, 0));
        }
        _occlusionFunction.Apply();

        UpdateMaterialProperties();
        base.Init();
    } 

    public void UpdateMaterialProperties()
    { 
    }

    public override void Release()
    {
        base.Release();
    }

    public override void Render(PostProcessRenderContext ctx)
    {
        var cmd = ctx.command;  

        cmd.BeginSample("Custom SSAO"); 
  
        var descriptor = new RenderTextureDescriptor
        {
            width = ctx.camera.pixelWidth,
            height = ctx.camera.pixelHeight,
            msaaSamples = 1,
            dimension = UnityEngine.Rendering.TextureDimension.Tex2D,
            colorFormat = ctx.sourceFormat
        };

        var _HorizonalBlur = Shader.PropertyToID("_HorizonalBlur");
        var _VerticalBlur = Shader.PropertyToID("_VerticalBlur");
         
          
        // SSAO
        var viewToClip = ctx.camera.projectionMatrix;
        var viewToWorld = ctx.camera.cameraToWorldMatrix;
        var worldToView = ctx.camera.worldToCameraMatrix;

        _material.SetTexture("_RandomTex", _randomTexture);
        _material.SetTexture("_OcclusionFunction", _occlusionFunction);
         
        _material.SetMatrix("viewToClip", viewToClip);
        _material.SetMatrix("clipToView", viewToClip.inverse);
        _material.SetMatrix("viewToWorld", viewToWorld);
        _material.SetMatrix("worldToView", worldToView);

        _material.SetInt("_Samples", settings.Samples.value);
        _material.SetFloat("_DropOffFactor", settings.DropOff.value);
        _material.SetFloat("_Intensity", settings.Intensity.value);
        _material.SetFloat("_Range", settings.Range.value);

        if (settings.Blur.value)
        { 
            cmd.GetTemporaryRT(_HorizonalBlur, descriptor);
            cmd.GetTemporaryRT(_VerticalBlur, descriptor);

            cmd.Blit(ctx.source, _HorizonalBlur, _material, 0);
         
            // Horizontal Blur
            _material.SetVector("BlurOffset_Flip", new Vector2(1.3333333f / ctx.camera.pixelWidth, 0));
            cmd.SetGlobalTexture("_MainTex", _HorizonalBlur);
            cmd.Blit(_HorizonalBlur, _VerticalBlur, _material, 1); 

            cmd.ReleaseTemporaryRT(_HorizonalBlur);

            // Vertical Blur
            _material.SetVector("BlurOffset_Flip", new Vector2(0, 1.3333333f / ctx.camera.pixelHeight)); ;
            cmd.SetGlobalTexture("_MainTex", _VerticalBlur);
            cmd.Blit(_VerticalBlur, ctx.destination, _material, 2);

            cmd.ReleaseTemporaryRT(_VerticalBlur);
        }
        else
        {
            cmd.Blit(ctx.source, ctx.destination, _material, 0);
        }
           
        cmd.EndSample("Custom SSAO"); 
    }
}
