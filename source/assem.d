module cephyr.assem;

import std.typecons, std.variant, std.sumtype, std.array, std.algorithm, std.range;

import cephyr.temporary;
import cephyr.stack;
import cephyr.libroutine;
import cephyr.primitive;

alias Operand = Stack!Assem;
alias Sequence = Operand;
alias MemSpace = size_t;
alias Address = long;
alias SyscallNR = int;

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

struct Jump
{
    enum DestKind
    {
        Label,
        Address,
    }

    DestKind dest_kind;
    Sequence condition;

    union
    {
        Address v_address;
        Label v_label;
    }

    this(Address v_address, Sequence condition = null)
    {
        this.dest_kind = DestKind.Address;
        this.condition = condition;
        this.v_address = v_address;
    }

    this(Label v_label, Sequence condition = null)
    {
        this.dest_kind = DestKind.Label;
        this.condition = condition;
        this.v_address = v_address;
    }

}

struct Call
{
    enum Kind
    {
        Address,
        Label,
        LibraryRoutine,
        SystemCall,
    }

    Kind kind;
    bool is_offset;
    Temporary[] arguments;

    union
    {
        Address v_address;
        Label v_label;
        LibraryRoutine v_libroutine;
        SyscallNR v_syscall;
    }

    this(Address v_addrress, bool is_offset = false)
    {
        this.kind = Kind.Address;
        this.is_offset = is_offset;
        this.v_address = v_address;
    }

    this(Label v_label)
    {
        this.kind = Kind.Label;
        this.v_label = v_label;
    }

    this(LibraryRoutine v_libroutine)
    {
        this.kind = Kind.LibraryRoutine;
        this.v_libroutine = v_libroutine;
    }

    this(SyscallNR v_syscall)
    {
        this.kind = Kind.SystemCall;
        this.v_syscall = v_syscall;
    }
}

struct Const
{
    Temporary temporary;
    Primitive primitive;
}

struct MemoryMove
{
    Temporary temporary;
    Primitive index;
}

class Assem
{
    Instruction instruction;

    union
    {
        Temporary v_temporary;
        Label v_label;
        BinaryOp v_binaryop;
        UnaryOp v_unaryop;
        RelOp v_relop;
        Sequence v_sequence;
        MemSpace v_memspace;
        Jump v_jump;
        Call v_call;
        Const v_const;
        MemoryMove v_memmove;
    }

    this(Instruction instruction)
    {
        this.instruction = instruction;
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

    this(Instruction instruction, MemSpace v_memspace)
    {
        this.instruction = instruction;
        this.v_memspace = v_memspace;
    }

    this(Instruction instruction, Jump v_jump)
    {
        this.instruction = instruction;
        this.v_jump = v_jump;
    }

    this(Instruction instruction, Call v_call)
    {
        this.instruction = instruction;
        this.v_call = v_call;
    }

    this(Instruction instrruction, Const v_const)
    {
        this.instruction = instruction;
        this.v_const = v_const;
    }

    this(Instruction instruction, MemoryMove v_memmove)
    {
        this.instruction = instruction;
        this.v_memmove = v_memmove;
    }
}
