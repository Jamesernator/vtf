"use strict"

dxt = require('dxt-js')
jpg = require('jpeg-js')

### All decoders return an object containing data, width and height
    where width and height are number of pixels and data is an array-like
    of RGBA8888 data
    encoders expect the same objects as the decoders return

    total_bits is the total number of bits per pixel

    for all encoders/decoders raw frame data in and out is assumed to be
    Uint8Array's, if needed they will be converted to Uint8Arrays using
    Uint8Array.from(data)
###

VTFImageFormats =
    '-1': 'NONE'
    0: 'RGBA8888'
    1: 'ABGR8888'
    2: 'RGB888'
    3: 'BGR888'
    4: 'RGB565'
    5: 'I8'
    6: 'IA88'
    7: 'P8'
    8: 'A8'
    9: 'RGB888_BLUESCREEN'
    10: 'BGR888_BLUESCREEN'
    11: 'ARGB8888'
    12: 'BGRA8888'
    13: 'DXT1'
    14: 'DXT3'
    15: 'DXT5'
    16: 'BGRX8888'
    17: 'BGR565'
    18: 'BGRX5551'
    19: 'BGRA4444'
    20: 'DXT1_ONEBITALPHA'
    21: 'BGRA5551'
    22: 'UV88'
    23: 'UVWQ8888'
    24: 'RGBA16161616F'
    25: 'RGBA16161616'
    26: 'UVLX8888'

    NONE: -1
    RGBA8888: 0
    ABGR8888: 1
    RGB888: 2
    BGR888: 3
    RGB565: 4
    I8: 5
    IA88: 6
    P8: 7
    A8: 8
    RGB888_BLUESCREEN: 9
    BGR888_BLUESCREEN: 10
    ARGB8888: 11
    BGRA8888: 12
    DXT1: 13
    DXT3: 14
    DXT5: 15
    BGRX8888: 16
    BGR565: 17
    BGRX5551: 18
    BGRA4444: 19
    DXT1_ONEBITALPHA: 20
    BGRA5551: 21
    UV88: 22
    UVWQ8888: 23
    RGBA16161616F: 24
    RGBA16161616: 25
    UVLX8888: 26

exports.ImageFormats =
    NONE: {}

    RGBA8888:
        total_bits: 32
        encode: ({width, height, data}) ->
            return {
                width,
                height,
                data
            }
        decode: ({width, height, data}) ->
            return {
                width,
                height,
                data
            }
    ABGR8888:
        total_bits: 32
    RGB888:
        total_bits: 24
    BGR888:
        total_bits: 24
    RGB565:
        total_bits: 16
    I8:
        total_bits: 8
    IA88:
        total_bits: 16
    P8:
        total_bits: 8
    A8:
        total_bits: 8
    RGB888_BLUESCREEN:
        total_bits: 24
    BGR888_BLUESCREEN:
        total_bits: 24
    ARGB8888:
        total_bits: 32
    BGRA8888:
        total_bits: 32
    DXT1:
        total_bits: 4
        decode: ({width, height, data}) ->
            raw_frame = Uint8Array.from(data)
            return {
                data: dxt.decompress raw_frame,
                        width, height,
                        dxt.flags.DXT1
                width: width
                height: height
            }

        encode: ({width, height, data}) ->
            raw_frame = Uint8Array.from(data)
            return {
                data: dxt.compress raw_frame,
                    width, height,
                    dxt.flags.DXT1
                width: width
                height: height
            }
    DXT3:
        total_bits: 8
        decode: ({width, height, data}) ->
            # data should be a Uint8Array or Buffer, but we'll try converting
            # it to one anyway
            raw_frame = Uint8Array.from(data)
            return {
                data: dxt.decompress raw_frame,
                        width, height,
                        dxt.flags.DXT3
                width: width
                height: height
            }
        encode: ({width, height, data}) ->
            raw_frame = Uint8Array.from(data)
            return {
                data: dxt.compress raw_frame,
                        width, height,
                        dxt.flags.DXT3
                width: width
                height: height
            }
    DXT5:
        total_bits: 8
        decode: ({width, height, data}) ->
            # data should be a Uint8Array or Buffer, but we'll try converting
            # it to one anyway
            raw_frame = Uint8Array.from(data)
            return {
                data: dxt.decompress raw_frame,
                    width, height,
                    dxt.flags.DXT3
                width: width
                height: height
            }
        encode: ({width, height, data}) ->
            raw_frame = Uint8Array.from(data)
            return {
                data: dxt.compress raw_frame,
                        width, height,
                        dxt.flags.DXT5
                width: width
                height: height
            }
    BGRX8888:
        total_bits: 32
    BGR565:
        total_bits: 16
    BGRX5551:
        total_bits: 16
    BGRA4444:
        total_bits: 16
    DXT1_ONEBITALPHA:
        total_bits: 4
    BGRA5551:
        total_bits: 16
    UV88:
        total_bits: 16
    UVWQ8888:
        total_bits: 32
    RGBA16161616F:
        total_bits: 64
    RGBA16161616:
        total_bits: 64
    UVLX8888:
        total_bits: 32

    ### --- Non raw formats --- ###
    JPEG:
        encode: ({data, width, height}) ->
            return jpg.encode({data, width, height})
        decode: ({data}) ->
            return jpg.decode({data})


exports.TextureFlags =
    POINTSAMPLE: 0x00000001
    TRILINEAR: 0x00000002
    CLAMPS: 0x00000004
    CLAMPT: 0x00000008
    ANISOTROPIC: 0x00000010
    HINT_DXT5: 0x00000020
    PWL_CORRECTED: 0x00000040
    NORMAL: 0x00000080
    NOMIP: 0x00000100
    NOLOD: 0x00000200
    ALL_MIPS: 0x00000400
    PROCEDURAL: 0x00000800

    ONEBITALPHA: 0x00001000
    EIGHTBITALPHA: 0x00002000

    ENVMAP: 0x00004000
    RENDERTARGET: 0x00008000
    DEPTHRENDERTARGET: 0x00010000
    NODEBUGOVERRIDE: 0x00020000
    SINGLECOPY: 0x00040000
    PRE_SRGB: 0x00080000

    UNUSED_00100000: 0x00100000
    UNUSED_00200000: 0x00200000
    UNUSED_00400000: 0x00400000

    NODEPTHBUFFER: 0x00800000

    UNUSED_01000000: 0x01000000

    CLAMPU: 0x02000000
    VERTEXTEXTURE: 0x04000000
    SSBUMP: 0x08000000

    UNUSED_10000000: 0x10000000

    BORDER: 0x20000000

    UNUSED_40000000: 0x40000000
    UNUSED_80000000: 0x80000000
