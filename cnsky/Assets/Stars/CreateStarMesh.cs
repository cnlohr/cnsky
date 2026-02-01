#if UNITY_EDITOR
using UnityEngine;
using UnityEditor;

public class CreateMeshStars : MonoBehaviour
{
	[MenuItem("Tools/Create Star Mesh")]
	static void CreateMesh_()
	{
		int vertices = 117955; // Generate 118k points.
		Mesh mesh = new Mesh();
		mesh.vertices = new Vector3[1];
		mesh.bounds = new Bounds(new Vector3(0, 0, 0), new Vector3(1000000, 1000000, 1000000));
		mesh.SetIndices(new int[vertices], MeshTopology.Points, 0, false, 0);
		AssetDatabase.CreateAsset(mesh, "Assets/cnlohr/Stars/starpoints.asset");
		
		vertices = 1024; // Generate line points
		mesh = new Mesh();
		mesh.vertices = new Vector3[1];
		mesh.bounds = new Bounds(new Vector3(0, 0, 0), new Vector3(1000000, 1000000, 1000000));
		mesh.SetIndices(new int[vertices], MeshTopology.Points, 0, false, 0);
		AssetDatabase.CreateAsset(mesh, "Assets/cnlohr/Stars/constellationpoints.asset");
	}
}
#endif