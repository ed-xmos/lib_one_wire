#ifndef _ow_h_
#define _ow_h_

//One wire timing parameters
#define RESET_PULSE_TICKS        48000        //480us
#define PRESENCE_PERIOD_TICKS    48000        //480us
#define PRESENCE_SAMPLE_TICKS     6800        //Earliest it comes is 60us and earliest it goes is 75us so set halfway

#define SLOT_TIME_TICKS           8000        //80us
#define RECOVERY_TIME_TICKS        100        //1us

#define WRITE_0_RELEASE_TICKS     6000        //60us. note must be less than SLOT_TIME_TICKS else write 0 will not release
#define WRITE_1_RELEASE_TICKS      100        //1us

#define READ_ASSERT_TICKS          100        //1us
#define READ_SAMPLE_TICKS         1400        //14us

#if (WRITE_0_RELEASE_TICKS >= SLOT_TIME_TICKS)
#error WRITE_0_RELEASE_TICKS must be greater than SLOT_TIME_TICKS
#endif

//Sizes array used for reading. This is the largest size read we can expect
#define MAX_DATA_BYTES              16

typedef enum presence_status_t{
    OW_NOT_PRESENT,
    OW_PRESENT
}presence_status_t;

//One wire server commands
typedef interface one_wire_if {
    void send_command(unsigned char cmd);
    void start_read_bytes(unsigned n_bytes);
    void get_read_bytes(unsigned char data[], unsigned n_bytes);
    void reset(void);
    [[notification]] slave void cmd_finshed(void);
    [[clears_notification]] presence_status_t check_status(void);
}one_wire_if;

//One wire server task
[[combinable]]
void one_wire(server one_wire_if i_ow, port p_ow);

//Helper function to wait for previous command
presence_status_t wait_for_completion(client one_wire_if i_one_wire);


#endif
