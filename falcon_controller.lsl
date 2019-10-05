// CONSTS
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

// list of all `cab` objects
// [string shaft, key uuid, ...]
list    cabs;
integer cabs_stride = 2;

// list of all `doorway` object
// [float z-pos, string floor, string shaft, key uuid, ...]
list    doorways;
integer doorways_stride = 4;

// list of all `call_buttons` objects
// [string floor, key uuid, ...]
list    buttons;
integer buttons_stride = 2;

// [string name, float doorway_offset...]
list    shafts;
integer shafts_stride = 2;

// [float z-pos, string name, ...]
list    floors;
integer floors_stride = 2;

// important objects/ids
key uuid  = NULL_KEY;
key owner = NULL_KEY;

// state etc
integer listen_handle;
string current_state;

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

/*
 * Reads the object's description and parses its contents as a list 
 * of three string elements: bank, shaft and floor identifier.
 */
list get_identifiers()
{
    return parse_ident(llGetObjectDesc(), ":");
}

/*
 * Compares the element at position `idx` from the given list of identifiers
 * with this object's identifier list and returns TRUE if they are the same.
 */
integer ident_matches(list ident, integer idx)
{
    return llList2String(get_identifiers(), idx) == llList2String(ident, idx);
}

process_message(integer chan, string name, key id, string msg)
{
    // Debug print the received message
    //debug(" < `" + msg + "`");
    
    // Get details about the sender
    list details = llGetObjectDetails(id, ([OBJECT_NAME, OBJECT_DESC, 
                                            OBJECT_POS, OBJECT_ROT, OBJECT_OWNER]));
   
    // Abort if the message came from someone else's object
    if (owner != llList2Key(details, 4))
    {
        return;
    }

    // Split the message on spaces and extract the first two tokens
    list    tokens     = llParseString2List(msg, [" "], []);
    integer num_tokens = llGetListLength(tokens);
    string  signature  = llList2String(tokens, MSG_IDX_SIG);
    string  ident      = llList2String(tokens, MSG_IDX_IDENT);
    string  command    = llList2String(tokens, MSG_IDX_CMD);
    list    params     = llList2List(tokens, MSG_IDX_PARAMS, num_tokens - 1);
    
    if (command == "pong")
    {
        handle_cmd_pong(signature, id, ident);
        return;
    }
    
    if (command == "status")
    {
        handle_cmd_status(signature, id, ident, params, details);
    }
}

handle_cmd_pong(string sig, key id, string ident)
{
    // Currently nothing
}

