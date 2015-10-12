"use strict"

fs = require('fs')
jpg = require('jpeg-js')
dxt = require('dxt-js')
struct = require('bufferpack')
color = require('onecolor')

async = require('./async.coffee')
formats = require('./formats.coffee')

Function::get = (prop, get) ->
    Object.defineProperty @prototype, prop, {get, configurable: yes}

Function::set = (prop, set) ->
    Object.defineProperty @prototype, prop, {set, configurable: yes}

{VTFImageFormats, TextureFlags, GeneralImageFormats} = 'formats'

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

class Color
    ### This is a wrapper around the onecolor library exposing just one
        method toRGBA which gives a Uint8Array of 4 bytes
    ###
    @RGBA_ARRAY = [
        new Color([255, 0, 0, 255])
        new Color([0, 255, 0, 255])
        new Color([0, 0, 255, 255])
        new Color([0, 0, 0, 0])
    ]
    constructor: (data) ->
        @color = new color(data)

    toRGBA: ->
        vals = @color.toJSON()[1...].map (val) -> val*255
        return new Uint8Array(vals)


class Image
    ### An image is an iterator of pixels and additionally has
        a width and height, a pixel is a Uint8Array with 4 values:
        Uint8Array[red, green, blue, alpha]
    ###
    constructor: (@width, @height, iterator) ->
        @[Symbol.iterator] = iterator

    @get 'data', ->
        data = new Uint8Array(@width*@height*4)
        pixel_iterator = @[Symbol.iterator]()

        index = 0
        while true
            {value: pixel, done} = pixel_iterator.next()
            if done
                break
            data.set(pixel, index)
            index += 4
        return data

    @from: ({width, height, data: rgba_data}) ->
        ### data must be rgba data of the form of a slice-supporting
            array that
        ###
        iterator = ->
            for start in [0...width*height*4] by 4
                yield rgba_data[start...start + 4]
        return new Image(width, height, iterator)


class Squares extends Image
    constructor: (@width, @height, colors=Color.RGBA_ARRAY) ->
        @[Symbol.iterator] = ->
            array = new Uint8Array(@width*@height*4) # 4 colors per pixel
            for _ in [0...@height/2]
                yield from @row(colors[0...2])
            for _ in [0...@height/2]
                yield from @row(colors[2...4])

    row: (colors) ->
        for _ in [0...@width/2]
            yield colors[0].toRGBA()
        for _ in [0...@width/2]
            yield colors[1].toRGBA()


class Frames
    ### Frames is an iterable of Images with a consistent width and height ###
    constructor: (@width, @height, iterator) ->
        @[Symbol.iterator] = iterator

    @get 'data', ->
        ### This is the binary packed pixel data of the Frames ###
        result = new Uint8Array(frames.length*@width*@height*4)

        frames = Array.from this

        current = 0
        for frame in frames
            result.set frame.data, current
            current += frame.data.length
        return result

    @get 'length', ->
        ### This is the number of frames ###
        return Array.from(this).length

    @from: (frames_list) ->
        ### Given a list of frames this creates a frame object
        ###
        width = frames_list[0].width
        height = frames_list[1].height
        frames_equal = frames_list.every (frame) ->
            frame.width is width and frame.height is height
        unless frames_equal
            throw new Error('Frames not same size')
        iterator = ->
            for frame in frames_list
                yield frame
        return new Frames width, height, iterator


class VTFFile
    constructor: (@header, @mipmaps, @low_res_image_data, @other_data=null) ->

    @from: (raw_data) ->
        header = @get_header(raw_data)
        mipmaps = @get_frames(header, raw_data)
        low_res_image_data = @get_low_res_image_data(header, raw_data)

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



async.main ->
    #data = yield read_file('c_drg_cowmangler.vtf')
    #VTFFile.from(data)
    #raw_img = dxt.decompress data[data.length-start...data.length-end],
    #    real_size, real_size,
    #    dxt.flags.DXT5
    #jpeg_raw =
    #    data: raw_img
    #    width: real_size
    #    height: real_size
    #console.log jpeg_raw

    #yield write_file('test.jpg', jpg.encode(jpeg_raw, 100).data)
    yield write_file 'test.jpg', jpg.encode(new Squares(512, 512)).data
    yield return

window = this

window.fs = fs
window.dxt = dxt
