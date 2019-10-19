// [string shaft, key uuid, string state, ...]
#define CABS_STRIDE 3

#define CABS_IDX_SHAFT 0
#define CABS_IDX_UUID  1
#define CABS_IDX_STATE 2

// [string floor, string shaft, key uuid, string state, ...]
#define DOORWAYS_STRIDE 4

#define DOORWAYS_IDX_FLOOR 0
#define DOORWAYS_IDX_SHAFT 1
#define DOORWAYS_IDX_UUID  2
#define DOORWAYS_IDX_STATE 3

// [string floor, key uuid, string state ...]
#define BUTTONS_STRIDE 3

#define BUTTONS_IDX_FLOOR 0
#define BUTTONS_IDX_UUID  1
#define BUTTONS_IDX_STATE 2

// [string name, float doorway_offset, string recall_floor...]
#define SHAFTS_STRIDE 3

#define SHAFTS_IDX_NAME         0
#define SHAFTS_IDX_DOORWAY_DIST 1
#define SHAFTS_IDX_RECALL_FLOOR 2

// [float zpos, string name, ...]
#define FLOORS_STRIDE 2

#define FLOORS_IDX_ZPOS 0
#define FLOORS_IDX_NAME 1

