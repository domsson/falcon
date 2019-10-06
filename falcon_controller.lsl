////////////////////////////////////////////////////////////////////////////////
////  GENERAL CONSTANTS                                                     ////
////////////////////////////////////////////////////////////////////////////////

integer DEBUG = TRUE;
integer CHANNEL = -130104;
string  SIGNATURE = "falcon-control";

string SIGNATURE_CAB     = "falcon-cab";
string SIGNATURE_DOORWAY = "falcon-doorway";
string SIGNAUTRE_BUTTONS = "falcon-buttons";

integer NOT_FOUND = -1; // ll* functions often return -1 to indicate 'not found'
float   FLOAT_MAX = 3.402823466E+38;

float PAIRING_TIME = 3.0;
float SETUP_TIME   = 6.0;

integer SHAFTS_MAX = 4;
integer FLOORS_MAX = 16;

integer MSG_IDX_SIG    = 0;
integer MSG_IDX_IDENT  = 1;
integer MSG_IDX_CMD    = 2;
integer MSG_IDX_PARAMS = 3;

integer IDENT_IDX_BANK  = 0;
integer IDENT_IDX_SHAFT = 1;
integer IDENT_IDX_FLOOR = 2;

////////////////////////////////////////////////////////////////////////////////
////  MAIN DATA STRUCTURES                                                  ////
////////////////////////////////////////////////////////////////////////////////

// List of all `cab` objects operating in this bank
// [string shaft, key uuid, ...]
list    cabs;
integer CABS_STRIDE = 2;

integer CABS_IDX_SHAFT = 0;
integer CABS_IDX_UUID  = 1;

// List of all `doorway` objects for this bank
// [string floor, string shaft, key uuid, ...]
list    doorways;
integer DOORWAYS_STRIDE = 3;

integer DOORWAYS_IDX_FLOOR = 0;
integer DOORWAYS_IDX_SHAFT = 1;
integer DOORWAYS_IDX_UUID  = 2;

// List of all `call_buttons` objects for this bank
// [string floor, key uuid, ...]
list    buttons;
integer BUTTONS_STRIDE = 2;

integer BUTTONS_IDX_FLOOR = 0;
integer BUTTONS_IDX_UUID  = 0;

// List of all elevator shafts in this bank
// [string name, float doorway_offset, string recall_floor...]
list    shafts;
integer SHAFTS_STRIDE = 3;

integer SHAFTS_IDX_NAME          = 0;
integer SHAFTS_IDX_DOORWAY_DIST  = 1;
integer SHAFTS_IDX_RECALL_FLOOR  = 2;

// List of all floors
// Order important: lowest floor (zpos) first!
// [float zpos, string name, ...]
list    floors;
integer FLOORS_STRIDE = 2;

integer FLOORS_IDX_ZPOS = 0;
integer FLOORS_IDX_NAME = 1;

////////////////////////////////////////////////////////////////////////////////
////  OTHER SCRIPT STATE GLOBALS                                            ////
////////////////////////////////////////////////////////////////////////////////

// important objects/ids
key uuid  = NULL_KEY;
key owner = NULL_KEY;

// state etc
integer listen_handle;
string current_state;

////////////////////////////////////////////////////////////////////////////////
////  FUNCTIONS                                                             ////
////////////////////////////////////////////////////////////////////////////////

/*
 * Debug output `msg` via llOwnerSay if the global variable DEBUG is TRUE
 */
debug(string msg)
{
    if (DEBUG)
    {
        llOwnerSay(msg);
    }
}

float round(float val, integer digits)
{
    float factor = llPow(10, digits);
    return llRound(val * factor) / factor;
}

/*
 * Parses an identifier string into a list of 3 elements, using `sep` 
 * as the separator to split the string into tokens. An empty string 
 * will yield a list with three empty string elements.
 */
list parse_ident(string ident, string sep)
{
    list tks = llParseString2List(ident, [sep], []);
    return [llList2String(tks, 0), llList2String(tks, 1), llList2String(tks, 2)];
}

string get_ident()
{
    // This is all this does at the moment, yet. But wait, don't delete this
    // function yet! The point is that we might implement some more advanced
    // logic here in the future. Caching the description string, for example.
    return llGetObjectDesc();
}

