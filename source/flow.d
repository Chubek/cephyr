module cephyr.flow;

import std.typecons, std.variant, std.sumtype, std.array, std.algorithm, std.range, std.conv;

import cephyr.set;
import cephyr.stack;
import cephyr.queue;
import cephyr.inter;
import cephyr.temporary;

struct FlowNode
{
    alias FlowNodeSet = Set!(FlowNode*);
    alias LabelSet = Set!Label;

    Label label;
    IRInstruction data;
    FlowNodeSet predecessors;
    FlowNodeSet successors;
    LabelSet gen_set;
    LabelSet kill_set;
    LabelSet in_set;
    LabelSet out_set;
    LabelSet[Label] use_def_chain;
    LabelSet[Label] def_use_chain;

    this(Label label, IRInstruction data)
    {
        this.label = label;
        this.data = data;
    }

    void addPredecessor(FlowNode* node)
    {
        this.predecessors ~= node;
    }

    void addSuccessor(FlowNode* node)
    {
        this.successor ~= node;
    }

    void addToGenSet(Label label)
    {
        this.gen_set ~= label;
    }

    void addToKillSet(Label label)
    {
        this.kill_set ~= label;
    }

    void addToInSet(Label label)
    {
        this.in_set ~= label;
    }

    void addToOutSet(Label label)
    {
        this.out_set ~= label;
    }

    void addToDefUseChain(Label subject, Label label)
    {
        this.def_use_chain[subject] ~= label;
    }

    void addToUseDefChain(Label subject, Label label)
    {
        this.use_def_chain[subject] ~= label;
    }
}

class FlowGraph
{
    alias Nodes = Set!FlowNode;
    alias Edges = Nodes[FlowNode];
    alias Dominators = Node[FlowNode];
    alias IDoms = FlowNode[FlowNode];
    alias Sorted = Set!FlowNode*;

    Nodes nodes;
    Edges edges;
    FlowNode* entry_node;
    FlowNode* exit_node;

    void addEdge(FlowNode from, FlowNode to)
    {
        from.addSuccessor(to);
        to.addPredecessor(from);
        this.nodes ~= from;
        this.nodes ~= to;
        this.edges[from] ~= to;
    }

    void markAsEntry(FlowNode* node)
    {
        this.entry_node = node;
    }

    void markAsExit(FlowNode* node)
    {
        this.exit_node = node;
    }

    Dominators computeDominators()
    {
        Dominators output = null;
        output[this.entry_node] = Set(this.entry_node);

        foreach (node; this.nodes[])
        {
            if (node == this.entry_node)
                continue;
            output[node] = this.nodes.dup;
        }

        bool changed = true;
        while (changed)
        {
            changed = false;
            foreach (node; this.nodes[])
            {
                if (node == this.entry_node)
                    continue;

                auto new_output = output[node].dup;
                foreach (pred; node.predecessors[])
                {
                    new_output = new_output & output[pred];
                }

                new_output ~= node;

                if (new_output != output[node])
                {
                    output[node] = new_output;
                    changed = true;
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
            if (node == this.entry_node || node in idoms)
                continue;

            foreach (discrim_node; this.nodes[])
            {
                if (discrim_node != node && discrim_node !in idoms && discrim_node in dominators[node])
                {
                    idoms[node] = discrim_node;
                    break;
                }
            }
        }

        return idoms;
    }

    Sorted topologicalSort()
    {
        Sorted sorted;
        bool[FlowNode* ] in_stack = false;
        bool[FlowNode* ] visited = false;

        void dfsVisit(FlowNode* node)
        {
            if (node in in_stack || node in visited)
                return;

            in_stack[node] = true;
            visited[node] = true;

            foreach (succ; node.successors[])
                dfsVisit(succ);

            in_stack.remove(node);
            sorted ~= node;
        }

        dfsVisit(this.entry_node);
        return sorted;
    }
}
