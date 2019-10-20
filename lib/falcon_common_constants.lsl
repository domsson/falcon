#define DEBUG TRUE

#define CHANNEL -130104

#define SIG_CONTROLLER "falcon-control"
#define SIG_CAB        "falcon-cab"
#define SIG_DOORWAY    "falcon-doorway"
#define SIG_BUTTONS    "falcon-buttons"

#define NOT_FOUND   -1
#define NOT_HANDLED -8
#define FLOAT_MAX    3.402823466E+38

#define MSG_IDX_SIG     0
#define MSG_IDX_IDENT   1
#define MSG_IDX_CMD     2
#define MSG_IDX_PARAMS  3

#define IDENT_IDX_BANK  0
#define IDENT_IDX_SHAFT 1
#define IDENT_IDX_FLOOR 2

#define CFG_IDX_FLOOR_INFO 0
#define CFG_IDX_CURR_FLOOR 1
#define CFG_IDX_BASE_FLOOR 2

#define STATE_INITIAL "default"
#define STATE_PAIRING "pairing"
#define STATE_CONFIG  "config"
#define STATE_RUNNING "running"
#define STATE_ERROR   "error"

#define CMD_PING    "ping"
#define CMD_PONG    "pong"
#define CMD_PAIR    "pair"
#define CMD_STATUS  "status"
#define CMD_CONFIG  "config"
#define CMD_CHANNEL "channel"
#define CMD_EVENT   "event"
#define CMD_RESET   "reset"
#define CMD_SUB     "subscribe"


