#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"

#include <malloc.h>
//#include <assert.h>


static __inline unsigned get_u32(const unsigned char *p)
{
    return *(const unsigned*)p;
}

static __inline void put_u32(unsigned char *p, unsigned x)
{
    *(unsigned*)p = x;
}

static int xdecompress(lua_State *L)
//const unsigned char *inp, unsigned char *outbuf, unsigned outlen
{
    const unsigned char *inp = lua_tostring(L, 1);
//    unsigned int outlen      = lua_tointeger(L, 2);
    unsigned int outlen      = lua_tounsignedx(L, 2, NULL);

    unsigned char *outbuf;
    outbuf = malloc(outlen);


    const unsigned counts[16] = {
        4, 0, 1, 0,
        2, 0, 1, 0,
        3, 0, 1, 0,
        2, 0, 1, 0
    };
    unsigned char *outp = outbuf, *p;
    unsigned char *outlast = outbuf + outlen - 1;
    unsigned mask = 1, bits, len, off;

    for (;;) {
//        assert(mask != 0);
        if (mask == 1) {
            mask = get_u32(inp);
//printf("reload mask=%x\n", mask);
            inp += 4;
        }
        bits = get_u32(inp);
        if (mask & 1) {
            mask >>= 1;
            len = 3;
            ++inp;
            if (bits & 3) {
                ++inp;
                if (bits & 2) {
                    if (bits & 1) {
                        ++inp;
                        if ((bits & 0x7f) == 3) {
                            ++inp;
                            off = bits >> 15;
                            len += (bits >> 7) & 0xff;
                        } else {
                            off = (bits >> 7) & 0x1ffff;
                            len += ((bits >> 2) & 0x1f) - 1;
                        }
                    } else {
                        off = (bits >> 6) & 0x3ff;
                        len += (bits >> 2) & 0xf;
                    }
                } else {
                    off = (bits >> 2) & 0x3fff;
                }
            } else {
                off = (bits >> 2) & 0x3f;
            }
//printf("back ref bits=%u off=%u len=%u\n", bits & 3, off, len);
//            assert(outp - off >= outbuf);
//            assert(outp + len <= outlast);
            p = outp;
            outp += len;
            do {
                put_u32(p, get_u32(p - off));
                p += 3;
            } while (p < outp);
        } else if (outp < outlast - 10) {
            put_u32(outp, bits);
            len = counts[mask & 0x0f];
//printf("literal run len=%u\n", len);
            outp += len;
            inp += len;
            mask >>= len;
        } else {
//printf("tail len=%u\n", (unsigned)(outlast - outp));
            while (outp <= outlast) {
                if (mask == 1) {
                    mask = 0x80000000;
                    inp += 4;
                }
                *outp++ = *inp++;
                mask >>= 1;
            }

            lua_pushlstring(L, outbuf, outlen);
            free(outbuf);
            return 1;
        }
    }
}


static const struct luaL_Reg metro_lz[] = {
    {"xdecompress", xdecompress},
    {NULL, NULL}
};

int __declspec(dllexport) luaopen_metro_lz(lua_State *L)
{
    luaL_newlib(L, metro_lz);
//    luaL_register(L, "metro_lz", metro_lz);
    return 1;
}