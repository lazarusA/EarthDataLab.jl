module ESDC
import YAXArrays.Datasets: Dataset, Cube, open_dataset
using Zarr: S3Store, zopen
using Dates: Dates, now
export esdc, esdd
global cubesdict


function __init__()
  global cubesdict, cubesdict3
  cubesdict = Dict(
    ("low","ts","global") => ("esdl-esdc-v2.1.1","esdc-8d-0.25deg-184x90x90-2.1.1.zarr"),
    ("low","map","global") => ("esdl-esdc-v2.1.1","esdc-8d-0.25deg-1x720x1440-2.1.1.zarr"),
    ("high","ts","global") => ("esdl-esdc-v2.1.1","esdc-8d-0.083deg-184x270x270-2.1.1.zarr"),
    ("high","map","global") => ("esdl-esdc-v2.1.1","esdc-8d-0.083deg-1x2160x4320-2.1.1.zarr"),
    ("low","ts","Colombia") => ("esdl-esdc-v2.0.1","Cube_2019lowColombiaCube_184x60x60.zarr"),
    ("low","map","Colombia") => ("esdl-esdc-v2.0.1","Cube_2019lowColombiaCube_1x336x276.zarr/"),
    ("high","ts","Colombia") => ("esdl-esdc-v2.0.1","Cube_2019highColombiaCube_184x120x120.zarr"),
    ("high","map","Colombia") => ("esdl-esdc-v2.0.1","Cube_2019highColombiaCube_1x3360x2760.zarr"),
  )
  cubesdict3 = Dict(
    "ts" => "esdc-8d-0.25deg-256x128x128-3.0.2.zarr",
    "map" => "esdc-8d-0.25deg-1x720x1440-3.0.2.zarr",
    "tiny" => "esdc-16d-2.5deg-46x72x1440-3.0.2.zarr",
  )
end

"""
    function esdd(;kwargs...)

Opens a datacube from the AWS as a Dataset. This works on any system, but
might involve some latency depending on connection speed. One can either specify a `bucket`
and `store` or pick a resolution, chunking and cube region.

### Keyword arguments

  * `bucket=nothing` specify an OBS bucket for example "obs-esdc-v2.0.0"
  * `store=""` specify the root path of the cube, for example "esdc-8d-0.25deg-184x90x90-2.0.0.zarr"
  * `res="low"` pick a datacube resolution (`"low"` or `"high"` for v2 or `"low"` or `"tiny"` for v3)
  * `chunks="ts"` choose a chunking (`"ts"` for time series access or `"map"` for spatial analyses)
  * `region="global"` choose a datacube (either `"global"` or `"Colombia"`), works only for esdc v2
  * `version=3`
"""
function esdd(;bucket=nothing, store="", res="low", chunks="ts", region="global", version=3)
  if version == 2
    if bucket===nothing
      bucket, store = cubesdict[(res,chunks,region)]
    end
  elseif version == 3
    if bucket===nothing
      bucket = "esdl-esdc-v3.0.2"
      if res=="tiny"
        store = cubesdict3[res]
      else
        store = cubesdict3[chunks]
      end
    end
  end
  path = "https://s3.bgc-jena.mpg.de:9000/" * bucket * "/" * store
  open_dataset(zopen(path,consolidated=true,fill_as_missing=true))
end

"""
    function esdc(;kwargs...)

Opens a datacube from the AWS as a Dataset. This works on any system, but
might involve some latency depending on connection speed. One can either specify a `bucket`
and `store` or pick a resolution, chunking and cube region.

### Keyword arguments

  * `bucket=nothing` specify an OBS bucket for example "obs-esdc-v2.0.0"
  * `store=""` specify the root path of the cube, for example "esdc-8d-0.25deg-184x90x90-2.0.0.zarr"
  * `res="low"` pick a datacube resolution (`"low"` or `"high"`)
  * `chunks="ts"` choose a chunking (`"ts"` for time series access or `"map"` for spatial analyses)
  * `region="global"` choose a datacube (either `"global"` or `"Colombia"`)

"""
esdc(;kwargs...) = Cube(esdd(;kwargs...),target_type = Union{Float32,Missing})

end # module
