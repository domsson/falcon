////////////////////////////////////////////////////////////////////////////////
////  CONSTANTS                                                             ////
////////////////////////////////////////////////////////////////////////////////

#include "falcon_common_constants.lsl"
string SIGNATURE = SIG_CONTROLLER;

float PAIRING_TIME = 3.0;
float SETUP_TIME   = 6.0;

////////////////////////////////////////////////////////////////////////////////
////  OTHER SCRIPT STATE GLOBALS                                            ////
////////////////////////////////////////////////////////////////////////////////

// important objects/ids
key uuid  = NULL_KEY;
key owner = NULL_KEY;

// state etc
integer listen_handle;
string  current_state;


////////////////////////////////////////////////////////////////////////////////
////  MAIN DATA STRUCTURES                                                  ////
////////////////////////////////////////////////////////////////////////////////

// List of all `cab` objects operating in this bank
// [string shaft, key uuid, string state, ...]
list    cabs;
integer CABS_STRIDE = 3;

integer CABS_IDX_SHAFT = 0;
integer CABS_IDX_UUID  = 1;
integer CABS_IDX_STATE = 2;

// List of all `doorway` objects for this bank
// [string floor, string shaft, key uuid, string state, ...]
list    doorways;
integer DOORWAYS_STRIDE = 4;

integer DOORWAYS_IDX_FLOOR = 0;
integer DOORWAYS_IDX_SHAFT = 1;
integer DOORWAYS_IDX_UUID  = 2;
integer DOORWAYS_IDX_STATE = 3;

// List of all `call_buttons` objects for this bank
// [string floor, key uuid, string state ...]
list    buttons;
integer BUTTONS_STRIDE = 3;

integer BUTTONS_IDX_FLOOR = 0;
integer BUTTONS_IDX_UUID  = 1;
integer BUTTONS_IDX_STATE = 2;

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
////  UTILITY FUNCTIONS                                                     ////
////////////////////////////////////////////////////////////////////////////////

#include "falcon_common_functions.lsl"

print_component_info()
{
    integer num_shafts  = get_strided_length(shafts,   SHAFTS_STRIDE);
    integer num_cabs    = get_strided_length(cabs,     CABS_STRIDE);
    integer num_floors  = get_strided_length(floors,   FLOORS_STRIDE);
    integer num_doors   = get_strided_length(doorways, DOORWAYS_STRIDE);
    integer num_buttons = get_strided_length(buttons,  BUTTONS_STRIDE);
        
    debug("Components:\n" + 
            "- " + (string) num_shafts  + " shafts\n" +
            "- " + (string) num_cabs    + " cabs\n" + 
            "- " + (string) num_floors  + " floors\n" + 
            "- " + (string) num_doors   + " doorways\n" + 
            "- " + (string) num_buttons + " call buttons\n"
    );
}

////////////////////////////////////////////////////////////////////////////////
////  MESSAGE HANDLING FUNCTIONS                                            ////
////////////////////////////////////////////////////////////////////////////////

/*
 * Handles the incoming message. Returns a numeric value, where TRUE and other 
 * positive values are generally a sign of success. NOT_HANDLED indicates that 
 * no handler for this command is known or the handler didn't know what to do 
 * with the message. FALSE or other negative values indicate failure.
 */
integer process_message(integer chan, string name, key id, string msg)
{
    // Split the message on spaces
    list    tokens     = llParseString2List(msg, [" "], []);
    integer num_tokens = llGetListLength(tokens);
    
    // Extract the different components
    string sig    = llList2String(tokens, MSG_IDX_SIG);
    string ident  = llList2String(tokens, MSG_IDX_IDENT);
    string cmd    = llList2String(tokens, MSG_IDX_CMD);
    list   params = llList2List(tokens,   MSG_IDX_PARAMS, num_tokens - 1);
    
    // Hand over to the appropriate command handler
    if (cmd == CMD_PONG)
    {
        return handle_cmd_pong(id, sig, ident, params);
    }
    if (cmd == CMD_STATUS)
    {
        return handle_cmd_status(id, sig, ident, params);
    }
    
    // Message has not been handled
    return NOT_HANDLED;
}

