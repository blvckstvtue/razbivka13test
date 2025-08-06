/* Debug version of SM Franug CSGO Sprays to identify animation issues */

#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <clientprefs>

#define SOUND_SPRAY_REL "*/items/spraycan_spray.wav"
#define SOUND_SPRAY "items/spraycan_spray.wav"

// Graffiti balloon model
#define GRAFFITI_MODEL "models/12konsta/graffiti/v_ballon4ik.mdl"
#define GRAFFITI_ANIM_DURATION 3.0 // Longer duration for testing

#define MAX_SPRAYS 128
#define MAX_MAP_SPRAYS 200

int g_iLastSprayed[MAXPLAYERS + 1];
char path_decals[PLATFORM_MAX_PATH];
int g_sprayElegido[MAXPLAYERS + 1];

// Animation system variables
int g_iGraffitiModelIndex = 0;
bool g_bIsPlayingSprayAnim[MAXPLAYERS + 1] = {false, ...};
int g_iStoredViewModel[MAXPLAYERS + 1] = {-1, ...};
Handle g_hAnimTimer[MAXPLAYERS + 1] = {INVALID_HANDLE, ...};

int g_time;
int g_distance;
bool g_use;
int g_maxMapSprays;
int g_resetTimeOnKill;
int g_showMsg;
bool g_enableAnimation;

Handle h_distance;
Handle h_time;
Handle hCvar;
Handle h_use;
Handle h_maxMapSprays;
Handle h_resetTimeOnKill;
Handle h_showMsg;
Handle h_enableAnimation;

Handle c_GameSprays = INVALID_HANDLE;

enum struct Listado
{
	char Nombre[32];
	int index;
}

enum struct MapSpray
{
	float vecPos[3];
	int index3;
}

Listado g_sprays[MAX_SPRAYS];
int g_sprayCount = 0;

MapSpray g_spraysMapAll[MAX_MAP_SPRAYS];
int g_sprayMapCount = 0;
int g_sprayIndexLast = 0;

#define PLUGIN "1.5.2-DEBUG"

public Plugin myinfo =
{
	name = "SM Franug CSGO Sprays DEBUG",
	author = "Franc1sco Steam: franug, Enhanced by Assistant",
	description = "DEBUG version to troubleshoot spray animation",
	version = PLUGIN,
	url = "http://steamcommunity.com/id/franug"
};