process_message(integer chan, string name, key id, string msg)
{
    // Split the message on spaces and extract the different parts
    list    tokens     = llParseString2List(msg, [" "], []);
    integer num_tokens = llGetListLength(tokens);
    string  signature  = llList2String(tokens, MSG_IDX_SIG);
    string  ident      = llList2String(tokens, MSG_IDX_IDENT);
    string  command    = llList2String(tokens, MSG_IDX_CMD);
    list    params     = llList2List(tokens,   MSG_IDX_PARAMS, num_tokens - 1);
    
    if (command == "pong")
    {
        handle_cmd_pong(signature, id, ident, params);
        return;
    }
    
    if (command == "status")
    {
        handle_cmd_status(signature, id, ident, params);
        return;
    }
}

handle_cmd_pong(string sig, key id, string ident, list params)
{
    // Currently nothing
}

handle_cmd_status(string sig, key id, string ident, list params)
{
    list ident_tokens = parse_ident(ident, ":");
    if (sig == "falcon-cab")
    {
        add_cab(id, llList2String(ident_tokens, IDENT_IDX_SHAFT));
        return;
    }
    if (sig == "falcon-doorway")
    {
        // Get details about the sender
        list details = llGetObjectDetails(id, [OBJECT_POS]);
        vector pos = llList2Vector(details, 0);
        string floor = llList2String(ident_tokens, IDENT_IDX_FLOOR);
        string shaft = llList2String(ident_tokens, IDENT_IDX_SHAFT);
        add_doorway(id, pos.z, floor, shaft);
        return;
    }
    if (sig == "falcon-buttons")
    {
        add_buttons(id, llList2String(ident_tokens, IDENT_IDX_FLOOR));
        return;
    }
}

/*
 * Send a message to the object with UUID `id`.
 * Note: this function depends on the globals `SIGNATURE` and `CHANNEL`.
 */ 
send_message(key id, string cmd, list params)
{
    list msg = [SIGNATURE, get_ident(),
                cmd,  llDumpList2String(params, " ")];
    llRegionSayTo(id, CHANNEL, llDumpList2String(msg, " "));
}

/*
 * Broadcast a message to all objects in the region.
 * Note: this function depends on the globals `SIGNATURE` and `CHANNEL`.
 */
send_broadcast(string cmd, list params)
{
    list msg = [SIGNATURE, get_ident(),
                cmd,  llDumpList2String(params, " ")];
    llRegionSay(CHANNEL, llDumpList2String(msg, " "));
}

/*
 * Get the length of the strided list `l`, given it's stride length `s`.
 */
integer get_strided_length(list l, integer s)
{
    return llGetListLength(l) / s;
}

/*
 * Adds the elevator cab with UUID `uuid` and shaft name `shaft` 
 * to the list of cabs, unless `id` is already in the list.
 */
integer add_cab(key uuid, string shaft)
{
    // Abort if the cab with this UUID has already been added
    if (llListFindList(cabs, (list) uuid) != NOT_FOUND)
    {
        return FALSE;
    }
    
    // Abort if a cab for this shaft has already been added
    if (llListFindList(cabs, (list) shaft) != NOT_FOUND)
    {
        return FALSE;
    }
    
    // Add the cab
    cabs += [shaft, uuid];

    // Abort if the given shaft has already been added
    if (llListFindList(shafts, (list) shaft) != NOT_FOUND)
    {
        return FALSE;
    }
    
    // Add the shaft
    shafts += [shaft, 0.0, ""];
    
    return TRUE;
}

integer add_floor(float zpos, string name)
{
    integer zpos_idx = llListFindList(floors, (list) zpos);
    integer name_idx = llListFindList(floors, (list) name);
    
    // both found and match:       1
    // neither found:              0
    // only one found or mismatch: < 0 or > 1
    integer idx_match = name_idx - zpos_idx;
    
    // Floor not yet in list (success)
    if (idx_match == 0)
    {
        floors += [zpos, name];
        return TRUE;
    }
    
    // Floor already in list (not an error)
    if (idx_match == 1)
    {
        return TRUE;
    }
    
    // Either only zpos or name was found in the list, or both were found but 
    // didn't match, meaning they are already associated with a different zpos 
    // or floor number accordingly; either way: we have a mismatch (error)
    return FALSE;
}

