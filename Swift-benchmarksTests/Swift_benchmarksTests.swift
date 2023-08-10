//
//  Swift_benchmarksTests.swift
//  Swift-benchmarksTests
//
//  Created by Tom Ebergen on 08/08/2023.
//
import Foundation
import XCTest

import RealmSwift
import DuckDB
import SQLite

@testable import Swift_benchmarks

class RealmTrip : Object {
    @objc var vendor_name           : String = ""
    @objc var passenger_count       : Int = 0
    @objc var trip_distance         : Double = 0
    @objc var pickup_longitude      : Double = 0
    @objc var pickup_latitude       : Double = 0
    @objc var rate_code             : String = ""
    @objc var store_and_fwd         : String = ""
    @objc var dropoff_longitude     : Double = 0
    @objc var dropoff_latitude      : Double = 0
    @objc var payment_type          : String = ""
    @objc var fare_amount           : Double = 0
    @objc var extra                 : Double = 0
    @objc var mta_tax               : Double = 0
    @objc var tip_amount            : Double = 0
    @objc var tolls_amount          : Double = 0
    @objc var total_amount          : Double = 0
    @objc var improvement_surcharge : Double = 0
    @objc var congestion_surcharge  : Double = 0
    @objc var pickup_location_id    : Int = 0
    @objc var dropoff_location_id   : Int = 0
    @objc var year                  : String = ""
    @objc var month                 : String = ""
}

class Swift_benchmarksTests: XCTestCase {
    
    func GetTaxiFileName() -> String {
        return "/Users/tomebergen/Swift-benchmarks/taxi-one-month-subset.csv"
    }
    
    func readCSV(inputFile: String, separator: String) -> [String] {
         // split the filename
        do {
            let content = try String(contentsOfFile: inputFile)
            let parsedCSV: [String] = content.components(separatedBy: "\n")
            return parsedCSV
        }
        catch {
            return []
        }
    }
    
    override func setUpWithError() throws {
        // do nothing
    }
    
    func loadRealmData() throws -> [RealmTrip] {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        var parsed_data : [RealmTrip] = []
        let all_data = readCSV(inputFile: GetTaxiFileName(), separator: ",")
        for row in all_data {
            var trip = RealmTrip()
            let parsed_row = row.components(separatedBy: ",")
            if (parsed_row.count < 24) {
                // empty row probably
                break
            }
            trip.vendor_name           = String(parsed_row[0])
//            trip.pickup_datetime       = Time.init(Date(parsed_row[1]))
//            trip.dropoff_datetime      = Time.init(Date(parsed_row[2]))
            trip.passenger_count       = Int(parsed_row[3]) ?? 0
            trip.trip_distance         = Double(parsed_row[4]) ?? 0
            trip.pickup_longitude      = Double(parsed_row[5]) ?? 0
            trip.pickup_latitude       = Double(parsed_row[6]) ?? 0
            trip.rate_code             = String(parsed_row[7])
            trip.store_and_fwd         = String(parsed_row[8])
            trip.dropoff_longitude     = Double(parsed_row[9]) ?? 0
            trip.dropoff_latitude      = Double(parsed_row[10]) ?? 0
            trip.payment_type          = String(parsed_row[11])
            trip.fare_amount           = Double(parsed_row[12]) ?? 0
            trip.extra                 = Double(parsed_row[13]) ?? 0
            trip.mta_tax               = Double(parsed_row[14]) ?? 0
            trip.tip_amount            = Double(parsed_row[15]) ?? 0
            trip.tolls_amount          = Double(parsed_row[16]) ?? 0
            trip.total_amount          = Double(parsed_row[17]) ?? 0
            trip.improvement_surcharge = Double(parsed_row[18]) ?? 0
            trip.congestion_surcharge  = Double(parsed_row[19]) ?? 0
            trip.pickup_location_id    = Int(parsed_row[20]) ?? 0
            trip.dropoff_location_id   = Int(parsed_row[21]) ?? 0
            trip.year                  = String(parsed_row[22])
            trip.month                 = String(parsed_row[23])
            parsed_data.append(trip)
        }
        
        // Setup Realm - Delete all previously used instances
        let realm_filename = "realm-benchmark"
        var config = Realm.Configuration.defaultConfiguration
        config.deleteRealmIfMigrationNeeded = true
        config.fileURL!.deleteLastPathComponent()
        config.fileURL!.appendPathComponent(realm_filename)
        config.fileURL!.appendPathExtension("realm")
        var realm_connection = try! Realm(configuration: config)
        
        if let realm_path_url = config.fileURL {
            print("saving realm config at " + realm_path_url.absoluteString)
        }
        
        // Delete the objects currenlty in the realm db
        let allTrips = realm_connection.objects(RealmTrip.self)
        try! realm_connection.write {
            realm_connection.delete(allTrips)
        }
        
        return parsed_data
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
    }

