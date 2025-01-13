module cephyr.temporary;

import std.typecons, std.variant, std.sumtype, std.array, std.algorithm, std.conv;

struct Temporary
{
    enum Kind
    {
        InFrame,
        InRegister,
        InBinary,
    }

    size_t offset;
    size_t size;
    static size_t offset_counter;

    this(Kind kind, size_t size)
    {
        this.kind = kind;
        this.size = size;
        this.offset = this.offset_counter;
        this.offset_counter += size;
    }

    void resetOffsetCounter()
    {
        this.offset_counter = 0;
    }

    static Temporary newInFrame(size_t size)
    {
        return Temporary(Kind.InFrame, size);
    }

    static Temporary newInRegister(size_t size)
    {
        return Temporary(Kind.InRegister, size);
    }

    static Temporary newInBinary(size_t size)
    {
        return Temporary(Kind.InBinary, size);
    }
}

struct Label
{
    enum MAX_LOCAL = 9;
    enum MAX_MANGLED = 12;

    enum Kind
    {
        Local,
        Global,
        Mangled,
    }

    Kind kind;
    string name;
    static int local_num;

    this(Kind kind, string name)
    {
        this.kind = kind;
        this.name = name;
    }

    void resetLocalNum()
    {
        this.local_num = 0;
    }

    static Label newLocal()
    {
        if (this.local_num == MAX_LOCAL)
            this.local_num = 0;
        return Label(Kind.Local, (this.local_num++).to!string);
    }

    static Label newGlobal(string name)
    {
        return Label(Kind.Global, name);
    }

    static Label newMangled()
    {
        return Label(Kind.Mangled, generateRandomString());
    }

}

string generateRandomString(size_t length)
{
    import std.random, std.range;

    enum charset = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
    auto rng = Random();
    return iota(0, length).map!(_ => charset[uniform(0, charset.length, rng)]).array;
}