public void OnPluginStart()
{
	c_GameSprays = RegClientCookie("Sprays", "Sprays", CookieAccess_Private);
	hCvar = CreateConVar("sm_franugsprays_version", PLUGIN, "SM Franug CSGO Sprays DEBUG", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	SetConVarString(hCvar, PLUGIN);

	RegConsoleCmd("sm_spray", MakeSpray);
	RegConsoleCmd("sm_sprays", GetSpray);
	RegConsoleCmd("sm_spraydebug", DebugSpraySystem); // Debug command
	HookEvent("round_start", roundStart);
	HookEvent("player_death", Event_PlayerDeath);

	h_time = CreateConVar("sm_csgosprays_time", "10", "Cooldown between sprays (reduced for testing)");
	h_distance = CreateConVar("sm_csgosprays_distance", "115", "How far the sprayer can reach");
	h_use = CreateConVar("sm_csgosprays_use", "1", "Spray when a player runs +use (Default: E)");
	h_maxMapSprays = CreateConVar("sm_csgosprays_mapmax", "25", "Maximum ammount of sprays on the map");
	h_resetTimeOnKill = CreateConVar("sm_csgosprays_reset_time_on_kill", "1", "Reset the cooldown on a kill");
	h_showMsg = CreateConVar("sm_csgosprays_show_messages", "1", "Print messages of this plugin to the players");
	h_enableAnimation = CreateConVar("sm_csgosprays_enable_animation", "1", "Enable graffiti balloon animation during spraying");

	g_time = GetConVarInt(h_time);
	g_distance = GetConVarInt(h_distance);
	g_use = GetConVarBool(h_use);
	g_maxMapSprays = GetConVarInt(h_maxMapSprays);
	g_resetTimeOnKill = GetConVarBool(h_resetTimeOnKill);
	g_showMsg = GetConVarBool(h_showMsg);
	g_enableAnimation = GetConVarBool(h_enableAnimation);

	HookConVarChange(h_time, OnConVarChanged);
	HookConVarChange(h_distance, OnConVarChanged);
	HookConVarChange(hCvar, OnConVarChanged);
	HookConVarChange(h_use, OnConVarChanged);
	HookConVarChange(h_maxMapSprays, OnConVarChanged);
	HookConVarChange(h_resetTimeOnKill, OnConVarChanged);
	HookConVarChange(h_showMsg, OnConVarChanged);
	HookConVarChange(h_enableAnimation, OnConVarChanged);

	SetCookieMenuItem(SprayPrefSelected, 0, "Sprays");
	AutoExecConfig();
	
	PrintToServer("[SPRAY DEBUG] Plugin loaded - Animation enabled: %d", g_enableAnimation);
}

// Debug command to check spray system status
public Action DebugSpraySystem(int client, int args)
{
	if(!client)
		return Plugin_Handled;
		
	PrintToChat(client, "=== SPRAY DEBUG INFO ===");
	PrintToChat(client, "Animation enabled: %s", g_enableAnimation ? "YES" : "NO");
	PrintToChat(client, "Graffiti model index: %d", g_iGraffitiModelIndex);
	PrintToChat(client, "Is playing animation: %s", g_bIsPlayingSprayAnim[client] ? "YES" : "NO");
	PrintToChat(client, "Stored viewmodel: %d", g_iStoredViewModel[client]);
	
	// Check current viewmodel
	int viewModel = GetEntPropEnt(client, Prop_Send, "m_hViewModel");
	if(viewModel > 0)
	{
		int currentModel = GetEntProp(viewModel, Prop_Send, "m_nModelIndex");
		PrintToChat(client, "Current viewmodel: %d (entity: %d)", currentModel, viewModel);
		
		// Get model name
		char modelName[PLATFORM_MAX_PATH];
		GetPrecachedModelOfIndex(currentModel, modelName, sizeof(modelName));
		PrintToChat(client, "Model path: %s", modelName);
	}
	else
	{
		PrintToChat(client, "ERROR: No viewmodel found!");
	}
	
	return Plugin_Handled;
}

public void OnPluginEnd()
{
	for(int client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client))
		{
			if(g_bIsPlayingSprayAnim[client])
			{
				RestoreOriginalViewModel(client);
			}
			OnClientDisconnect(client);
		}
	}
}

public void OnClientCookiesCached(int client)
{
	char SprayString[12];
	GetClientCookie(client, c_GameSprays, SprayString, sizeof(SprayString));
	g_sprayElegido[client] = StringToInt(SprayString);
}

public void OnClientDisconnect(int client)
{
	if(g_hAnimTimer[client] != INVALID_HANDLE)
	{
		KillTimer(g_hAnimTimer[client]);
		g_hAnimTimer[client] = INVALID_HANDLE;
	}
	
	g_bIsPlayingSprayAnim[client] = false;
	g_iStoredViewModel[client] = -1;
	
	if(AreClientCookiesCached(client))
	{
		char SprayString[12];
		Format(SprayString, sizeof(SprayString), "%i", g_sprayElegido[client]);
		SetClientCookie(client, c_GameSprays, SprayString);
	}
}

