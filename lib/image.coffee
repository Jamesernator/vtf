jpg = require('jpeg-js')
dxt = require('dxt-js')
struct = require('bufferpack')
color = require('onecolor')

formats = require('./formats.coffee')
{ImageFormats, TextureFlags, VTFImageFormats} = 'formats'

## --- CoffeeScript getter and setter -----

Function::get = (prop, get) ->
    Object.defineProperty @prototype, prop, {get, configurable: yes}

Function::set = (prop, set) ->
    Object.defineProperty @prototype, prop, {set, configurable: yes}

## --- Format of a VTF header -----

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

## --- Abstractions -----

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
        ### This returns a size 4 Uint8Array which represents a single pixel ###
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

    @from: ({width, height, data, format}) ->
        ### data must be rgba data of the form of a slice-supporting
            array that
        ###
        format ?= 'RGBA8888'

        unless ImageFormats[format]?.decode?
            throw new Error("No decoder for format: #{format}")
        decoded = ImageFormats[format].decode({width, height, data}).data

        iterator = ->
            for start in [0...width*height*4] by 4
                raw = rgba_data[start...start + 4]
                if format?

        return new Image(width, height, iterator)



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

    @from: ({data: rgba_data, width, height, frames}) ->
        ### Given a block of rgba_data this reads out frames number of
            frames of size width*height
        ###
        console.assert rgba_data.length is width*height*4*frames,
            'rbga_data must be of size width*height*4*frames'
        iterator = ->
            frame_length = width*height*4

            current = 0
            for frame_no in [0...frames]
                yield rbga_data[current...current+frame_length]
                current += frame_length
        return new Frames(width, height, iterator)


class MipMap
    ### A MipMap is an iterator of Frames, all Frames objects must
        have the same length and each frame must have a height and width,
        the iterator must yield frames from smallest to largest
    ###
    constructor: (@width, @height, iterator) ->
        ### width and height are the width and height of the largest mipmap ###
        @[Symbol.iterator] = iterator

    @from: ({data: rgba_data, width, height, frames, mipmaps}) ->
        ### Frames is number of frames per mipmap and mipmaps is number of
            mipmaps
        ###
        iterator = ->
            end = 0
            count = 0
            sizes_iter = @sizes(width, height)
            while count < no_mipmaps
                {value: size, done} = sizes_iter.next()
                start -= size * frames
                if done
                    break
                raw = rgba_data[rgba_data.length+start...rgba_data.length+end]
                yield Frames.from(raw)
                end = start

    @from: (rgba_data, width, height, no_mipmaps=Infinity) ->
        ### Direction is whether mipmaps go from smallest to largest
            or largest to smallest, direction is towards largest,
            if no_mipmaps isn't specified we'll run until we hit
            the final mipmap
        ###
        iterator = ->
            start = - width*height*4 # 4 bytes per pixel
            end = -
            count = 0
            sizes_iter = @sizes(width, height)
            while count < no_mipmaps
                {value: size, done} = sizes_iter.next()
                if done
                    break
                yield rgba_data[start]

    @sizes: (width, height) ->
        ### This yields lengths of rgba_data to read ###
        while width > 0 and height > 0
            yield width*height*4
            width /= 2
            height /= 2


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