handle_cmd_status(string sig, key id, string ident, list params, list details)
{
    if (sig == "falcon-cab")
    {
        //cabs = add_component(cabs, id, ident);
        list ident_tokens = parse_ident(ident, ":");
        if (add_cab(id, llList2String(ident_tokens, IDENT_IDX_SHAFT)) == FALSE)
        {
            debug("Could not add cab: " + ident);
        }
        return;
    }
    if (sig == "falcon-doorway")
    {
        //doorways = add_component(doorways, id, ident);
        vector pos = llList2Vector(details, 2);
        float z = pos.z;
        list ident_tokens = parse_ident(ident, ":");
        string floor = llList2String(ident_tokens, IDENT_IDX_FLOOR);
        string shaft = llList2String(ident_tokens, IDENT_IDX_SHAFT);
        if (add_doorway(id, z, floor, shaft) == FALSE)
        {
            debug("Could not add doorway: " + ident);
        }
        return;
    }
    if (sig == "falcon-buttons")
    {
        //buttons = add_component(buttons, id, ident);
        list ident_tokens = parse_ident(ident, ":");
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
    list msg = [SIGNATURE, llDumpList2String(get_identifiers(), ":"),
                cmd,  llDumpList2String(params, " ")];
    llRegionSayTo(id, CHANNEL, llDumpList2String(msg, " "));
}

/*
 * Broadcast a message to all objects in the region.
 * Note: this function depends on the globals `SIGNATURE` and `CHANNEL`.
 */
send_broadcast(string cmd, list params)
{
    list msg = [SIGNATURE, llDumpList2String(get_identifiers(), ":"),
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
    shafts += [shaft, 0.0];
    
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
        return 1;
    }
    
    // Floor already in list (not an error)
    if (idx_match == 1)
    {
        return 0;
    }
    
    // Either only zpos or name was found in the list, or both were found 
    // but didn't match, meaning they are already associated with another
    // zpos or floor number; either way we have a mismatch (error)
    return -1;
}

integer add_doorway(key uuid, float z, string floor, string shaft)
{
    float z_rounded = round(z, 2);
    if (add_floor(z_rounded, floor) == -1)
    {
        return FALSE;
    }
    doorways += [z_rounded, floor, shaft, uuid];
    return TRUE;
}

integer add_buttons(key uuid, string floor)
{
    if (llListFindList(buttons, (list) uuid) == NOT_FOUND)
    {
        buttons += [floor, uuid];
        return TRUE;
    }
    return FALSE;
}

/*
 * Returns the index of the given shaft's doorway that is closest to the given
 * z-position or NOT_FOUND if we don't know of any doorways for that shaft yet.
 */
integer get_closest_doorway(float zpos, string shaft)
{
    integer closest_doorway  = -1;
    float   closest_distance = FLOAT_MAX;
    
    // doorways list:
    //         0             1             2          3
    // [float z-pos, string floor, string shaft, key uuid, ...]
    
    integer i;
    integer num_doorways = get_strided_length(doorways, doorways_stride);
    for (i = 0; i < num_doorways; ++i)
    {
        string doorway_shaft = llList2String(doorways, i * doorways_stride + 2);
        if (shaft == doorway_shaft)
        {
            float doorway_zpos = llList2Float(doorways, i * doorways_stride + 0);
            float distance = llFabs(doorway_zpos - zpos);
        
            if (distance < closest_distance)
            {
                closest_doorway  = i;
                closest_distance = distance;
            }
        }
    }
    return closest_doorway;
}

// TODO temp function for testing get_closest_doorway()
find_closest_doorways()
{
    integer num_cabs = get_strided_length(cabs, cabs_stride);
    integer i;
    
    for (i = 0; i < num_cabs; ++i)
    {
        key    cab_uuid  = llList2Key(cabs,    i * cabs_stride + 1);
        string cab_shaft = llList2String(cabs, i * cabs_stride + 0);
        
        list   details  = llGetObjectDetails(cab_uuid, ([OBJECT_POS]));
        vector pos      = llList2Vector(details, 0);
        
        integer doorway_index = get_closest_doorway(pos.z, cab_shaft);
        
        debug("Closest doorway for " + cab_shaft + ": " + (string) doorway_index);
    }
}

integer all_components_in_place()
{
    // TODO: this needs to be rewritten now that the doorway list has
    //       changed so dramatically compared to its previous form
      
    return TRUE;
}

integer num_doorways_per_shaft(string shaft)
{
    // TODO: this needs to be rewritten now that the doorway list has
    //       changed so dramatically compared to its previous form
    
    return 0;
}

integer all_components_setup()
{
    // TODO
    return FALSE;
}

sort_components()
{
    cabs     = llListSort(cabs,     cabs_stride,     TRUE);
    doorways = llListSort(doorways, doorways_stride, TRUE);
    buttons  = llListSort(buttons,  buttons_stride,  TRUE);
    shafts   = llListSort(shafts,   shafts_stride,   TRUE);
    floors   = llListSort(floors,   floors_stride,   TRUE);
    
    debug("Floors: "   + llDumpList2String(floors, " "));
    debug("Doorways: " + llDumpList2String(doorways, " "));
    debug("Shafts: "   + llDumpList2String(shafts, " "));
    debug("Cabs: "     + llDumpList2String(cabs, " "));
}

integer init()
{
    uuid = llGetKey();
    owner = llGetOwner();
        
    return TRUE;
}

default
{
    state_entry()
    {
        current_state = "default";
        debug("Memory usage: " + (string) llGetUsedMemory());
        init();
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
 * Broadcast a pairing request to all objects in in the region, then wait
 * for a reply from suitable components (same owner, same elevator bank) 
 * and keep track of them.
 */
state pairing
{
    state_entry()
    {
        current_state = "pairing";
        
        listen_handle = llListen(CHANNEL, "", NULL_KEY, "");
    
        debug("Started pairing process...");
        debug("Memory usage: " + (string) llGetUsedMemory());
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
        llOwnerSay("Cabs: "     + (string) get_strided_length(cabs, cabs_stride));
        llOwnerSay("Doorways: " + (string) get_strided_length(doorways, doorways_stride));
        llOwnerSay("Buttons: "  + (string) get_strided_length(buttons, buttons_stride));
        
        sort_components();
        find_closest_doorways();
        
        if (all_components_in_place())
        {
            llOwnerSay("Pairing done. Everything is in place.");
            state setup; 
        }
        else
        {
            llOwnerSay("Pairing done. Some components are missing.");
            state default;
        }
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
        
        debug("Started setup process...");
        debug("Memory usage: " + (string) llGetUsedMemory());
        // TODO figure out which doorway is 'base' doorway
        // TODO get 'base' doorways position/rotation
        // TODO send 'setup' message to all components
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
            state default;
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
        
        debug("System is in operation...");
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