public void OnConVarChanged(Handle convar, const char[] oldValue, const char[] newValue)
{
	if (convar == h_time)
	{
		g_time = StringToInt(newValue);
	}
	else if (convar == h_distance)
	{
		g_distance = StringToInt(newValue);
	}
	else if (convar == hCvar)
	{
		SetConVarString(hCvar, PLUGIN);
	}
	else if (convar == h_use)
	{
		g_use = view_as<bool>(StringToInt(newValue));
	}
	else if (convar == h_maxMapSprays)
	{
		if(StringToInt(newValue) > MAX_MAP_SPRAYS)
		{
			g_maxMapSprays = MAX_MAP_SPRAYS;
			SetConVarInt(h_maxMapSprays, MAX_MAP_SPRAYS);
		}
		else
			g_maxMapSprays = StringToInt(newValue);
	}
	else if (convar == h_resetTimeOnKill)
	{
		g_resetTimeOnKill = view_as<bool>(StringToInt(newValue));
	}
	else if (convar == h_showMsg)
	{
		g_showMsg = view_as<bool>(StringToInt(newValue));
	}
	else if (convar == h_enableAnimation)
	{
		g_enableAnimation = view_as<bool>(StringToInt(newValue));
		PrintToServer("[SPRAY DEBUG] Animation toggled: %s", g_enableAnimation ? "ENABLED" : "DISABLED");
	}
}

public Action roundStart(Handle event, const char[] name, bool dontBroadcast)
{
	for (int i = 1; i < MaxClients; i++)
		if (IsClientInGame(i))
			g_iLastSprayed[i] = false;

	if(g_sprayMapCount > g_maxMapSprays)
		g_sprayMapCount = g_maxMapSprays;
	for (int j = 0; j < g_sprayMapCount; j++)
	{
		TE_SetupBSPDecalCall(g_spraysMapAll[j].vecPos, g_spraysMapAll[j].index3);
		TE_SendToAll();
	}
}

public void OnClientPostAdminCheck(int iClient)
{
	g_iLastSprayed[iClient] = false;
	g_bIsPlayingSprayAnim[iClient] = false;
	g_iStoredViewModel[iClient] = -1;
	g_hAnimTimer[iClient] = INVALID_HANDLE;
}

public void OnMapStart()
{
	char sBuffer[256];
	Format(sBuffer, sizeof(sBuffer), "sound/%s", SOUND_SPRAY);
	AddFileToDownloadsTable(sBuffer);

	FakePrecacheSound(SOUND_SPRAY_REL);

	// Precache graffiti balloon model with extensive logging
	PrintToServer("[SPRAY DEBUG] Attempting to precache model: %s", GRAFFITI_MODEL);
	g_iGraffitiModelIndex = PrecacheModel(GRAFFITI_MODEL);
	PrintToServer("[SPRAY DEBUG] Model precached with index: %d", g_iGraffitiModelIndex);
	
	AddFileToDownloadsTable(GRAFFITI_MODEL);
	AddFileToDownloadsTable("materials/Models/12konsta/graffiti/v_ballon4ik.vmt");
	AddFileToDownloadsTable("materials/Models/12konsta/graffiti/v_ballon4ik.vtf");

	BuildPath(Path_SM, path_decals, sizeof(path_decals), "configs/csgo-sprays/sprays.cfg");
	ReadDecals();
	g_sprayMapCount = 0;
	g_sprayIndexLast = 0;
	
	PrintToServer("[SPRAY DEBUG] Map start complete. Graffiti model index: %d", g_iGraffitiModelIndex);
}

// Debug function to store current viewmodel
void StoreCurrentViewModel(int client)
{
	int viewModel = GetEntPropEnt(client, Prop_Send, "m_hViewModel");
	PrintToChat(client, "[DEBUG] Getting viewmodel entity: %d", viewModel);
	
	if(viewModel > 0 && IsValidEntity(viewModel))
	{
		g_iStoredViewModel[client] = GetEntProp(viewModel, Prop_Send, "m_nModelIndex");
		PrintToChat(client, "[DEBUG] Stored current viewmodel index: %d", g_iStoredViewModel[client]);
		
		// Get current model name for debugging
		char currentModelName[PLATFORM_MAX_PATH];
		GetPrecachedModelOfIndex(g_iStoredViewModel[client], currentModelName, sizeof(currentModelName));
		PrintToChat(client, "[DEBUG] Current model: %s", currentModelName);
	}
	else
	{
		PrintToChat(client, "[DEBUG] ERROR: Invalid viewmodel entity!");
	}
}

