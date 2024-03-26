void DrawMapInfoTab() {
    if (g_MTConn is null) {
        UI::Text("Null connection");
        return;
    }

    UI::Text("Size: " + g_MTConn.mapSize.ToString());
    UI::Text("Base (encoded): " + g_MTConn.mapBase);
    UI::Text("Car: " + tostring(MapCar(g_MTConn.baseCar)));
    UI::Text("Total Blocks Placed: " + g_MTConn.totalBlocksPlaced);
    UI::Text("Total Blocks Deleted: " + g_MTConn.totalBlocksRemoved);
    UI::Text("Total Items Placed: " + g_MTConn.totalItemsPlaced);
    UI::Text("Total Items Deleted: " + g_MTConn.totalItemsRemoved);
}