integer add_doorway(key uuid, float z, string floor, string shaft)
{
    float z_rounded = round(z, 2);
    if (add_floor(z_rounded, floor) == FALSE)
    {
        return FALSE;
    }
    doorways += [floor, shaft, uuid];
    return TRUE;
}

integer add_buttons(key uuid, string floor)
{
    // Buttons with that UUID have already been added
    if (llListFindList(buttons, (list) uuid) != NOT_FOUND)
    {
        return FALSE;
    }
    
    // We explicitly allow for several button objects that operate on
    // the same floor, so we aren't going to check if there is already
    // a button object for the given floor in the list.    
    buttons += [floor, uuid];
    return TRUE;
}

/*
 * Return the z-position for this doorway as per the floors list.
 */
float get_doorway_zpos(string floor)
{
    // floors: [float z-pos, string name, ...]
    // TODO: use index constants and math instead of -1
    return llList2Float(floors, llListFindList(floors, [floor]) - 1);
}

/*
 * Returns the index of the given shaft's doorway that is closest to the given
 * z-position or NOT_FOUND if we don't know of any doorways for that shaft yet.
 */
list get_closest_doorway(string shaft, float zpos)
{
    integer closest_doorway  = -1;
    float   closest_distance = FLOAT_MAX;
    
    // doorways: [string floor, string shaft, key uuid, ...]
    
    integer num_doorways = get_strided_length(doorways, DOORWAYS_STRIDE);
    integer i;
    
    for (i = 0; i < num_doorways; ++i)
    {
        string doorway_shaft = llList2String(doorways, i * DOORWAYS_STRIDE + DOORWAYS_IDX_SHAFT);
        if (shaft == doorway_shaft)
        {
            string doorway_floor = llList2String(doorways, i * DOORWAYS_STRIDE + DOORWAYS_IDX_FLOOR);
            float  doorway_zpos  = get_doorway_zpos(doorway_floor);
            float  distance = llFabs(doorway_zpos - zpos);
        
            if (distance < closest_distance)
            {
                closest_doorway  = i;
                closest_distance = distance;
            }
        }
    }
    return [closest_doorway, closest_distance];
}

integer set_shaft_details(string shaft, float doorway_offset, string recall_floor)
{
    // Check if the given floor exists in the `floors` list
    integer floor_index = llListFindList(floors, [recall_floor]);
    if (floor_index == NOT_FOUND)
    {
        return FALSE;
    }

    // Check if the given shaft exists in the `shafts` list   
    integer shaft_index = llListFindList(shafts, [shaft]);
    if (shaft_index == NOT_FOUND)
    {
        return FALSE;
    }
    
    // shafts: [string name, float doorway_offset, string recall_floor...]
    shafts = llListReplaceList(shafts, [doorway_offset, recall_floor], shaft_index + 1, shaft_index + 2);
    return TRUE;
}

// TODO: rename this function to something that better describes what it does
integer init_recall_floors()
{
    integer success = TRUE;
    integer num_cabs = get_strided_length(cabs, CABS_STRIDE);
    integer i;
    
    for (i = 0; i < num_cabs; ++i)
    {
        // doorways: [string floor, string shaft, key uuid, ...]
        // cabs:     [string shaft, key uuid, ...]
        
        key    cab_uuid  = llList2Key(cabs,    i * CABS_STRIDE + CABS_IDX_UUID);
        string cab_shaft = llList2String(cabs, i * CABS_STRIDE + CABS_IDX_SHAFT);
        
        list   details = llGetObjectDetails(cab_uuid, [OBJECT_POS]);
        vector pos     = llList2Vector(details, 0);
        
        list closest_doorway = get_closest_doorway(cab_shaft, pos.z);
        integer doorway_index  = llList2Integer(closest_doorway, 0);
        float   doorway_offset = llList2Float(closest_doorway, 1);
        string  doorway_floor  = llList2String(doorways, doorway_index * DOORWAYS_STRIDE + DOORWAYS_IDX_FLOOR);
        
        if (set_shaft_details(cab_shaft, doorway_offset, doorway_floor) == FALSE)
        {
            success = FALSE;
        }
    }
    return success;
}

