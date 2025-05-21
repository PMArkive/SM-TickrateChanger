
#pragma newdecls required
#pragma semicolon 1

#include <dhooks>

// The range check in the engine is wrong
#define MINIMUM_TICK_INTERVAL	(0.0011)
#define MAXIMUM_TICK_INTERVAL	(0.0999)

ConVar sm_tickrate;

Address sv;
int m_offset_flTickInterval;

float g_flTickInterval = -1.0;

public Plugin myinfo =
{
	name = "Tickrate Changer",
	author = "Mikusch, ficool2",
	description = "Allows changing the server's tickrate at runtime.",
	version = "1.0.1",
	url = "https://github.com/Mikusch/SM-TickrateChanger"
}

public void OnPluginStart()
{
	GameData gamedata = new GameData("tickrate_changer");
	if (!gamedata)
		ThrowError("Failed to find gamedata/tickrate_changer.txt");
	
	DynamicDetour detour = DynamicDetour.FromConf(gamedata, "CServerGameDLL::GetTickInterval");
	if (detour == null)
		ThrowError("Failed to setup 'CServerGameDLL::GetTickInterval' detour");
	
	detour.Enable(Hook_Pre, Detour_GetTickInterval);

	detour = DynamicDetour.FromConf(gamedata, "SV_ActivateServer");
	if (detour == null)
		ThrowError("Failed to setup 'SV_ActivateServer' detour");
	
	detour.Enable(Hook_Pre, Detour_ActivateServer);

	sm_tickrate = CreateConVar("sm_tickrate", "-1", "Tickrate of the server, requires a level change to take effect. Set to -1 to use the default tickrate.", _, true, 10.0, true, 1000.0);

	sv =  gamedata.GetMemSig("sv");
	if (sv == Address_Null)
		ThrowError("Failed to find 'sv' signature");
	
	m_offset_flTickInterval = gamedata.GetOffset("CBaseServer::m_flTickInterval");
	if (m_offset_flTickInterval == -1)
		ThrowError("Failed to find 'CBaseServer::m_flTickInterval' offset");
	
	delete gamedata;
	
	// On first server load, parse the tickrate param. Otherwise leave it be.
	float tickrate = GetCommandLineParamFloat("-tickrate");
	if (tickrate)
	{
		sm_tickrate.FloatValue = tickrate;
		g_flTickInterval = GetDesiredTickInterval();
	}

	RegPluginLibrary("tickrate_changer");
}

static MRESReturn Detour_GetTickInterval(DHookReturn ret)
{
	if (g_flTickInterval == -1.0)
		return MRES_Ignored;
	
	StoreToAddress(sv + view_as<Address>(m_offset_flTickInterval), g_flTickInterval, NumberType_Int32);

	ret.Value = g_flTickInterval;
	return MRES_Supercede;
}

static MRESReturn Detour_ActivateServer(DHookReturn ret)
{
	g_flTickInterval = GetDesiredTickInterval();
	return MRES_Ignored;
}

float GetDesiredTickInterval()
{
	float tickrate = sm_tickrate.FloatValue;
	if (tickrate == -1.0)
		return tickrate;
	
	return Clamp(1.0 / tickrate, MINIMUM_TICK_INTERVAL, MAXIMUM_TICK_INTERVAL);
}

any Min(any a, any b)
{
	return (a <= b) ? a : b;
}

any Max(any a, any b)
{
	return (a >= b) ? a : b;
}

any Clamp(any val, any min, any max)
{
	return Min(Max(val, min), max);
}
