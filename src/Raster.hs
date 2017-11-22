module Raster
  ( Raster
  , Pixel(..)
  , render
  , rasterWith
  , rasterWithUpdate
  , toPixel
  , fromRasterCoord
  , toRasterCoord
  , fromPixel
  , mapColor
  , emptyRaster
  ) where

import Color (Dot, RGBA(..), collapseColor, emptyColor)
import Constants (rasterSize)
import Data.Array.Repa (Array, DIM2, DIM3, Z(..), (:.)(..))
import qualified Data.Array.Repa as R
import qualified Data.Vector as V
import Poly (Point(..))

type Raster = V.Vector RGBA

emptyRaster :: Raster
emptyRaster = V.generate (rasterSize * rasterSize) $ const emptyColor

-- Bitmap is a two dimensional array (stored as unboxed vectors)
-- of 24 bit rgb pixels.
type Bitmap = Array R.U DIM2 Dot

type Layer = Array R.D DIM2 RGBA

data Pixel = Pixel
  { x :: Int
  , y :: Int
  } deriving (Eq, Show)

render :: Raster -> Bitmap
render raster = collapse $ mapColor (color) $ newLayer
  where
    color (Pixel {x, y}) _ = raster V.! (x * rasterSize + y)

rasterWithUpdate :: Raster -> V.Vector ((Int, Int), RGBA) -> Raster
rasterWithUpdate raster updates = V.update raster updates'
  where
    updates' = V.map (\((x, y), color) -> (x * rasterSize + y, color)) updates

rasterWith :: (Double -> Double -> RGBA) -> Raster
rasterWith f = V.generate (rasterSize * rasterSize) f'
  where
    f' i = f x y
      where
        x = fromRasterCoord pixelX
        y = fromRasterCoord pixelY
        pixelX = i `div` rasterSize
        pixelY = i - (pixelX * rasterSize)

-- The vector dimensions are 0-1 within our square frame.
toPixel :: Point -> Pixel
toPixel Point {x, y} = Pixel {x = toRasterCoord x, y = toRasterCoord y}

fromPixel :: Pixel -> Point
fromPixel Pixel {x, y} = Point {x = fromRasterCoord x, y = fromRasterCoord y}

toRasterCoord :: Double -> Int
toRasterCoord coord = floor $ (fromIntegral rasterSize) * coord

fromRasterCoord :: Int -> Double
fromRasterCoord coord = (fromIntegral coord) / (fromIntegral rasterSize)

collapse :: Layer -> Bitmap
collapse layer =
  let [img] = R.computeP $ R.map collapseColor layer
  in img

mapColor :: (Pixel -> RGBA -> RGBA) -> Layer -> Layer
mapColor f layer = R.traverse layer (id) proxy
  where
    proxy indx (Z :. y :. x) = f Pixel {x, y} $ indx (Z :. y :. x)

newLayer :: Layer
newLayer = R.traverse raw packDims packPixel
  where
    packDims (Z :. h :. w :. c) = (Z :. h :. w)
    packPixel indx (Z :. y :. x) =
      RGBA
      { red = indx (Z :. y :. x :. 0)
      , green = indx (Z :. y :. x :. 1)
      , blue = indx (Z :. y :. x :. 2)
      , alpha = indx (Z :. y :. x :. 3)
      }

raw :: Array R.U DIM3 Double
raw =
  R.fromListUnboxed
    (Z :. rasterSize :. rasterSize :. 4)
    (take (rasterSize * rasterSize * 4) (cycle [0]))