    // test how fast
    func testRealmImport() throws {
        // Measure performance of reading the csv in swift
        // loading it into a realm db
        // then deleting it from the same realm db
        self.measure {
            let realm_filename = "realm-benchmark"
            var config = Realm.Configuration.defaultConfiguration
            config.deleteRealmIfMigrationNeeded = true
            config.fileURL!.deleteLastPathComponent()
            config.fileURL!.appendPathComponent(realm_filename)
            config.fileURL!.appendPathExtension("realm")
            
            do {
                var parsed_data = try loadRealmData()
                // add the objects
                let realm_connection = try! Realm(configuration: config)
                try realm_connection.write {
                    realm_connection.add(parsed_data)
                }
                // delete the objects as well
                let allTrips = realm_connection.objects(RealmTrip.self)
                if (allTrips.count != parsed_data.count) {
                    print("FAILURE")
                    exit(1)
                }
                try! realm_connection.write {
                    realm_connection.delete(allTrips)
                }
            }
            catch {
                print("realm error \(error)")
                exit(1)
            }
        }
    }
    
}


extension Swift_benchmarksTests {
    func testDuckDBImport() throws {
        // Measure performance of inserting all parsed data into Realm database
        print("starting duckdb test")
        self.measure {
            // measure performance of reading a csv into a duckdb instance
            // and dropping all the records.
            do {
                let database = try Database(store: .inMemory)
                let connection = try database.connect()
                
                try connection.execute("Create Table trips as (select * from read_csv_auto('\(GetTaxiFileName())'))")
                // check amount
                let result = try connection.query("""
                  Select * from trips;
                """)
                
                let _ = result[0].cast(to: String.self) // vendor_name
                let _ = result[3].cast(to: Int.self) // passenger_count
                let _ = result[4].cast(to: Double.self) // trip_distance
                let _ = result[5].cast(to: String.self) // pickup_longitude
                let _ = result[6].cast(to: String.self) // pickup_latitude
                let _ = result[7].cast(to: String.self) // rate_code
                let _ = result[8].cast(to: String.self) // store_and_fwd
                let _ = result[9].cast(to: String.self) // dropoff_longitude
                let _ = result[10].cast(to: String.self) // dropoff_latitude
                let _ = result[11].cast(to: String.self) // payment_type
                let _ = result[12].cast(to: Double.self) // fare_amount
                let _ = result[13].cast(to: Double.self) // extra
                let _ = result[14].cast(to: Double.self) // mta_tax
                let _ = result[15].cast(to: Double.self) // tip_amount
                let _ = result[16].cast(to: Double.self) // tolls_amount
                let _ = result[17].cast(to: Double.self) // total_amount
                let _ = result[18].cast(to: Double.self) // improvement_surcharge
                let _ = result[19].cast(to: Double.self) // congestion_surcharge
                let _ = result[20].cast(to: Int.self) // pickup_location_id
                let _ = result[21].cast(to: Int.self) // dropoff_location_id
                let _ = result[22].cast(to: Int.self) // year
                let _ = result[23].cast(to: Int.self) // month
                
                if (result.rowCount != 50000) {
                    print("error during DUCKDB importing. Counts don't match")
                }
                try connection.execute("drop table trips;")
            } catch {
                print("duckdb error \(error)")
                exit(1)
            }
        }
    }
}


extension Swift_benchmarksTests {
    
