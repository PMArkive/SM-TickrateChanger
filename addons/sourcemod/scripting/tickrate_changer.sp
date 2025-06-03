#pragma newdecls required
#pragma semicolon 1

#include <dhooks>

#define MINIMUM_TICK_INTERVAL	(0.001)
#define MAXIMUM_TICK_INTERVAL	(0.1)

ConVar sm_interval_per_tick;

Address sv;					// CBaseServer
Address host_state;			// CCommonHostState
Address g_ServerGameDLL;	// CServerGameDLL

int m_flTickInterval;	// CBaseServer::m_flTickInterval
int interval_per_tick;	// CCommonHostState::interval_per_tick

public Plugin myinfo =
{
	name = "Runtime Tickrate Changer",
	author = "Mikusch, ficool2",
	description = "Allows changing the server's tickrate at runtime.",
	version = "1.1.1",
	url = "https://github.com/Mikusch/SM-TickrateChanger"
}

public void OnPluginStart()
{
	GameData gamedata = new GameData("tickrate_changer");
	if (!gamedata)
		SetFailState("Failed to find gamedata/tickrate_changer.txt");
	
	sv =  GetMemSig(gamedata, "sv");
	host_state = GetMemSig(gamedata, "host_state");
	g_ServerGameDLL = GetMemSig(gamedata, "g_ServerGameDLL");
	
	m_flTickInterval = GetOffset(gamedata, "CBaseServer::m_flTickInterval");
	interval_per_tick = GetOffset(gamedata, "CCommonHostState::interval_per_tick");
	
	char defInterval[32];
	FloatToString(GetDefaultTickInterval(gamedata), defInterval, sizeof(defInterval));
	
	DynamicDetour detour = CreateDynamicDetour(gamedata, "CGameServer::SpawnServer");
	detour.Enable(Hook_Pre, CGameServer_SpawnServer);
	
	DynamicHook hook = CreateDynamicHook(gamedata, "CServerGameDLL::GetTickInterval");
	hook.HookRaw(Hook_Pre, g_ServerGameDLL, CServerGameDLL_GetTickInterval);
	
	delete detour;
	delete hook;
	delete gamedata;
	
	sm_interval_per_tick = CreateConVar("sm_interval_per_tick", defInterval, "Time between server ticks (applied on level change).", FCVAR_NOTIFY, true, MINIMUM_TICK_INTERVAL, true, MAXIMUM_TICK_INTERVAL);
	RegServerCmd("sm_tickrate", OnTickRateChanged, "Sets the tickrate of the server (applied on level change).");
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("tickrate_changer");
	
	return APLRes_Success;
}

float GetCustomTickInterval()
{
	int tickrate = GetCommandLineParamInt("-tickrate", 0);
	if (tickrate)
		sm_interval_per_tick.FloatValue = (1.0 / tickrate);
	
	return sm_interval_per_tick.FloatValue;
}

DynamicDetour CreateDynamicDetour(GameData gamedata, const char[] name)
{
	DynamicDetour detour = DynamicDetour.FromConf(gamedata, name);
	if (detour == null)
		SetFailState("Failed to setup '%s' detour", name);
	
	return detour;
}

DynamicHook CreateDynamicHook(GameData gamedata, const char[] name)
{
	DynamicHook hook = DynamicHook.FromConf(gamedata, name);
	if (hook == null)
		SetFailState("Failed to setup '%s' hook", name);
	
	return hook;
}

Address GetMemSig(GameData gamedata, const char[] name)
{
	Address adr = gamedata.GetMemSig(name);
	if (adr == Address_Null)
		SetFailState("Failed to find '%s' signature", name);
	
	return adr;
}

int GetOffset(GameData gamedata, const char[] name)
{
	int offset = gamedata.GetOffset(name);
	if (offset == -1)
		SetFailState("Failed to find '%s' offset", name);
	
	return offset;
}

float GetDefaultTickInterval(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Virtual, "CServerGameDLL::GetTickInterval");
	PrepSDKCall_SetReturnInfo(SDKType_Float, SDKPass_ByValue);
	Handle call = EndPrepSDKCall();
	if (!call)
		SetFailState("Failed to create SDKCall 'CServerGameDLL::GetTickInterval'");
	
	float interval = SDKCall(call, g_ServerGameDLL);
	delete call;
	return interval;
}

static MRESReturn CServerGameDLL_GetTickInterval(DHookReturn ret)
{
	float interval = GetCustomTickInterval();
	StoreToAddress(sv + view_as<Address>(m_flTickInterval), interval, NumberType_Int32);
	ret.Value = interval;
	return MRES_Supercede;
}

static MRESReturn CGameServer_SpawnServer(DHookReturn ret, DHookParam params)
{
	// This will make sure certain tick-related properties in CGameServer are set correctly
	StoreToAddress(host_state + view_as<Address>(interval_per_tick), GetCustomTickInterval(), NumberType_Int32);
	return MRES_Ignored;
}

static Action OnTickRateChanged(int args)
{
	if (args < 1)
	{
		ReplyToCommand(0, "[SM] Usage: sm_tickrate <tickrate>");
		return Plugin_Handled;
	}
	
	int tickrate = GetCmdArgInt(1);
	if (tickrate)
		sm_interval_per_tick.FloatValue = (1.0 / tickrate);
	else
		sm_interval_per_tick.RestoreDefault();
	
	return Plugin_Handled;
}