integer handle_cmd_pong(key id, string sig, string ident, list params)
{
    // Currently nothing
    return NOT_HANDLED;
}

integer handle_cmd_status(key id, string sig, string ident, list params)
{
    // Parse the object's ident string into a list
    list ident_tokens = parse_ident(ident, ":");
    
    // Get the state of the object
    string status = llList2String(params, 0);
    
    // Handle based on type of object
    if (sig == SIG_CAB)
    {
        // TODO: what happens if cab isn't in list yet?
        // Perform status update
        integer idx = llListFindList(cabs, [id]);
        cabs = llListReplaceList(cabs, [status], idx+1, idx+1);
        
        if (status == STATE_PAIRED)
        {
            // Add the cab to our list
            string shaft = llList2String(ident_tokens, IDENT_IDX_SHAFT);
            add_shaft(shaft);
            return add_cab(id, shaft, status);
        }
    }
    if (sig == SIG_DOORWAY)
    {
        // TODO: what happens if doorway isn't in list yet?
        // Perform status update
        integer idx = llListFindList(doorways, [id]);
        doorways = llListReplaceList(doorways, [status], idx+1, idx+1);
        
        if (status == STATE_PAIRED)
        {
            // Query doorway object's details to get its z-position
            list details = llGetObjectDetails(id, [OBJECT_POS]);
            vector pos   = llList2Vector(details, 0);
            float zpos   = round(pos.z, 2);
            
            // Parse floor and shaft name from doorway's ident string
            string floor = llList2String(ident_tokens, IDENT_IDX_FLOOR);
            string shaft = llList2String(ident_tokens, IDENT_IDX_SHAFT);
            
            // Add the doorway to our list
            integer success = TRUE;
            add_floor(zpos, floor);
            return add_doorway(id, floor, shaft, status);
        }
    }
    if (sig == SIG_BUTTONS)
    {
        // TODO: what happens if buttons aren't in list yet?
        // Perform status update
        integer idx = llListFindList(buttons, [id]);
        buttons = llListReplaceList(buttons, [status], idx+1, idx+1);
        
        if (status == STATE_PAIRED)
        {
            // Add the call buttons to our list
            string floor = llList2String(ident_tokens, IDENT_IDX_FLOOR);
            return add_buttons(id, floor, status);
        }
    }
    
    // Message has not been handled after all
    return NOT_HANDLED;
}

/*
 * Adds the shaft with name `shaft` to the list of shafts.
 * Returns TRUE on success, FALSE if the shaft was already in the list.
 */
integer add_shaft(string shaft)
{
    // Abort if the given shaft has already been added
    if (llListFindList(shafts, [shaft]) != NOT_FOUND)
    {
        return FALSE;
    }
    
    // Add the shaft
    shafts += [shaft, 0.0, ""];
    return TRUE;
}

/*
 * Adds the elevator cab with UUID `uuid` to the list of cabs.
 * Returns TRUE on success, FALSE if the cab was already in the list.
 */
integer add_cab(key uuid, string shaft, string status)
{
    // Abort if the cab with this UUID has already been added
    if (llListFindList(cabs, [uuid]) != NOT_FOUND)
    {
        return FALSE;
    }
    
    // Abort if a cab for this shaft has already been added
    if (llListFindList(cabs, [shaft]) != NOT_FOUND)
    {
        return FALSE;
    }
    
    // Add the cab
    cabs += [shaft, uuid, status];
    return TRUE;
}

/*
 * Adds the floor with the z-position `zpos` and the name `name` to the list of 
 * floors. Returns TRUE on success, FALSE if the floor was already in the list 
 * or -1 on error. An error occurs when the list already has one or two floors  * that each have either the given z-position OR name, but not both (mismatch).
 */
