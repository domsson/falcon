////////////////////////////////////////////////////////////////////////////////
////  CONSTANTS                                                             ////
////////////////////////////////////////////////////////////////////////////////

#include "falcon_common_constants.lsl"
#include "falcon_controller_constants.lsl"

string SIGNATURE = SIG_CONTROLLER;

float PAIRING_TIME = 3.0;
float CONFIG_TIME  = 6.0;

////////////////////////////////////////////////////////////////////////////////
////  OTHER SCRIPT STATE GLOBALS                                            ////
////////////////////////////////////////////////////////////////////////////////

// important objects/ids
key uuid  = NULL_KEY;
key owner = NULL_KEY;

// state etc
integer listen_handle;
string  current_state;
string  next_state;

////////////////////////////////////////////////////////////////////////////////
////  MAIN DATA STRUCTURES                                                  ////
////////////////////////////////////////////////////////////////////////////////

// List of all `cab` objects operating in this bank
// [string shaft, key uuid, string state, ...]
list cabs;

// List of all `doorway` objects for this bank
// [string floor, string shaft, key uuid, string state, ...]
list doorways;

// List of all `call_buttons` objects for this bank
// [string floor, key uuid, string state ...]
list buttons;

// List of all elevator shafts in this bank
// [string name, float doorway_offset, string recall_floor...]
list shafts;

// List of all floors (order important: lowest floor first!)
// [float zpos, string name, ...]
list floors;

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
    // Get the object's owner and position; abort if owner doesn't match ours
    // as we aren't interested in other people's component's status
    list details = llGetObjectDetails(id, [OBJECT_OWNER, OBJECT_POS]);
    if (owner != llList2Key(details, 0))
    {
        return NOT_HANDLED;
    }
    
    /*
    key controller = llList2Key(params, 1);
        
    // We don't care if the component isn't paired to us
    if (controller != uuid)
    {
        return NOT_HANDLED;
    }
    */
    
    // Parse the object's ident string into a list
    list ident_tokens = parse_ident(ident, ":");
    
    // Get the state of the object
    string status = llList2String(params, 0);
    
    // Handle based on type of object
    if (sig == SIG_CAB)
    {
        // Try to find the cab in our list of cabs
        integer idx = llListFindList(cabs, [id]);

        // If we already know about the cab...
        if (idx != NOT_FOUND)
        {
            debug("updating cab status");
            
            // ...update its status in our bookkeeping
            cabs = llListReplaceList(cabs, [status], idx+1, idx+1);
            return TRUE;
        }
        
        // If we're waiting for cabs to pair with us...
        if (current_state == STATE_PAIRING)
        {
            debug("adding cab to list");
            
            // Add the shaft to our list
            string shaft = llList2String(ident_tokens, IDENT_IDX_SHAFT);
            add_shaft(shaft);
                
            // Add the cab to our list and return success or failure
            return add_cab(id, shaft, status);
        }
        
        // We didn't do anything
        return NOT_HANDLED;
    }
    if (sig == SIG_DOORWAY)
    {
        // Try to find the doorway in our list of doorways
        integer idx = llListFindList(doorways, [id]);
        
        // If we already know about the doorway...
        if (idx != NOT_FOUND)
        {
            debug("updating doorway status");
            
            // ...update its status in our bookkeeping
            doorways = llListReplaceList(doorways, [status], idx+1, idx+1);
            return TRUE;
        }
        
        // If we're waiting for doorways to pair with us...
        if (current_state == STATE_PAIRING)
        {
            debug("adding doorway to list");
            
            // Get dooway's z-position
            vector pos   = llList2Vector(details, 1);
            float zpos   = round(pos.z, 2);
            
            // Parse floor and shaft name from doorway's ident string
            string floor = llList2String(ident_tokens, IDENT_IDX_FLOOR);
            string shaft = llList2String(ident_tokens, IDENT_IDX_SHAFT);
            
            // Add the floor to our list
            add_floor(zpos, floor);
            
            // Add the doorway to our list
            return add_doorway(id, floor, shaft, status);
        }

        // We didn't do anything
        return NOT_HANDLED;
    }
    if (sig == SIG_BUTTONS)
    {
        // Try to find the buttons in our list of buttons
        integer idx = llListFindList(buttons, [id]);
        
        // If we already know about the buttons...
        if (idx != NOT_FOUND)
        {
            debug("updating buttons status");
            
            // ...update its status in our bookkeeping
            buttons = llListReplaceList(buttons, [status], idx+1, idx+1);
        }
        
        // If we're waiting for buttons to pair with us...
        if (current_state == STATE_PAIRING)
        {
            debug("adding buttons to list");
            
            // Add the call buttons to our list
            string floor = llList2String(ident_tokens, IDENT_IDX_FLOOR);
            return add_buttons(id, floor, status);
        }
        
        // We didn't do anything
        return NOT_HANDLED;
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
 * Finds the closest doorway to each cab (on z), then update the shafts list 
 * with that information, effectively inserting the base/recall doorways.
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
        key    cab_uuid  = llList2Key(cabs,    i*CABS_STRIDE + CABS_IDX_UUID);
        string cab_shaft = llList2String(cabs, i*CABS_STRIDE + CABS_IDX_SHAFT);
        
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
 * Gathers all the information that the componetns need to perform config, then 
 * sends a config request message with all that information to the components.
 * Returns the number of components that were messaged.
 *
 * TODO: Add error handling
 */
integer request_component_setup()
{
    integer num_components_messaged = 0;
    string floor_info = "";
    
    integer num_shafts = get_strided_length(shafts, SHAFTS_STRIDE);
    integer s;
    
    integer num_doorways = get_strided_length(doorways, DOORWAYS_STRIDE);
    integer d;
    
    integer num_cabs = get_strided_length(cabs, CABS_STRIDE);
    integer c;
    
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
        floor_info = llDumpList2String(get_floor_info(shaft), ",");
        
        // The params list contains information for the component's config
        // process; some of that information is the same for all components.
        // Common information will be at the beginning of the params list.
        // Specific information, which is only relevant for select components, 
        // will be placed at the end of the params list.
        
        // COMMON --------------------------------------------------------------
        // floor_info:   list of all floors (names and accessibility)
        // floor_num:    index of current floor (could be same as rc_floor_num)
        // rc_floor_num: index of recall floor (could be same as floor_num) 
        // DOORWAYS ONLY -------------------------------------------------------
        // pos:          position of reference doorway
        // rot:          rotation of reference doorway

        // Iterate doorways, message those with a matching shaft name
        for (d = 0; d < num_doorways; ++d)
        {
            integer dw_shaft_idx = d * DOORWAYS_STRIDE + DOORWAYS_IDX_SHAFT;
            string dw_shaft = llList2String(doorways, dw_shaft_idx);
                   
            // Only instruct doorways that match the current shaft    
            if (dw_shaft == shaft)
            {
                // Current floor unknown, will be filled in by function
                list params = [floor_info, NOT_FOUND, rc_floor_num, pos, rot];
                request_doorway_setup(d, params);
                ++num_components_messaged;
            }
        }

        // Iterate cabs, message those with a matching shaft name
        for (c = 0; c < num_cabs; ++c)
        {
            integer cab_shaft_idx = c * CABS_STRIDE + CABS_IDX_SHAFT;
            string cab_shaft = llList2String(cabs, cab_shaft_idx);
            
            // Only instruct cabs that match the current shaft    
            if (cab_shaft == shaft)
            {
                // Current floor is same as recall floor
                list params = [floor_info, rc_floor_num, rc_floor_num];
                request_cab_setup(c, params);
                ++num_components_messaged;
            }
        }        
    }
    
    integer num_buttons = get_strided_length(buttons, BUTTONS_STRIDE);
    integer b;
    
    // Iterate and message all buttons, recycle most recent floor_info
    for (b = 0; b < num_buttons; ++b)
    {
        list params = [floor_info, NOT_FOUND, NOT_FOUND];
        request_button_setup(b, params);
        ++num_components_messaged;   
    }
        
    return num_components_messaged;
}

