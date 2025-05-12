from cffi import FFI

ffi = FFI()
ffi.cdef("""
int rtl_init(const char* name);
int rtl_finish();
void crc32_rtl(uint64_t src1, uint64_t src2) ;
""")


c = ffi.dlopen("./libcrc.so", flags=ffi.RTLD_GLOBAL)
lib = ffi.dlopen("./lib/libaccel_rtl_crc32.so", flags=ffi.RTLD_GLOBAL)

lib.rtl_init(b"Crc32")
lib.crc32_rtl(0x168, 0x321)
lib.crc32_rtl(0, 0x10)
lib.rtl_finish()
#lib.crc32_rtl(0x168, 0x321)
