module cephyr.inter;

import std.typecons, std.variant, std.sumtype, std.array, std.algorithm, std.range, std.conv;

import cephyr.stack;

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

    size_t toHash()
    {
        size_t hash = DJB2_INIT;
        foreach (chr; this.id.to!string)
            hash = (hash << 5) + hash + chr;
        return hash;
    }

    bool opEqual(const Label rhs) const
    {
        return this.id == rhs.id;
    }

    void assignRegister(Register v_register)
    {
        this.v_register = v_register;
    }

    void assignMemoryOffset(size_t v_offset)
    {
        this.v_offset = v_offset;
    }

    bool isRegister() const
    {
        return this.kind == Kind.Register;
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
    Label label;
    size_t size;

    bool defines_value;
    bool[] srcs_in_use;

    this(OpCode op, Label dst = null, Label[] srcs, Label label = null)
    {
        this.op = op;
        this.dst = dst;
        this.srcs = srcs;
        this.label = label;

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
}
