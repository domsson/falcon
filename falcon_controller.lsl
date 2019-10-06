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

// List of all `cab` objects operating in this bank
// [string shaft, key uuid, ...]
list    cabs;
integer cabs_stride = 2;

// List of all `doorway` objects for this bank
// TODO: should we store floor index instead of floor name?
// [string floor, string shaft, key uuid, ...]
list    doorways;
integer doorways_stride = 3;

// List of all `call_buttons` objects for this bank
// [string floor, key uuid, ...]
list    buttons;
integer buttons_stride = 2;

// List of all elevator shafts in this bank
// TODO: should we store floor name instead of index?
// [string name, float doorway_offset, integer recall_floor...]
list    shafts;
integer shafts_stride = 3;

// List of all floors
// Order important: lowest floor (zpos) first!
// [float zpos, string name, ...]
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
    shafts += [shaft, 0.0, 0];
    
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
    return llList2Float(floors, llListFindList(floors, [floor]) - 1);
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
    //          0             1          2
    // [string floor, string shaft, key uuid, ...]
    
    integer i;
    integer num_doorways = get_strided_length(doorways, doorways_stride);
    for (i = 0; i < num_doorways; ++i)
    {
        string doorway_shaft = llList2String(doorways, i * doorways_stride + 1);
        if (shaft == doorway_shaft)
        {
            string doorway_floor = llList2String(doorways, i * doorways_stride + 0);
            float doorway_zpos = get_doorway_zpos(doorway_floor);
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

integer set_recall_floor(string shaft, string floor)
{
    integer floor_index = get_strided_index_by_member(floors, floors_stride, 1, floor);
    integer shaft_index = get_strided_index_by_member(shafts, shafts_stride, 0, shaft);
    
    if (floor_index == NOT_FOUND)
    {
        return FALSE;
    }
    
    if (shaft_index == NOT_FOUND)
    {
        return FALSE;
    }
    
    // shafts: [string name, float doorway_offset, integer recall_floor...]
    integer shaft_offset = shaft_index * shafts_stride + 2;
    
    shafts = llListReplaceList(shafts, [floor_index], shaft_offset, shaft_offset);
    return TRUE;
}

init_recall_floors()
{
    /*
    integer num_cabs = get_strided_length(cabs, cabs_stride);
    integer i;
    
    for (i = 0; i < num_cabs; ++i)
    {
        key    cab_uuid  = llList2Key(cabs,    i * cabs_stride + 1);
        string cab_shaft = llList2String(cabs, i * cabs_stride + 0);
        
        list   details  = llGetObjectDetails(cab_uuid, ([OBJECT_POS]));
        vector pos      = llList2Vector(details, 0);
        
        integer doorway_index = get_closest_doorway(pos.z, cab_shaft);
        
        // Add the recall_floor index to the shafts lists
        // doorways: [string floor, string shaft, key uuid, ...]
        string floor = llList2String(doorways, doorway_index * doorways_stride + 0);
        set_recall_floor(cab_shaft, floor);
        
        debug("Closest doorway for " + cab_shaft + ": " + (string) doorway_index);
    }
    */
    integer num_shafts = get_strided_length(shafts, shafts_stride);
    integer i;
    
    for (i = 0; i < num_shafts; ++i)
    {
        // shafts: [string name, float doorway_offset, integer recall_floor...]
        string cab_shaft = llList2String(shafts, i * shafts_stride + 0);
        // cabs: [string shaft, key uuid, ...]
        key   cab_uuid = llList2Key(cabs, llListFindList(cabs, [cab_shaft]) + 1);
        
        //key    cab_uuid  = llList2Key(cabs,    i * cabs_stride + 1);
        //string cab_shaft = llList2String(cabs, i * cabs_stride + 0);
        
        list   details  = llGetObjectDetails(cab_uuid, ([OBJECT_POS]));
        vector pos      = llList2Vector(details, 0);
        
        integer doorway_index = get_closest_doorway(pos.z, cab_shaft);
        
        // Add the recall_floor index to the shafts lists
        // doorways: [string floor, string shaft, key uuid, ...]
        string floor = llList2String(doorways, doorway_index * doorways_stride + 0);
        set_recall_floor(cab_shaft, floor);
        
        debug("Closest doorway for " + cab_shaft + ": " + (string) doorway_index);
    }
}

/*
 * Given the strided list `l` (with a stide of `s`), this function attempts 
 * to find the string member `m`, which is at stride offset `o`, then returns 
 * the index (at the beginning of the stride) of the element containing it.
 * If the member couldn't be found, NOT_FOUND (-1) is returned.
 */
integer get_strided_index_by_member(list l, integer s, integer o, string m)
{
    integer num_items = get_strided_length(l, s);
    integer i;
    
    for (i = 0; i < num_items; ++i)
    {
        string member = llList2String(l, i * s + o);
        if (member == m)
        {
            return i;
        }
    }
    return NOT_FOUND;
}



list get_doorway_details(integer index)
{
    key uuid = llList2Key(doorways, index * doorways_stride + 2);
    return llGetObjectDetails(uuid, [OBJECT_POS, OBJECT_ROT]);   
}

integer get_recall_floor(string shaft)
{
    integer idx = llListFindList(shafts, [shaft]);
    if (idx == NOT_FOUND)
    {
        return NOT_FOUND;
    }
    // shafts:   [string name, float doorway_offset, integer recall_floor...]
    return llList2Integer(shafts, idx + 2);
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
    
    integer num_floors = get_strided_length(floors, floors_stride);
    integer f;
    
    for (f = 0; f < num_floors; ++f)
    {
        // doorways: [float z-pos, string floor, string shaft, key uuid]
        // floors:   [float z-pos, string name, ...]
        
        float  f_zpos = llList2Float(floors, f * floors_stride + 0);
        string f_name = llList2String(floors, f * floors_stride + 1);
        
        integer accessible = llListFindList(doorways, [f_zpos, f_name, shaft]) != NOT_FOUND;
        
        floor_info += [ f_name + ":" + (string) accessible ];
    }
    
    return floor_info;
}

// TODO: this is MASSIVE... both in size as well as in complexity :(
integer request_doorway_setup()
{
    /*
    string pos = (string)pos.x +","+ (string)pos.y +","+ (string)pos.z;
    string rot = (string)rot.x +","+ (string)rot.y +","+ (string)rot.z +","+ (string)rot.s;
     
    // syntax:  "setup posx,posy,posz rotx,roty,rotz,rots"
    // example: "16.000000,94.221990,27.550000 0.707107,0.000000,0.000000,0.707107"   
    */

    integer num_shafts = get_strided_length(shafts, shafts_stride);
    integer s;
    
    integer num_doorways = get_strided_length(doorways, doorways_stride);
    integer d;
    
    for (s = 0; s < num_shafts; ++s)
    {
        string shaft = llList2String(shafts, s * shafts_stride + 0);
        integer base_doorway_idx = llList2Integer(shafts, s * shafts_stride + 2);
        list base_doorway_details = get_doorway_details(base_doorway_idx);
        vector base_doorway_pos = llList2Vector(base_doorway_details, 0);
        rotation base_doorway_rot = llList2Rot(base_doorway_details, 1);
        string f_info = llDumpList2String(get_floor_info(shaft), ",");
        integer f_recall = get_recall_floor(shaft);
        
        for (d = 0; d < num_doorways; ++d)
        {
            // doorways: [string floor, string shaft, key uuid]
            key doorway_uuid = llList2Key(doorways, d * doorways_stride + 2);
            string doorway_shaft = llList2String(doorways, d * doorways_stride + 1);
            string doorway_floor = llList2String(doorways, d * doorways_stride + 0);
            
            // floors:   [float z-pos, string name, ...]
            integer doorway_floor_idx = llListFindList(floors, [doorway_floor]) / doorways_stride;                        
            if (doorway_shaft == shaft)
            {
                string pos = "<" + (string) base_doorway_pos.x + "," +
                                   (string) base_doorway_pos.y + "," + 
                                   (string) base_doorway_pos.z + ">";
                string rot = "<" + (string) base_doorway_rot.x + "," + 
                                   (string) base_doorway_rot.y + "," + 
                                   (string) base_doorway_rot.z + "," + 
                                   (string) base_doorway_rot.s + ">";
                send_message(doorway_uuid, "setup", [pos, rot, f_info, f_recall, doorway_floor_idx]);
            }
        }
    }
    
    // TODO
    return TRUE;
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
    cabs     = llListSort(cabs,     cabs_stride,     TRUE);
    doorways = llListSort(doorways, doorways_stride, TRUE);
    buttons  = llListSort(buttons,  buttons_stride,  TRUE);
    shafts   = llListSort(shafts,   shafts_stride,   TRUE);
    floors   = llListSort(floors,   floors_stride,   TRUE);
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
        init_recall_floors();
        
        debug("Floors: "   + llDumpList2String(floors, " "));
        debug("Doorways: " + llDumpList2String(doorways, " "));
        debug("Shafts: "   + llDumpList2String(shafts, " "));
        debug("Cabs: "     + llDumpList2String(cabs, " "));
        
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
        
        debug("Started setup process...");
        debug("Memory usage: " + (string) llGetUsedMemory());
        
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
