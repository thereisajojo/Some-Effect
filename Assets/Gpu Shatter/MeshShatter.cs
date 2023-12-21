using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class MeshShatter : MonoBehaviour
{
    public Material ShatterMat;
    private List<Mesh> meshes;

    private void Start()
    {
        meshes = new List<Mesh>();
        
        MeshFilter[] meshFilters = GetComponentsInChildren<MeshFilter>();
        foreach (var meshFilter in meshFilters)
        {
            meshes.Add(meshFilter.sharedMesh);
        }

        SkinnedMeshRenderer[] skinnedMeshRenderers = GetComponentsInChildren<SkinnedMeshRenderer>();
        foreach (var skinnedMeshRenderer in skinnedMeshRenderers)
        {
            meshes.Add(skinnedMeshRenderer.sharedMesh);
        }
    }

    private void Shatter()
    {
        
    }
}
