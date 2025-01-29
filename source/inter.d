module cephyr.inter;

import std.typecons, std.variant, std.sumtype, std.array, std.algorithm, std.range, std.conv;

import cephyr.stack;

alias InstrID = int;

struct Register
{
    enum Size
    {
        UpperByte,
        LowerByte,
        Word,
        Double,
        Quad,
    }

    enum Name
    {
        RAX,
        RBX,
        RCX,
        RDX,
        RSI,
        RDI,
        RBP,
        RSP,
        R8,
        R9,
        R10,
        R11,
        R12,
        R13,
        R14,
        R15,
        RIP,
        RFLAGS,
    }

    Size size;
    Name name;

    this(Name name)
    {
        this.size = Size.Double;
        this.name = name;
    }

    void demoteToLowerByte()
    {
        this.size = Size.LowerByte;
    }

    void demoteToHigherByte()
    {
        this.size = Size.HigherByte;
    }

    void demoteToWord()
    {
        this.size = Size.Word;
    }

    void remoteToDouble()
    {
        this.size = Size.Double;
    }

    void promoteToQuad()
    {
        this.size = Size.Quad;
    }

    string toString() const
    {
        switch (this.name)
        {
        case Name.RAX:
            switch (this.size)
            {
            case Size.UpperByte:
                return "ah";
            case Size.LowerByte:
                return "al";
            case Size.Double:
                return "eax";
            case Size.Quad:
                return "rax";
            default:
                throw new Error("Register name invalid");
            }
        case Name.RBX:
            switch (this.size)
            {
            case Size.UpperByte:
                return "bh";
            case Size.LowerByte:
                return "bl";
            case Size.Double:
                return "ebx";
            case Size.Quad:
                return "rbx";
            default:
                throw new Error("Register name invalid");
            }
        case Name.RCX:
            switch (this.size)
            {
            case Size.UpperByte:
                return "ch";
            case Size.LowerByte:
                return "cl";
            case Size.Double:
                return "ecx";
            case Size.Quad:
                return "rcx";
            default:
                throw new Error("Register name invalid");
            }
        case Name.RDX:
            switch (this.size)
            {
            case Size.UpperByte:
                return "dh";
            case Size.LowerByte:
                return "dl";
            case Size.Double:
                return "edx";
            case Size.Quad:
                return "rdx";
            default:
                throw new Error("Register name invalid");
            }
        case Name.RSI:
            switch (this.size)
            {
            case Size.LowerByte:
                return "sil";
            case Size.Double:
                return "esi";
            case Size.Quad:
                return "rsi";
            default:
                throw new Error("Register name invalid");
            }
        case Name.RDI:
            switch (this.size)
            {
            case Size.LowerByte:
                return "dil";
            case Size.Double:
                return "edi";
            case Size.Quad:
                return "rdi";
            default:
                throw new Error("Register name invalid");
            }
        case Name.RBP:
            switch (this.size)
            {
            case Size.LowerByte:
                return "bpl";
            case Size.Double:
                return "ebp";
            case Size.Quad:
                return "rbp";
            default:
                throw new Error("Register name invalid");
            }
        case Name.RSP:
            switch (this.size)
            {
            case Size.LowerByte:
                return "spl";
            case Size.Double:
                return "esp";
            case Size.Quad:
                return "rsp";
            default:
                throw new Error("Register name invalid");
            }
        case Name.R8:
            switch (this.size)
            {
            case Size.LowerByte:
                return "r8b";
            case Size.Word:
                return "r8w";
            case Size.Double:
                return "r8d";
            case Size.Quad:
                return "r8";
            default:
                throw new Error("Register name invalid");
            }
        case Name.R9:
            switch (this.size)
            {
            case Size.LowerByte:
                return "r9b";
            case Size.Word:
                return "r9w";
            case Size.Double:
                return "r9d";
            case Size.Quad:
                return "r9";
            default:
                throw new Error("Register name invalid");
            }
        case Name.R10:
            switch (this.size)
            {
            case Size.LowerByte:
                return "r10b";
            case Size.Word:
                return "r10w";
            case Size.Double:
                return "r10d";
            case Size.Quad:
                return "r10";
            default:
                throw new Error("Register name invalid");
            }
        case Name.R11:
            switch (this.size)
            {
            case Size.LowerByte:
                return "r11b";
            case Size.Word:
                return "r11w";
            case Size.Double:
                return "r11d";
            case Size.Quad:
                return "r11";
            default:
                throw new Error("Register name invalid");
            }
        case Name.R12:
            switch (this.size)
            {
            case Size.LowerByte:
                return "r12b";
            case Size.Word:
                return "r12w";
            case Size.Double:
                return "r12d";
            case Size.Quad:
                return "r12";
            default:
                throw new Error("Register name invalid");
            }
        case Name.R13:
            switch (this.size)
            {
            case Size.LowerByte:
                return "r13b";
            case Size.Word:
                return "r13w";
            case Size.Double:
                return "r13d";
            case Size.Quad:
                return "r13";
            default:
                throw new Error("Register name invalid");
            }
        case Name.R14:
            switch (this.size)
            {
            case Size.LowerByte:
                return "r14b";
            case Size.Word:
                return "r14w";
            case Size.Double:
                return "r14d";
            case Size.Quad:
                return "r14";
            default:
                throw new Error("Register name invalid");
            }
        case Name.R15:
            switch (this.size)
            {
            case Size.LowerByte:
                return "r15b";
            case Size.Word:
                return "r15w";
            case Size.Double:
                return "r15d";
            case Size.Quad:
                return "r15";
            default:
                throw new Error("Register name invalid");
            }
        case Name.RIP:
            switch (this.size)
            {
            case Size.Double:
                return "eip";
            case Size.Quad:
                return "rip";
            default:
                throw new Error("Register name invalid");
            }
        case Name.RFLAGS:
            switch (this.size)
            {
            case Size.Double:
                return "eflags";
            case Size.Quad:
                return "rflags";
            default:
                throw new Error("Register name invalid");
            }
        default:
            throw new Error("Unsupported register");
        }
    }

