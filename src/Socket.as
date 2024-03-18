class MapTogetherConnection {
    Net::Socket@ socket;
    string op_token;
    bool hasErrored = false;
    string error;

    string roomId;
    string roomPassword;
    uint actionRateLimit;

    // create a room
    MapTogetherConnection(const string &in password, uint roomMsBetweenActions = 0) {
        InitSock();
        if (socket is null) return;
        // 1 = create
        socket.Write(uint8(1));
        roomPassword = password;
        WriteLPString(socket, roomPassword);
        socket.Write(roomMsBetweenActions);
        ExpectOKResp();
        ExpectRoomDetails();
    }

    // join a room
    MapTogetherConnection(const string &in roomId, const string &in password = "") {
        InitSock();
        if (socket is null) return;
        // 2 = join
        socket.Write(uint8(2));
        WriteLPString(socket, roomId);
        roomPassword = password;
        WriteLPString(socket, roomPassword);
        ExpectOKResp();
        ExpectRoomDetails();
    }

    bool get_IsConnected() {
        return socket !is null && !hasErrored && roomId.Length == 6;
    }
    bool get_IsConnecting() {
        return socket !is null && !hasErrored && roomId.Length == 0;
    }
    bool get_IsShutdown() {
        return socket is null || hasErrored;
    }

    void ExpectRoomDetails() {
        // let _ = write_lp_string(&mut stream, &self.id_str).await;
        // let _ = stream.write_u32_le(self.action_rate_limit).await;
        roomId = ReadLPString(socket);
        if (roomId.Length != 6) {
            CloseWithErr("Invalid room id from server: " + roomId);
            return;
        }
        actionRateLimit = socket.ReadUint32();
    }

    void ExpectOKResp() {
        while (socket.Available() < 3) yield();
        auto resp = socket.ReadRaw(3);
        if (resp == "OK_") return;
        if (resp != "ERR") {
            CloseWithErr("Unexpected response from server: " + resp);
        } else {
            auto msg = ReadLPString(socket);
            CloseWithErr("Error from Server: " + msg);
        }
    }

    protected void InitSock() {
        string op_token = GetAuthToken();
        trace('token: ' + op_token);
        @this.socket = Net::Socket();
        if (!socket.Connect("127.0.0.1", 19796)) {
            CloseWithErr("Failed to connect to MapTogether server");
            return;
        }
        socket.Write(uint16(op_token.Length));
        socket.WriteRaw(op_token);
    }

    protected void CloseWithErr(const string &in err) {
        NotifyError(err);
        if (socket is null) return;
        hasErrored = true;
        error = err;
        socket.Close();
        @socket = null;
    }

    void Close() {
        if (socket is null) return;
        socket.Close();
        @socket = null;
    }
}



const string ReadLPString(Net::Socket@ socket) {
    auto len = socket.ReadUint16();
    return socket.ReadRaw(len);
}

void WriteLPString(Net::Socket@ socket, const string &in str) {
    socket.Write(uint16(str.Length));
    socket.WriteRaw(str);
}
