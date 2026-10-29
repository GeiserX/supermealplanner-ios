//  The shapes, read from the answers the server actually sends.
//
//  The payloads here are copied from `GET /api/v1/...` against the test household, trimmed. A field
//  the server adds later must not break decoding, and a field it has always sent must land.

import XCTest

final class ModelTests: XCTestCase {
    private func decode<T: Decodable>(_ json: String, as type: T.Type = T.self) throws -> T {
        try JSONDecoder().decode(T.self, from: Data(json.utf8))
    }

    func testADayCarriesTheMealsInOrderWithEachPersonsPlate() throws {
        let day: Day = try decode("""
        {"day":"2026-10-20","today":"2026-10-20","paused":false,"planned":true,
         "meals":[{"meal":"lunch","dishes":[{"recipe":{"id":"lentils","name":"Lentils","kind":"batch",
           "minutes":45,"tags":["legume"],"protein":"legume","video":null},
           "plates":[{"person":"ana","name":"Ana","recipe":{"id":"lentils","name":"Lentils","tags":[]},
             "factor":1.1,"lines":["220 g lentils"],"kcal":610,"protein_g":31.5}]}]}],
         "people":[{"person":"ana","name":"Ana","kcal_target":1800,"kcal":1750,"protein_target":110.0,
           "protein_g":104.2,"factor":1.1,"toppers":["yoghurt"],"days_since_injection":3}],
         "defrost_for_tomorrow":[{"id":"stew","name":"Stew","tags":[]}],
         "votes":{"lentils":1},"person":"ana"}
        """)
        XCTAssertEqual(day.meals.first?.meal, "lunch")
        XCTAssertEqual(day.meals.first?.dishes.first?.plates.first?.lines, ["220 g lentils"])
        XCTAssertEqual(day.meals.first?.dishes.first?.plates.first?.proteinG, 31.5)
        XCTAssertEqual(day.people.first?.kcalTarget, 1800)
        XCTAssertEqual(day.people.first?.daysSinceInjection, 3)
        XCTAssertEqual(day.defrostForTomorrow.first?.name, "Stew")
        XCTAssertEqual(day.votes["lentils"], 1)
    }

    func testADishSharedByMoreThanOnePersonShowsTheTotalForEveryoneTogether() throws {
        let day: Day = try decode("""
        {"day":"2026-10-20","meals":[{"meal":"lunch","dishes":[
          {"recipe":{"id":"soup","name":"Soup","tags":[]},
           "plates":[{"person":"ana","name":"Ana","factor":1.0,"lines":["200 g leeks (≈ 1 leek)"]},
                     {"person":"ben","name":"Ben","factor":1.5,"lines":["300 g leeks (≈ 1.5 leeks)"]}],
           "total":{"recipe":{"id":"soup","name":"Soup","tags":[]},"factor":2.5,
             "lines":["500 g leeks (≈ 2.5 leeks)"],"kcal":900,"protein_g":40.0}},
          {"recipe":{"id":"bread","name":"Bread","tags":[]},
           "plates":[{"person":"ana","name":"Ana","factor":1.0,"lines":["50 g bread"]}],
           "total":{"factor":1.0,"lines":["50 g bread"]}},
          {"recipe":{"id":"fruit","name":"Fruit","tags":[]},"plates":[]}]}]}
        """)
        let dishes = try XCTUnwrap(day.meals.first?.dishes)
        XCTAssertEqual(dishes[0].together?.lines, ["500 g leeks (≈ 2.5 leeks)"])
        XCTAssertEqual(dishes[0].together?.factor, 2.5)
        XCTAssertNil(dishes[1].together, "one person alone needs no total")
        XCTAssertNil(dishes[2].together, "an older server without the total still decodes")

        let recipe: RecipeFull = try decode("""
        {"recipe":{"id":"soup","name":"Soup"},"plate":{"factor":1.0,"lines":["200 g leeks"]},
         "plates":[{"person":"ana","name":"Ana","factor":1.0,"lines":["200 g leeks"]},
                   {"person":"ben","name":"Ben","factor":1.5,"lines":["300 g leeks"]}],
         "total":{"factor":2.5,"lines":["500 g leeks (≈ 2.5 leeks)"],"kcal":900,"protein_g":40.0}}
        """)
        XCTAssertEqual(recipe.together?.lines, ["500 g leeks (≈ 2.5 leeks)"])
        XCTAssertEqual(recipe.plates.map(\.person), ["ana", "ben"])
    }

