module cephyr.assem;

import std.typecons, std.variant, std.sumtype, std.array, std.algorithm, std.range;

import cephyr.temporary;
import cephyr.stack;

alias Operand = Stack!Assem;

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

struct BinaryOp
{
    enum Operator
    {
        Add,
        Sub,
        Mul,
        Div,
        Mod,
        Shr,
        Shl,
        And,
        Or,
        BitAnd,
        BitOr,
        BitXor,
    }

    Operator operator;
    Operand left, right;

    this(Operator operator, Operand left, Operand right)
    {
        this.operator = operator;
        this.left = left;
        this.right = right;
    }
}

struct UnaryOp
{
    enum Operator
    {
        Neg,
        Not,
        BitNot,
    }

    Operator operator;
    Operand operand;

    this(Operator operator, Operand operand)
    {
        this.operator = operator;
        this.operand = operand;
    }
}

struct RelOp
{
    enum Operator
    {
        Eq,
        Ne,
        Gt,
        Ge,
        Le,
        Lt,
        ULe,
        ULt,
        UGt,
        UGe,
    }

    Operator operator;
    Operand left, right;

    this(Operator operator, Operand left, Operand right)
    {
        this.operator = operator;
        this.left = left;
        this.right = right;
    }

}

struct Assem
{
    alias Sequence = Operand;

    Instruction instruction;

    union
    {
        Temporary v_temporary;
        Label v_label;
        BinaryOp v_binaryop;
        UnaryOp v_unaryop;
        RelOp v_relop;
        Sequence v_sequence;
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

    this(Instruction instruction, BinaryOp v_binaryop)
    {
        this.instruction = instruction;
        this.v_binaryop = v_binaryop;
    }

    this(Instruction instruction, UnaryOp v_unaryop)
    {
        this.instruction = instruction;
        this.v_unaryop = v_unaryop;
    }

    this(Instruction instruction, RelOp v_relop)
    {
        this.instruction = instruction;
        this.v_relop = v_relop;
    }

    this(Instruction instruction, Sequence v_sequence)
    {
        this.instruction = instruction;
        this.v_sequence = v_sequence;
    }
}
