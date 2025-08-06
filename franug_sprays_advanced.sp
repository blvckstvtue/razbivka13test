/* Advanced version that works with custom_weapons.sp by hooking model changes */

#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <clientprefs>

#define SOUND_SPRAY_REL "*/items/spraycan_spray.wav"
#define SOUND_SPRAY "items/spraycan_spray.wav"

// Graffiti balloon model
#define GRAFFITI_MODEL "models/12konsta/graffiti/v_ballon4ik.mdl"
#define GRAFFITI_ANIM_DURATION 2.0

#define MAX_SPRAYS 128
#define MAX_MAP_SPRAYS 200

int g_iLastSprayed[MAXPLAYERS + 1];
char path_decals[PLATFORM_MAX_PATH];
int g_sprayElegido[MAXPLAYERS + 1];

// Advanced animation system variables
int g_iGraffitiModelIndex = 0;
bool g_bIsPlayingSprayAnim[MAXPLAYERS + 1] = {false, ...};
int g_iStoredViewModel[MAXPLAYERS + 1] = {-1, ...};
Handle g_hAnimTimer[MAXPLAYERS + 1] = {INVALID_HANDLE, ...};
Handle g_hProtectionTimer[MAXPLAYERS + 1] = {INVALID_HANDLE, ...};

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

#define PLUGIN "1.6.0-ADVANCED"

public Plugin myinfo =
{
	name = "SM Franug CSGO Sprays Advanced",
	author = "Franc1sco Steam: franug, Enhanced by Assistant",
	description = "Advanced spray system that works with custom_weapons.sp",
	version = PLUGIN,
	url = "http://steamcommunity.com/id/franug"
};

