shared enum MapMood {
    Day = 0,
    Night = 1,
    Sunset = 2,
    Sunrise = 3,
}

shared enum MapBase {
    NoStadium = 32,
    StadiumOld = 64,
    Stadium155 = 128,
}

// Encoded in map_base bits 2-4 (0 = Stadium keeps the byte compatible with
// protocol v5, which only used mood in bits 0-1 and base in bits 5-7).
shared enum MapEnv {
    Stadium = 0,
    RedIsland = 1,
    GreenCoast = 2,
    BlueBay = 3,
    WhiteShore = 4,
}

shared enum MapCar {
    CarSport,
    CarSnow,
    CarRally,
    CarDesert,
}