// Debug function to switch to graffiti balloon viewmodel
void SetGraffitiViewModel(int client)
{
	int viewModel = GetEntPropEnt(client, Prop_Send, "m_hViewModel");
	PrintToChat(client, "[DEBUG] Setting graffiti model on entity: %d", viewModel);
	
	if(viewModel > 0 && IsValidEntity(viewModel))
	{
		PrintToChat(client, "[DEBUG] Changing model from %d to %d", GetEntProp(viewModel, Prop_Send, "m_nModelIndex"), g_iGraffitiModelIndex);
		SetEntProp(viewModel, Prop_Send, "m_nModelIndex", g_iGraffitiModelIndex);
		
		// Verify the change
		int newModelIndex = GetEntProp(viewModel, Prop_Send, "m_nModelIndex");
		PrintToChat(client, "[DEBUG] Model change result: %d (should be %d)", newModelIndex, g_iGraffitiModelIndex);
		
		if(newModelIndex == g_iGraffitiModelIndex)
		{
			PrintToChat(client, "[DEBUG] ✅ Model change SUCCESS!");
		}
		else
		{
			PrintToChat(client, "[DEBUG] ❌ Model change FAILED!");
		}
	}
	else
	{
		PrintToChat(client, "[DEBUG] ERROR: Cannot set model on invalid entity!");
	}
}

// Debug function to restore original viewmodel
void RestoreOriginalViewModel(int client)
{
	if(!g_bIsPlayingSprayAnim[client] || g_iStoredViewModel[client] == -1)
	{
		PrintToChat(client, "[DEBUG] Restore skipped - not animating or no stored model");
		return;
	}
		
	int viewModel = GetEntPropEnt(client, Prop_Send, "m_hViewModel");
	PrintToChat(client, "[DEBUG] Restoring viewmodel on entity: %d", viewModel);
	
	if(viewModel > 0 && IsValidEntity(viewModel))
	{
		PrintToChat(client, "[DEBUG] Restoring model from %d to %d", GetEntProp(viewModel, Prop_Send, "m_nModelIndex"), g_iStoredViewModel[client]);
		SetEntProp(viewModel, Prop_Send, "m_nModelIndex", g_iStoredViewModel[client]);
		
		// Verify the restoration
		int restoredModelIndex = GetEntProp(viewModel, Prop_Send, "m_nModelIndex");
		PrintToChat(client, "[DEBUG] Model restore result: %d (should be %d)", restoredModelIndex, g_iStoredViewModel[client]);
	}
	
	g_bIsPlayingSprayAnim[client] = false;
	g_iStoredViewModel[client] = -1;
	PrintToChat(client, "[DEBUG] Animation state reset");
}

// Timer callback to restore original viewmodel
public Action Timer_RestoreViewModel(Handle timer, int client)
{
	g_hAnimTimer[client] = INVALID_HANDLE;
	PrintToChat(client, "[DEBUG] Timer triggered - restoring viewmodel");
	
	if(IsClientInGame(client) && IsPlayerAlive(client))
	{
		RestoreOriginalViewModel(client);
	}
	else
	{
		g_bIsPlayingSprayAnim[client] = false;
		g_iStoredViewModel[client] = -1;
		PrintToChat(client, "[DEBUG] Timer cleanup - client not valid");
	}
	
	return Plugin_Stop;
}

