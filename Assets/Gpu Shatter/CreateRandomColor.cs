using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using Random = UnityEngine.Random;

public class CreateRandomColor : MonoBehaviour
{
    public Material ShatterMaterial;
    private Mesh mesh;
    private ComputeBuffer cb;
    
    void Start()
    {
        MeshFilter meshFilter = GetComponentInChildren<MeshFilter>();
        if (meshFilter)
        {
            mesh = meshFilter.sharedMesh;
        }
        else
        {
            mesh = GetComponentInChildren<SkinnedMeshRenderer>().sharedMesh;
        }

        int triCount = mesh.triangles.Length;
        
        cb = new ComputeBuffer(10000, sizeof(float) * 4);
        Color[] randomColors = new Color[10000];
        for (int i = 0; i < randomColors.Length; i++)
        {
            randomColors[i] = new Color(Random.Range(0f, 1f), Random.Range(0f, 1f), Random.Range(0f, 1f), Random.Range(0f, 1f) < 0.5f ? 0:1);
        }
        cb.SetData(randomColors);
        
        ShatterMaterial.SetBuffer("RandomBuffer", cb);
    }

    private void OnDestroy()
    {
        cb.Dispose();
    }
}
