uint GetMwIdValue(const string &in name) {
    auto x = MwId();
    x.SetName(name);
    // warn("Value for " + name + Text::Format(" = 0x%08x", x.Value));
    return x.Value;
}



const uint32 MwId_Value_XertroV = GetMwIdValue("0a2d1bc0-4aaa-4374-b2db-3d561bdab1c9");
const uint32 MwId_Value_Ville = GetMwIdValue("6e16c55c-54c8-4fed-a090-d6466bcc9d10");
const uint32 MwId_Value_SkiFreak = GetMwIdValue("dadbaf28-e7b5-429b-bf37-8c8c1419fcf4");
const uint32 MwId_Value_Trunckley = GetMwIdValue("c777b486-07ef-48cf-85f9-5faeedcf3c68");
const uint32 MwId_Value_ArEyeses = GetMwIdValue("fc8467b8-b253-457f-b8bb-3bbd2bb5bfdd");
const uint32 MwId_Value_ArDotDotDot = GetMwIdValue("d10cdccd-31e7-491f-9504-d72ee3a70de6");
const uint32 MwId_Value_Hylis = GetMwIdValue("2232c721-f215-4036-b28b-772eee46632c");
const uint32 MwId_Value_Tona = GetMwIdValue("7cd60a75-609a-4e64-b286-16f329878249");
const uint32 MwId_Value_Eyebo = GetMwIdValue("a07f01cd-afb0-4230-9c13-868c1ede28a3");
const uint32 MwId_Value_Spike = GetMwIdValue("5f9c2a43-593f-4e84-a64d-82319058dd3a");
const uint32 MwId_Value_Kora = GetMwIdValue("e879bbd8-db22-4dbb-9510-8d445b5db320");
const uint32 MwId_Value_Lakanta = GetMwIdValue("73fbc796-2a6f-472f-a130-818ab5ee4618");
const uint32 MwId_Value_Naxanria = GetMwIdValue("4f507640-c862-45f1-9a21-1e05ed91eb82");
const uint32 MwId_Value_TNTree = GetMwIdValue("aa32fc89-e0c4-4b73-a33e-026df0807b5c");
// DD2
const uint32 MwId_Value_Maji = GetMwIdValue("bfcf62ff-0f9e-40aa-b924-11b9c70b8a09");
const uint32 MwId_Value_Lentillion = GetMwIdValue("e5879f9f-b6e9-4351-8727-4fe0e33dff3d");
const uint32 MwId_Value_Maxchess = GetMwIdValue("356ec472-d537-44d8-a13d-c2a1a298e776");
const uint32 MwId_Value_Sparkling = GetMwIdValue("2212a68c-7071-4901-9b4f-d8af9c51d00c");
const uint32 MwId_Value_Jaakaah = GetMwIdValue("b23b4877-77c4-4064-bbdd-1f94d08102f6");
const uint32 MwId_Value_Classic = GetMwIdValue("90b09865-7de1-4a50-92a4-753e59fcbc00");
const uint32 MwId_Value_Tekky = GetMwIdValue("a198e640-779a-47c0-97b5-9d38a351e7fa");
const uint32 MwId_Value_Doondy = GetMwIdValue("90c040a6-e3ec-43d8-a8de-a9f6de065257");
const uint32 MwId_Value_Rioyter = GetMwIdValue("da944352-d9c8-4826-b572-98c06f956656");
const uint32 MwId_Value_Maverick = GetMwIdValue("eddaa892-06de-48a9-b6e6-55389d2adda0");
const uint32 MwId_Value_sightorld = GetMwIdValue("b4670285-ef39-4984-ab8b-4fe26a2c644c");
const uint32 MwId_Value_Whiskey = GetMwIdValue("36a44731-1924-428b-afff-6ead4645ba41");
const uint32 MwId_Value_Plaxity = GetMwIdValue("ad6b44c0-091c-4183-8f60-af61ffec2f8a");
const uint32 MwId_Value_Viiru = GetMwIdValue("b3c7b1cf-db35-4c8b-9756-f5e4c0b68ed5");
const uint32 MwId_Value_Kubas = GetMwIdValue("21029447-5895-4e1e-829c-14dedb4af788");
const uint32 MwId_Value_Jumper = GetMwIdValue("66c68931-a0e2-4949-ab21-679e31ef1590");
const uint32 MwId_Value_sPeq = GetMwIdValue("7599d4de-2ced-46d0-abf6-91612e1dca30");
const uint32 MwId_Value_EntryLag = GetMwIdValue("225988c0-56c7-4906-8df0-e54afb6ada49");

bool Is_MwId_Value_DD2(uint32 v) {
    return v == MwId_Value_Maji
        || v == MwId_Value_Lentillion
        || v == MwId_Value_Maxchess
        || v == MwId_Value_Sparkling
        || v == MwId_Value_Jaakaah
        || v == MwId_Value_Classic
        || v == MwId_Value_Tekky
        || v == MwId_Value_Doondy
        || v == MwId_Value_Rioyter
        || v == MwId_Value_Maverick
        || v == MwId_Value_sightorld
        || v == MwId_Value_Whiskey
        || v == MwId_Value_Plaxity
        || v == MwId_Value_Viiru
        || v == MwId_Value_Kubas
        || v == MwId_Value_Jumper
        || v == MwId_Value_sPeq
        || v == MwId_Value_EntryLag
    ;
}
