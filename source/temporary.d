module cephyr.temporary;

import std.typecons, std.variant, std.sumtype, std.array, std.algorithm, std.conv;

struct Temporary
{
    alias TempId = long;
    alias Color = int;

    enum Size
    {
        Byte,
        Half,
        Double,
        Quad,
    }

    enum Kind
    {
        Spilled,
        InRegister,
        SavedRegister,
    }

    Size size;
    Kind kind;
    TempId id;
    string value;
    size_t offset;
    bool defines;
    Color color = -1;
    static TempId id_counter;

    this(Kind kind)
    {
        this.kind = kind;
        this.id = id_counter++;
    }

    this(Kind kind, string value)
    {
        this.kind = kind;
        this.value = value;
        this.id = id_counter++;
    }

    this(Kind kind, Size size, size_t offset)
    {
        this.kind = kind;
        this.size = size;
        this.offset = offset;
        this.id = id_counter++;
    }

    this(Kind kind, size_t offset)
    {
        this.kind = kind;
        this.offset = offset;
        this.id = id_counter++;
    }

    void setDefines()
    {
	this.defines = true;
    }

    void setUses()
    {
	this.defines = false;
    }

    void resetIdCounter()
    {
        this.id_counter = 0;
    }

    TempId getId() const
    {
        return this.id;
    }

    void setColor(Color color)
    {
        this.color = color;
    }

    Color getColor() const
    {
        return this.color;
    }

    void spillToMemory(size_t offset, Size size)
    {
        this.kind = Kind.Spilled;
        this.offset = offset;
        this.size = size;
    }

    static Temporary newSpilled(size_t offset)
    {
        return Temporary(Kind.Spilled, offset);
    }

    static Temporary newSpilledByte(size_t offset)
    {
        return Temporary(Kind.Spilled, Size.Byte, offset);
    }

    static Temporary newSpilledHalf(size_t offset)
    {
        return Temporary(Kind.Spilled, Size.Half, offset);
    }

    static Temporary newSpilledDouble(size_t offset)
    {
        return Temporary(Kind.Spilled, Size.Double, offset);
    }

    static Temporary newSpilledQuad(size_t offset)
    {
        return Temporary(Kind.Spilled, Size.Quad, offset);
    }

    static Temporary newInRegister()
    {
        return Temporary(Kind.InRegister);
    }

    static Temporary newSavedRegister(string value)
    {
        return Temporary(Kind.SavedRegister, value);
    }

    string toString() const
    {
        import std.format : format;

        if (this.kind == Kind.Spilled)
            return format("m%d", this.id);
        else if (this.kind == Kind.InRegister)
            return format("r%d", this.id);
        else
            return format("[%d]{%s}", this.id, this.value);
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
        else if (this.kind == Kind.Global)
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
