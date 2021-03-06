#include <sourcemod>
#include <sdktools>
#include <smlib>

#pragma semicolon 1

public Plugin myinfo =
{
	name = "IG Beam Module",
	description = "Beam effects. Cool",
	author = "derwangler",
	version = "1.0",
	url = "http://www.imperfectgamers.org/"
};

#include <ig_surf/ig_core>
#include <ig_surf/ig_beams>

#define BEAM_LOGGING
#define BEAM_LOGGING_PATH "addons/sourcemod/logs/ig_logs/beams"

#define BEAM_SPRITE_PATH "materials/sprites/laserbeam.vmt"
#define HALO_SPRITE_PATH "materials/sprites/halo.vmt"

#if defined BEAM_LOGGING
char g_szLogFile[PLATFORM_MAX_PATH];
#endif

int g_BeamSprite;
int g_HaloSprite;
char g_szMapName[128];

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary(IG_BEAMS);

	CreateNative("IG_SendBeamBoxToClient", Native_SendBeamBoxToClient);
	CreateNative("IG_SendBeamBoxRotatableToClient", Native_SendBeamBoxRotatableToClient);
	CreateNative("IG_SendBeamToClient", Native_SendBeamToClient);

	return APLRes_Success;
}

public void OnPluginStart()
{
#if defined BEAM_LOGGING
	if (!DirExists(BEAM_LOGGING_PATH))
		CreateDirectory(BEAM_LOGGING_PATH, 511);
#endif
}

/*public void OnPluginStop()
{

}*/

public void OnMapStart()
{
	InitPrecache();
	GetCurrentMap(g_szMapName, 128);

#if defined BEAM_LOGGING
	FormatEx(g_szLogFile, sizeof(g_szLogFile), "%s/%s.log", BEAM_LOGGING_PATH, g_szMapName);
#endif
}

public void OnMapEnd()
{
	Format(g_szMapName, sizeof(g_szMapName), "");
}

stock void InitPrecache()
{
	g_BeamSprite = PrecacheModel(BEAM_SPRITE_PATH, true);
	g_HaloSprite = PrecacheModel(HALO_SPRITE_PATH, true);
}


public int Native_SendBeamBoxToClient(Handle hPlugin, int numParams)
{
	int client = GetNativeCell(1);
	float mins[3], maxs[3], life;
	GetNativeArray(2, mins, sizeof(mins));
	GetNativeArray(3, maxs, sizeof(maxs));
	life = GetNativeCell(4);
	int color[4];
	GetNativeArray(5, color, sizeof(color));
	bool full = GetNativeCell(6);
	//Effect_DrawBeamBoxToClient(client, mins, maxs, g_BeamSprite, g_HaloSprite, 0, DEF_BEAM_FRAMERATE, life, 1.0, 1.0, 1, 1.0, color, 0);
	TE_SendBeamBoxToClient(client, mins, maxs, g_BeamSprite, g_HaloSprite, 0, DEF_BEAM_FRAMERATE, life, 1.0, 1.0, 2, 0.0, color, 0, full);
}

public int Native_SendBeamBoxRotatableToClient(Handle hPlugin, int numParams)
{
	int client = GetNativeCell(1);
	float origin[3], mins[3], maxs[3], angles[3], life;
	GetNativeArray(2, origin, sizeof(origin));
	GetNativeArray(3, mins, sizeof(mins));
	GetNativeArray(4, maxs, sizeof(maxs));
	GetNativeArray(5, angles, sizeof(angles));
	life = GetNativeCell(6);
	int color[4];
	GetNativeArray(7, color, sizeof(color));
	Effect_DrawBeamBoxRotatableToClient(client, origin, mins, maxs, angles, g_BeamSprite, g_HaloSprite, 0, DEF_BEAM_FRAMERATE, life, 1.0, 1.0, 2, 0.0, color, 0);
}

public int Native_SendBeamToClient(Handle hPlugin, int numParams)
{
	int client = GetNativeCell(1);
	float start[3], end[3], life;
	GetNativeArray(2, start, sizeof(start));
	GetNativeArray(3, end, sizeof(end));
	life = GetNativeCell(4);
	int color[4];
	GetNativeArray(5, color, sizeof(color));
	TE_SetupBeamPoints(start, end, g_BeamSprite, g_HaloSprite, 0, DEF_BEAM_FRAMERATE, life, 1.0, 1.0, 2, 0.0, color, 0);
	TE_SendToClient(client);
}