    func testOnlyTheMealOfTheMomentStartsUnfoldedUntilOneIsFoldedByHand() throws {
        let day: Day = try decode("""
        {"day":"2026-10-20","now":"13:05","meals":[
          {"meal":"breakfast","hours":{"from":"00:00","until":"12:00"},"open":false,"dishes":[]},
          {"meal":"lunch","hours":{"from":"12:00","until":"16:00"},"open":true,"dishes":[]},
          {"meal":"dinner","dishes":[]}]}
        """)
        let breakfast = day.meals[0], lunch = day.meals[1], dinner = day.meals[2]
        XCTAssertEqual(lunch.open, true)
        XCTAssertFalse(breakfast.isUnfolded([:]))
        XCTAssertTrue(lunch.isUnfolded([:]))
        // A server without `open` folds nothing away.
        XCTAssertTrue(dinner.isUnfolded([:]))

        let folds = ["breakfast": true, "lunch": false]
        XCTAssertTrue(breakfast.isUnfolded(folds))
        XCTAssertFalse(lunch.isUnfolded(folds))
    }

    func testAFieldThisVersionDoesNotKnowIsIgnored() throws {
        // The contract is that fields are added inside api 1. An app in a pocket must survive that.
        let day: Day = try decode("""
        {"day":"2026-10-20","planned":true,"meals":[],"people":[],
         "something_new":{"nested":[1,2,3]},"votes":{}}
        """)
        XCTAssertEqual(day.day, "2026-10-20")
    }

