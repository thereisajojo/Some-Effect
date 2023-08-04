using System;
using System.IO;
using UnityEditor;
using UnityEngine;

public class CreateInteriorMap : EditorWindow
{
    private Texture[] textures = new Texture[5];

    private GameObject[] quads = new GameObject[5];

    private GameObject camObj;

    private float depth = 1;
    private string outputName = "Interior";

    private bool texturesHasNull
    {
        get
        {
            foreach (var tex in textures)
            {
                if (tex == null) return true;
            }

            return false;
        }
    }

    [MenuItem("Tools/Create 2D Interior Map")]
    static void Open()
    {
        GetWindow<CreateInteriorMap>();
    }

    private void OnGUI()
    {
        textures[0] = EditorGUILayout.ObjectField("正面", textures[0], typeof(Texture), false) as Texture;
        textures[1] = EditorGUILayout.ObjectField("天花板", textures[1], typeof(Texture), false) as Texture;
        textures[2] = EditorGUILayout.ObjectField("地板", textures[2], typeof(Texture), false) as Texture;
        textures[3] = EditorGUILayout.ObjectField("左侧", textures[3], typeof(Texture), false) as Texture;
        textures[4] = EditorGUILayout.ObjectField("右侧", textures[4], typeof(Texture), false) as Texture;

        depth = EditorGUILayout.FloatField("深度", depth);
        outputName = EditorGUILayout.TextField("贴图名称", outputName);

        if (GUILayout.Button("创建"))
        {
            if (texturesHasNull) return;

            quads[0] = CreateQuad("forward", textures[0]);
            quads[1] = CreateQuad("ceiling", textures[1]);
            quads[2] = CreateQuad("floor", textures[2]);
            quads[3] = CreateQuad("left", textures[3]);
            quads[4] = CreateQuad("right", textures[4]);

            quads[1].transform.localScale = new Vector3(1, depth, 1);
            quads[1].transform.eulerAngles = new Vector3(-90, 0, 0);
            quads[1].transform.position = new Vector3(0, 0.5f, -depth / 2);

            quads[2].transform.localScale = new Vector3(1, depth, 1);
            quads[2].transform.eulerAngles = new Vector3(90, 0, 0);
            quads[2].transform.position = new Vector3(0, -0.5f, -depth / 2);
            
            quads[3].transform.localScale = new Vector3(depth, 1, 1);
            quads[3].transform.eulerAngles = new Vector3(0, -90, 0);
            quads[3].transform.position = new Vector3(-0.5f, 0, -depth / 2);
            
            quads[4].transform.localScale = new Vector3(depth, 1, 1);
            quads[4].transform.eulerAngles = new Vector3(0, 90, 0);
            quads[4].transform.position = new Vector3(0.5f, 0, -depth / 2);

            camObj = new GameObject("Camera");
            camObj.hideFlags = HideFlags.DontSave;
            camObj.transform.position = new Vector3(0, 0, -(depth + 1));
            Camera camera = camObj.AddComponent<Camera>();
            camera.enabled = false;
            camera.nearClipPlane = 1;
            camera.farClipPlane = depth + 1.1f;
            camera.fieldOfView = 53.13f; // atan(0.5)的两倍
            camera.cullingMask = LayerMask.GetMask("Ignore Raycast");

            RenderTexture outputRT = new RenderTexture(512, 512, 0, RenderTextureFormat.Default);
            camera.targetTexture = outputRT;
            camera.Render();
            SaveRt(outputRT, outputName);

            DestroyObj();
        }
    }

    private GameObject CreateQuad(string texName, Texture tex)
    {
        GameObject obj = GameObject.CreatePrimitive(PrimitiveType.Quad);
        obj.name = texName;
        obj.hideFlags = HideFlags.DontSave;
        obj.layer = LayerMask.NameToLayer("Ignore Raycast");

        float roomDepth = 1 / (depth + 1);
        Material mat = new Material(Shader.Find("Universal Render Pipeline/Unlit"))
        {
            mainTexture = tex,
            color = new Color(1,1,1,roomDepth)
        };
        obj.GetComponent<MeshRenderer>().sharedMaterial = mat;

        return obj;
    }

    private void SaveRt(RenderTexture rt, string texName)
    {
        RenderTexture active = RenderTexture.active;
        RenderTexture.active = rt;
        Texture2D png = new Texture2D(rt.width, rt.height, TextureFormat.RGBA32, false);
        png.ReadPixels(new Rect(0, 0, rt.width, rt.height), 0, 0);
        png.Apply();
        RenderTexture.active = active;
        byte[] bytes = png.EncodeToPNG();
        string tex2dPath = AssetDatabase.GetAssetPath(textures[0]);
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

    private void DestroyObj()
    {
        foreach (var quad in quads)
        {
            if (quad) DestroyImmediate(quad);
        }

        if (camObj) DestroyImmediate(camObj);
    }
}