string get_recall_floor(string shaft)
{
    integer idx = llListFindList(shafts, [shaft]);
    // shafts: [string name, float doorway_offset, string recall_floor...]
    return llList2String(shafts, idx + SHAFTS_IDX_RECALL_FLOOR);
}

/*
 * Returns a list that contains one string for each floor of the given shaft,
 * consisting of the floor name, a colon (":") and a 0 or 1, depending on 
 * whether that floor is accessible from the given shaft.
 * Example: ["B2:1", "B1:1", "1:1", "2:0", "3:1"]
 */
list get_floor_info(string shaft)
{
    list floor_info = [];
    
    integer num_floors = get_strided_length(floors, FLOORS_STRIDE);
    integer f;

    for (f = 0; f < num_floors; ++f)
    {
        // doorways: [string floor, string shaft, key uuid, ...]
        // floors:   [float z-pos, string name, ...]        
        float  f_zpos  = llList2Float(floors,  f * FLOORS_STRIDE + FLOORS_IDX_ZPOS);
        string f_name  = llList2String(floors, f * FLOORS_STRIDE + FLOORS_IDX_NAME);
        
        // Check if there is a doorway for this floor and shaft
        integer access = llListFindList(doorways, [f_name, shaft]) != NOT_FOUND;
        
        floor_info += [ f_name + ":" + (string) access ];
    }
    
    return floor_info;
}

// TODO: this is MASSIVE... both in size as well as in complexity :(
integer request_doorway_setup()
{
    integer num_doorways_messaged = 0;
    
    integer num_shafts = get_strided_length(shafts, SHAFTS_STRIDE);
    integer s;
    
    integer num_doorways = get_strided_length(doorways, DOORWAYS_STRIDE);
    integer d;
    
    for (s = 0; s < num_shafts; ++s)
    {
        // shafts:   [string name, float doorway_offset, string recall_floor...]
        // doorways: [string floor, string shaft, key uuid, ...]
        
        string shaft = llList2String(shafts, s * SHAFTS_STRIDE + SHAFTS_IDX_NAME);
        string recall_floor = llList2String(shafts, s * SHAFTS_STRIDE + SHAFTS_IDX_RECALL_FLOOR);
        integer base_doorway_idx = llListFindList(doorways, [recall_floor, shaft]);
        // TODO: what if the above line yields NOT_FOUND?
        key base_doorway_uuid = llList2Key(doorways, base_doorway_idx + DOORWAYS_IDX_UUID);
        
        list base_doorway_details = llGetObjectDetails(base_doorway_uuid, [OBJECT_POS, OBJECT_ROT]);
        vector   base_doorway_pos = llList2Vector(base_doorway_details, 0);
        rotation base_doorway_rot = llList2Rot(base_doorway_details, 1);
        
        string f_info   = llDumpList2String(get_floor_info(shaft), ",");
        string f_recall = get_recall_floor(shaft);
        
        for (d = 0; d < num_doorways; ++d)
        {
            // doorways: [string floor, string shaft, key uuid, ...]
            // floors:   [float z-pos, string name, ...]
            
            string doorway_shaft = llList2String(doorways, d * DOORWAYS_STRIDE + DOORWAYS_IDX_SHAFT);
                       
            if (doorway_shaft == shaft)
            {
                key    doorway_uuid  = llList2Key(doorways, d * DOORWAYS_STRIDE + DOORWAYS_IDX_UUID);
                string doorway_floor = llList2String(doorways, d * DOORWAYS_STRIDE + DOORWAYS_IDX_FLOOR);
                
                integer recall_floor_idx  = llListFindList(floors, [f_recall]) / DOORWAYS_STRIDE;
                integer doorway_floor_idx = llListFindList(floors, [doorway_floor]) / DOORWAYS_STRIDE; 
            
                string pos = "<" + (string) base_doorway_pos.x + "," +
                                   (string) base_doorway_pos.y + "," + 
                                   (string) base_doorway_pos.z + ">";
                string rot = "<" + (string) base_doorway_rot.x + "," + 
                                   (string) base_doorway_rot.y + "," + 
                                   (string) base_doorway_rot.z + "," + 
                                   (string) base_doorway_rot.s + ">";
                
                //
                //                                   .- pos of reference doorway
                //                                   |    .- rot of reference doorway
                //                                   |    |    .- list of all floors
                //                                   |    |    |       .- recall floor index
                //                                   |    |    |       |                 .- your floor index
                //                                   |    |    |       |                 |
                send_message(doorway_uuid, "setup", [pos, rot, f_info, recall_floor_idx, doorway_floor_idx]);
                ++num_doorways_messaged;
            }
        }
    }
    
    return num_doorways_messaged;
}

