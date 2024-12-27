// -*- mode: C++; c-file-style: "virtutech-c++" -*-

/*
  © 2024 Intel Corporation

  This software and the related documents are Intel copyrighted materials, and
  your use of them is governed by the express license under which they were
  provided to you ("License"). Unless the License provides otherwise, you may
  not use, modify, copy, publish, distribute, disclose or transmit this software
  or the related documents without Intel's prior written permission.

  This software and the related documents are provided as is, with no express or
  implied warranties, other than those that are expressly stated in the License.
*/

// This file is generated by the script bin/gen-cc-interface

#ifndef MODULES_CRC32_RTL_DEVICE_CPP_CRC32_RTL_INTERFACE_H
#define MODULES_CRC32_RTL_DEVICE_CPP_CRC32_RTL_INTERFACE_H

#include "../crc32_rtl-interface.h"

#include <simics/iface/interface-info.h>
#include <simics/utility.h>  // get_interface

namespace simics {
namespace iface {

class Crc32RtlInterface {
  public:
    using ctype = crc32_rtl_interface_t;

    // Function override and implemented by user
    virtual bool start_crc(unsigned int src, unsigned int dst, size_t size, bool blocking) = 0;

    // Function convert C interface call to C++ interface call
    class FromC {
      public:
        static bool start_crc(conf_object_t *obj, unsigned int src, unsigned int dst, size_t size, bool blocking) {
            return get_interface<Crc32RtlInterface>(obj)->start_crc(src, dst, size, blocking);
        }
    };

    // Function convert C++ interface call to C interface call
    class ToC {
      public:
        ToC() : obj_(nullptr), iface_(nullptr) {}
        ToC(conf_object_t *obj, const Crc32RtlInterface::ctype *iface)
            : obj_(obj), iface_(iface) {}

        bool start_crc(unsigned int src, unsigned int dst, size_t size, bool blocking) const {
            return iface_->start_crc(obj_, src, dst, size, blocking);
        }

        const Crc32RtlInterface::ctype *get_iface() const {
            return iface_;
        }

      private:
        conf_object_t *obj_;
        const Crc32RtlInterface::ctype *iface_;
    };

    class Info : public InterfaceInfo {
      public:
        // InterfaceInfo
        std::string name() const override { return CRC32_RTL_INTERFACE; }
        const interface_t *cstruct() const override {
            static constexpr Crc32RtlInterface::ctype funcs {
                FromC::start_crc,
            };
            return &funcs;
        }
    };
};

}  // namespace iface
}  // namespace simics

#endif
