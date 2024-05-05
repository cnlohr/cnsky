#if UNITY_EDITOR
using UnityEngine;
using UnityEditor;

public class CreateMesh : MonoBehaviour
{
	[MenuItem("Tools/Create Display Meshes")]
	static void CreateMesh_()
	{
		int vertices = 2048*512/24; // Generate 43,690 points.
		Mesh mesh = new Mesh();
		mesh.vertices = new Vector3[1];
		mesh.bounds = new Bounds(new Vector3(0, 0, 0), new Vector3(100, 100, 100));
		mesh.SetIndices(new int[vertices], MeshTopology.Points, 0, false, 0);
		AssetDatabase.CreateAsset(mesh, "Assets/SatelliteStuff/Display/pointlist.asset");

		vertices = 3;
		mesh = new Mesh();
		mesh.vertices = new Vector3[1];
		mesh.bounds = new Bounds(new Vector3(0, 0, 0), new Vector3(100, 100, 100));
		mesh.SetIndices(new int[vertices], MeshTopology.Points, 0, false, 0);
		AssetDatabase.CreateAsset(mesh, "Assets/SatelliteStuff/Display/onepoint.asset");
	}
}
#endif