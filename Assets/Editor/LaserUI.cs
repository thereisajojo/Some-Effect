using System.Collections;
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;

public class LaserUI : ShaderGUI
{
    public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] properties)
    {
        EditorGUILayout.LabelField("Group 0");
        var lightSpan0 = FindProperty("_LightSpan0", properties);
        var lightOffset0 = FindProperty("_LightOffset0", properties);
        var saturation0 = FindProperty("_Saturation0", properties);
        var brightness0 = FindProperty("_Brightness0", properties);
        materialEditor.ShaderProperty(lightSpan0, lightSpan0.displayName);
        materialEditor.ShaderProperty(lightOffset0, lightOffset0.displayName);
        materialEditor.ShaderProperty(saturation0, saturation0.displayName);
        materialEditor.ShaderProperty(brightness0, brightness0.displayName);
        
        EditorGUILayout.Space(10);
        
        EditorGUILayout.LabelField("Group 1");
        var lightSpan1 = FindProperty("_LightSpan1", properties);
        var lightOffset1 = FindProperty("_LightOffset1", properties);
        var saturation1 = FindProperty("_Saturation1", properties);
        var brightness1 = FindProperty("_Brightness1", properties);
        materialEditor.ShaderProperty(lightSpan1, lightSpan1.displayName);
        materialEditor.ShaderProperty(lightOffset1, lightOffset1.displayName);
        materialEditor.ShaderProperty(saturation1, saturation1.displayName);
        materialEditor.ShaderProperty(brightness1, brightness1.displayName);
        
        EditorGUILayout.Space(10);

        var enableFlow = FindProperty("_EnableFlow", properties);
        materialEditor.ShaderProperty(enableFlow, enableFlow.displayName);
        if (enableFlow.floatValue == 1f)
        {
            var noiseMap = FindProperty("_BaseMap", properties);
            var flowSpeed = FindProperty("_FlowSpeed", properties);
            materialEditor.ShaderProperty(noiseMap, noiseMap.displayName);
            materialEditor.ShaderProperty(flowSpeed, flowSpeed.displayName);
        }
    }
}
