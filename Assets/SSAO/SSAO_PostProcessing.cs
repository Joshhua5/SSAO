using System;
using System.Reflection;
using UnityEngine;
using UnityEngine.Rendering.PostProcessing;
using UnityEngine.Experimental.Rendering;
using System.Collections.Generic;

[Serializable]
[PostProcess(typeof(SSAO_Renderer), PostProcessEvent.AfterStack, "Custom/Screen Space Ambient Occlusion")]
public sealed class SSAO_PostProcessing : PostProcessEffectSettings
{
    [Range(0.01f, 2)]
    public FloatParameter Range = new FloatParameter { value = 0.2f };

    [Range(0.5f, 10)]
    public FloatParameter Intensity = new FloatParameter { value = 0.6f };
     
    [Range(1, 32)]
    public IntParameter Samples = new IntParameter { value = 32 };

    [Range(1, 10)]
    public IntParameter DropOff = new IntParameter { value = 3 };

    public BoolParameter OcclusionOnly = new BoolParameter { value = false };
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
    private static readonly int _RandomSamples = Shader.PropertyToID("_RandomSamples");

    private Material _material;
    private Texture2D _randomTexture; 
    private List<Vector4> _randomSamples = new List<Vector4>(64);
    private System.Random random = new System.Random();

    static RenderTextureDescriptor occlusionDescriptor = new RenderTextureDescriptor
    { 
        msaaSamples = 1,
        dimension = UnityEngine.Rendering.TextureDimension.Tex2D,
        colorFormat = RenderTextureFormat.RHalf
    };

    private void UniformRandomOnSphere(out float x, out float y, out float z)
    {
        // http://corysimon.github.io/articles/uniformdistn-on-sphere/
        // These random values aren't uniform, but we can get that by rejecting values that fall outside of a sphere within our cube of random values [-1, 1]^3  

        x = (float)random.NextDouble() * 2f - 1f;
        y = (float)random.NextDouble() * 2f - 1f;
        z = (float)random.NextDouble() * 2f - 1f;

        // http://corysimon.github.io/articles/uniformdistn-on-sphere/
        // These random values aren't uniform, but we can get that by rejecting values that fall outside of a sphere within our cube of random values [-1, 1]^3 
        float magnitude = Mathf.Sqrt((x * x) + (y * y) + (z * z));
        if (magnitude >= 1) 
            UniformRandomOnSphere(out x, out y, out z);  
        else
        { 
            // Normalize
            x /= magnitude;
            y /= magnitude;
            z /= magnitude;
        }
    }
     
    public override void Init()
    {
        // Setup the shader
        var shader = Shader.Find("Hidden/SSAO");
        _material = new Material(shader);

        // Generate the random texture to act as a seed for each pixel
        const int randomWidth = 256, randomHeight = 256;
        _randomTexture = new Texture2D(randomWidth, randomHeight, TextureFormat.RGBAHalf, false, true);
        var scratchColor = new Color(0, 0, 0, 1);
        for (int x = 0; x < randomWidth; ++x)
        {
            for (int y = 0; y < randomHeight; ++y)
            {
                UniformRandomOnSphere(out scratchColor.r, out scratchColor.g, out scratchColor.b);
                _randomTexture.SetPixel(x, y, scratchColor);
            }
        }
        _randomTexture.Apply();

        // Generate the random values that will be used for each sample, by doting them with the random 'seed'
        
        for(int i = 0; i < 32; ++i)
        {
            float x, y, z;
            UniformRandomOnSphere(out x, out y, out z); 
            _randomSamples.Add(new Vector4(x, y, z, 1)); 
        }

         _material.SetVectorArray(_RandomSamples, _randomSamples);
          
        UpdateMaterialProperties();
        base.Init();
    } 

    public void UpdateMaterialProperties()
    { 
        _material.SetInt(_Samples, settings.Samples.value - settings.Samples.value % 3);
        _material.SetFloat(_DropOffFactor, settings.DropOff.value);
        _material.SetFloat(_Intensity, settings.Intensity.value);
        _material.SetFloat(_Range, settings.Range.value);

        _material.SetVectorArray(_RandomSamples, _randomSamples);
        _material.SetTexture(_RandomTex, _randomTexture); 
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

        if (settings.OcclusionOnly)
        { 
            cmd.Blit(ctx.source, ctx.destination, _material, 0); 
        }
        else
        {  
            occlusionDescriptor.width = ctx.screenWidth;
            occlusionDescriptor.height = ctx.screenHeight;

            // Occlusion
            cmd.GetTemporaryRT(_Occlusion, occlusionDescriptor);

            cmd.BeginSample("Occlusion");
            cmd.Blit(ctx.source, _Occlusion, _material, 0);
            cmd.EndSample("Occlusion");

            // Horizontal Blur
            cmd.GetTemporaryRT(_Blur, occlusionDescriptor);

            cmd.BeginSample("Blur");
            _material.SetVector(_BlurOffset, new Vector2(1.3333333f / ctx.camera.pixelWidth, 0));
            cmd.SetGlobalTexture(_OcclusionTex, _Occlusion);
            cmd.Blit(_Occlusion, _Blur, _material, 1);

            cmd.ReleaseTemporaryRT(_Occlusion);

            // Vertical Blur
            _material.SetVector(_BlurOffset, new Vector2(0, 1.3333333f / ctx.camera.pixelHeight));
            cmd.SetGlobalTexture(_MainTex, ctx.source);
            cmd.SetGlobalTexture(_OcclusionTex, _Blur);
            cmd.Blit(ctx.source, ctx.destination, _material, 2);

            cmd.ReleaseTemporaryRT(_Blur);

            cmd.EndSample("Blur");
        }
        cmd.EndSample("Custom SSAO"); 
    }
}