integer add_floor(float zpos, string name)
{
    integer zpos_idx = llListFindList(floors, [zpos]);
    integer name_idx = llListFindList(floors, [name]);
    
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
        return FALSE;
    }
    
    // Either only zpos or name was found in the list, or both were found but 
    // didn't match, meaning they are already associated with a different zpos 
    // or floor number accordingly; either way: we have a mismatch (error)
    return -1;
}

/*
 * Adds the doorway with UUID `uuid` to the list of doorways.
 * Returns TRUE on success, FALSE if the doorway was already in the list.
 */
integer add_doorway(key uuid, string floor, string shaft, string status)
{
    // Abort if this doorway is already in the list of doorways
    if (llListFindList(doorways, [uuid]) != NOT_FOUND)
    {
        return FALSE;
    }
    
    // Add the doorway
    doorways += [floor, shaft, uuid, status];
    return TRUE;
}

/*
 * Adds the call buttons with UUID `uuid` to the list of call buttons.
 * Returns TRUE on success, FALSE if these buttons were already in the list.
 */
integer add_buttons(key uuid, string floor, string status)
{
    // Buttons with that UUID have already been added
    if (llListFindList(buttons, [uuid]) != NOT_FOUND)
    {
        return FALSE;
    }
    
    // We explicitly allow for several button objects that operate on
    // the same floor, so we aren't going to check if there is already
    // a button object for the given floor in the list.    
    buttons += [floor, uuid, status];
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
    
    integer num_doorways = get_strided_length(doorways, DOORWAYS_STRIDE);
    integer i;
    
    for (i = 0; i < num_doorways; ++i)
    {
        // Get the shaft name of this doorway
        integer shaft_idx = i * DOORWAYS_STRIDE + DOORWAYS_IDX_SHAFT;
        string doorway_shaft = llList2String(doorways, shaft_idx);
        
        // Only continue if the doorway belongs to the shaft of interest
        if (shaft == doorway_shaft)
        {
            // Get the floor name of this doorway
            integer floor_idx = i * DOORWAYS_STRIDE + DOORWAYS_IDX_FLOOR;
            string doorway_floor = llList2String(doorways, floor_idx);
            
            // Get the z-position of this doorway
            float doorway_zpos = get_doorway_zpos(doorway_floor);
            
            // Calculate the distance of the doorway to the given zpos
            float distance = llFabs(doorway_zpos - zpos);
        
            // Check if this doorway is closer than any previous one
            if (distance < closest_distance)
            {
                closest_doorway  = i;
                closest_distance = distance;
            }
        }
    }
     
    // Return the index of the closest doorway, plus its distance
    return [closest_doorway, closest_distance];
}

/*
 * Amend the list entry for the given `shaft` by adding/updating the members
 * `doorway_offset` and `recall_floor` (aka. `base_floor`) to the given values.
 * Returns TRUE on success, FALSE if the given floor or shaft are not known.
 */
integer set_shaft_details(string shaft, float dw_offset, string base_floor)
{
    // Check if the given floor exists in the `floors` list
    integer floor_index = llListFindList(floors, [base_floor]);
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
    integer start = shaft_index + 1;
    integer end   = shaft_index + 2;
    shafts = llListReplaceList(shafts, [dw_offset, base_floor], start, end);
    return TRUE;
}

/*
 * Find the closest doorway to each cab (on the z-axis), then updates the shafts 
 * list with that information, effectively inserting the base/recall doorways.
 * Returns TRUE on success, FALSE if none or not all entries could be updated.
 */