    func testAnOlderServerThatOmitsAFieldStillDecodes() throws {
        let day: Day = try decode(#"{"day":"2026-10-20"}"#)
        XCTAssertFalse(day.planned)
        XCTAssertTrue(day.meals.isEmpty)
    }

    func testTheShoppingListKeepsItsSectionsAndTicks() throws {
        let list: Shopping = try decode("""
        {"monday":"2026-10-19","view":"mercadona","views":[{"id":"mercadona","label":"Mercadona"}],
         "labels":{"veg":"Fruit and veg"},
         "stores":[{"id":"mercadona","name":"Mercadona","total":42.17,"unpriced":1,
           "sections":[{"section":"veg","lines":[{"ingredient":"onion","name":"Onion","section":"veg",
             "amount":"3 ud","qty":3.0,"unit":"ud","product":"Cebolla","packs":1,"price":1.2}]}]}],
         "ticked":["onion"],"have":["salt"],"stocked":["rice"]}
        """)
        XCTAssertEqual(list.stores.first?.sections.first?.lines.first?.name, "Onion")
        XCTAssertEqual(list.labels["veg"], "Fruit and veg")
        XCTAssertEqual(list.ticked, ["onion"])
        XCTAssertEqual(list.have, ["salt"])
        XCTAssertEqual(list.stocked, ["rice"])
        // A server older than the pantry sends no `stocked`.
        let older: Shopping = try decode(#"{"monday":"2026-10-19"}"#)
        XCTAssertTrue(older.stocked.isEmpty)
    }

    func testThePantryCarriesAmountsAndWhenFreshFoodGoesOff() throws {
        let pantry: Pantry = try decode("""
        {"day":"2026-10-28",
         "items":[{"ingredient":"hake","name":"Hake","qty":600.0,"unit":"g","amount":"600 g",
                   "since":"2026-10-26","expires":"2026-10-29"},
                  {"ingredient":"rice","name":"Rice","qty":1000.0,"unit":"g","amount":"1 kg",
                   "since":"2026-10-20","expires":null}],
         "have":[{"ingredient":"salt","name":"Salt"}]}
        """)
        XCTAssertEqual(pantry.items.map(\.name), ["Hake", "Rice"])
        XCTAssertEqual(pantry.items[0].expires, "2026-10-29")
        XCTAssertEqual(pantry.items[0].amount, "600 g")
        XCTAssertNil(pantry.items[1].expires, "food that keeps until it is used up has no date")
        XCTAssertEqual(pantry.have.map(\.ingredient), ["salt"])
        XCTAssertThrowsError(try decode(#"{"items":[{"ingredient":"rice","name":"Rice","qty":"lots"}]}"#,
                                        as: Pantry.self), "a field of the wrong type still throws")
    }

    func testASectionKeepsWhatIsLeftToBuyOnTopAndTheBasketBelowInTickOrder() throws {
        let list: Shopping = try decode("""
        {"monday":"2026-10-19","stores":[{"id":"shop","name":"Shop","sections":[{"section":"veg",
          "lines":[{"ingredient":"leek","name":"Leek","position":1},
                   {"ingredient":"onion","name":"Onion","position":3},
                   {"ingredient":"pepper","name":"Pepper","position":2},
                   {"ingredient":"carrot","name":"Carrot","position":0}]}]}],
         "ticked":["onion","pepper"],"ticked_order":["onion","pepper"]}
        """)
        XCTAssertEqual(list.tickedOrder, ["onion", "pepper"])
        let section = try XCTUnwrap(list.stores.first?.sections.first)
        func names(_ ticked: [String]) -> [String] { section.ordered(ticked: ticked).map(\.ingredient) }
        XCTAssertEqual(names(list.tickedOrder), ["carrot", "leek", "onion", "pepper"])
        // A new tick goes to the end of its section.
        XCTAssertEqual(names(["onion", "pepper", "carrot"]), ["leek", "onion", "pepper", "carrot"])
        // An untick goes back among what is left to buy, at its usual place.
        XCTAssertEqual(names(["pepper"]), ["carrot", "leek", "onion", "pepper"])
        XCTAssertEqual(names([]), ["carrot", "leek", "pepper", "onion"])
    }

    func testTheWeeksTicksCarryTheOrderTheyWereMadeIn() throws {
        let ticks: Ticked = try decode("""
        {"ok":true,"monday":"2026-10-19","ticked":["milk","salt"],"ticked_order":["salt","milk"],
         "ticked_at":{"salt":"2026-10-20T18:30:00+00:00"}}
        """)
        XCTAssertEqual(ticks.ticked, ["milk", "salt"])
        XCTAssertEqual(ticks.tickedOrder, ["salt", "milk"])
    }

    func testPairingReadsTheTokenAndWhoItBelongsTo() throws {
        let paired: Paired = try decode("""
        {"token":"abc","device_id":3,"device":"iPhone de Ana","person":"ana",
         "person_name":"Ana","household":"Casa"}
        """)
        XCTAssertEqual(paired.token, "abc")
        XCTAssertEqual(paired.deviceID, 3)
        XCTAssertEqual(paired.personName, "Ana")
    }

    func testProgressArrivesAlreadyInTheHouseholdsWords() throws {
        let progress: Progress = try decode("""
        {"today":"2026-10-20","people":[{"person":"ana","name":"Ana",
          "weights":[{"day":"2026-10-13","kg":71.2}],"trend":[{"day":"2026-10-13","kg":71.4}],
          "trend_kg":71.4,"rate_kg_week":-0.35,"mode":"loss","kcal":1800,"protein_g":110.0,
          "flags":["Bajando despacio"],"changed":null}]}
        """)
        XCTAssertEqual(progress.people.first?.flags, ["Bajando despacio"])
        XCTAssertEqual(progress.people.first?.rateKgWeek, -0.35)
        XCTAssertNil(progress.people.first?.changed)
    }

    func testACookingSheetKnowsWhereEachContainerGoes() throws {
        let sheet: Cook = try decode("""
        {"day":"2026-10-18","dishes":[{"recipe":{"id":"stew","name":"Stew","tags":[]},
          "servings":6.0,"morning":true,"eat_on":["2026-10-19","2026-10-26"],
          "for_text":"for Monday and the 26th","split_text":"4 for Ana, 2 for Leo",
          "lines":["1.2 kg beef"],
          "containers":[{"eat":"2026-10-26","storage":"freezer","defrost_on":"2026-10-25",
            "servings":{"ana":2.0}}]}]}
        """)
        let dish = try XCTUnwrap(sheet.dishes.first)
        XCTAssertTrue(dish.morning)
        XCTAssertEqual(dish.containers.first?.storage, "freezer")
        XCTAssertEqual(dish.containers.first?.defrostOn, "2026-10-25")
        XCTAssertEqual(dish.containers.first?.servings["ana"], 2.0)
    }
}

extension ModelTests {
    func testAWrongTypeIsStillAnError() throws {
        // The missing-key overloads must not swallow a real contract break: `meals` as an object is
        // not an empty list, it is a server sending something this app cannot read.
        XCTAssertThrowsError(try JSONDecoder().decode(
            Day.self, from: Data(#"{"day":"2026-10-20","meals":{"lunch":1}}"#.utf8)))
        XCTAssertThrowsError(try JSONDecoder().decode(
            Day.self, from: Data(#"{"day":"2026-10-20","paused":"yes"}"#.utf8)))
    }

    func testAMissingKeyThatMattersIsStillAnError() throws {
        // `day` has no sensible empty value, so it stays required: a reply without it is not a day.
        XCTAssertThrowsError(try JSONDecoder().decode(Day.self, from: Data("{}".utf8)))
    }
}
