module CubeIO
importall ..Cubes
importall ..DAT
importall ..CubeAPI
importall ..CubeAPI.CachedArrays
importall ..Proc
importall ..Mask
import DataArrays: isna
import DataArrays
exportmissval(x::AbstractFloat)=oftype(x,NaN)
exportmissval(x::Integer)=typemax(x)

function copyMAP(xout::AbstractArray,maskout::AbstractArray{UInt8},xin::AbstractArray,maskin::AbstractArray{UInt8})
    #Start loop through all other variables
    for (iout,vin,min) in zip(eachindex(xout),xin,maskin)
      if (x>UInt8(0)) || (x & FILLED)==FILLED
        xout[iout]=vin
      else
        xout[iout]=exportmissval(vin)
      end
      maskout[iout]=min
    end
end

import NetCDF.ncread, NetCDF.ncclose
import StatsBase.Weights
import StatsBase.sample
#function readLandSea(c::Cube)
#    m=ncread(joinpath(c.base_dir,"mask","mask.nc"),"mask")
#    scale!(m,OCEAN)
#    a1=LonAxis((c.config.grid_x0:(c.config.grid_width-1))*c.config.spatial_res+c.config.spatial_res/2-180.0)
#    a2=LatAxis(90.0-(c.config.grid_y0:(c.config.grid_height-1))*c.config.spatial_res-c.config.spatial_res/2)
#    ncclose(joinpath(c.base_dir,"mask","mask.nc"))
#    CubeMem(CubeAxis[a1,a2],m,m);
#end


function getSpatiaPointAxis(mask::CubeMem)
    a=Tuple{Float64,Float64}[]
    ax=axes(mask)
    ocval=OCEAN
    for (ilat,lat) in enumerate(ax[2].values)
        for (ilon,lon) in enumerate(ax[1].values)
            if (mask.mask[ilon,ilat] & ocval) != ocval
                push!(a,(lon,lat))
            end
        end
    end
    SpatialPointAxis(a)
end

function toPointAxis(aout,ain,loninds,latinds,pointax)
  xout, maskout = aout
  xin , maskin  = ain
  iout = 1
  for (ilon,ilat) in zip(loninds,latinds)
    xout[iout]=xin[ilon,ilat]
    maskout[iout]=maskin[ilon,ilat]
    iout+=1
  end
end
export toPointAxis
registerDATFunction(toPointAxis,(LonAxis,LatAxis),((cube,pargs)->pargs[3],),inmissing=:mask,outmissing=:mask)

"""
    extractLonLats(c::AbstractCubeData,pl::Matrix)

Extracts a list of longitude/latitude coordinates from a data cube. The coordinates
are specified through the matrix `pl` where `size(pl)==(N,2)` and N is the number
of extracted coordinates. Returns a data cube without `LonAxis` and `LatAxis` but with a
`SpatialPointAxis` containing the input locations.
"""
function extractLonLats(c::AbstractCubeData,pl::Matrix)
  size(pl,2)==2 || error("Coordinate list must have exactly 2 columns")
  axlist=axes(c)
  ilon=findAxis(LonAxis,axlist)
  ilat=findAxis(LatAxis,axlist)
  ilon>0 || error("Input cube must contain a LonAxis")
  ilat>0 || error("input cube must contain a LonAxis")
  lonax=axlist[ilon]
  latax=axlist[ilat]
  pointax = SpatialPointAxis([(pl[i,1],pl[i,2]) for i in 1:size(pl,1)])
  loninds = map(ll->axVal2Index(lonax,ll[1]),pointax.values)
  latinds = map(ll->axVal2Index(latax,ll[2]),pointax.values)
  y=mapCube(toPointAxis,c,loninds,latinds,pointax,max_cache=1e8)
end
export extractLonLats

"""
    sampleLandPoints(cube, nsample;nomissing=false)

Get an area-weighted sample from all non-ocean grid cells. This will return a new Cube
where the `LonAxis` and `LatAxis` are condensed into a single `SpatialPointAxis` of
length `nsample`. If `nomissing=true` only grid cells will be selected which don't contain any missing values.
This makes sense for gap-filled cubes to make sure that grid cells with systematic seasonal gaps are not selected
in the sample.
"""
function sampleLandPoints(cdata::CubeAPI.AbstractCubeData,nsample::Integer,nomissing=false)
  axlist=axes(cdata)
  ilon=findAxis(LonAxis,axlist)
  ilat=findAxis(LatAxis,axlist)
  if nomissing
    remAxes=filter(i->!(isa(i,LonAxis) || isa(i,LatAxis)),axlist)
    cm=reduceCube(i->any(ismissing,i),cdata,ntuple(i->typeof(remAxes[i]),length(remAxes)),outtype=(Bool,))
    m=map(i->(i ? OCEAN : VALID),cm.data)
    cm=CubeMem(CubeAxis[axlist[ilon],axlist[ilat]],m,m)
  else
    bs=ntuple(i->in(i,(ilon,ilat)) ? length(axlist[i]) : 1,length(axlist))
    sargs=ntuple(i->ifelse(in(i,(ilon,ilat)),1:length(axlist[i]),1),length(axlist))
    mh=getMemHandle(cdata,1,CartesianIndex(bs))
    a,m=getSubRange(mh,sargs...)
    m=copy(m)
    cm=CubeMem(CubeAxis[axlist[ilon],axlist[ilat]],m,m)
  end
  sax=getSpatiaPointAxis(cm);
  isempty(sax.values) && error("Could not find any valid coordinates to extract a sample from. Please check for systematic missing values if you set nomissing=true")
  w=Weights(map(i->cosd(i[2]),sax.values))
  sax2=SpatialPointAxis(sample(sax.values,w,nsample,replace=false))
  y=mapCube(toPointAxis,(cdata,axlist[ilon],axlist[ilat],sax2),max_cache=1e8);
end
export sampleLandPoints
end