integer init_recall_floors()
{
    integer success = TRUE;
    integer num_cabs = get_strided_length(cabs, CABS_STRIDE);
    integer i;
    
    for (i = 0; i < num_cabs; ++i)
    {
        // Get the cab's UUID and the name of its shaft
        key    cab_uuid  = llList2Key(cabs,    i * CABS_STRIDE + CABS_IDX_UUID);
        string cab_shaft = llList2String(cabs, i * CABS_STRIDE + CABS_IDX_SHAFT);
        
        // Query the position of the cab so we can get its z-position
        list   details = llGetObjectDetails(cab_uuid, [OBJECT_POS]);
        vector pos     = llList2Vector(details, 0);
        
        // Get information on the closest doorway to the given z-position
        list closest_dw = get_closest_doorway(cab_shaft, pos.z);
        
        // Extract and gather more information on the closest doorway
        integer dw_index  = llList2Integer(closest_dw, 0);
        float   dw_offset = llList2Float(closest_dw, 1);
        integer dw_floor_idx = dw_index * DOORWAYS_STRIDE + DOORWAYS_IDX_FLOOR;
        string  dw_floor  = llList2String(doorways, dw_floor_idx);
        
        // Update the shafts list with this doorway's nfo
        if (set_shaft_details(cab_shaft, dw_offset, dw_floor) == FALSE)
        {
            success = FALSE;
        }
    }
    return success;
}

/*
 * Returns the name of the base/recall floor for the given shaft.
 */
string get_recall_floor(string shaft)
{
    integer idx = llListFindList(shafts, [shaft]);
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
        // Get floor name and z-position
        integer zpos_idx = f * FLOORS_STRIDE + FLOORS_IDX_ZPOS;
        integer name_idx = f * FLOORS_STRIDE + FLOORS_IDX_NAME;
        float  f_zpos = llList2Float(floors, zpos_idx);
        string f_name = llList2String(floors, name_idx);
        
        // Check if there is a doorway for this floor and shaft
        integer access = llListFindList(doorways, [f_name, shaft]) != NOT_FOUND;
        
        // Add the info to the list
        floor_info += [f_name + ":" + (string) access];
    }
    return floor_info;
}

/*
 * Gathers all the information that the doorways need to perform setup, then 
 * sends a setup request message with all that information to the doorways.
 * Returns the number of doorways that were messaged.
 *
 * TODO: Add error handling
 * TODO: Maybe split this into two functions
 */
