/*


Nopping these calls will block u/r and ctrl+z/y from working in the editor.
It does not stop API calls, though. (which is perfect for us)


Trackmania.exe.text+F7C7BB - FF 90 48020000        - call qword ptr [rax+00000248] { undo?
 }
Trackmania.exe.text+F7C7C1 - E9 FF010000           - jmp Trackmania.exe.text+F7C9C5
Trackmania.exe.text+F7C7C6 - 49 8B CE              - mov rcx,r14
Trackmania.exe.text+F7C7C9 - E8 72F82EFF           - call Trackmania.exe.text+26C040
Trackmania.exe.text+F7C7CE - 85 C0                 - test eax,eax
Trackmania.exe.text+F7C7D0 - 0F84 EF010000         - je Trackmania.exe.text+F7C9C5
Trackmania.exe.text+F7C7D6 - 41 8B 46 1C           - mov eax,[r14+1C]
Trackmania.exe.text+F7C7DA - 24 05                 - and al,05 { 5 }
Trackmania.exe.text+F7C7DC - 41 3A C5              - cmp al,r13l


Trackmania.exe.text+F7C818 - FF 90 48020000        - call qword ptr [rax+00000248] { redo?
 }
Trackmania.exe.text+F7C81E - E9 A2010000           - jmp Trackmania.exe.text+F7C9C5
Trackmania.exe.text+F7C823 - 49 8B CE              - mov rcx,r14
Trackmania.exe.text+F7C826 - E8 15F82EFF           - call Trackmania.exe.text+26C040
Trackmania.exe.text+F7C82B - 85 C0                 - test eax,eax
Trackmania.exe.text+F7C82D - 0F84 92010000         - je Trackmania.exe.text+F7C9C5
Trackmania.exe.text+F7C833 - 48 8B 07              - mov rax,[rdi]
Trackmania.exe.text+F7C836 - 48 8B CF              - mov rcx,rdi
Trackmania.exe.text+F7C839 - FF 90 50010000        - call qword ptr [rax+00000150]
Trackmania.exe.text+F7C83F - 41 3B C5              - cmp eax,r13d
Trackmania.exe.text+F7C842 - 0F85 7D010000         - jne Trackmania.exe.text+F7C9C5


the function called is +DD7690

Trackmania.exe.text+DD7690 - 48 89 5C 24 10        - mov [rsp+10],rbx { UNDO/REDO function
 }
Trackmania.exe.text+DD7695 - 48 89 74 24 18        - mov [rsp+18],rsi
Trackmania.exe.text+DD769A - 57                    - push rdi
Trackmania.exe.text+DD769B - 48 83 EC 20           - sub rsp,20 { 32 }
Trackmania.exe.text+DD769F - 8B 81 480D0000        - mov eax,[rcx+00000D48]
Trackmania.exe.text+DD76A5 - 8B F2                 - mov esi,edx
Trackmania.exe.text+DD76A7 - 48 8B D9              - mov rbx,rcx
Trackmania.exe.text+DD76AA - 85 C0                 - test eax,eax
Trackmania.exe.text+DD76AC - 74 2F                 - je Trackmania.exe.text+DD76DD
Trackmania.exe.text+DD76AE - 83 F8 07              - cmp eax,07 { 7 }
Trackmania.exe.text+DD76B1 - 0F85 BF000000         - jne Trackmania.exe.text+DD7776
Trackmania.exe.text+DD76B7 - 48 8B 91 78040000     - mov rdx,[rcx+00000478]
Trackmania.exe.text+DD76BE - 44 8B C6              - mov r8d,esi
Trackmania.exe.text+DD76C1 - 48 81 C2 68030000     - add rdx,00000368 { 872 }
Trackmania.exe.text+DD76C8 - E8 E3661600           - call Trackmania.exe.text+F3DDB0
Trackmania.exe.text+DD76CD - 48 8B 5C 24 38        - mov rbx,[rsp+38]
Trackmania.exe.text+DD76D2 - 48 8B 74 24 40        - mov rsi,[rsp+40]
Trackmania.exe.text+DD76D7 - 48 83 C4 20           - add rsp,20 { 32 }




*/


MemPatcher@ Patch_PreventUserUndo = MemPatcher(
    "FF 90 48 02 00 00 E9 FF 01 00 00 49 8B CE E8 72 F8 2E FF 85 C0 0F 84 EF 01 00 00 41 8B 46 1C 24 05 41 3A C5 75 1A 48 8B 4F 68 BA 6A 00 00 00",
    {0}, {"90 90 90 90 90 90"}, {"FF 90 48 02 00 00"}
);

MemPatcher@ Patch_PreventUserRedo = MemPatcher(
    "FF 90 48 02 00 00 E9 A2 01 00 00 49 8B CE E8 15 F8 2E FF 85 C0 0F 84 92 01 00 00 48 8B 07 48 8B CF FF 90 50 01 00 00 41 3B C5 0F 85 7D 01 00 00 48 8B 8F E0 00 00 00 48 85 C9 0F 84 6D 01 00 00 E8 C3 C5 CB FF",
    {0}, {"90 90 90 90 90 90"}, {"FF 90 48 02 00 00"}
);

bool UserUndoRedoDisablePatchEnabled {
    get {
        return Patch_PreventUserUndo.IsApplied && Patch_PreventUserRedo.IsApplied;
    }
    set {
        Patch_PreventUserUndo.IsApplied = value;
        Patch_PreventUserRedo.IsApplied = value;
    }
}