#define WALL_BEAMBOX_OFFSET_UNITS 1.0

stock void TE_SendBeamBoxToClient(  int client,
									float upperCorner[3],
									float bottomCorner[3],
									int modelIndex,
									int haloIndex,
									int startFrame,
									int frameRate,
									float life,
									float width,
									float endWidth,
									int fadeLength,
									float amplitude,
									const int color[4],
									int speed,
									bool full)
{
	float corners[8][3];
	for (int i=0; i < 4; i++)
	{
		Array_Copy(bottomCorner, corners[i], 3);
		Array_Copy(upperCorner, corners[i+4], 3);
	}

	corners[1][0] = upperCorner[0];
	corners[2][0] = upperCorner[0];
	corners[2][1] = upperCorner[1];
	corners[3][1] = upperCorner[1];
	corners[4][0] = bottomCorner[0];
	corners[4][1] = bottomCorner[1];
	corners[5][1] = bottomCorner[1];
	corners[7][0] = bottomCorner[0];

	//Array_Copy(uppercorner, corners[0], 3);
	//Array_Copy(bottomcorner, corners[7], 3);

	// Calculate mins
	float min[3];
	for (int i = 0; i < 3; i++)
	{
		min[i] = corners[0][i];
		if (corners[7][i] < min[i])
			min[i] = corners[7][i];
	}

	// Pull corners in to prevent them being hidden inside the ground/walls/ceiling
	for (int j = 0; j < 3; j++)
	{
		for (int i = 0; i < 8; i++)
		{
			if (corners[i][j] == min[j])
				corners[i][j] += WALL_BEAMBOX_OFFSET_UNITS;
			else
				corners[i][j] -= WALL_BEAMBOX_OFFSET_UNITS;
		}

		min[j] += WALL_BEAMBOX_OFFSET_UNITS;
	}

	// Bottom
	for (int i=0; i < 4; i++)
	{
		int j = ( i == 3 ? 0 : i+1 );
		TE_SetupBeamPoints(corners[i], corners[j], modelIndex, haloIndex, startFrame, frameRate, life, width, endWidth, fadeLength, amplitude, color, speed);
		TE_SendToClient(client);
	}

	// Top
	for (int i=4; i < 8; i++)
	{
		int j = ( i == 7 ? 4 : i+1 );
		TE_SetupBeamPoints(corners[i], corners[j], modelIndex, haloIndex, startFrame, frameRate, life, width, endWidth, fadeLength, amplitude, color, speed);
		TE_SendToClient(client);
	}

	// All Vertical Lines
	for (int i=0; i < 4; i++)
	{
		TE_SetupBeamPoints(corners[i], corners[i+4], modelIndex, haloIndex, startFrame, frameRate, life, width, endWidth, fadeLength, amplitude, color, speed);
		TE_SendToClient(client);
	}
}

stock void TE_SendBeamLineToClient( int client,
									const float start[3],
									const float end[3],
									int modelIndex = 0,
									int haloIndex = 0,
									int startFrame = 0,
									int frameRate = 30,
									float life = 0.0,
									float width = 1.0,
									float endWidth = 1.0,
									int fadeLength = 0,
									float amplitude = 0.0,
									const int color[4] = { 255, 255, 255, 200 },
									int speed = 0)
{

	float points[2][3];
	Array_Copy(start, points[0], 3);
	Array_Copy(end, points[1], 3);

	// Calculate mins
	float min[3];
	for (int i = 0; i < 3; i++) {
		min[i] = points[0][i];
		if (points[1][i] < min[i])
			min[i] = points[1][i];
	}

	// Pull points in by 1 unit to prevent them being hidden inside the ground / walls / ceiling
	for (int j = 0; j < 3; j++) {
		for (int i = 0; i < 2; i++) {
			if (points[i][j] == min[j])
				points[i][j] += WALL_BEAMBOX_OFFSET_UNITS;
			else
				points[i][j] -= WALL_BEAMBOX_OFFSET_UNITS;
		}

		min[j] += WALL_BEAMBOX_OFFSET_UNITS;
	}

	//TE_SetupBeamPoints(points[0], points[1], modelIndex, haloIndex, startFrame, frameRate, life, width, endWidth, fadeLength, amplitude, color, speed);
	TE_SetupBeamPoints(start, end, modelIndex, haloIndex, startFrame, frameRate, life, width, endWidth, fadeLength, amplitude, color, speed);
	TE_SendToClient(client);
}
