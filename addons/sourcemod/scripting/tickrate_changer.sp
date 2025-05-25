#pragma newdecls required
#pragma semicolon 1

#include <dhooks>

#define DEFAULT_TICK_INTERVAL	(0.015)
#define MINIMUM_TICK_INTERVAL	(0.001)
#define MAXIMUM_TICK_INTERVAL	(0.1)

ConVar sm_interval_per_tick;

Address sv;			// CBaseServer
Address host_state;	// CCommonHostState

int m_flTickInterval;	// CBaseServer::m_flTickInterval
int interval_per_tick;	// CCommonHostState::interval_per_tick

float g_flTickInterval = DEFAULT_TICK_INTERVAL;

public Plugin myinfo =
{
	name = "Runtime Tickrate Changer",
	author = "Mikusch, ficool2",
	description = "Allows changing the server's tickrate at runtime.",
	version = "1.1.0",
	url = "https://github.com/Mikusch/SM-TickrateChanger"
}

public void OnPluginStart()
{
	GameData gamedata = new GameData("tickrate_changer");
	if (!gamedata)
		SetFailState("Failed to find gamedata/tickrate_changer.txt");
	
	CreateDetour(gamedata, "CServerGameDLL::GetTickInterval", CServerGameDLL_GetTickInterval);
	CreateDetour(gamedata, "CGameServer::SpawnServer", CGameServer_SpawnServer);
	CreateDetour(gamedata, "SV_ActivateServer", SV_ActivateServer);

	sv =  GetMemSig(gamedata, "sv");
	host_state = GetMemSig(gamedata, "host_state");

	m_flTickInterval = GetOffset(gamedata, "CBaseServer::m_flTickInterval");
	interval_per_tick = GetOffset(gamedata, "CCommonHostState::interval_per_tick");

	delete gamedata;
	
	sm_interval_per_tick = CreateConVar("sm_interval_per_tick", "0.015", "Time between server ticks (applied on level change).", FCVAR_NOTIFY, true, MINIMUM_TICK_INTERVAL, true, MAXIMUM_TICK_INTERVAL);
	RegServerCmd("sm_tickrate", OnTickRateChanged, "Sets the tickrate of the server (applied on level change).");
	
	RegPluginLibrary("tickrate_changer");
}

void UpdateTickInterval()
{
	int tickrate = GetCommandLineParamInt("-tickrate", 0);
	if (tickrate)
		sm_interval_per_tick.FloatValue = (1.0 / tickrate);
	
	g_flTickInterval = sm_interval_per_tick.FloatValue;
}

DynamicDetour CreateDetour(GameData gamedata, const char[] name, DHookCallback callback)
{
	DynamicDetour detour = DynamicDetour.FromConf(gamedata, name);
	if (detour == null)
		SetFailState("Failed to setup '%s' detour", name);
	
	if (!detour.Enable(Hook_Pre, callback))
		SetFailState("Failed to enable '%s' detour", name);
	
	return detour;
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

static MRESReturn CServerGameDLL_GetTickInterval(DHookReturn ret)
{
	StoreToAddress(sv + view_as<Address>(m_flTickInterval), g_flTickInterval, NumberType_Int32);
	
	ret.Value = g_flTickInterval;
	return MRES_Supercede;
}

// Called on level change
static MRESReturn CGameServer_SpawnServer(DHookReturn ret, DHookParam params)
{
	UpdateTickInterval();
	StoreToAddress(host_state + view_as<Address>(interval_per_tick), g_flTickInterval, NumberType_Int32);

	return MRES_Ignored;
}

// Called on server init and level change
static MRESReturn SV_ActivateServer(DHookReturn ret)
{
	UpdateTickInterval();

	return MRES_Ignored;
}

static Action OnTickRateChanged(int args)
{
	if (args < 1)
	{
		ReplyToCommand(0, "[SM] Usage: sm_tickrate <tickrate>");
		return Plugin_Handled;
	}

	if (GetCmdArgInt(1))
		sm_interval_per_tick.FloatValue = (1.0 / GetCmdArgInt(1));
	else
		sm_interval_per_tick.RestoreDefault();
	
	return Plugin_Handled;
}