// Debug spray function with detailed logging
Action PerformSprayWithAnimation(int client, float fClientEyeViewPoint[3])
{
	PrintToChat(client, "[DEBUG] === SPRAY ANIMATION START ===");
	PrintToChat(client, "[DEBUG] Animation enabled: %s", g_enableAnimation ? "YES" : "NO");
	PrintToChat(client, "[DEBUG] Currently animating: %s", g_bIsPlayingSprayAnim[client] ? "YES" : "NO");
	PrintToChat(client, "[DEBUG] Client valid: %s", (IsClientInGame(client) && IsPlayerAlive(client)) ? "YES" : "NO");
	PrintToChat(client, "[DEBUG] Graffiti model index: %d", g_iGraffitiModelIndex);
	
	// Store current viewmodel if animation is enabled and client is valid
	if(g_enableAnimation && !g_bIsPlayingSprayAnim[client] && IsClientInGame(client) && IsPlayerAlive(client))
	{
		// Check if we have a valid graffiti model index
		if(g_iGraffitiModelIndex <= 0)
		{
			PrintToChat(client, "[DEBUG] ❌ FAILED: Invalid graffiti model index: %d", g_iGraffitiModelIndex);
		}
		else
		{
			PrintToChat(client, "[DEBUG] ✅ Starting animation sequence...");
			StoreCurrentViewModel(client);
			SetGraffitiViewModel(client);
			g_bIsPlayingSprayAnim[client] = true;
			
			// Set timer to restore original viewmodel
			if(g_hAnimTimer[client] != INVALID_HANDLE)
			{
				KillTimer(g_hAnimTimer[client]);
				PrintToChat(client, "[DEBUG] Killed existing timer");
			}
			g_hAnimTimer[client] = CreateTimer(GRAFFITI_ANIM_DURATION, Timer_RestoreViewModel, client);
			PrintToChat(client, "[DEBUG] Timer set for %.1f seconds", GRAFFITI_ANIM_DURATION);
		}
	}
	else
	{
		PrintToChat(client, "[DEBUG] Animation skipped - conditions not met");
	}
	
	// Create the spray decal
	if(g_sprayElegido[client] == 0)
	{
		TE_SetupBSPDecal(fClientEyeViewPoint, g_sprays[GetRandomInt(1, g_sprayCount-1)].index);
	}
	else
	{
		if(g_sprays[g_sprayElegido[client]].index == 0)
		{
			PrintToChat(client, " \x04[SM_CSGO-SPRAYS]\x01 Your spray doesn't work, choose another one with !sprays!");
			return Plugin_Handled;
		}
		TE_SetupBSPDecal(fClientEyeViewPoint, g_sprays[g_sprayElegido[client]].index);
		
		// Save spray position and identifier
		if(g_sprayIndexLast == g_maxMapSprays)
			g_sprayIndexLast = 0;
		g_spraysMapAll[g_sprayIndexLast].vecPos = fClientEyeViewPoint;
		g_spraysMapAll[g_sprayIndexLast].index3 = g_sprays[g_sprayElegido[client]].index;
		g_sprayIndexLast++;
		if(g_sprayMapCount != g_maxMapSprays)
			g_sprayMapCount++;
	}
	TE_SendToAll();
	
	PrintToChat(client, "[DEBUG] === SPRAY ANIMATION END ===");
	return Plugin_Continue;
}

