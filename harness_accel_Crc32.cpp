
#include <vpi_user.h>
#include <cstdint>
#include <cassert>
#include <string>
#include <iostream>
#include <vector>

// access to Simics PCI memory interface
#include "simics_pci_memory.hpp"

// C-based forward declaration to allow DML to call into this harness
extern "C" {
    #include "harness.h"


class VerilogSignal {
private:
    std::string _name;
    int _value;
    vpiHandle _handle;


public:
    VerilogSignal(std::string name, int value = 0) : _name(name), _value(value) {
        _handle = vpi_handle_by_name((PLI_BYTE8*)name.c_str(), 0);
    }

    // Read access
    operator int() {
        std::cout << "Reading " << _name <<" value: " << _value << std::endl;

        s_vpi_value value_s = {vpiIntVal, {NULL}};

        vpi_get_value(_handle, &value_s);

        _value = value_s.value.integer;
        return _value;
    }

    // Write access
    VerilogSignal& operator=(uint64_t value) {
        std::cout << "Setting " << _name <<" value to: " << value << std::endl;
        _value = value;
        s_vpi_value var_value;
        var_value.format = vpiIntVal;
        var_value.value.integer = value;

        vpi_put_value(_handle, &var_value, NULL, vpiNoDelay);
        var_value = var_value;
        return *this;
    }
};

#define SIGNAL(name) VerilogSignal name
#define SIGNALI(name) name("Crc32." #name)

class VCrc32 {
    public:
        SIGNAL(io_cmd_bits_rs1);
        SIGNAL(io_cmd_bits_rs2);
        SIGNAL(io_cmd_valid);
        SIGNAL(io_mem_req_ready);
        SIGNAL(io_mem_resp_valid);
        SIGNAL(io_mem_req_valid);
        SIGNAL(io_mem_req_bits_addr);
        SIGNAL(io_mem_req_bits_size_in_bytes);
        SIGNAL(io_mem_req_bits_is_read);
        SIGNAL(io_mem_req_bits_data);
        SIGNAL(io_mem_resp_bits_data);
        SIGNAL(io_resp_bits_data);
        SIGNAL(io_resp_valid);
        SIGNAL(reset);
        SIGNAL(clock);
        VCrc32() : 
            SIGNALI(io_cmd_bits_rs1),
            SIGNALI(io_cmd_bits_rs2),
            SIGNALI(io_cmd_valid),
            SIGNALI(io_mem_req_ready),
            SIGNALI(io_mem_resp_valid),
            SIGNALI(io_mem_req_valid),
            SIGNALI(io_mem_req_bits_addr),
            SIGNALI(io_mem_req_bits_size_in_bytes),
            SIGNALI(io_mem_req_bits_is_read),
            SIGNALI(io_mem_req_bits_data),
            SIGNALI(io_mem_resp_bits_data),
            SIGNALI(io_resp_bits_data),
            SIGNALI(io_resp_valid),
            SIGNALI(reset),
            SIGNALI(clock) {}
        void eval() {}
        void final() {
            vpi_control(vpiFinish,0);
        }
};

extern "C" void VcsSimUntil(long *t);

class VerilatedContext {
    public:
    void timeInc(int inc) {
        // Simulate time increment

        static long int t = 0;

        // Get the current simulation time
        //vpi_get_time(_handle, &current_time);
        std::cout << "Current simulation time: " << t << std::endl;

        // Print the current simulation time
        t += inc;
        
        std::cout << "Next simulation time: " << t << std::endl;
        VcsSimUntil(&t);
    }

};

// verilated RTL design-under-test
//#include "verilated_vcd_c.h"
//class VerilatedVcdC;
//#include "VCrc32.h"
static VerilatedContext * contextp = NULL;
static VCrc32* dut = NULL;

std::string test_name;
#define VERBOSE (1)
uint64_t cycle_count = 0;

void setup_rtl_callback(conf_object_t * device, conf_object_t * memory_space) {
    auto ret = setup_pci_interface(device, memory_space);
    assert(ret == 0); // interface setup correctly
    std::cout << "[Harness] RTL callback interface has been configured" << std::endl;
}

void step(const uint64_t cycles = 1) {
    assert(dut);
    for (uint64_t i = 0; i < cycles; i++) {
        dut->clock = 0;
        contextp->timeInc(1);
        dut->eval();
        #if USE_TRACE == 1
        if(tfd) {
            tfd->dump(static_cast<vluint64_t>(2 * cycle_count));
            tfd->flush();
        }
        #endif
        dut->clock = 1;
        contextp->timeInc(1);
        dut->eval();
        #if USE_TRACE == 1
        if(tfd) {
            tfd->dump(static_cast<vluint64_t>(2 * cycle_count + 1));
            tfd->flush();
        }
        #endif
        cycle_count++;
    }
    vpi_flush();
    //vpi_control(vpiStop,0);
    vpi_mcd_flush(0);
}

extern "C" int rtl_init(const char* name);
extern "C" void rtl_finish();
extern "C" int vcs_main(int argc, const char* const* argv);
extern "C" void VcsInit();

int rtl_init(const char* name) {

    const char *const argv[] = {"libcrc.so", "-ucli", "-do", "run.do"};
    int argc = 4;
    vcs_main(argc, argv);
    // Initialize VCS
    VcsInit();

    dut = new VCrc32();
    assert(dut);
    cycle_count = 0;

    dut->reset = 1;
    step();
    dut->reset = 0;

    dut->io_mem_req_ready = true; // always ready to handle memory transactions
    dut->io_cmd_valid = false; // invalid command
    dut->io_mem_resp_valid = false; // no memory response

    std::cout << std::endl << "[Harness] Starting test on RTL DUT: " << name;
    #if USE_TRACE == 1
    std::cout << " with VCD trace: " << test_name + std::string(".vcd");
    #endif
    std::cout << std::endl;

    atexit(rtl_finish);

    return 0;
}

void rtl_finish() {
    #if USE_TRACE == 1
    assert(tfd);
    tfd->close();
    delete tfd;
    #endif
    #if USE_COVERAGE == 1
    std::string coverage_file_name = std::string(test_name) + std::string(".dat");
    printf("[Harness] Writing coverage data to: %s\n", coverage_file_name.c_str());
    contextp->coveragep()->write(coverage_file_name.c_str());
    #endif
    assert(dut);
    dut->final();
    delete dut;
    delete contextp;
    printf("[Harness] Terminating RTL simulation\n");
}

void crc32_rtl(uint64_t src1, uint64_t src2) {
    if (dut == NULL) {
        rtl_init("SelfInit");
    }
    assert(dut);

    if (src1 == 0 && src2 == 0) {
        if (VERBOSE) std::cout << "[Harness] Terminating simulation" << std::endl;
        rtl_finish();
        return;
    }

    uint64_t start_cycle_count = cycle_count;
    std::cout << "[Harness] Sending coomand: 0x" << std::hex << src1 << " 0x" << src2 << std::dec << " at cycle: " << start_cycle_count << std::endl;

    dut->io_cmd_bits_rs1 = src1;
    dut->io_cmd_bits_rs2 = src2;
    dut->io_cmd_valid = true; // valid command

    step();

    dut->io_cmd_valid = false; // invalid command
    dut->io_mem_req_ready = true; // always ready to handle memory transactions

    int timeout = 1000;
    while (!dut->io_resp_valid) {
        if (timeout -- < 0) {
            std::cerr << "[Harness] Timeout waiting for response" << std::endl;
            break;
        }
        
        if (VERBOSE) std::cout << "[Harness] Step at cycle: " << cycle_count << std::endl;
        dut->io_mem_resp_valid = false; // no response by default

        if (dut->io_mem_req_valid) { // memory request
            uint64_t addr = dut-> io_mem_req_bits_addr;

            if (dut->io_mem_req_bits_is_read) { // memory read request (no data)
                if (VERBOSE) std::cout << "[Harness] Mem Read: addr 0x" << std::hex << addr << ", size 0x" << (uint16_t)dut->io_mem_req_bits_size_in_bytes << std::dec << std::endl;
                uint64_t val = rtl_memory_read(addr, dut->io_mem_req_bits_size_in_bytes);
                if (VERBOSE) std::cout << std::hex << "[Harness] Read data 0x" << val << std::dec << std::endl;
                dut->io_mem_resp_bits_data = val;
                dut->io_mem_resp_valid = true; // we do have a mem response
            } else { // memory write has request (this has data, no response)
                uint64_t data = dut->io_mem_req_bits_data;
                if (VERBOSE) std::cout << "[Harness] Mem write: addr 0x" << std::hex << addr << ", size 0x" << (uint16_t)dut->io_mem_req_bits_size_in_bytes << ", data 0x" << data << std::dec << std::endl;
                rtl_memory_write(addr, dut->io_mem_req_bits_size_in_bytes, data);
            }
        }
        step();
    }
    std::cout << "[Harness] response: 0x" << std::hex << dut->io_resp_bits_data << std::dec << ", latency: " << cycle_count - start_cycle_count << " cycles" << std::endl;
    step();
}
