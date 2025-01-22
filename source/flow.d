module cephyr.flow;

import std.typecons, std.variant, std.sumtype, std.array, std.algorithm, std.range, std.conv;

import cephyr.set;
import cephyr.stack;
import cephyr.queue;
import cephyr.inter;
import cephyr.temporary;

class FlowNode
{
    alias FlowNodeSet = Set!FlowNode;

    Label label;
    IRInstruction instr;
    FlowNodeSet predecessors;
    FlowNodeSet successors;

    this(Label label, IRInstruction instr)
    {
        this.label = label;
        this.instr = instr;
    }

    void addPredecessor(FlowNode node)
    {
        this.predecessors ~= node;
    }

    void addSuccessor(FlowNode node)
    {
        this.successor ~= node;
    }
}

class FlowGraph
{
    alias Nodes = Set!FlowNode;
    alias Edges = Nodes[FlowNode];
    alias Dominators = Nodes[FlowNode];
    alias IDoms = FlowNode[FlowNode];

    Nodes nodes;
    Edges edges;
    FlowNode entry_node;
    FlowNode exit_node;

    void addEdge(FlowNode from, FlowNode to)
    {
        from.addSuccessor(to);
        to.addPredecessor(from);
        this.nodes ~= from;
        this.nodes ~= to;
        this.edges[from] ~= to;
    }

    void markAsEntry(FlowNode node)
    {
        this.entry_node = node;
    }

    void markAsExit(FlowNode node)
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

    void topologicalSortForwards()
    {
        Nodes sorted;
        bool[FlowNode] in_stack = false;
        bool[FlowNode] visited = false;

        void dfsVisit(FlowNode node)
        {
            if (node in in_stack || node in visited)
                return;

            in_stack[node] = true;
            visited[node] = true;

            foreach (succ; node.successors[])
                dfsVisit(succ);

            in_stack.remove(node);
            sorted ~= *node;
        }

        dfsVisit(this.entry_node);
        this.nodes = sorted;
    }

    void topologicalSortBackwards()
    {
        Nodes sorted;
        bool[FlowNode] in_stack = false;
        bool[FlowNode] visited = false;

        void dfsVisit(FlowNode node)
        {
            if (node in in_stack || node in visited)
                return;

            in_stack[node] = true;
            visited[node] = true;

            foreach (pred; node.predecessors[])
                dfsVisit(pred);

            in_stack.remove(node);
            sorted ~= *node;
        }

        dfsVisit(this.exit_node);
        this.nodes = sorted;
    }

}
