module cephyr.frame;

import std.typecons, std.variant, std.sumtype, std.array, std.range, std.algorithm;

import cephyr.temporary;
import cephyr.stack;

alias Address = size_t;
alias CallStack = Stack!Frame;

class Frame
{
    Temporary[] arguments;
    Temporary[] locals;
    Temporary[string] saved_registers;
    Address return_address;
    Address static_link;

    this(Address return_address)
    {
        this.return_address = return_address;
    }

    this(Address return_address, Address static_link)
    {
        this.return_address = return_address;
        this.static_link = static_link;
    }

    void addArgument(Temporary argument)
    {
        this.arguments ~= argument;
    }

    void addLocal(Temporary local)
    {
        this.locals ~= local;
    }

    void addSavedRegister(string name, Temporary register)
    {
        this.saved_registers[name] = register;
    }

}
