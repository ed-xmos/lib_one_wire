#include <xs1.h>
#include <print.h>
#include "one_wire.h"

port p_ow = XS1_PORT_1G;

//DS18S20 commands
#define MATCH_ROM      0x55
#define READ_ROM       0x33
#define SKIP_ROM       0xCC
#define CONVERT_T      0x44
#define READ_SCRATCH   0xBE
#define WRITE_SCRATCH  0x4E
#define COPY_TO_EEPROM 0x48
#define RECALL_EEPROM  0xB8
#define READ_PSU       0xB4


void write_to_eeprom(client one_wire_if i_one_wire, unsigned char data[2]){
  i_one_wire.check_status();
  i_one_wire.reset();
  wait_for_completion(i_one_wire); 
  i_one_wire.send_command(SKIP_ROM);
  wait_for_completion(i_one_wire);
  i_one_wire.send_command(WRITE_SCRATCH);
  wait_for_completion(i_one_wire);
  i_one_wire.send_command(data[0]);
  wait_for_completion(i_one_wire);
  i_one_wire.send_command(data[1]);
  wait_for_completion(i_one_wire);
  i_one_wire.reset();
  wait_for_completion(i_one_wire); 
  i_one_wire.send_command(SKIP_ROM);
  wait_for_completion(i_one_wire);
  i_one_wire.send_command(COPY_TO_EEPROM);
  wait_for_completion(i_one_wire);
}

void read_from_eeprom(client one_wire_if i_one_wire, unsigned char data[2]){
  i_one_wire.check_status();
  i_one_wire.reset();
  wait_for_completion(i_one_wire); 
  i_one_wire.send_command(SKIP_ROM);
  wait_for_completion(i_one_wire);
  i_one_wire.send_command(RECALL_EEPROM);
  wait_for_completion(i_one_wire);
  i_one_wire.reset();
  wait_for_completion(i_one_wire); 
  i_one_wire.send_command(SKIP_ROM);
  wait_for_completion(i_one_wire); 
  i_one_wire.send_command(READ_SCRATCH);
  wait_for_completion(i_one_wire);
  unsigned char bytes[9];
  i_one_wire.start_read_bytes(9);
  wait_for_completion(i_one_wire);
  i_one_wire.get_read_bytes(bytes, 9);
  data[0] = bytes[2];
  data[1] = bytes[3];
}

void convert_and_read_scratch(client one_wire_if i_one_wire, unsigned char data[9]){
  i_one_wire.check_status();
  i_one_wire.reset();
  wait_for_completion(i_one_wire); 
  i_one_wire.send_command(SKIP_ROM);
  wait_for_completion(i_one_wire);
  i_one_wire.send_command(CONVERT_T);
  wait_for_completion(i_one_wire);
  i_one_wire.reset();
  wait_for_completion(i_one_wire);
  i_one_wire.send_command(SKIP_ROM);
  wait_for_completion(i_one_wire);
  i_one_wire.send_command(READ_SCRATCH);
  wait_for_completion(i_one_wire);
  i_one_wire.start_read_bytes(9);
  wait_for_completion(i_one_wire);
  i_one_wire.get_read_bytes(data, 9);
}


void test(client one_wire_if i_one_wire){
  printstr("Test started\n");
  int counter = 0;
  while(1){
    unsigned char bytes[9] = {0};

    convert_and_read_scratch(i_one_wire, bytes);
    //printstr("\nBytes read:\n");
    //for(int i = 0; i < n_bytes; i++) printhexln(bytes[i]);

    short temp = bytes[0] | ((unsigned)bytes[1] << 8);
    printstr("temp=");printint(temp>>1);
    if(temp & 0x1) {
      printstr(".5");
    }
    else{
      printstr(".0");
    }
    printstr("C\n");
    
    unsigned char eeprom[2];
    eeprom[0] = counter;
    eeprom[1] = counter + 100;
    write_to_eeprom(i_one_wire, eeprom);
    eeprom[0] = 0xff; //Trash temp bytes so we are sure we get valid data back
    eeprom[1] = 0xff;

    delay_milliseconds(10); //Let the EEPROM write complete
    
    read_from_eeprom(i_one_wire, eeprom);
    printstr("EEPROM: ");
    printint(eeprom[0]);
    printstr(", ");
    printintln(eeprom[1]);

    counter++;
    delay_seconds(1);
  }
}

int main(void){
  one_wire_if i_one_wire;
  printstr("par\n");
  par{
    one_wire(i_one_wire, p_ow);
    test(i_one_wire);
  }
  return 0;
}