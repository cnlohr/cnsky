#if UNITY_EDITOR
using UnityEngine;
using UnityEditor;
using UnityEditor.Build;
using UnityEditor.SceneManagement;

public class StarMeshScript : MonoBehaviour
{
	public MeshFilter starMesh;
	public MeshFilter constellationMesh;
	
	public void RefreshMesh( bool first, BuildTarget newTarget )
	{
		if( newTarget == BuildTarget.Android )
		{
			Debug.Log( "Targeting stars for Android" );
		}
		else
		{
			Debug.Log( "Targeting stars for Windows" );
		}
		
		if( !starMesh )
		{
			Debug.LogError( "Componet does not have star mesh." );
			return;
		}

//		Mesh mesh = new Mesh();
		Mesh mesh = starMesh.sharedMesh;
		if( !mesh )
		{
			Debug.Log( "Star Mesh did not exist. Creating" );
			mesh = starMesh.mesh = new Mesh();
		}


		int vertices = 117955; // Generate 118k points. *4 for quads.
		mesh.indexFormat = UnityEngine.Rendering.IndexFormat.UInt32;
		mesh.vertices = new Vector3[vertices];
		mesh.bounds = new Bounds(new Vector3(0, 0, 0), new Vector3(1000000, 1000000, 1000000));
		int [] inds = new int[0];
		if( newTarget == BuildTarget.Android )
		{
			// For OpenGL we need actual indices.
			inds = new int[vertices];
			int i;
			for( i = 0; i < vertices; i++ )
			{
				inds[i] = i;
			}
		}

		mesh.SetIndices(inds, MeshTopology.Points, 0, false, 0);
		//AssetDatabase.CreateAsset(mesh, "Assets/Stars/starpoints.asset");
		//((target as MonoBehaviour).GetComponent<MeshFilter>()).mesh = mesh;
		
		AssetDatabase.CreateAsset(mesh, "Assets/cnlohr/Stars/starpoints.asset");
		GetComponent<MeshFilter>().mesh = mesh;

/*		{
			int vertices = 1024; // Generate line points
			Mesh mesh = new Mesh();
			mesh.vertices = new Vector3[1];
			mesh.bounds = new Bounds(new Vector3(0, 0, 0), new Vector3(1000000, 1000000, 1000000));
			mesh.SetIndices(new int[vertices], MeshTopology.Points, 0, false, 0);
			AssetDatabase.CreateAsset(mesh, "Assets/Stars/constellationpoints.asset");
		}
*/
/*
		int vertices = 128; // Generate 118k points. *4 for quads.
		Mesh mesh = new Mesh();
		mesh.vertices = new Vector3[vertices];
		mesh.bounds = new Bounds(new Vector3(0, 0, 0), new Vector3(1000000, 1000000, 1000000));
		int [] inds = new int[vertices];
		int i;
		for( i = 0; i < vertices; i++ )
			inds[i] = i;
		mesh.SetIndices(inds, MeshTopology.Points, 0, false, 0);
		AssetDatabase.CreateAsset(mesh, "Assets/PointTest/testpoints.asset");
*/

//		((target as MonoBehaviour).GetComponent<MeshFilter>()).mesh = mesh;
		//add everthing the button would do.

	}
}


public class StarsSwitcher : IActiveBuildTargetChanged
{
	[InitializeOnLoadMethod]
	private static void OnInitialize()
	{
		EditorSceneManager.sceneOpened += OnSceneOpened;
	}

	private static void OnSceneOpened( UnityEngine.SceneManagement.Scene scene, OpenSceneMode mode) { }

	public int callbackOrder => 2;

	public void OnActiveBuildTargetChanged(BuildTarget previousTarget, BuildTarget newTarget)
	{
		StarMeshScript[] gos = Object.FindObjectsOfType(typeof(StarMeshScript)) as StarMeshScript[];
		bool first = true;
		foreach(StarMeshScript c in gos){
			c.RefreshMesh(first, newTarget);
			first = false;
		}
	}
}



[CustomEditor(typeof(StarMeshScript))]
public class PointTestGenHelperEditor : Editor
{
	public override void OnInspectorGUI ()
	{
		DrawDefaultInspector();

		// Should this be EditorUserBuildSettings.activeBuildTarget or BuildAssetBundlesParameters.targetPlatform
		if(GUILayout.Button("Gen And Attach"))
			(target as StarMeshScript).RefreshMesh( true, EditorUserBuildSettings.activeBuildTarget );
	}
}

#endif