const string AirModeOnlyPattern = "";

// TODO


/*

74 14 48 8B CE E8 23 31 DB FF 48 C7 45 F0 01 00 00 00 85 C0 74 08 48 C7 45 F0 00 00 00 00 49 8B 46 38 44 8B A7 68 01 00 00 48 89 45 08 41 0F B6 86 9C 00 00 00 88 85 C8 00 00 00 41 0F B6 86 9D 00 00 00 88 85 B0 00 00 00 8B 86 28 01 00 00 89 45 A8 44 89 64 24 60 45 85 ED 74 09

Trackmania.exe.text+10F9363 - 74 14                 - je Trackmania.exe.text+10F9379 { check if air mode (jmp if not) }
Trackmania.exe.text+10F9365 - 48 8B CE              - mov rcx,rsi
Trackmania.exe.text+10F9368 - E8 2331DBFF           - call Trackmania.exe.text+EAC490
Trackmania.exe.text+10F936D - 48 C7 45 F0 01000000  - mov qword ptr [rbp-10],00000001 { 1 }
Trackmania.exe.text+10F9375 - 85 C0                 - test eax,eax
Trackmania.exe.text+10F9377 - 74 08                 - je Trackmania.exe.text+10F9381
Trackmania.exe.text+10F9379 - 48 C7 45 F0 00000000  - mov qword ptr [rbp-10],00000000 { 0 }


 */
