namespace EditorPatches {
    import bool get_DisableClubItems_IsApplied() from "MapTogether";
    import void set_DisableClubItems_IsApplied(bool value) from "MapTogether";
    import bool get_SkipClubFavItemUpdate_IsApplied() from "MapTogether";
    import void set_SkipClubFavItemUpdate_IsApplied(bool value) from "MapTogether";
}

import void EditNewMapFrom(MapBase base, MapMood mood, MapCar vehicle, nat3 size) from "MapTogether";