    static Register fromColor(int color)
    {
	// TODO
    }
}

struct Label
{
    enum DJB2_INIT = 5381;

    enum Kind
    {
        InRegister,
        Spilled,
        Temporary,
    }

    Kind kind;
    int id;
    static int id_counter;
    bool reserved;

    union
    {
        Register v_register;
        size_t v_offset;
    }

    this()
    {
        this.kind = Kind.Temporary;
        this.id = this.id_counter++;
    }

    this(Register v_register)
    {
        this.kind = Kind.InRegister;
        this.v_register = v_register;
        this.reserved = true;
    }

    size_t toHash()
    {
        size_t hash = DJB2_INIT;
        foreach (chr; this.id.to!string)
            hash = (hash << 5) + hash + chr;
        return hash;
    }

    bool opEquals(const Label rhs) const
    {
        return this.id == rhs.id;
    }

    void promoteToRegister(int color)
    {
        this.kind = Kind.InRegister;
        this.v_register = Register.fromColor(color);
    }

    void spillToMemory(size_t v_offset)
    {
        this.kind = Kind.Spilled;
        this.v_offset = v_offset;
    }

    bool isRegister() const
    {
        return this.kind == Kind.InRegister;
    }

    bool isSpilled() const
    {
        return this.kind == Kind.Spilled;
    }

    bool isTemporary() const
    {
        return this.kind == Kind.Temporary;
    }
}

enum OpCode
{
    Load,
    Store,
    LoadEffectiveAddress,

    Add,
    Subtract,
    Multiply,
    Divide,
    Modulo,
    Negate,

    BitwiseAnd,
    BitwiseOr,
    BitwiseXor,
    BitwiseNot,

    ShiftLeft,
    ShiftRight,
    RotateRight,
    ArithmethicRotateLeft,

    Compare,
    Test,

    Jump,
    JumpIfEqual,
    JumpIfNotEqual,
    JumpIfLess,
    JumpIfLessEqual,
    JumpIfGreater,
    JumpIfGreaterEqual,
    Call,
    Return,

    PushIntoStack,
    PopFromStack,

    Phi,
    Move,
    NoOperation,
    DefineLabel,
}

class IRInstruction
{
    OpCode op;
    Label dst;
    Label[] srcs;
    InstrID id;
    static InstrID id_counter;
    size_t size;

    bool defines_value;
    bool[] srcs_in_use;

    this(OpCode op, Label dst = null, Label[] srcs, Label label = null)
    {
        this.op = op;
        this.dst = dst;
        this.srcs = srcs;
        this.id = this.id_counter++;

        final switch (op)
        {
        case OpCode.Load, OpCode.Add, OpCode.Subtract, OpCode.Multiply,
                OpCode.Divide, OpCode.Modulo, OpCode.BitwiseAnd, OpCode.BitwiseOr,
                OpCode.BitwiseXor, OpCode.ShiftLeft, OpCode.ShiftRight,
                OpCode.Move, OpCode.Phi:
                this.defines_value = true;
            break;
        default:
            this.defines_value = false;
        }

        this.srcs_in_use = new bool[srcs.length];
        foreach (i; 0 .. srcs.length)
        {
            this.srcs_in_use[i] = true;

            if (op == OpCode.Phi && i % 2 == 1)
                this.srcs_in_use[i] = false;
            if (op == OpCode.Call && i == 0)
                this.srcs_in_use[i] = false;
        }
    }

    Label[] getDefinedVariables() const
    {
        if (!defines_value || dst is null)
            return [];
        return [dst];
    }

    Label[] getUsedVariables() const
    {
        Label[] uses;
        foreach (i, src; this.srcs)
        {
            if (this.src_is_use[i])
                uses ~= src;
        }
        return uses;
    }

    Label[] getAllVariables() const
    {
        Label[] variables;
        foreach (def; getDefinedVariables())
            variables ~= def;
        foreach (use; getUsedVariables())
            variables ~= use;
        return variables;
    }

    bool isMove() const
    {
        return this.op == OpCode.Move;
    }
}
