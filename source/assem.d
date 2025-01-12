module cephyr.assem;

import std.typecons, std.variant, std.sumtype, std.array, std.algorithm, std.range;

import cephyr.temporary;

enum Instruction
{
    AllocByte,
    AllocHalf,
    AllocDouble,
    AllocQuad,
    AllocN,
    MoveMemory,
    Call,
    Jump,
    JumpZ,
    JumpNZ,
    PushStack,
    PopStack,
    Return,
    Const,
    Sequence,
    Label,
    BinaryOp,
    UnaryOp,
    RelOp,
    LibCall,
    SysCall,
    Phi,
}

struct Assem
{
    Instruction instruction;

    union
    {
        Temporary v_temporary;
        Label v_label;
    }

    this(Instruction instruction, Temporary v_temporary)
    {
        this.instruction = instruction;
        this.v_temporary = v_temporary;
    }

    this(Instruction instruction, Label v_label)
    {
        this.instruction = instruction;
        this.v_label = v_label;
    }
}
