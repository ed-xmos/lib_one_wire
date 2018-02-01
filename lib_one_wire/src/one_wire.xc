#include <xs1.h>
#include <print.h>
#include <string.h>
#include "one_wire.h"

typedef enum one_wire_ll_state_t {
    OW_LL_IDLE = 0, 
    OW_LL_RESET_ASSERT,
    OW_LL_RESET_DETECT,
    OW_LL_WRITE,
    OW_LL_READ,
    OW_LL_RECOVER 
    } one_wire_ll_state_t;

//Debug strings. May be removed if debug of one wire not needed
const char *state_txt[] = {
    "OW_LL_IDLE",
    "OW_LL_RESET_ASSERT",
    "OW_LL_RESET_DETECT",
    "OW_LL_WRITE",
    "OW_LL_READ",
    "OW_LL_RECOVER"
};

typedef enum one_wire_prot_state_t {
    OW_PROT_IDLE = 0, 
    OW_PROT_RESET,
    OW_PROT_CMD,
    OW_PROT_READ 
    } one_wire_prot_state_t;

interface one_wire_ll_if {
    void send_reset(void);
    void write_cycle(int bit);
    void read_cycle(void);
    [[notification]] slave void action_needed(void);
    [[clears_notification]] one_wire_ll_state_t get_status(int &data);
};


[[combinable]]
static void one_wire_protocol(server one_wire_if i_ow, client interface one_wire_ll_if i_low_level){
    unsigned char cmd  = 0;
    unsigned char data[MAX_DATA_BYTES] = {0};
    unsigned data_idx  = 0;
    unsigned bits_left = 0;

    one_wire_prot_state_t prot_state = OW_PROT_IDLE;
    presence_status_t present = OW_NOT_PRESENT;

    while(1){
        select{
            case i_ow.send_command(unsigned char new_cmd):
                cmd = new_cmd;
                prot_state = OW_PROT_CMD;
                bits_left = 8;
                i_low_level.write_cycle(cmd & 0x1);
                //printstr("C");
            break;

            case i_ow.reset(void):
                prot_state = OW_PROT_RESET;
                i_low_level.send_reset();
            break;

            case i_ow.start_read_bytes(unsigned n_bytes):
                prot_state = OW_PROT_READ;
                bits_left = n_bytes * 8;
                data_idx = 0;
                memset(data, 0, sizeof(data));
                i_low_level.read_cycle();
                //printstr("L");
            break;

            case i_ow.get_read_bytes(unsigned char read_data[], unsigned n_bytes):
                //if (n_bytes > MAX_DATA_BYTES) n_bytes = MAX_DATA_BYTES; commented out because array bounds check will catch this
                memcpy(read_data, data, n_bytes);
            break;


            case i_ow.check_status(void) -> presence_status_t presence:
                presence = present;
            break;

            case i_low_level.action_needed():
                //printstr("+");
                int bit = 0;
                one_wire_ll_state_t ll_state = i_low_level.get_status(bit);
                switch(prot_state){
                    case OW_PROT_CMD:
                        cmd >>= 1;
                        bits_left --;
                        if (bits_left == 0) {
                            prot_state = OW_PROT_IDLE;
                            i_ow.cmd_finshed();
                        }
                        else{
                            i_low_level.write_cycle(cmd & 0x1);
                        }
                    break;

                    case OW_PROT_RESET:
                        prot_state = OW_PROT_IDLE;
                        //printf("presence bit: %d\n", bit);
                        if (bit) present = OW_NOT_PRESENT;
                        else present = OW_PRESENT;
                        i_ow.cmd_finshed();
                    break;

                    case OW_PROT_READ:
                        //printintln(bit);
                        if(bit) data[data_idx / 8] |= 0x1 << (data_idx % 8);
                        bits_left --;
                        data_idx ++;
                        if (bits_left == 0) {
                            prot_state = OW_PROT_IDLE;
                            i_ow.cmd_finshed();
                        }
                        else{
                            i_low_level.read_cycle();
                        }
                    break;

                    case OW_PROT_IDLE:
                        //printstr("**INVALID***");
                    break;
                }
                //printf("State = %s, data = %d\n", state_txt[ll_state], data);
            break;
        }
    }
}

