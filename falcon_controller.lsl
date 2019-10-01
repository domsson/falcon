integer channel = -130104;
integer listen_handle;

// CONSTS
integer NOT_FOUND = -1; // ll* functions often return -1 to indicate 'not found'

// [key cab_key, string name ...]
list    cabs = [];
integer cabs_stride = 2;

// [key display_key, integer floor ...]
list    displays = [];
integer displays_stride = 2;

// [key controls_key, integer floor ...]
list    controls = [];
integer controls_stride = 2;

// [key doorways_key, integer floor ...]
list    doorways = [];
integer doorways_stride = 2;

/*
 * Adds the elevator cab with UUID `id` and name `name` 
 * to the list of cabs, unless `id` is already in the list.
 */
add_cab(key id, string name)
{
    if (llListFindList(cabs, (list) id) == NOT_FOUND)
    {
        cabs += [id, name];
    }
}

/*
 * Adds the floor component (controls, display or doorway)
 * to the given list, unless `id` is already in the list.
 */
add_floor_component(list component_list, key id, integer floor)
{
    if (llListFindList(component_list, (list) id) == NOT_FOUND)
    {
        component_list += [id, floor];
    }
}

default
{
    state_entry()
    {
        listen_handle = llListen(channel, "", NULL_KEY, "");
        llRegionSay(channel, "falcon-ping");
    }

    touch_start(integer total_number)
    {
        
    }
    
    listen(integer channel, string name, key id, string message)
    {
        llOwnerSay(llGetObjectName() + " < `" + message + "`");
        llRegionSayTo(id, channel, "falcon-setup");
    }
}
