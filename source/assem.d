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
    Assign,
    Index,
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

    static BinaryOp newAdd(Operand left, Operand right)
    {
        return BinaryOp(Operator.Add, left, right);
    }

    static BinaryOp newSub(Operand left, Operand right)
    {
        return BinaryOp(Operator.Sub, left, right);
    }

    static BinaryOp newMul(Operand left, Operand right)
    {
        return BinaryOp(Operator.Mul, left, right);
    }

    static BinaryOp newDiv(Operand left, Operand right)
    {
        return BinaryOp(Operator.Div, left, right);
    }

    static BinaryOp newMod(Operand left, Operand right)
    {
        return BinaryOp(Operator.Mod, left, right);
    }

    static BinaryOp newShr(Operand left, Operand right)
    {
        return BinaryOp(Operator.Shr, left, right);
    }

    static BinaryOp newShl(Operand left, Operand right)
    {
        return BinaryOp(Operator.Shl, left, right);
    }

    static BinaryOp newAnd(Operand left, Operand right)
    {
        return BinaryOp(Operator.And, left, right);
    }

    static BinaryOp newOr(Operand left, Operand right)
    {
        return BinaryOp(Operator.Or, left, right);
    }

    static BinaryOp newBitAnd(Operand left, Operand right)
    {
        return BinaryOp(Operator.BitAnd, left, right);
    }

    static BinaryOp newBitOr(Operand left, Operand right)
    {
        return BinaryOp(Operator.BitOr, left, right);
    }

    static BinaryOp newBitXor(Operand left, Operand right)
    {
        return BinaryOp(Operator.BitXor, left, right);
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

    static UnaryOp newNeg(Operand operand)
    {
        return UnaryOp(Operator.Neg, operand);
    }

    static UnaryOp newNot(Operand operand)
    {
        return UnaryOp(Operator.Not, operand);
    }

    static UnaryOp newBitNot(Operand operand)
    {
        return UnaryOp(Operator.BitNot, operand);
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

    static RelOp newEq(Operand left, Operand right)
    {
        return RelOp(Operator.Eq, left, right);
    }

    static RelOp newNe(Operand left, Operand right)
    {
        return RelOp(Operator.Ne, left, right);
    }

    static RelOp newGt(Operand left, Operand right)
    {
        return RelOp(Operator.Gt, left, right);
    }

    static RelOp newGe(Operand left, Operand right)
    {
        return RelOp(Operator.Ge, left, right);
    }

    static RelOp newLe(Operand left, Operand right)
    {
        return RelOp(Operator.Le, left, right);
    }

    static RelOp newLt(Operand left, Operand right)
    {
        return RelOp(Operator.Lt, left, right);
    }

    static RelOp newULe(Operand left, Operand right)
    {
        return RelOp(Operator.ULe, left, right);
    }

    static RelOp newULt(Operand left, Operand right)
    {
        return RelOp(Operator.ULt, left, right);
    }

    static RelOp newUGt(Operand left, Operand right)
    {
        return RelOp(Operator.UGt, left, right);
    }

    static RelOp newUGe(Operand left, Operand right)
    {
        return RelOp(Operator.UGe, left, right);
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

struct Assign
{
    Temporary temporary;
    Sequence sequence;
}

struct Index
{
    Temporary temporary;
    Sequence sequence;
    Operand index;
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
        Assign v_assign;
        Index v_index;
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

    this(Instruction instruction, Assign v_assign)
    {
        this.instruction = instruction;
        this.v_assign = v_assign;
    }

    this(Instruction instruction, Index v_index)
    {
        this.instruction = instruction;
        this.v_index = v_index;
    }

    Label[] getDefinedVariables()
    {
        switch (this.instruction)
        {
        case Instruction.AllocByte:
        case Instruction.AllocHalf:
        case Instruction.AllocDouble:
        case Instruction.AllocQuad:
        case Instruction.AllocN:
            return [this.v_temporary.label];
        case Instruction.Assign:
            return [this.v_assign.temporary.label];
        default:
            return [];
        }
    }

    Label[] getUsedVariables()
    {
        switch (this.instruction)
        {
        case Instruction.Call:
            Label[] result;
            foreach (arg; this.v_call.arguments)
                result ~= arg.label;
            return result;
        case Instruction.Index:
            return [this.v_index.temporary.label];
        default:
            return [];
        }
    }
}
