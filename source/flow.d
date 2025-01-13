module cephyr.cfg;

import std.typecons, std.variant, std.sumtype, std.array, std.algorithm, std.range;

import cephyr.set;
import cephyr.stack;
import cephyr.queue;
import cephyr.assem;

alias Daton = Assem;

class BasicBlock
{
    Set!BasicBlock predecessors;
    Set!BasicBlock successors;
    Assem data;
    bool is_terminal;

    this(Assem data, bool is_terminal = false)
    {
        this.data = data;
        this.is_terminal = is_terminal;
    }

    void addPredecessor(BasicBlock block)
    {
        this.predecessors ~= block;
    }

    void addSuccessor(BasicBlock block)
    {
        this.successors ~= block;
    }
}

class CFG
{
    alias BBlockEdge = Tuple!(BasicBlock, "from", BasicBlock, "to");
    alias BBSet = Set!BasicBlock;
    alias Edges = Set!BBlockEdge;
    alias Dominators = BBSet[BasicBlock];

    BasicBlock entry;
    BasicBlock exit;
    BBSet nodes;
    Edges edges;

    this(Assem entry, Assem exit)
    {
        this.entry = new BasicBlock(entry);
        this.exit = new BasicBlock(exit, true);
        this.nodes ~= this.entry;
        this.nodes ~= this.exit;
        addEdge(this.entry, this.exit);
    }

    void addEdge(BasicBlock from, BasicBlock to)
    {
        from.addSuccessor(to);
        to.addPredecessor(from);
        this.edges ~= tuple!("from", "to")(from, to);
    }

    Dominators computeDominators()
    {
        Dominators output = null;
        output[this.entry] = Set(this.entry);

        foreach (node; this.nodes[])
        {
            if (node == this.entry)
                continue;
            output[node] = this.nodes;
        }

        bool changed = true;
        while (changed)
        {
            changed = false;

            foreach (node; this.nodes[])
            {
                if (node == this.entry)
                    continue;

                BBSet intersection = BBSet();
                foreach (pred; node.predecessors[])
                    intersection = intersection & pred;

                auto new_output = output.dup;
                new_output[node] = Set(node) + intersection;

                if (output != new_output)
                {
                    output = new_output.dup;
                    changed = true;
                }
            }
        }

    }
}