public void OnPluginStart()
{
	c_GameSprays = RegClientCookie("Sprays", "Sprays", CookieAccess_Private);
	hCvar = CreateConVar("sm_franugsprays_version", PLUGIN, "SM Franug CSGO Sprays Advanced", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	SetConVarString(hCvar, PLUGIN);

	RegConsoleCmd("sm_spray", MakeSpray);
	RegConsoleCmd("sm_sprays", GetSpray);
	HookEvent("round_start", roundStart);
	HookEvent("player_death", Event_PlayerDeath);

	h_time = CreateConVar("sm_csgosprays_time", "30", "Cooldown between sprays");
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
	
	PrintToServer("[SPRAY ADVANCED] Plugin loaded - Animation enabled: %d", g_enableAnimation);
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
	// Clean up animation timers
	if(g_hAnimTimer[client] != INVALID_HANDLE)
	{
		KillTimer(g_hAnimTimer[client]);
		g_hAnimTimer[client] = INVALID_HANDLE;
	}
	
	if(g_hProtectionTimer[client] != INVALID_HANDLE)
	{
		KillTimer(g_hProtectionTimer[client]);
		g_hProtectionTimer[client] = INVALID_HANDLE;
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
	g_hProtectionTimer[iClient] = INVALID_HANDLE;
}

public void OnMapStart()
{
	char sBuffer[256];
	Format(sBuffer, sizeof(sBuffer), "sound/%s", SOUND_SPRAY);
	AddFileToDownloadsTable(sBuffer);

	FakePrecacheSound(SOUND_SPRAY_REL);

	// Precache graffiti balloon model
	g_iGraffitiModelIndex = PrecacheModel(GRAFFITI_MODEL);
	AddFileToDownloadsTable(GRAFFITI_MODEL);
	
	// Add materials to download table
	AddFileToDownloadsTable("materials/Models/12konsta/graffiti/v_ballon4ik.vmt");
	AddFileToDownloadsTable("materials/Models/12konsta/graffiti/v_ballon4ik.vtf");

	BuildPath(Path_SM, path_decals, sizeof(path_decals), "configs/csgo-sprays/sprays.cfg");
	ReadDecals();
	g_sprayMapCount = 0;
	g_sprayIndexLast = 0;
}

// Function to store current viewmodel
void StoreCurrentViewModel(int client)
{
	int viewModel = GetEntPropEnt(client, Prop_Send, "m_hViewModel");
	if(viewModel > 0 && IsValidEntity(viewModel))
	{
		g_iStoredViewModel[client] = GetEntProp(viewModel, Prop_Send, "m_nModelIndex");
	}
}

// Advanced function to set and PROTECT graffiti viewmodel
void SetGraffitiViewModel(int client)
{
	int viewModel = GetEntPropEnt(client, Prop_Send, "m_hViewModel");
	if(viewModel > 0 && IsValidEntity(viewModel))
	{
		SetEntProp(viewModel, Prop_Send, "m_nModelIndex", g_iGraffitiModelIndex);
		
		// Start aggressive protection timer to fight against custom_weapons.sp
		if(g_hProtectionTimer[client] != INVALID_HANDLE)
		{
			KillTimer(g_hProtectionTimer[client]);
		}
		g_hProtectionTimer[client] = CreateTimer(0.1, Timer_ProtectGraffitiModel, client, TIMER_REPEAT);
	}
}

// Timer that repeatedly ensures graffiti model stays active
public Action Timer_ProtectGraffitiModel(Handle timer, int client)
{
	if(!IsClientInGame(client) || !IsPlayerAlive(client) || !g_bIsPlayingSprayAnim[client])
	{
		g_hProtectionTimer[client] = INVALID_HANDLE;
		return Plugin_Stop;
	}
	
	int viewModel = GetEntPropEnt(client, Prop_Send, "m_hViewModel");
	if(viewModel > 0 && IsValidEntity(viewModel))
	{
		int currentModel = GetEntProp(viewModel, Prop_Send, "m_nModelIndex");
		
		// If custom_weapons.sp changed our model back, force it again
		if(currentModel != g_iGraffitiModelIndex)
		{
			SetEntProp(viewModel, Prop_Send, "m_nModelIndex", g_iGraffitiModelIndex);
			// Optional: Show debug message
			// PrintToChat(client, "[SPRAY] Fighting custom_weapons interference!");
		}
	}
	
	return Plugin_Continue;
}

// Function to restore original viewmodel
void RestoreOriginalViewModel(int client)
{
	if(!g_bIsPlayingSprayAnim[client] || g_iStoredViewModel[client] == -1)
		return;
		
	// Stop protection timer
	if(g_hProtectionTimer[client] != INVALID_HANDLE)
	{
		KillTimer(g_hProtectionTimer[client]);
		g_hProtectionTimer[client] = INVALID_HANDLE;
	}
		
	int viewModel = GetEntPropEnt(client, Prop_Send, "m_hViewModel");
	if(viewModel > 0 && IsValidEntity(viewModel))
	{
		SetEntProp(viewModel, Prop_Send, "m_nModelIndex", g_iStoredViewModel[client]);
	}
	
	g_bIsPlayingSprayAnim[client] = false;
	g_iStoredViewModel[client] = -1;
}

// Timer callback to restore original viewmodel
public Action Timer_RestoreViewModel(Handle timer, int client)
{
	g_hAnimTimer[client] = INVALID_HANDLE;
	
	if(IsClientInGame(client) && IsPlayerAlive(client))
	{
		RestoreOriginalViewModel(client);
	}
	else
	{
		g_bIsPlayingSprayAnim[client] = false;
		g_iStoredViewModel[client] = -1;
	}
	
	return Plugin_Stop;
}

// Enhanced spray function with protection system
Action PerformSprayWithAnimation(int client, float fClientEyeViewPoint[3])
{
	// Store current viewmodel if animation is enabled and client is valid
	if(g_enableAnimation && !g_bIsPlayingSprayAnim[client] && IsClientInGame(client) && IsPlayerAlive(client))
	{
		// Check if we have a valid graffiti model index
		if(g_iGraffitiModelIndex <= 0)
		{
			if(g_showMsg)
			{
				PrintToChat(client, " \x04[SM_CSGO-SPRAYS]\x01 Graffiti model not loaded properly!");
			}
		}
		else
		{
			StoreCurrentViewModel(client);
			SetGraffitiViewModel(client); // This starts the protection timer
			g_bIsPlayingSprayAnim[client] = true;
			
			// Set timer to restore original viewmodel
			if(g_hAnimTimer[client] != INVALID_HANDLE)
			{
				KillTimer(g_hAnimTimer[client]);
			}
			g_hAnimTimer[client] = CreateTimer(GRAFFITI_ANIM_DURATION, Timer_RestoreViewModel, client);
			
			if(g_showMsg)
			{
				PrintToChat(client, " \x04[SM_CSGO-SPRAYS]\x01 Graffiti balloon animation activated!");
			}
		}
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
			if(g_showMsg)
			{
				PrintToChat(client, " \x04[SM_CSGO-SPRAYS]\x01 Your spray doesn't work, choose another one with !sprays!");
			}
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

	// Perform spray with advanced animation protection
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

		// Perform spray with advanced animation protection
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
		
		if(g_hProtectionTimer[victim] != INVALID_HANDLE)
		{
			KillTimer(g_hProtectionTimer[victim]);
			g_hProtectionTimer[victim] = INVALID_HANDLE;
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