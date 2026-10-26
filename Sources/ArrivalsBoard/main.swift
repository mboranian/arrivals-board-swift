// The Swift Programming Language
// https://docs.swift.org/swift-book
import Foundation
import TabularData
import ArrivalsCore

/*############Parse the local GTFS data for use throughout###########################################################################*/
let stopsURL: URL = URL(fileURLWithPath: "bart-gtfs/stops.txt")
let stops: DataFrame = try loadStops(url: stopsURL)

let tripsURL: URL = URL(fileURLWithPath: "bart-gtfs/trips.txt")
let headsignDict = try loadHeadsigns(url: tripsURL)

/*############Coordinates Constant to for testing. Make live later###########################*/
let currCoords: (lon: Double, lat: Double) = (lon: -122.40645430093018, lat: 37.66203119672221)

//TODO: Add loop
let board: StationBoard = try await getDepartures(headsigns: headsignDict, stops: stops, coords: currCoords)

printStationBoard(board: board)