integer request_cab_setup()
{
    // TODO
    return FALSE;
}

integer all_components_setup()
{
    // TODO
    return FALSE;
}

sort_components()
{
    floors = llListSort(floors, FLOORS_STRIDE, TRUE);
}

////////////////////////////////////////////////////////////////////////////////
////  STATES                                                                ////
////////////////////////////////////////////////////////////////////////////////

default
{
    state_entry()
    {
        current_state = "default";
        debug("State: " + current_state + "\nMemory: " + (string) llGetUsedMemory() + " bytes");
        
        // Basic initialization
        uuid  = llGetKey();
        owner = llGetOwner();
    }

    touch_end(integer total_number)
    {
        state pairing; 
    }

    state_exit()
    {
        // Nothing (yet)
    }
}

/*
 * Broadcast a pairing request to all objects in the region, then wait
 * for a reply from suitable components (same owner, same elevator bank) 
 * and keep track of them.
 */
state pairing
{
    state_entry()
    {
        current_state = "pairing";
        debug("State: " + current_state + "\nMemory: " + (string) llGetUsedMemory() + " bytes");
                
        listen_handle = llListen(CHANNEL, "", NULL_KEY, "");

        send_broadcast("pair", []);
        llSetTimerEvent(PAIRING_TIME);
    }
    
    listen(integer channel, string name, key id, string message)
    {
        process_message(channel, name, id, message);
    }
    
    timer()
    {        
        llSetTimerEvent(0.0);
        /*
        llOwnerSay("Cabs: "     + (string) get_strided_length(cabs, CABS_STRIDE));
        llOwnerSay("Doorways: " + (string) get_strided_length(doorways, DOORWAYS_STRIDE));
        llOwnerSay("Buttons: "  + (string) get_strided_length(buttons, BUTTONS_STRIDE));
        */
        
        sort_components();
        init_recall_floors();
        
        /*
        debug("Floors: "   + llDumpList2String(floors, " "));
        debug("Doorways: " + llDumpList2String(doorways, " "));
        debug("Shafts: "   + llDumpList2String(shafts, " "));
        debug("Cabs: "     + llDumpList2String(cabs, " "));
        */
        
        llOwnerSay("Pairing done.");
        state setup;
    }
    
    state_exit()
    {
        llSetTimerEvent(0.0);
    }
}

state setup
{
    state_entry()
    {
        current_state = "setup";
        debug("State: " + current_state + "\nMemory: " + (string) llGetUsedMemory() + " bytes");
        
        // TODO send 'setup' message to all components
        request_doorway_setup();
        request_cab_setup();
        
        llSetTimerEvent(SETUP_TIME);
    }
    
    listen(integer channel, string name, key id, string message)
    {
        process_message(channel, name, id, message);
    }
    
    timer()
    {        
        llSetTimerEvent(0.0);
        if (all_components_setup())
        {
            llOwnerSay("Setup done. All systems ready.");
            state ready; 
        }
        else
        {
            llOwnerSay("Setup failed.");
            llResetScript();
        }
    }
    
    state_exit()
    {
        llSetTimerEvent(0.0);
    }
}

state ready
{
    state_entry()
    {
        current_state = "ready";
        debug("State: " + current_state + "\nMemory: " + (string) llGetUsedMemory() + " bytes");
    }
    
    listen(integer channel, string name, key id, string message)
    {
        process_message(channel, name, id, message);
    }
    
    state_exit()
    {
        // Nothing yet
    }
}
