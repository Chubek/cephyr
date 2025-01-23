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
    FlowNodeSet generates;
    FlowNodeSet kills;

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
    alias Exprs = Nodes[FlowNode];
    alias Liveness = Tuple!(Exprs, "live_in", Exprs, "live_out");
    alias Interference = Set!Label[Label];

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

    IDoms computeIDoms(Dominators dominators)
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

    void computeGenKillSets()
    {
        foreach (node; this.nodes[])
        {
            bool[Label] defined = false;
            foreach (def; node.instr.getDefinedVariables())
            {
                if (defined[def])
                    node.killed ~= node;

                defined[def] = true;
                node.generated ~= node;
            }
        }
    }

    Exprs computeAvailableExprs()
    {
        Exprs output = null;
        Exprs input = null;

        foreach (node; this.nodes[])
        {
            if (node == this.entry_node)
                continue;
            input[node] = Set();
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

                auto old_out = output[node].dup;

                foreach (pred; node.predecessors[])
                    input[node] = input[node] & output[pred];

                output[node] = node.generates + (input[node] - node.kills);

                if (output[node] != old_out)
                    changed = true;
            }
        }

        return output;
    }

    Liveness computeExprs()
    {
        Exprs output = null;
        Exprs input = null;

        foreach (node; this.nodes[])
        {
            if (node == this.entry_node)
                continue;

            input[node] = Set();
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

                auto old_in = input[node].dup;
                auto old_out = output[node].dup;

                input[node] = node.generates + (old_out - node.kills);

                foreach (succ; node.successors[])
                    output[node] = output[node] + input[succ];

                if (output[node] != old_out || input[node] != old_in)
                    changed = true;

            }
        }

        return tuple("live_in", "live_out")(input, output);
    }

    Interference computeInterference()
    {
        Interference interf;
        Liveness liveness = this.computeLiveness();

        Exprs live_out = liveness.live_out;
        foreach (node, nodes; live_out)
        {
            interf[node.label] = Set();
            Label[] alive;
            foreach (node_prime; nodes[])
            {
                foreach (def; node_prime.instr.getDefinedVariables())
                {
                    interf[node.label] ~= def;
                    alive ~= def;
                }

                foreach (live; alive)
                    interf[node.label] ~= live;
            }
        }

	return interf;
    }
}
