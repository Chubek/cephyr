module cephyr.flow;

import std.typecons, std.variant, std.sumtype, std.array, std.algorithm,
    std.range, std.conv, std.math;

import cephyr.set;
import cephyr.stack;
import cephyr.queue;
import cephyr.inter;
import cephyr.temporary;

class FlowNode
{
    alias FlowNodeSet = Set!FlowNode;
    alias Instructions = Stack!IRInstruction;

    Instructions instr;
    FlowNodeSet predecessors;
    FlowNodeSet successors;
    FlowNodeSet generates;
    FlowNodeSet kills;

    this(Instructions instr)
    {
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
    alias Loops = Set!Nodes;
    alias Exprs = Nodes[FlowNode];
    alias AvailExprs = Tuple!(Exprs, "in", Exprs, "out");
    alias Liveness = Tuple!(Exprs, "live_in", Exprs, "live_out");
    alias LiveRange = Tuple!(InstrID, "start", InstrID, "end");
    alias LiveRanges = Set!LiveRange[Label];
    alias Interference = Set!Label[Label];
    alias NestingTree = Nodes[Nodes];
    alias NestingDepth = size_t[Nodes];
    alias NestingInstr = size_t[InstrID];
    alias AccessFreq = size_t[Label];
    alias Instructions = Set!IRInstruction;

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

    Instructions getAllInstructions()
    {
        Instructions instrs;
        bool[FlowNode] visited = false;

        void appendInstr(FlowNode node)
        {
            if (visited[node])
                return;

            instrs = instrs + node.instr;
            visited[node] = true;

            foreach (pred; node.predecessors[])
                appendInstr(pred);
            foreach (succ; node.successors[])
                appendInstr(succ);
        }

        appendInstr(this.entry_node);
        return instrs;
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
        Nodes in_path;
        bool[FlowNode] visited = false;

        void dfsVisit(FlowNode node)
        {
            if (visited[node])
                return;

            if (node in in_path)
                loops ~= in_path;

            in_path ~= node;

            foreach (succ; node.successors[])
                dfsVisit(succ);

            in_path = in_path.removeItem(node);
            visited[node] = true;
        }

        dfsVisit(this.entry_node);

        foreach (node; this.nodes[])
            if (node !in visited)
                dfsVisit(node);

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

            node.generates = (generates - kills).dup;
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
            input[node] = new Set();
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

            input[node] = new Set();
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

    LiveRanges computeLiveRanges()
    {
        LiveRanges output;

        foreach (node; this.nodes[])
        {
            foreach (instr; node.instr[])
            {
                foreach (use; instr.getUsedVariables())
                {
                    if (use !in output)
                        output[use] = tuple("start", "end")(instr.id, instr.id);
                    else
                    {
                        auto range = output[use];
                        output[use] = tuple("start", "end")(range.start, instr.id);
                    }
                }

                foreach (def; instr.getDefinedVariables())
                {
                    if (def !in output)
                        output[def] = tuple("start", "end")(instr.id, instr.id);
                    else
                    {
                        auto range = output[def];
                        output[def] = tuple("start", "end")(range.start, instr.id);
                    }

                }

            }
        }

        return output;
    }

    Interference computeInterference(Liveness liveness)
    {
        Interference interf;

        auto live_out = liveness.live_out;

        foreach (node, nodes; live_out)
        {
            foreach (live_out_node; nodes[])
            {
                foreach (instr1; live_out_node.instr[])
                {
                    foreach (instr2; live_out_node.instr[])
                    {
                        foreach (var1; instr1.getAllVariables())
                        {
                            foreach (var2; instr2.getAllVariables())
                            {
                                if (var1 != var2)
                                {
                                    interf[var1] ~= var2;
                                    interf[var2] ~= var1;
                                }
                            }
                        }
                    }
                }
            }
        }

        return interf;
    }

    NestingTree buildLoopNestingTree(Loops loops)
    {
        NestingTree output;

        Nullable!Nodes findParentLoop(Nodes loop, Loops loops)
        {
            Nullable!Nodes parent;

            foreach (other_loop; loops[])
            {
                if (loop != other_loop && loop in other_loop)
                {
                    parent = other_loop;
                    return parent;
                }
            }

            return parent;
        }

        foreach (loop; loops[])
        {
            auto parent = findParentLoop(loop, loops);

            if (parent.isNull)
                output[new Set()] ~= loop;
            else
                output[parent.get] ~= loop;
        }

        return output;
    }

    NestingDepth calculateNestingDepths(NestingTree nesting_tree)
    {
        NestingDepth output;

        void assignNestingDepths(NestingTree nesting_tree,
                ref NestingDepth output, current_loop = null, current_depth = 0)
        {
            if (!current_loop)
                current_loop = new Set();

            output[current_loop] = current_depth;
            foreach (child_loop; nesting_tree[current_loop])
                assignNestingDepths(nesting_tree, output, child_loop, current_depth + 1);
        }

        assignNestingDepths(nesting_tree, output);
        return output;
    }

    NestingInstr calculateInstrNestingDepths(NestingDepths nesting_depths)
    {
        NestingInstr output;

        foreach (node; this.nodes[])
        {
            foreach (instr; node.getAllInstructions().opSlice())
            {
                auto max_depth = 0;
                foreach (loop, depth; nesting_depths)
                {
                    if (loop.filter!(x => instr in x.getAllInstructions()).length > 0)
                        max_depth = max(max_depth, depth);
                }
                output[instr.id] = max_depth;
            }
        }

        return output;
    }

    AccessFreq calculateAccessFrequencies()
    {
        AccessFreq output = null;

        foreach (node; this.nodes[])
        {
            foreach (instr; node.instr[])
            {
                foreach (var; instr.getAllVariables())
                {
                    output.require(var, 1);
                    output[var] += 1;
                }
            }

        }

        return output;
    }

}