integer request_doorway_setup()
{
    integer num_doorways_messaged = 0;
    
    integer num_shafts = get_strided_length(shafts, SHAFTS_STRIDE);
    integer s;
    
    integer num_doorways = get_strided_length(doorways, DOORWAYS_STRIDE);
    integer d;
    
    for (s = 0; s < num_shafts; ++s)
    {
        // Get the shaft's name and recall floor name
        integer shaft_name_idx  = s * SHAFTS_STRIDE + SHAFTS_IDX_NAME;
        integer shaft_rc_fl_idx = s * SHAFTS_STRIDE + SHAFTS_IDX_RECALL_FLOOR;
        string shaft    = llList2String(shafts, shaft_name_idx);
        string rc_floor = llList2String(shafts, shaft_rc_fl_idx);
        
        // Find the doorway of the shaft's recall floor and get its UUID
        integer base_dw_idx = llListFindList(doorways, [rc_floor, shaft]);
        integer base_dw_uuid_idx = base_dw_idx + DOORWAYS_IDX_UUID;
        key base_dw_uuid = llList2Key(doorways, base_dw_uuid_idx);
        
        // Find the list index for the recall floor based on it's floor name
        // [float zpos, string name, ...]
        integer rc_floor_idx = llListFindList(floors, [rc_floor]) - 1;
        integer rc_floor_num = rc_floor_idx / FLOORS_STRIDE;
        
        // Query the base/recall doorway's position and rotation
        list pos_rot = [OBJECT_POS, OBJECT_ROT];
        list base_dw_details = llGetObjectDetails(base_dw_uuid, pos_rot);
        vector   base_dw_pos = llList2Vector(base_dw_details, 0);
        rotation base_dw_rot = llList2Rot(base_dw_details, 1);
        
        // Serialize base doorway's position and rotation
        string pos = "<" + (string) base_dw_pos.x + "," +
                           (string) base_dw_pos.y + "," + 
                           (string) base_dw_pos.z + ">";
        string rot = "<" + (string) base_dw_rot.x + "," + 
                           (string) base_dw_rot.y + "," + 
                           (string) base_dw_rot.z + "," + 
                           (string) base_dw_rot.s + ">";
        
        // Construct the floor info string
        string floor_info = llDumpList2String(get_floor_info(shaft), ",");
        
        for (d = 0; d < num_doorways; ++d)
        {
            // doorways: [string floor, string shaft, key uuid, ...]
            // floors:   [float z-pos, string name, ...]
            
            integer dw_shaft_idx = d * DOORWAYS_STRIDE + DOORWAYS_IDX_SHAFT;
            string dw_shaft = llList2String(doorways, dw_shaft_idx);
                   
            // Continue with the next iteration if the shaft doesn't match    
            if (dw_shaft != shaft)
            {
                jump request_doorway_setup_continue;
            }
            
            // Get the doorways' UUID and floor name
            integer dw_uuid_idx  = d * DOORWAYS_STRIDE + DOORWAYS_IDX_UUID;
            integer dw_floor_idx = d * DOORWAYS_STRIDE + DOORWAYS_IDX_FLOOR;
            key    dw_uuid  = llList2Key(doorways, dw_uuid_idx);
            string dw_floor = llList2String(doorways, dw_floor_idx);
            
            // Find the list indices for the recall floor, as well as 
            // this doorway's floor; for this we use the floor names:
            // [float zpos, string name, ...]
            integer floor_idx = llListFindList(floors, [dw_floor]) - 1;
            integer floor_num = floor_idx / FLOORS_STRIDE; 
         
            // Lastly, we gather and pack all the relevant parameters
            //
            //             .- pos of reference doorway
            //             |    .- rot of reference doorway
            //             |    |    .- list of all floors
            //             |    |    |           .- recall floor index
            //             |    |    |           |             .- floor index
            //             |    |    |           |             |
            list params = [pos, rot, floor_info, rc_floor_num, floor_num];
            
            // Finally, we can send the setup message to the doorway
            send_message(dw_uuid, CMD_SETUP, params);
            ++num_doorways_messaged;
            
            // Label for skipping an interation of this loop
            @request_doorway_setup_continue;
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
    integer num_cabs = get_strided_length(cabs, CABS_STRIDE);
    integer c;
    
    for (c = 0; c < num_cabs; ++c)
    {
        integer idx = c * CABS_STRIDE + CABS_IDX_STATE;
        string status = llList2String(cabs, idx);
        if (status != STATE_RUNNING)
        {
            return FALSE;
        }
    }
    
    integer num_doorways = get_strided_length(doorways, DOORWAYS_STRIDE);
    integer d;
    
    for (d = 0; d < num_doorways; ++d)
    {
        integer idx = d * DOORWAYS_STRIDE + DOORWAYS_IDX_STATE;
        string status = llList2String(doorways, idx);
        if (status != STATE_RUNNING)
        {
            return FALSE;
        }
    }
        
    return TRUE;
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
        current_state = STATE_INITIAL;
        print_state_info();
        
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
        current_state = STATE_PAIRING;
        print_state_info();
                
        listen_handle = llListen(CHANNEL, "", NULL_KEY, "");

        send_broadcast(CMD_PAIR, []);
        llSetTimerEvent(PAIRING_TIME);
    }
    
    listen(integer channel, string name, key id, string message)
    {
        process_message(channel, name, id, message);
    }
    
    timer()
    {        
        llSetTimerEvent(0.0);
        
        sort_components();
        init_recall_floors();

        llOwnerSay("Pairing done.");
        print_component_info();

        state startup;
    }
    
    state_exit()
    {
        llSetTimerEvent(0.0);
    }
}

state startup
{
    state_entry()
    {
        current_state = STATE_STARTUP;
        print_state_info();
        
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
            state running; 
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

state running
{
    state_entry()
    {
        current_state = STATE_RUNNING;
        print_state_info();
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