public Action MakeSpray(int iClient, int args)
{
	if(!iClient || !IsClientInGame(iClient))
		return Plugin_Continue;

	if(!IsPlayerAlive(iClient))
	{
		if(g_showMsg)
		{
			PrintToChat(iClient, " \x04[SM_CSGO-SPRAYS]\x01 You need to be alive to use this command!");
		}
		return Plugin_Handled;
	}

	// Check if already playing spray animation
	if(g_bIsPlayingSprayAnim[iClient])
	{
		if(g_showMsg)
		{
			PrintToChat(iClient, " \x04[SM_CSGO-SPRAYS]\x01 Please wait for the current spray animation to finish!");
		}
		return Plugin_Handled;
	}

	int iTime = GetTime();
	int restante = (iTime - g_iLastSprayed[iClient]);

	if(restante < g_time)
	{
		if(g_showMsg)
		{
			PrintToChat(iClient, " \x04[SM_CSGO-SPRAYS]\x01 You need to wait %i second(s) to use this command again!", g_time-restante);
		}
		return Plugin_Handled;
	}

	float fClientEyePosition[3];
	GetClientEyePosition(iClient, fClientEyePosition);

	float fClientEyeViewPoint[3];
	GetPlayerEyeViewPoint(iClient, fClientEyeViewPoint);

	float fVector[3];
	MakeVectorFromPoints(fClientEyeViewPoint, fClientEyePosition, fVector);

	if(GetVectorLength(fVector) > g_distance)
	{
		if(g_showMsg)
		{
			PrintToChat(iClient, " \x04[SM_CSGO-SPRAYS]\x01 You are too far away from the wall to use this command!");
		}
		return Plugin_Handled;
	}

	// Perform spray with debug animation
	PerformSprayWithAnimation(iClient, fClientEyeViewPoint);

	EmitSoundToAll(SOUND_SPRAY_REL, iClient, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.6);

	g_iLastSprayed[iClient] = iTime;
	return Plugin_Handled;
}

public Action GetSpray(int client, int args)
{
	Menu menu = new Menu(DIDMenuHandler);
	menu.SetTitle("Choose your Spray");
	char item[4];
	menu.AddItem("0", "Random spray");
	for (int i=1; i<g_sprayCount; ++i) {
		Format(item, 4, "%i", i);
		menu.AddItem(item, g_sprays[i].Nombre);
	}
	menu.ExitButton = true;
	menu.Display(client, 0);
}

