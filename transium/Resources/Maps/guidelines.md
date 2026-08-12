# Maps Resources Guidelines

The `Resources/Maps` subfolder contains 2 pmtiles to be used to render in
MapLibre.

## `bali_basemap.pmtiles`

This file acts as a base layer for our map. It contains these layers:

- `land` : The Bali island shape.
- `kecamatan` : All Kecamatan shapes
- `kelurahan` : All Kelurahan shapes
- `water` : All water feature shapes
- `streams` : All water stream lines
- `vegetation` : All vegetations feature
- `roads` : All roads feature

## `bali_transit.pmtiles`

This file acts as transit network for our map. It contains these layers:

- `bus_stops` : All bus stops points
- `bus_routes` : All bus routes linestring