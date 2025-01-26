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
    alias Instr = Stack!IRInstruction;

    Label label;
    Instr instr;
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

    void addInstr(IRInstruction instr)
    {
        this.instr.push(instr);
    }
}

class FlowGraph
{
    alias Nodes = Set!FlowNode;
    alias Edges = Nodes[FlowNode];
    alias Dominators = Nodes[FlowNode];
    alias IDoms = FlowNode[FlowNode];
    alias Loops = Set!FlowNode;
    alias Exprs = Nodes[FlowNode];
    alias AvailExprs = Tuple!(Exprs, "in", Exprs, "out");
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

    Loops detectLoops()
    {
        Loops loops;
        bool[FlowNode] in_path = false;
        bool[FlowNode] visited = false;

        void dfsVisit(FlowNode node)
        {
            if (visited[node])
                return;

            if (in_path[node])
                loops ~= node;

            in_path[node] = true;
            visited[node] = true;

            foreach (succ; node.successors[])
                dfsVisit(succ);

            in_path.remove(node);
        }

        dfsVisit(this.entry_node);
        return loops;
    }

    void computeGenKillSets()
    {
        foreach (node; this.nodes[])
        {
            Nodes generates;
            Nodes kills;
            foreach (instr; node.instr[])
            {
                foreach (use; instr.getUsedVaribles())
                    generates ~= use;

                foreach (def; instr.getDefinedVariables())
                    kills ~= def;
            }

            node.generates = generates - kills;
            node.kills = kills.dup;
        }
    }

    AvailExprs computeAvailableExprs()
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

                foreach (pred; node.predecessors[])
                    input[node] = input[node] & output[pred];

                output[node] = node.generates + (input[node] - node.kills);

                if (output[node] != old_out || input[node] != old_in)
                    changed = true;
            }
        }

        return tuple("in", "out")(input, output);
    }

    Liveness computeLiveness()
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
            foreach (node_prime; nodes[])
            {
                foreach (instr; node_prime.instr[])
                {
                    foreach (def; instr.getDefinedVariables())
                        interf[node.label] ~= def;

                    foreach (use; instr.getUsedVariables())
                        interf[node.label] ~= use;
                }
            }
        }

        return interf;
    }
}