public int DIDMenuHandler(Menu menu, MenuAction action, int client, int itemNum)
{
	if ( action == MenuAction_Select )
	{
		char info[4];

		GetMenuItem(menu, itemNum, info, sizeof(info));
		g_sprayElegido[client] = StringToInt(info);
		if(g_showMsg)
		{
			if(g_sprayElegido[client] == 0)
			{
				PrintToChat(client, " \x04[SM_CSGO-SPRAYS]\x01 You have choosen\x03 a random spray \x01as your spray!");
			}
			else
			{
				PrintToChat(client, " \x04[SM_CSGO-SPRAYS]\x01 You have choosen\x03 %s \x01as your spray!",g_sprays[g_sprayElegido[client]].Nombre);
			}
		}
	}
	else if (action == MenuAction_Cancel) 
	{ 
		PrintToServer("Client %d's menu was cancelled.  Reason: %d", client, itemNum); 
	} 
		
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

stock bool GetPlayerEyeViewPoint(int iClient, float fPosition[3])
{
	float fAngles[3];
	GetClientEyeAngles(iClient, fAngles);

	float fOrigin[3];
	GetClientEyePosition(iClient, fOrigin);

	Handle hTrace = TR_TraceRayFilterEx(fOrigin, fAngles, MASK_SHOT, RayType_Infinite, TraceEntityFilterPlayer);
	if(TR_DidHit(hTrace))
	{
		TR_GetEndPosition(fPosition, hTrace);
		CloseHandle(hTrace);
		return true;
	}
	CloseHandle(hTrace);
	return false;
}

public bool TraceEntityFilterPlayer(int iEntity, int iContentsMask)
{
	return iEntity > MaxClients;
}

void TE_SetupBSPDecalCall(const float[] vecOrigin, int index2) {
	float vector[3];
	for (int i=0; i < 3; i++)
		vector[i] = vecOrigin[i];
	TE_SetupBSPDecal(vector, index2);
}

void TE_SetupBSPDecal(const float vecOrigin[3], int index2) {
	TE_Start("World Decal");
	TE_WriteVector("m_vecOrigin",vecOrigin);
	TE_WriteNum("m_nIndex",index2);
}

void ReadDecals() {
	char buffer[PLATFORM_MAX_PATH];
	char download[PLATFORM_MAX_PATH];
	Handle kv;
	Handle vtf;
	g_sprayCount = 1;

	kv = CreateKeyValues("Sprays");
	FileToKeyValues(kv, path_decals);

	if (!KvGotoFirstSubKey(kv)) {
		SetFailState("CFG File not found: %s", path_decals);
		CloseHandle(kv);
	}
	do {
		KvGetSectionName(kv, buffer, sizeof(buffer));
		Format(g_sprays[g_sprayCount].Nombre, 32, "%s", buffer);
		KvGetString(kv, "path", buffer, sizeof(buffer));
		
		int precacheId = PrecacheDecal(buffer, true);
		g_sprays[g_sprayCount].index = precacheId;
		char decalpath[PLATFORM_MAX_PATH];
		Format(decalpath, sizeof(decalpath), buffer);
		Format(download, sizeof(download), "materials/%s.vmt", buffer);
		AddFileToDownloadsTable(download);
		vtf = CreateKeyValues("LightmappedGeneric");
		FileToKeyValues(vtf, download);
		KvGetString(vtf, "$basetexture", buffer, sizeof(buffer), buffer);
		CloseHandle(vtf);
		Format(download, sizeof(download), "materials/%s.vtf", buffer);
		AddFileToDownloadsTable(download);
		g_sprayCount++;
	} while (KvGotoNextKey(kv));
	CloseHandle(kv);

	for (int i=g_sprayCount; i<MAX_SPRAYS; ++i) 
	{
		g_sprays[i].index = 0;
	}
}

public Action OnPlayerRunCmd(int iClient, int &buttons, int &impulse)
{
	if(!g_use) return;

	if (buttons & IN_USE)
	{
		if(!IsPlayerAlive(iClient))
		{
			return;
		}

		// Check if already playing spray animation
		if(g_bIsPlayingSprayAnim[iClient])
		{
			return;
		}

		int iTime = GetTime();
		int restante = (iTime - g_iLastSprayed[iClient]);

		if(restante < g_time)
		{
			return;
		}

		float fClientEyePosition[3];
		GetClientEyePosition(iClient, fClientEyePosition);

		float fClientEyeViewPoint[3];
		GetPlayerEyeViewPoint(iClient, fClientEyeViewPoint);

		float fVector[3];
		MakeVectorFromPoints(fClientEyeViewPoint, fClientEyePosition, fVector);

		if(GetVectorLength(fVector) > g_distance)
		{
			return;
		}

		// Perform spray with debug animation
		PerformSprayWithAnimation(iClient, fClientEyeViewPoint);

		if(g_showMsg)
		{
			PrintToChat(iClient, " \x04[SM_CSGO-SPRAYS]\x01 You have used your spray.");
		}
		EmitAmbientSound(SOUND_SPRAY_REL, fVector, iClient, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.6);

		g_iLastSprayed[iClient] = iTime;
	}
}

public Action Event_PlayerDeath(Handle event, const char[] name, bool dontBroadcast)
{
	if(g_resetTimeOnKill)
	{
		int user = GetClientOfUserId(GetEventInt(event, "attacker"));
		int victim = GetClientOfUserId(GetEventInt(event, "userid"));

		if(user == 0 || user == victim || IsFakeClient(user))
			return Plugin_Continue;
		
		g_iLastSprayed[user] = false;
	}

	int victim = GetClientOfUserId(GetEventInt(event, "userid"));
	if(victim > 0 && g_bIsPlayingSprayAnim[victim])
	{
		if(g_hAnimTimer[victim] != INVALID_HANDLE)
		{
			KillTimer(g_hAnimTimer[victim]);
			g_hAnimTimer[victim] = INVALID_HANDLE;
		}
		RestoreOriginalViewModel(victim);
	}

	return Plugin_Continue;
}

stock void FakePrecacheSound(const char[] szPath)
{
	AddToStringTable( FindStringTable( "soundprecache" ), szPath );
}

public int SprayPrefSelected(int client, CookieMenuAction action, any info, char[] buffer, int maxlen)
{
	if (action == CookieMenuAction_SelectOption)
	{
		GetSpray(client,0);
	}
}