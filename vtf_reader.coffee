"use strict"

fs = require('fs')
jpg = require('jpeg-js')
dxt = require('dxt-js')
async = require('./async.coffee')
struct = require('bufferpack')
{VTFImageFormats, TextureFlags} = require('./formats.coffee')

VTF_HEADER_FORMAT = "<4s(signature)
                     I(version1)
                     I(version2)
                     I(headerSize)
                     H(width)
                     H(height)
                     I(flags)
                     H(frames)
                     H(firstFrame)
                     B(p0)B(p1)B(p2)B(p3)
                     f(reflectivity1)f(reflectivity2)f(reflectivity3)
                     B(p4)B(p5)B(p6)B(p7)
                     f(bumpmapScale)
                     I(highResImageFormat)
                     B(mipmapCount)
                     I(lowResImageFormat)
                     B(lowResImageWidth)
                     B(lowResImageHeight)
                     H(depth)
                    "

##----- Promise based file functions -------------------

read_file = (path, encoding=null) ->
    return new Promise (resolve, reject) ->
        fs.readFile path, encoding, (err, data) ->
            if err?
                reject(err)
            else
                resolve(data)

write_file = (path, data, opts=null) ->
    return new Promise (resolve, reject) ->
        fs.writeFile path, data, opts, (err) ->
            if err?
                reject()
            else
                resolve()

file_exists = (path) ->
    return new Promise (resolve, reject) ->
        fs.exists path, (result) ->
            resolve(result)

read_dir = (path) ->
    return new Promise (resolve, reject) ->
        fs.readdir path, (err, files) ->
            if err?
                reject(err)
            else
                resolve(files)

class Frame
    constructor: (raw_rgba) ->

    @from: (format, raw_image_buffer) ->


class Frames
    constructor: (@frames) ->
        ### frames should be an iterable (NOT an iterator) ###

    to_packed: ()



class VTFFile
    constructor: (@header, @mipmaps, @low_res_image_data, @other_data=null) ->


    @from: (raw_data) ->
        header = @get_header(raw_data)
        mipmaps = @get_frames(header, raw_data)
        low_res_image_data = @get_low_res_image_data(header, raw_data)

        front_bytes = header.headerSize + low_res_image_data.length


    @get_header: (vpk_data) ->
        ### This reads a vtf header and returns the fields ###
        raw = struct.unpack(VTF_HEADER_FORMAT, vpk_data)
        result =
            signature: raw.signature
            version: [raw.version1, raw.version2].join('.')
            headerSize: raw.headerSize
            width: raw.width
            height: raw.height
            flags: raw.flags
            frames: raw.frames
            firstFrame: raw.firstFrame
            padding1: [raw.p0, raw.p1, raw.p2, raw.p3]
            reflectivity: [
                raw.reflectivity1
                raw.reflectivity2
                raw.reflectivity3
            ]
            padding2: [raw.p4, raw.p5, raw.p6, raw.p7]
            bumpmapScale: raw.bumpmapScale
            highResImageFormat: raw.highResImageFormat
            mipmapCount: raw.mipmapCount
            lowResImageFormat: raw.lowResImageFormat
            lowResImageWidth: raw.lowResImageWidth
            lowResImageHiehgt: raw.lowResImageHeight
            depth: raw.depth
        return result

    @get_mipmaps: (header, raw_data) ->
        ### Creates an iterator of frames from the raw_data ###
        end = raw_data.length
        for frame_size in Array.from(@sizes(header))
            start = end - frame_size
            yield raw_data[start...end]
            end = start

    @sizes: (header) ->
        ### This yields a series of byte sizes given the initial size and
            number of mipmaps
            NOTE: reads 1 byte for DXT1 and DXT1_ONEBITALPHA modes instead of
            zero
        ###
        {height, width} = header

        format = VTFImageFormats[header.highResImageFormat]
        bytes_per_pixel = format.total_bits / 8
        for i in [0...header.mipmapCount]
            bytes = (width / (2**i)) * (height / (2**i)) * bytes_per_pixel
            if 0 < bytes < 1
                yield 1 # Special case when there is a 1x1 image with
                        # DXT1 or DXT1_ONEBITALPHA
            else
                yield bytes

    boundaries: (width, height, mipmap_no) ->
        ### Returns an offset from the end of the raw_data for where a given
            mipmap is located given the largest mipmap is of size width x height
        ###
        offset_start = width*height
        offset_end = 0

        if mipmap_no is 0
            return [offset_start, offset_end]

        for _no in [1..mipmap_no]
            width = width/2
            height = height/2
            offset_end = offset_start
            offset_start = offset_end + width * height
        return [offset_start, offset_end]

    frames: ->
        ### Yields a series of frames from the VTF raw_data ###
        for mipmap_no in [0...@header.mipmapCount]
            width = @header.width/(2**mipmap_no)
            height = @header.width/(2**mipmap_no)

            [offset_start, offset_end] = @boundaries(
                @header.width,
                @header.height,
                mipmap_no
            )

            start = @raw_data.length - offset_start
            end = @raw_data.length - offset_end
            raw_frame = @raw_data[start...end]

            data = dxt.decompress raw_frame,
                width, height,
                dxt.flags.DXT5

            yield {
                width
                height
                data
            }



async.main ->
    data = yield read_file('c_drg_cowmangler.vtf')
    VTFFile.from(data)
    ###
    raw_img = dxt.decompress data[data.length-start...data.length-end],
        real_size, real_size,
        dxt.flags.DXT5
    jpeg_raw =
        data: raw_img
        width: real_size
        height: real_size
    yield write_file('test.jpg', jpg.encode(jpeg_raw, 100).data)
    #console.log data[80...235].toString('ascii')
    ###

window = this

window.fs = fs
window.dxt = dxt
