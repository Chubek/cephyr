module cephyr.flow;

import std.typecons, std.variant, std.sumtype, std.array, std.algorithm, std.range, std.conv;

import cephyr.set;
import cephyr.stack;
import cephyr.queue;
import cephyr.assem;

enum DJB2_INIT = 5381;

class BasicBlock
{
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

class Daton
{
    alias Data = Stack!Assem;
    alias DatonSet = Set!Daton;

    Data data;
    Label label;
    DatonSet predecessors;
    DatonSet successors;
    DatonSet gen_set;
    DatonSet kill_set;
    DatonSet use_set;
    DatonSet def_set;
    DatonSet in_set;
    DatonSet out_set;
    bool is_sorted = false;

    this(Data data, Label label)
    {
        this.data = data;
        this.label = label;
    }

    this(Label label)
    {
        this.label = label;
    }

    void addPredecessor(Daton daton)
    {
        this.predecessors ~= daton;
    }

    void addSuccessor(Daton daton)
    {
        this.successors ~= daton;
    }

    Nullable!Daton findNodeByLabel(Label label)
    {
        Nullable!Daton found;
        auto preds_filtered = this.predecessors.filter!(x => x.label == label);
        auto succs_filtered = this.successors.filter!(x => x.label == label);

        if (preds_filtered.length > 0)
            found = preds_filtered[0];
        else if (succs_filtered.length > 0)
            found = succes_filtered[0];

        return found;
    }

    void pushAssem(Assem assem)
    {
        this.assem.push(assem);
    }

    Assem popAssem()
    {
        return this.assem.pop();
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
        this.nodes ~= from;
        this.nodes ~= to;
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
                auto runner = dominators[succ];
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
                auto runner = post_dominators[pred];
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

class DFG
{
    alias Nodes = Set!Daton;
    alias Sorted = Stack!Daton;

    Nodes nodes;
    Nodes entry_nodes;
    Nodes exit_nodes;

    void addEdge(Daton from, Daton to)
    {
        from.addSuccessor(to);
        to.addPredecessor(from);
        this.nodes ~= from;
        this.nodes ~= to;
    }

    void markAsEntry(Daton daton)
    {
        this.entry_nodes ~= daton;
    }

    void markAsExit(Daton daton)
    {
        this.exit_nodes ~= daton;
    }

    void computeGenKillSets()
    {
        foreach (node; this.nodes[])
        {
            foreach (assem; node.data[])
            {
                foreach (def_label; assem.getDefinedVariables())
                {
                    auto def_node = node.findNodeByLabel(def_label);

                    if (def_node.isNull)
                        continue;

                    if (def_node.get !in node.kill_set)
                        node.gen_set ~= def_node.get;

                    node.kill_set ~= def_node.get;

                }

            }
        }
    }

    void computeDefUseSets()
    {
        foreach (node; this.nodes[])
        {
            foreach (assem; node.data[])
            {
                foreach (use_label; assem.getUsedVariables())
                {
                    auto use_node = node.findNodeByLabel(use_label);

                    if (use_node.isNull)
                        continue;

                    if (use_node.get !in node.def_set)
                        node.use_set ~= use_node.get;
                }

                foreach (def_label; assem.getDefinedVariables())
                {
                    auto def_node = node.findNodeByLabel(def_label);

                    if (def_node.isNull)
                        continue;

                    node.def_set ~= def_node.get;
                }
            }
        }
    }

    void computeInOutSets()
    {
        bool changed = true;

        do
        {
            changed = false;

            foreach (node; this.nodes[])
            {
                auto old_in = node.in_set.dup;
                auto old_out = node.out_set.dup;

                node.out_set = Set();
                foreach (succ; node.successors[])
                    node.out_set = node.out_set + succ.in_set;

                node.in_set = Set();
                foreach (v; node.out_set[])
                    if (v !in node.kill_set)
                        node.in_set ~= v;

                if (old_in != node.in_set || old_out != node.out_set)
                    changed = true;
            }
        }
        while (changed);
    }

    Sorted topologicalSort()
    {
        Sorted sorted;
        bool[Daton] visited;
        bool[Daton] in_stack;

        void dfsVisit(Daton node)
        {
            if (node in in_stack || node in visited)
                return;

            in_stack[node] = true;
            visited[node] = true;

            foreach (succ; node.successors[])
                dfsVisit(succ);

            in_stack.remove(node);
            sorted.push(node);
        }

        foreach (entry; this.entry_nodes[])
            if (entry !in visited)
                dfsVisit(entry);

        foreach (node; this.nodes[])
            if (node !in visited)
                dfsVisit(node);

        return sorted;
    }
}
