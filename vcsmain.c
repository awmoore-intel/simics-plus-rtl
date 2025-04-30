extern int vcs_main(int argc, char** argv);
extern void VcsInit();
extern void VcsSimUntil(int *);
#include <unistd.h>

#include "vpi_user.h"
void print_simulation_time() {
    s_vpi_time current_time;

    // Set the type of time to retrieve
    current_time.type = vpiSimTime;

    // Get the current simulation time
    vpi_get_time(NULL, &current_time);

    // Print the current simulation time
    vpi_printf("Current simulation time: %u\n", current_time.low);
}

long getCurrentTime() {
    s_vpi_time current_time;

    // Set the type of time to retrieve
    current_time.type = vpiSimTime;

    // Get the current simulation time
    vpi_get_time(NULL, &current_time);

    // Print the current simulation time
    return current_time.low;

}

void pulse_clock(int count)  {
    int pulse_width = 1000;
    long currentTime = getCurrentTime();
	unsigned  long  t = currentTime;
    static vpiHandle clock = NULL;
    if(clock == NULL) clock =  vpi_handle_by_name("Crc32.clock", 0);
    for( int i = 0 ; i < count; i ++) {
        s_vpi_time var_time = {vpiSimTime,0,t,0};
        s_vpi_vecval var_vecval = {0,0};
        s_vpi_value var_value = {vpiVectorVal, (char *)&var_vecval};

        vpi_put_value(clock, &var_value, &var_time, vpiForceFlag);

        t += pulse_width;
        VcsSimUntil(&t);
        var_vecval.aval = 1;
        var_value.value.vector = &var_vecval;
        s_vpi_time var_time1 = {vpiSimTime,0,t,0};
        vpi_put_value(clock, &var_value, &var_time1, vpiForceFlag);
        t += pulse_width;
        VcsSimUntil(&t);
        print_simulation_time();
    }
}

int main(int argc, char** argv) {
	argv[0] = "libcrc.so";
	unsigned t[2] = {1000000,0};

	vcs_main(argc, argv);
	VcsInit();

    vpiHandle reset = vpi_handle_by_name("Crc32.reset", 0);
    vpiHandle clock = vpi_handle_by_name("Crc32.clock", 0);

    // vpi value
    s_vpi_time var_time = {vpiSimTime,0,0,0};
    s_vpi_vecval var_vecval = {1,0};
    s_vpi_value var_value = {vpiVectorVal, (char *)&var_vecval};

   // Try to initialize variables in design
    vpi_put_value(reset, &var_value, &var_time, vpiForceFlag);

    pulse_clock(10);
    var_vecval.aval = 0;
    vpi_put_value(reset, &var_value, &var_time, vpiForceFlag);
    pulse_clock(10);
    var_vecval.aval = 1;
    vpi_put_value(reset, &var_value, &var_time, vpiForceFlag);
    pulse_clock(10);

    VcsSimUntil(t);

    vpi_control(vpiFinish,0);
	return 0;
}