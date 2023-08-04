using System;
using System.IO;
using UnityEditor;
using UnityEngine;

public class Watch
{
    public DateTime beforeDT = System.DateTime.Now;
    public DateTime afterDT = System.DateTime.Now;


    public void Start() {

        beforeDT = System.DateTime.Now;
    }

    public void Stop() {
        afterDT = System.DateTime.Now;
    }

    public double ElapsedMilliseconds => afterDT.Subtract(beforeDT).TotalMilliseconds;
}

public class SdfGenerate : EditorWindow
{
    public RenderTexture rt;
    public Texture texture;
    public Shader shader;
    public int spread = 16;

    public bool save=true;

    public string savePath;

    public Vector2 size = new Vector2(1024, 1024);

    private SerializedObject serObj;
    private SerializedProperty prop_rt;
    private SerializedProperty prop_texture;
    private SerializedProperty prop_shader;
    private SerializedProperty prop_spread;
    private SerializedProperty prop_savePath;
    private SerializedProperty prop_size;

    [MenuItem("Tools/Generate SDF")]
    static void Open()
    {
        GetWindow<SdfGenerate>();
    }

    private void OnEnable()
    {
        serObj = new SerializedObject(this);
        prop_rt = serObj.FindProperty("rt");
        prop_texture = serObj.FindProperty("texture");
        prop_shader = serObj.FindProperty("shader");
        prop_spread = serObj.FindProperty("spread");
        prop_savePath = serObj.FindProperty("savePath");
        prop_size = serObj.FindProperty("size");
    }

    private void OnGUI()
    {
        serObj.Update();
        EditorGUILayout.PropertyField(prop_rt);
        EditorGUILayout.PropertyField(prop_texture);
        EditorGUILayout.PropertyField(prop_shader);
        EditorGUILayout.PropertyField(prop_spread);
        EditorGUILayout.PropertyField(prop_savePath);
        EditorGUILayout.PropertyField(prop_size);

        if (GUILayout.Button("生成"))
        {
            gen();
        }
    }

    public void gen() {
        var sdfGenerate = this;
        if (sdfGenerate.texture == null) {
            Debug.LogErrorFormat("texture is null ");
            return;
        }

        if (sdfGenerate.shader == null) {
            Debug.LogErrorFormat("shader is null ");
            return;
        }

        if (sdfGenerate.rt != null) {
            sdfGenerate.rt.Release();
            sdfGenerate.rt = null;
        }

        var watch = new Watch();
        watch.Start();

        var watch2 = new Watch();
        watch2.Start();

        sdfGenerate.rt = new RenderTexture((int)sdfGenerate.size.x, (int)sdfGenerate.size.y, 32, RenderTextureFormat.ARGB32);

        Material mat = new Material(sdfGenerate.shader);
        mat.hideFlags = HideFlags.DontSave;
        mat.SetFloat("_range", sdfGenerate.spread);

        var input_rt = RenderTexture.GetTemporary(new RenderTextureDescriptor(sdfGenerate.rt.width, sdfGenerate.rt.height, sdfGenerate.rt.format));



        Graphics.Blit(texture, input_rt);


        Graphics.Blit(input_rt, sdfGenerate.rt, mat);

        RenderTexture.ReleaseTemporary(input_rt);

        watch2.Stop();

        if (save) {
            SdfGenerate.savePng(this.rt, this.savePath);
        }
        watch.Stop();
        var mSeconds = watch.ElapsedMilliseconds / 1000.0;
        var mSceonds2 = watch2.ElapsedMilliseconds / 1000.0;
        Debug.LogErrorFormat("default 耗时：{0}秒，渲染耗时 {1}", mSeconds, mSceonds2);
    }

    public static void savePng(RenderTexture rt, string savePath) {
        Texture2D tex = new Texture2D(rt.width, rt.height, TextureFormat.RGB24, false);

        RenderTexture.active = rt;

        tex.ReadPixels(new Rect(0, 0, rt.width, rt.height), 0, 0);
        tex.Apply();

        var directory = Path.GetDirectoryName(savePath);
        var fileName = Path.GetFileName(savePath);

        if (!string.IsNullOrEmpty(directory)) {
            if (!Directory.Exists(directory)) {
                Directory.CreateDirectory(directory);
            }
        }
        else {
            Debug.LogErrorFormat("savePath directory no exist {0}", savePath);
            return;
        }



        File.WriteAllBytes(savePath, tex.EncodeToPNG());

        Debug.LogFormat("save png: {0}", savePath);
    }
}