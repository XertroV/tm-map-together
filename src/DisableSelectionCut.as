// MemPatcher@ Patch_DisableCutSelection = MemPatcher(
//     "12",
//     {}, {}
// );


/*

hmm not sure this is the best way to deal with it

Trackmania.exe.text+F875A9 - E8 02080000           - call Trackmania.exe.text+F87DB0 { reads selection buf (CUT)

 }
! patched
Trackmania.exe.text+F875AE - 31 C0                 - xor eax,eax
! patched
Trackmania.exe.text+F875B0 - EB 35                 - jmp Trackmania.exe.text+F875E7
Trackmania.exe.text+F875B2 - 48 8B 8B 18050000     - mov rcx,[rbx+00000518]
Trackmania.exe.text+F875B9 - E8 D26ABAFF           - call Trackmania.exe.text+B2E090
Trackmania.exe.text+F875BE - 8B D0                 - mov edx,eax
Trackmania.exe.text+F875C0 - 48 8B CB              - mov rcx,rbx
Trackmania.exe.text+F875C3 - E8 B81F0000           - call Trackmania.exe.text+F89580
Trackmania.exe.text+F875C8 - 83 F8 03              - cmp eax,03 { 3 }
Trackmania.exe.text+F875CB - 74 10                 - je Trackmania.exe.text+F875DD
Trackmania.exe.text+F875CD - 44 8B C0              - mov r8d,eax
Trackmania.exe.text+F875D0 - BA 01000000           - mov edx,00000001 { 1 }
Trackmania.exe.text+F875D5 - 48 8B CB              - mov rcx,rbx
Trackmania.exe.text+F875D8 - E8 93D3E4FF           - call Trackmania.exe.text+DD4970
Trackmania.exe.text+F875DD - 33 D2                 - xor edx,edx
Trackmania.exe.text+F875DF - 48 8B CB              - mov rcx,rbx
Trackmania.exe.text+F875E2 - E8 C9250000           - call Trackmania.exe.text+F89BB0
Trackmania.exe.text+F875E7 - 33 D2                 - xor edx,edx
Trackmania.exe.text+F875E9 - 48 8B CB              - mov rcx,rbx
Trackmania.exe.text+F875EC - 48 83 C4 20           - add rsp,20 { 32 }
Trackmania.exe.text+F875F0 - 5B                    - pop rbx
Trackmania.exe.text+F875F1 - E9 5AB9FFFF           - jmp Trackmania.exe.text+F82F50


*/