integer request_doorway_setup(integer d, list params)
{
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
    
    // [floor_info, floor_num, rc_floor_num, pos, rot];
    params = llListReplaceList(params, [floor_num], CFG_IDX_CURR_FLOOR, 
                                                    CFG_IDX_CURR_FLOOR);
    
    // Finally, we can send the setup message to the doorway
    send_message(dw_uuid, CMD_CONFIG, params);
    return TRUE;
}

integer request_cab_setup(integer c, list params)
{
    // Get the cab's UUID
    integer cab_uuid_idx  = c * CABS_STRIDE + CABS_IDX_UUID;
    key     cab_uuid  = llList2Key(cabs, cab_uuid_idx);

    // [floor_num, rc_floor_num, floor_info];
    send_message(cab_uuid, CMD_CONFIG, params);
    return TRUE;
}

integer request_button_setup(integer b, list params)
{
    integer button_uuid_idx = b * BUTTONS_STRIDE + BUTTONS_IDX_UUID;
    key     button_uuid = llList2Key(buttons, button_uuid_idx);
    
    send_message(button_uuid, CMD_CONFIG, params);
    return TRUE;
}

integer all_components_ready()
{
    integer num_cabs = get_strided_length(cabs, CABS_STRIDE);
    integer c;
    
    for (c = 0; c < num_cabs; ++c)
    {
        integer idx = c * CABS_STRIDE + CABS_IDX_STATE;
        string status = llList2String(cabs, idx);
        debug("Cab status: " + status);
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
        debug("Doorway status: " + status);
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

        state config;
    }
    
    state_exit()
    {
        llSetTimerEvent(0.0);
    }
}

state config
{
    state_entry()
    {
        current_state = STATE_CONFIG;
        print_state_info();
        
        listen_handle = llListen(CHANNEL, "", NULL_KEY, "");
        
        // Send 'config' message to all components
        request_component_setup();
        
        // Give components some time to perform configuration
        llSetTimerEvent(CONFIG_TIME);
    }
    
    listen(integer channel, string name, key id, string message)
    {
        process_message(channel, name, id, message);
    }
    
    timer()
    {
        // Time is up, let's see if all components are running
        llSetTimerEvent(0.0);
        if (all_components_ready())
        {
            llOwnerSay("Config done. All systems ready.");
            state running; 
        }
        else
        {
            llOwnerSay("Config failed.");
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
        
        listen_handle = llListen(CHANNEL, "", NULL_KEY, "");
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
