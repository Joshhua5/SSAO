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
}

[ExecuteInEditMode]
public class SSAO_Renderer : PostProcessEffectRenderer<SSAO_PostProcessing>
{

    private static readonly int DownRenderTargetID = Shader.PropertyToID("LBAO_Downsample");
    private static readonly int BlurRenderTargetID = Shader.PropertyToID("LBAO_Blur");

    private static readonly int _RandomTex = Shader.PropertyToID("_RandomTex");
    private static readonly int _OcclusionFunction = Shader.PropertyToID("_OcclusionFunction");
    private static readonly int _ViewToClip = Shader.PropertyToID("viewToClip");
    private static readonly int _ClipToView = Shader.PropertyToID("clipToView");
    private static readonly int _ViewToWorld = Shader.PropertyToID("viewToWorld");
    private static readonly int _WorldToView = Shader.PropertyToID("worldToView");
    private static readonly int _Samples = Shader.PropertyToID("_Samples");
    private static readonly int _DropOffFactor = Shader.PropertyToID("_DropOffFactor");
    private static readonly int _Intensity = Shader.PropertyToID("_Intensity");
    private static readonly int _Range = Shader.PropertyToID("_Range");

    private static readonly int _BlurOffset = Shader.PropertyToID("_BlurOffset");
    private static readonly int _OcclusionTex = Shader.PropertyToID("_OcclusionTex");
    private static readonly int _Blur = Shader.PropertyToID("_Blur");
    private static readonly int _Occlusion = Shader.PropertyToID("_Occlusion");
    private static readonly int _MainTex = Shader.PropertyToID("_MainTex");

    private Material _material;
    private Texture2D _randomTexture;
    private Texture2D _occlusionFunction;

    static RenderTextureDescriptor occlusionDescriptor = new RenderTextureDescriptor
    { 
        msaaSamples = 1,
        dimension = UnityEngine.Rendering.TextureDimension.Tex2D,
        colorFormat = RenderTextureFormat.RHalf
    };
     
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
        _material.SetInt(_Samples, settings.Samples.value);
        _material.SetFloat(_DropOffFactor, settings.DropOff.value);
        _material.SetFloat(_Intensity, settings.Intensity.value);
        _material.SetFloat(_Range, settings.Range.value);
         
        _material.SetTexture(_RandomTex, _randomTexture);
        _material.SetTexture(_OcclusionFunction, _occlusionFunction);
    }

    public override void Release()
    {
        base.Release();
    }

    public override void Render(PostProcessRenderContext ctx)
    {
        UpdateMaterialProperties();

        var cmd = ctx.command;

        cmd.BeginSample("Custom SSAO");
        
        // SSAO
        var viewToClip = ctx.camera.projectionMatrix;
        var viewToWorld = ctx.camera.cameraToWorldMatrix;
        var worldToView = ctx.camera.worldToCameraMatrix;
         
        _material.SetMatrix(_ViewToClip, viewToClip);
        _material.SetMatrix(_ClipToView, viewToClip.inverse);
        _material.SetMatrix(_ViewToWorld, viewToWorld);
        _material.SetMatrix(_WorldToView, worldToView);
        
        occlusionDescriptor.width = ctx.screenWidth;
        occlusionDescriptor.height = ctx.screenHeight;

        cmd.GetTemporaryRT(_Occlusion, occlusionDescriptor);
        cmd.GetTemporaryRT(_Blur, occlusionDescriptor);

        // Occlusion
        cmd.BeginSample("Occlusion");
        cmd.Blit(ctx.source, _Occlusion, _material, 0);
        cmd.EndSample("Occlusion");

        cmd.BeginSample("Blur");
        // Horizontal Blur
        _material.SetVector(_BlurOffset, new Vector2(1.3333333f / ctx.camera.pixelWidth, 0));
        cmd.SetGlobalTexture(_OcclusionTex, _Occlusion);
        cmd.Blit(_Occlusion, _Blur, _material, 1);
          
        cmd.ReleaseTemporaryRT(_Occlusion); 
        // Vertical Blur
        _material.SetVector(_BlurOffset, new Vector2(0, 1.3333333f / ctx.camera.pixelHeight)); ;
        cmd.SetGlobalTexture(_MainTex, ctx.source);
        cmd.SetGlobalTexture(_OcclusionTex, _Blur);
        cmd.Blit(ctx.source, ctx.destination, _material, 2);

        cmd.ReleaseTemporaryRT(_Blur);
        cmd.EndSample("Blur");


        cmd.EndSample("Custom SSAO"); 
    }
}
