using System;
using System.IO;
using UnityEditor;
using UnityEngine;

public class Watch
{
    public DateTime beforeDT = DateTime.Now;
    public DateTime afterDT = DateTime.Now;

    public void Start()
    {
        beforeDT = DateTime.Now;
    }

    public void Stop()
    {
        afterDT = DateTime.Now;
    }

    public double ElapsedMilliseconds => afterDT.Subtract(beforeDT).TotalMilliseconds;
}

/// <summary>
/// 由黑白图（R通道）生成SDF图
/// </summary>
public class SdfGenerate : EditorWindow
{
    public Texture texture;
    public int spread = 16;
    public string textureName;
    public Vector2Int size = new Vector2Int(1024, 1024);

    private bool canGenerate => texture != null && string.IsNullOrEmpty(textureName) && size is { x: > 0, y: > 0 };

    private SerializedObject serObj;
    private SerializedProperty prop_texture;
    private SerializedProperty prop_spread;
    private SerializedProperty prop_textureName;
    private SerializedProperty prop_size;

    [MenuItem("Tools/Generate SDF")]
    static void Open()
    {
        GetWindow<SdfGenerate>();
    }

    private void OnEnable()
    {
        serObj = new SerializedObject(this);
        prop_texture = serObj.FindProperty("texture");
        prop_spread = serObj.FindProperty("spread");
        prop_textureName = serObj.FindProperty("textureName");
        prop_size = serObj.FindProperty("size");
    }

    private void OnGUI()
    {
        serObj.Update();
        EditorGUILayout.PropertyField(prop_texture);
        EditorGUILayout.PropertyField(prop_spread);
        EditorGUILayout.PropertyField(prop_textureName);
        EditorGUILayout.PropertyField(prop_size);
        serObj.ApplyModifiedProperties();

        EditorGUI.BeginDisabledGroup(canGenerate);
        if (GUILayout.Button("生成"))
        {
            Generate();
        }
        EditorGUI.EndDisabledGroup();
    }

    public void Generate()
    {
        Shader sdfShader = Shader.Find("Hidden/SdfGenerateShader");
        if (!sdfShader)
        {
            Debug.LogError("缺失Shader：Hidden/SDFGenerateShader");
            return;
        }
        Material mat = new Material(sdfShader);
        mat.hideFlags = HideFlags.DontSave;
        mat.SetFloat("_range", spread);

        var watch = new Watch();
        watch.Start();

        RenderTexture rt0 = new RenderTexture(size.x, size.y, 0, RenderTextureFormat.ARGB32);
        RenderTexture rt1 = new RenderTexture(rt0);

        Graphics.Blit(texture, rt0);
        Graphics.Blit(rt0, rt1, mat);

        SavePng(rt1, textureName);
        watch.Stop();
        
        var mSeconds = watch.ElapsedMilliseconds / 1000.0;
        Debug.LogFormat("完成！ 耗时：{0}秒", mSeconds);

        // 释放资源
        RenderTexture.active = null;
        rt0.Release();
        rt1.Release();
        DestroyImmediate(mat);
    }

    public void SavePng(RenderTexture rt, string texName)
    {
        RenderTexture active = RenderTexture.active;
        RenderTexture.active = rt;
        Texture2D png = new Texture2D(rt.width, rt.height, TextureFormat.RGBA32, false);
        png.ReadPixels(new Rect(0, 0, rt.width, rt.height), 0, 0);
        png.Apply();
        RenderTexture.active = active;
        byte[] bytes = png.EncodeToPNG();
        string tex2dPath = AssetDatabase.GetAssetPath(texture);
        int splitIndex = tex2dPath.LastIndexOf("/", StringComparison.Ordinal);
        string directory = tex2dPath.Substring(0, splitIndex + 1);
        string path = directory + texName + ".png";
        Debug.Log($"SavePath = {path}");
        FileStream fs = File.Open(path, FileMode.Create);
        BinaryWriter writer = new BinaryWriter(fs);
        writer.Write(bytes);
        writer.Flush();
        writer.Close();
        fs.Close();
        DestroyImmediate(png);
        AssetDatabase.Refresh();
    }
}