module cephyr.cfg;

import std.typecons, std.variant, std.sumtype, std.array, std.algorithm, std.range, std.conv;

import cephyr.set;
import cephyr.stack;
import cephyr.queue;
import cephyr.assem;

alias Daton = Assem;

class BasicBlock
{
    enum DJB2_INIT = 5381;

    Set!BasicBlock predecessors;
    Set!BasicBlock successors;
    Assem data;
    int id;
    bool is_terminal;
    static int id_counter;

    this(Assem data, bool is_terminal = false)
    {
        this.data = data;
        this.id = this.id_counter++;
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

    bool opEquals(const BasicBlock rhs) const
    {
        return this.id == rhs.id;
    }

    size_t toHash()
    {
        size_t hash = DJB2_INIT;
        foreach (chr; this.id.to!string)
            hash = (hash << 5) + hash + chr;
        return hash;
    }
}

class CFG
{
    alias BBlockEdge = Tuple!(BasicBlock, "from", BasicBlock, "to");
    alias BBSet = Set!BasicBlock;
    alias Edges = Set!BBlockEdge;
    alias Dominators = BBSet[BasicBlock];
    alias IDoms = BasicBlock[BasicBlock];

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

                BBSet intersection = this.nodes.dup;
                foreach (pred; node.predecessors[])
                    intersection = intersection & output[pred];

                intersection ~= node;

                if (output[node] != intersection)
                {
                    output[node] = intersection;
                    changed = true;
                }
            }
        }

    }

    Dominators computePostDominators()
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

                BBSet intersection = this.nodes.dup;
                foreach (succ; node.successors[])
                    intersection = intersection & output[succ];

                intersection ~= node;

                if (output[node] != intersection)
                {
                    output[node] = intersection;
                    changed = true;
                }
            }
        }

    }

    Dominators computeDominanceFrontiers(Dominators dominators)
    {
        Dominators output = null;
        foreach (node; this.nodes[])
            output[node] = BBSet();

        foreach (node; this.nodes[])
        {
            foreach (succ; node.successors[])
            {
                auto runner = Set(succ);
                while (runner != dominators[node])
                {
                    output[runner] ~= node;
                    runner = dominators[runner];
                }
            }
        }

        return output;
    }

    Dominators computePostDominanceFrontiers(Dominators post_dominators)
    {
        Dominators output = null;
        foreach (node; this.nodes[])
            output[node] = BBSet();

        foreach (node; this.nodes[])
        {
            foreach (pred; node.predecessors[])
            {
                auto runner = Set(pred);
                while (runner != post_dominators[node])
                {
                    output[runner] ~= node;
                    runner = post_dominators[runner];
                }
            }
        }

        return output;
    }

    IDoms computeImmediateDominators(Dominators dominators)
    {
        IDoms idoms = null;

        foreach (node; this.nodes[])
        {
            BasicBlock idom = null;
            foreach (dom; dominators[node][])
            {
                if (dom != node)
                {
                    if (!idom || dominators[dom].getLength() > dominators[idom].getLength())
                        idom = dom;
                }
                idoms[dom] = idom;
            }
        }

        return idoms;
    }
}
