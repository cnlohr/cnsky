#if UNITY_EDITOR
using UnityEngine;
using UnityEditor;
using UnityEditor.Build;
using UnityEditor.SceneManagement;

public class StarMeshScript : MonoBehaviour
{
	public GameObject stars;
	public GameObject constellations;
	
	public Material starMaterialQuest;
	public Material starMaterialPC;
	
	const string starAssetName = "Assets/cnlohr/Stars/starpoints.asset";
	const string constellationAssetName = "Assets/cnlohr/Stars/constellationpoints.asset";

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
	
		MeshFilter starMesh = stars.GetComponent<MeshFilter>();
		MeshFilter constellationMesh = constellations.GetComponent<MeshFilter>();;

		if( newTarget == BuildTarget.Android )
		{
			stars.GetComponent<Renderer>().material = starMaterialQuest;
		}
		else
		{
			stars.GetComponent<Renderer>().material = starMaterialPC;
		}	

		{
			if( !starMesh )
			{
				Debug.LogError( "Componet does not have star mesh." );
				return;
			}

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
			int [] inds;

			// For OpenGL we need actual indices.
			inds = new int[vertices];
			int i;
			for( i = 0; i < vertices; i++ )
			{
				inds[i] = i;
			}

			mesh.SetIndices(inds, MeshTopology.Points, 0, false, 0);

			AssetDatabase.CreateAsset(mesh, starAssetName );
		}
		
		{
			if( !constellationMesh )
			{
				Debug.LogError( "Componet does not have constellation mesh." );
				return;
			}

			Mesh mesh = constellationMesh.sharedMesh;
			if( !mesh )
			{
				Debug.Log( "Constellation Mesh did not exist. Creating" );
				mesh = constellationMesh.mesh = new Mesh();
			}

			int vertices = 676; // Generate line points (Will be triangles)
			mesh.vertices = new Vector3[vertices];
			int [] inds = new int[vertices];
			int i;
			for( i = 0; i < vertices; i++ )
			{
				inds[i] = i;
			}

			mesh.bounds = new Bounds(new Vector3(0, 0, 0), new Vector3(1000000, 1000000, 1000000));
			mesh.SetIndices(inds, MeshTopology.Points, 0, false, 0);
			AssetDatabase.CreateAsset(mesh, constellationAssetName );
		}

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