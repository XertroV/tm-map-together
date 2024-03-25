MemPatcher@ Patch_DisableSweeps = MemPatcher(
    "0F 87 ?? ?? 00 00 48 98 0F B6 84 02 ?? ?? ?? ?? 8B 8C 82 ?? ?? ?? ?? 48 03 CA FF E1 48 8B 8F ?? ?? 00 00",
    {0}, {"90 E9"}, {"0F 87"}
);

/*
    v ja -> jmp
    0F 87 ?? ?? 00 00 48 98 0F B6 84 02 ?? ?? ?? ?? 8B 8C 82 ?? ?? ?? ?? 48 03 CA FF E1 48 8B 8F ?? ?? 00 00
     E8 8D B6 AF FF 48 8B D8 48 C7 44 24 68 0E 00 00 00 48 8D 05 8A 31 CB 00


    0F 87 94 08 00 00 48 98 0F B6 84 02 74 DC F7 00 8B 8C 82 4C DC F7 00 48 03 CA FF E1 48 8B 8F 98 04 00 00 E8 8D B6 AF FF 48 8B D8 48 C7 44 24 68 0E 00 00 00 48 8D 05 8A 31 CB 00


! ja -> jmp to skip every time
Trackmania.exe.text+F7C12B - 0F87 94080000         - ja Trackmania.exe.text+F7C9C5 { jmp here to skip all sweeps. 0F 87 -> 90 E9 (ja -> jmp)
 }
Trackmania.exe.text+F7C131 - 48 98                 - cdqe
Trackmania.exe.text+F7C133 - 0FB6 84 02 74DCF700   - movzx eax,byte ptr [rdx+rax+00F7DC74]
Trackmania.exe.text+F7C13B - 8B 8C 82 4CDCF700     - mov ecx,[rdx+rax*4+00F7DC4C]
Trackmania.exe.text+F7C142 - 48 03 CA              - add rcx,rdx
Trackmania.exe.text+F7C145 - FF E1                 - jmp rcx
Trackmania.exe.text+F7C147 - 48 8B 8F 98040000     - mov rcx,[rdi+00000498]
Trackmania.exe.text+F7C14E - E8 8DB6AFFF           - call Trackmania.exe.text+A777E0
Trackmania.exe.text+F7C153 - 48 8B D8              - mov rbx,rax
Trackmania.exe.text+F7C156 - 48 C7 44 24 68 0E000000 - mov qword ptr [rsp+68],0000000E { 14 }
Trackmania.exe.text+F7C15F - 48 8D 05 8A31CB00     - lea rax,[Trackmania.exe.rdata+3252F0] { ("Clear terrain?") }
Trackmania.exe.text+F7C166 - 4C 8D 44 24 60        - lea r8,[rsp+60]
Trackmania.exe.text+F7C16B - 48 89 44 24 60        - mov [rsp+60],rax
Trackmania.exe.text+F7C170 - 48 8D 55 90           - lea rdx,[rbp-70]
Trackmania.exe.text+F7C174 - E8 779518FF           - call Trackmania.exe.text+1056F0
Trackmania.exe.text+F7C179 - 48 8D 05 D882C500     - lea rax,[Trackmania.exe.rdata+2CA458] { ("SweepTerrainAndSave") }
Trackmania.exe.text+F7C180 - E9 1C020000           - jmp Trackmania.exe.text+F7C3A1
Trackmania.exe.text+F7C185 - 48 8B 8F 98040000     - mov rcx,[rdi+00000498] { rdi = editor; 0x498 -> app?

 }
Trackmania.exe.text+F7C18C - E8 4FB6AFFF           - call Trackmania.exe.text+A777E0
Trackmania.exe.text+F7C191 - 48 8B D8              - mov rbx,rax
Trackmania.exe.text+F7C194 - 48 C7 44 24 68 11000000 - mov qword ptr [rsp+68],00000011 { 17 }
Trackmania.exe.text+F7C19D - 48 8D 05 3431CB00     - lea rax,[Trackmania.exe.rdata+3252D8] { ("Clear all blocks?") }


*/
