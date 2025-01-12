module cephyr.node;

import std.typecons, std.variant, std.sumtype, std.range, std.array, std.algorithm;

alias Id = int;

struct FlowNode(T)
{
    FlowNode!T[] predecessors;
    FlowNode!T[] successors;
    T value;
    Id id;
    bool terminal;
    static Id id_counter;

    this(T value, bool terminal)
    {
        this.value = value;
	this.terminal = terminal;
        this.id = this.id_counter++;
    }

    void addPredecessor(FlowNode!T predecessor)
    {
        this.predecessors ~= predecessor;
    }

    void addSuccessor(FlowNode!T successor)
    {
        this.successors ~= successor;
    }

    void removePredecessor(Id id)
    {
        size_t index = 0;
        foreach (pred; this.predecessors)
        {
            if (pred.id == id)
                break;
            else
                index++;
        }
        this.predecessors = this.predecessors[0 .. index] ~ this.predecessors[index + 1 .. $];
    }

    void removeSuccessor(Id id)
    {
        size_t index = 0;
        foreach (succ; this.successors)
        {
            if (succ.id == id)
                break;
            else
                index++;
        }
        this.successors = this.successors[0 .. index] ~ this.successors[index + 1 .. $];
    }
}
