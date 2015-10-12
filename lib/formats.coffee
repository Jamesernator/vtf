"use strict"

dxt = require('dxt-js')
jpg = require('jpeg-js')

### All decoders return RGBA8888 byte arrays and
    similarly encoders expect RGBA8888, support is implied by the existence
    of a decoder/encoder

    total_bits is the total number of bits per pixel

    for all encoders/decoders raw frame data in and out is assumed to be
    Uint8Array's, if needed they will be converted to Uint8Arrays using
    Uint8Array.from(data)
###

exports.VTFImageFormats =
    '-1':
        name: 'NONE'
    0:
        name: 'RGBA8888'
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
    1:
        name: 'ABGR8888'
        total_bits: 32
    2:
        name: 'RGB888'
        total_bits: 24
    3:
        name: 'BGR888'
        total_bits: 24
    4:
        name: 'RGB565'
        total_bits: 16
    5:
        name: 'I8'
        total_bits: 8
    6:
        name: 'IA88'
        total_bits: 16
    7:
        name: 'P8'
        total_bits: 8
    8:
        name: 'A8'
        total_bits: 8
    9:
        name: 'RGB888_BLUESCREEN'
        total_bits: 24
    10:
        name: 'BGR888_BLUESCREEN'
        total_bits: 24
    11:
        name: 'ARGB8888'
        total_bits: 32
    12:
        name: 'BGRA8888'
        total_bits: 32
    13:
        name: 'DXT1'
        total_bits: 4
        decode: ({width, height, data}) ->
            raw_frame = Uint8Array.from(data)
            return dxt.decompress raw_frame,
                width, height,
                dxt.flags.DXT1
        encode: ({width, height, data}) ->
            raw_frame = Uint8Array.from(data)
            return dxt.compress raw_frame,
                width, height,
                dxt.flags.DXT1
    14:
        name: 'DXT3'
        total_bits: 8
        decode: ({width, height, data}) ->
            # data should be a Uint8Array or Buffer, but we'll try converting
            # it to one anyway
            raw_frame = Uint8Array.from(data)
            return dxt.decompress raw_frame,
                width, height,
                dxt.flags.DXT3
        encode: ({width, height, data}) ->
            raw_frame = Uint8Array.from(data)
            return dxt.compress raw_frame,
                width, height,
                dxt.flags.DXT3
    15:
        name: 'DXT5'
        total_bits: 8
        decode: ({width, height, data}) ->
            # data should be a Uint8Array or Buffer, but we'll try converting
            # it to one anyway
            raw_frame = Uint8Array.from(data)
            return dxt.decompress raw_frame,
                width, height,
                dxt.flags.DXT3
        encode: ({width, height, data}) ->
            raw_frame = Uint8Array.from(data)
            return dxt.compress raw_frame,
                width, height,
                dxt.flags.DXT5
    16:
        name: 'BGRX8888'
        total_bits: 32
    17:
        name: 'BGR565'
        total_bits: 16
    18:
        name: 'BGRX5551'
        total_bits: 16
    19:
        name: 'BGRA4444'
        total_bits: 16
    20:
        name: 'DXT1_ONEBITALPHA'
        total_bits: 4
    21:
        name: 'BGRA5551'
        total_bits: 16
    22:
        name: 'UV88'
        total_bits: 16
    23:
        name: 'UVWQ8888'
        total_bits: 32
    24:
        name: 'RGBA16161616F'
        total_bits: 64
    25:
        name: 'RGBA16161616'
        total_bits: 64
    26:
        name: 'UVLX8888'
        total_bits: 32


### All decoders return RBGA8888 data ####
exports.GeneralImageFormats =
    'jpg':
        'decode': (file_data) ->
            return jpg.decode(file_data)
        'encode': ({width, height, data}, quality=100) ->
            return jpg.encode({width, height, data}, quality)

exports.ImageAliasMap =
    ### The right hand side represents the GeneralImageFormats name ###
    'jpeg': 'jpg'


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