[[combinable]]
static void one_wire_ll(server interface one_wire_ll_if i_low_level, port p_ow){
    timer t_frame;    //Frame period
    timer t_deassert; //When to deassert pin
    timer t_sample;   //When to read pin

    int frame_time_trig    = 0;
    int deassert_time_trig = 0;
    int sample_time_trig   = 0;

    int sampled_bit        = 0;

    one_wire_ll_state_t ll_state = OW_LL_IDLE;

    while(1){
        select{
            //Start a reset
            case i_low_level.send_reset(void):
                t_frame :> frame_time_trig;
                frame_time_trig += RESET_PULSE_TICKS;
                ll_state = OW_LL_RESET_ASSERT;
                p_ow <: 0;
                //printstr("R");
            break;

            //Wait for end of reset assert, reset detect, read, write or recover period
            case (ll_state != OW_LL_IDLE) => t_frame when timerafter(frame_time_trig) :> int _:
                //printstr("t");
                switch (ll_state){
                case OW_LL_RESET_ASSERT:
                    //printstr(".");
                    p_ow :> void;
                    frame_time_trig += RESET_PULSE_TICKS;
                    t_sample :> sample_time_trig;
                    sample_time_trig += PRESENCE_SAMPLE_TICKS;
                    ll_state = OW_LL_RESET_DETECT;
                break;

                case OW_LL_RESET_DETECT:
                    //printstr(",");
                    ll_state = OW_LL_RECOVER;
                    frame_time_trig += RECOVERY_TIME_TICKS;
                break;

                case OW_LL_WRITE:
                case OW_LL_READ:
                    ll_state = OW_LL_RECOVER;
                    //printstr("i");
                    frame_time_trig += RECOVERY_TIME_TICKS;
                break;

                case OW_LL_RECOVER:
                    ll_state = OW_LL_IDLE;
                    i_low_level.action_needed();
                break;
            }
            break;


            //Sample either presence or data bit after reset or read
            case (ll_state == OW_LL_RESET_DETECT || ll_state == OW_LL_READ) => t_sample when timerafter(sample_time_trig) :> int _:
                //printstr("s");
                p_ow :> sampled_bit;
                sample_time_trig += 100000000; //Move to future way beyond frame so we disable this case from refiring
            break;

            //clear notification and get data/status
            case i_low_level.get_status(int &data) -> one_wire_ll_state_t state:
                data = sampled_bit;
                state = ll_state;
            break;

            //Start write cycle
            case i_low_level.write_cycle(int bit):
                ll_state = OW_LL_WRITE;
                t_deassert :> deassert_time_trig; //Note capture deassert first so this triggers just before frame
                deassert_time_trig += bit ? WRITE_1_RELEASE_TICKS : WRITE_0_RELEASE_TICKS;
                t_frame :> frame_time_trig;
                frame_time_trig += SLOT_TIME_TICKS;
                p_ow <: 0;
            break;

            //De-assert the line
            case (ll_state == OW_LL_WRITE
                || ll_state == OW_LL_READ) => t_deassert when timerafter(deassert_time_trig) :> int _:
                deassert_time_trig += 100000000; //Move to future way beyond frame so we disable this case from refiring
                p_ow :> void;
                //printstr("d");
            break;

            //Start a 1b read
            case i_low_level.read_cycle(void):
                //printstr("r");
                ll_state = OW_LL_READ;
                t_frame :> frame_time_trig;
                frame_time_trig += SLOT_TIME_TICKS;
                t_deassert :> deassert_time_trig;
                deassert_time_trig += READ_ASSERT_TICKS;                
                t_sample :> sample_time_trig;
                sample_time_trig += READ_SAMPLE_TICKS;
                p_ow <: 0;
            break;

        }
    }
}

//Helper function which waits for last command to finish
presence_status_t wait_for_completion(client one_wire_if i_one_wire){
  presence_status_t present;
  select{
    case i_one_wire.cmd_finshed():
      present = i_one_wire.check_status();
    break;
  }
  return present;
}

[[combinable]]
void one_wire(server one_wire_if i_ow, port p_ow){
    interface one_wire_ll_if i_low_level;
    [[combine]]
    par{
        one_wire_protocol(i_ow, i_low_level);
        one_wire_ll(i_low_level, p_ow);
    }
}

