module cephyr.inter;

import std.typecons, std.variant, std.sumtype, std.array, std.algorithm, std.range;

import cephyr.temporary;
import cephyr.stack;

static TemporaryManager temp_manager = new TemporaryManager();

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
