"use strict"

pfs = require('./promise_fs.coffee')
async = require('./async.coffee')

{Color, Image, Frames,}

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
    yield pfs.writeFile 'test.jpg', jpg.encode(new Squares(512, 512), 100).data
    yield return


root = window ? this
root.dxt = dxt
root.pfs = pfs
root.jpg = jpg
root.Squares = Squares
