#if UNITY_EDITOR
using UnityEngine;
using UnityEditor;

public class CreateMeshStars : MonoBehaviour
{
	[MenuItem("Tools/Create Star Mesh")]
	static void CreateMesh_()
	{
#if true
		int vertices = 117955*4; // Generate 118k points. *4 for quads.
		Mesh mesh = new Mesh();
		mesh.indexFormat = UnityEngine.Rendering.IndexFormat.UInt32;
		
		mesh.vertices = new Vector3[117955*4];
		mesh.bounds = new Bounds(new Vector3(0, 0, 0), new Vector3(1000000, 1000000, 1000000));
		int [] inds = new int[vertices];
		int i;
		for( i = 0; i < vertices; i++ )
		{
			inds[i] = i;
		}
		
		mesh.SetIndices(inds, MeshTopology.Quads, 0, false, 0);
		AssetDatabase.CreateAsset(mesh, "Assets/Stars/startris.asset");
#else
		int vertices = 117955; // Generate 118k points. *4 for quads.
		Mesh mesh = new Mesh();
		mesh.vertices = new Vector3[1];
		mesh.bounds = new Bounds(new Vector3(0, 0, 0), new Vector3(1000000, 1000000, 1000000));
		int [] inds = new int[vertices];
		mesh.SetIndices(inds, MeshTopology.Points, 0, false, 0);
		AssetDatabase.CreateAsset(mesh, "Assets/Stars/starpoints.asset");
#endif
		
		vertices = 1024; // Generate line points
		mesh = new Mesh();
		mesh.vertices = new Vector3[1];
		mesh.bounds = new Bounds(new Vector3(0, 0, 0), new Vector3(1000000, 1000000, 1000000));
		mesh.SetIndices(new int[vertices], MeshTopology.Points, 0, false, 0);
		AssetDatabase.CreateAsset(mesh, "Assets/Stars/constellationpoints.asset");
	}
}
#endif