    func testSQLiteImport() throws {
        // Measure performance of inserting all parsed data into Realm database
        self.measure {
            print("starting sqlite test")
            // measure performance of reading a csv into a duckdb instance
            // and dropping all the records.
            do {
                let database = try Connection("/Users/tomebergen/Swift-benchmarks/trips.sqlite3")
                let trips = Table("Trips")
                
                let vendor_name = Expression<String>("vendor_name")
                let passenger_count = Expression<Int>("passenger_count")
                let trip_distance = Expression<Double>("trip_distance")
                let pickup_longitude = Expression<Double>("pickup_longitude")
                let pickup_latitude = Expression<Double>("pickup_latitude")
                let rate_code = Expression<String>("rate_code")
                let store_and_fwd = Expression<String>("store_and_fwd")
                let dropoff_longitude = Expression<Double>("dropoff_longitude")
                let dropoff_latitude = Expression<Double>("dropoff_latitude")
                let payment_type = Expression<String>("payment_type")
                let fare_amount = Expression<Double>("fare_amount")
                let extra = Expression<Double>("extra")
                let mta_tax = Expression<Double>("mta_tax")
                let tip_amount = Expression<Double>("tip_amount")
                let tolls_amount = Expression<Double>("tolls_amount")
                let total_amount = Expression<Double>("total_amount")
                let improvement_surcharge = Expression<Double>("improvement_surcharge")
                let congestion_surcharge = Expression<Double>("congestion_surcharge")
                let pickup_location_id = Expression<Int>("pickup_location_id")
                let dropoff_location_id = Expression<Int>("dropoff_location_id")
                let year = Expression<Int>("year")
                let month = Expression<Int>("month")
                
                try database.run(trips.create { trip in
                    trip.column(vendor_name)
                    trip.column(passenger_count)
                    trip.column(trip_distance)
                    trip.column(pickup_longitude)
                    trip.column(pickup_latitude)
                    trip.column(rate_code)
                    trip.column(store_and_fwd)
                    trip.column(dropoff_longitude)
                    trip.column(dropoff_latitude)
                    trip.column(payment_type)
                    trip.column(fare_amount)
                    trip.column(extra)
                    trip.column(mta_tax)
                    trip.column(tip_amount)
                    trip.column(tolls_amount)
                    trip.column(total_amount)
                    trip.column(improvement_surcharge)
                    trip.column(congestion_surcharge)
                    trip.column(pickup_location_id)
                    trip.column(dropoff_location_id)
                    trip.column(year)
                    trip.column(month)
                })
                
                let all_data = readCSV(inputFile: GetTaxiFileName(), separator: ",")
                let start = DispatchTime.now()
                for row in all_data {
                    let parsed_row = row.components(separatedBy: ",")
                    if (parsed_row.count < 24) {
                        // empty row probably
                        break
                    }
                    let insert = trips.insert(
                        vendor_name           <- String(parsed_row[0]),
                        // pickup_datetime       <- Time.init(Date(parsed_row[1])),
                        // dropoff_datetime      <- Time.init(Date(parsed_row[2])),
                        passenger_count       <- Int(parsed_row[3]) ?? 0,
                        trip_distance         <- Double(parsed_row[4]) ?? 0,
                        pickup_longitude      <- Double(parsed_row[5]) ?? 0,
                        pickup_latitude       <- Double(parsed_row[6]) ?? 0,
                        rate_code             <- String(parsed_row[7]),
                        store_and_fwd         <- String(parsed_row[8]),
                        dropoff_longitude     <- Double(parsed_row[9]) ?? 0,
                        dropoff_latitude      <- Double(parsed_row[10]) ?? 0,
                        payment_type          <- String(parsed_row[11]),
                        fare_amount           <- Double(parsed_row[12]) ?? 0,
                        extra                 <- Double(parsed_row[13]) ?? 0,
                        mta_tax               <- Double(parsed_row[14]) ?? 0,
                        tip_amount            <- Double(parsed_row[15]) ?? 0,
                        tolls_amount          <- Double(parsed_row[16]) ?? 0,
                        total_amount          <- Double(parsed_row[17]) ?? 0,
                        improvement_surcharge <- Double(parsed_row[18]) ?? 0,
                        congestion_surcharge  <- Double(parsed_row[19]) ?? 0,
                        pickup_location_id    <- Int(parsed_row[20]) ?? 0,
                        dropoff_location_id   <- Int(parsed_row[21]) ?? 0,
                        year                  <- Int(parsed_row[22]) ?? 0,
                        month                 <- Int(parsed_row[23]) ?? 0
                    )
                    try database.run(insert)
                }
                let end = DispatchTime.now()
                let nanoTime = end.uptimeNanoseconds - start.uptimeNanoseconds
                let timeInterval = Double(nanoTime) / 1_000_000_000
                print("time to insert all records = \(timeInterval)")
                // check the count
                if (try database.scalar(trips.count) != 50000) {
                    print("error during sqlite3 ingestion")
                }
                // drop the table
                let drop = trips.drop(ifExists: true)
                try database.run(drop)
                print("done sqllite test")
            } catch {
                print("duckdb error \(error)")
                exit(1)
            }
        }
    }
}
