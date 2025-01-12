module cephyr.temporary;

import std.typecons, std.variant, std.sumtype, std.array, std.algorithm, std.conv;

struct Temporary
{
    alias TempId = long;

    enum Kind
    {
        Spilled,
        InRegister,
    }

    Kind kind;
    TempId id;
    static TempId id_counter;

    this(Kind kind)
    {
        this.kind = kind;
        this.id = id_counter++;
    }

    void resetIdCounter()
    {
        this.id_counter = 0;
    }

    TempId getId() const
    {
        return this.id;
    }

    static Temporary newSpilled()
    {
        return Temporary(Kind.Spilled);
    }

    static Temporary newInRegister()
    {
        return Temporary(Kind.InRegister);
    }

    string toString() const
    {
        import std.format : format;

        if (this.kind == Kind.Spilled)
            return format("m%d", this.id);
        else
            return format("r%d", this.id);
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

    string toString() const
    {
        import std.format : format;

        if (this.kind == Kind.Local)
            return format("%s:", this.name);
        else
            return format(".%s:", this.name);
    }

}

string generateRandomString(size_t length)
{
    import std.random, std.range;

    enum charset = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
    auto rng = Random();
    return iota(0, length).map!(_ => charset[uniform(0, charset.length, rng)]).array;
}
