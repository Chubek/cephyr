module cephyr.flow;

import std.typecons, std.variant, std.sumtype, std.array, std.algorithm,
    std.range, std.conv, std.math;

import cephyr.set;
import cephyr.stack;
import cephyr.queue;
import cephyr.inter;

class FlowNode
{
    alias FlowNodeSet = Set!FlowNode;
    alias LabelSet = Set!Label;
    alias Instructions = Stack!IRInstruction;

    Instructions instr;
    FlowNodeSet predecessors;
    FlowNodeSet successors;
    LabelSet generates;
    LabelSet kills;

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

    void addGeneratedVariable(Label variable)
    {
        this.generates ~= variable;
    }

    void addKilledVariable(Label variable)
    {
        this.kills ~= variable;
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
    alias IDoms = Nullable!FlowNode[FlowNode];
    alias Loops = Set!Nodes;
    alias Exprs = Set!Label[FlowNode];
    alias AvailExprs = Tuple!(Exprs, "in", Exprs, "out");
    alias ReachingExprs = Exprs;
    alias Liveness = Tuple!(Exprs, "live_in", Exprs, "live_out");
    alias LiveRange = Tuple!(InstrID, "start", InstrID, "end");
    alias LiveRanges = Set!LiveRange[Label];
    alias Interference = Set!Label[Label];
    alias NestingTree = Nodes[Nodes];
    alias NestingDepth = size_t[Nodes];
    alias NestingInstr = size_t[InstrID];
    alias AccessFreq = size_t[Label];
    alias Instructions = Set!IRInstruction;
    alias BackEdge = Tuple!(FlowNode, "source", FlowNode, "destination");
    alias BackEdges = Set!BackEdge;
    alias NaturalLoop = Tuple!(FlowNode, "header", Set!FlowNode, "body");
    alias NaturalLoops = Set!NaturalLoop;
    alias MoveEdge = Tuple!(Label, "source", Label, "destination");
    alias MoveEdges = Set!MoveEdge;

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

    MoveEdges computeMoveEdges()
    {
        MoveEdges output;

        foreach (instr; this.getAllInstructions()[])
        {
            if (instr.isMove())
                output ~= tuple("source", "destination")(instr.src[0], instr.dst);
        }

        return output;
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
        Nullable!FlowNode idom;
        IDoms idoms = idom.dup;

        FlowNode isClosestNode(FlowNode node, FlowNode dominator)
        {
            foreach (dom; dominators[node][])
                if (dom != node && dom != dominator)
                    if (dominator in dominators[dom])
                        return false;

            return true;
        }

        foreach (node; this.nodes[])
        {
            if (node == this.entry_node)
                continue;

            foreach (dom; dominators[node][])
            {
                if (dom != node)
                {
                    if (isClosestNode(node, dom))
                    {
                        idoms[node] = dom;
                        break;
                    }
                }
            }
        }

        return idoms;
    }

    BackEdges identifyBackEdges(Dominators dominators)
    {
        BackEdges output;

        foreach (node; this.nodes[])
        {
            foreach (succ; node.successors[])
            {
                if (succ in dominators[node])
                    output ~= tuple("source", "destination")(node, succ);
            }
        }

        return output;
    }

    NaturalLoops constructNaturalLoops(BackEdges back_edges)
    {
        NaturalLoops output;

        foreach (back_edge; back_edges)
        {
            auto header = back_edge.destination;
            Set!FlowNode loop_nodes = new Set();
            Stack!FlowNode stack = new Stack([header]);

            while (!stack.isEmpty())
            {
                auto current = stack.pop();
                if (current !in loop_nodes)
                    loop_nodes ~= current;

                foreach (pred; current.predecessors[])
                    if (pred != header)
                        stack.push(pred);
            }

            loop_nodes ~= header;
            output ~= tuple("header", "body")(header, output);
        }

        return output;
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
            Set!Label generates;
            Set!Label kills;
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
        Interference output;

        auto live_out_sets = liveness.live_out;

        foreach (node; this.nodes[])
        {
            auto live_out_set = live_out_sets[node];
            foreach (label_outer; live_out_set)
            {
                foreach (label_inner; live_out_set)
                {
                    if (label_inner == labe_outer)
                        continue;

                    output[label_outer] ~= label_inner;
                    output[label_inner] ~= label_outer;
                }
            }
        }

        return output;
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

    NestingDepth computeNestingDepths(NestingTree nesting_tree)
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

    NestingInstr computeInstrNestingDepths(NestingDepths nesting_depths)
    {
        NestingInstr output;

        foreach (node; this.nodes[])
        {
            foreach (instr; node.getAllInstructions()[])
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

    AccessFreq computeAccessFrequencies()
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

    ReachingExprs computeReachingExprs()
    {
        ReachingExprs input;
        Exprs output;

        bool changed = true;
        while (changed)
        {
            changed = false;
            foreach (node; this.nodes[])
            {
                auto old_input = input[node].dup;
                auto old_output = output[node].dup;

                foreach (pred; node.predecessors[])
                    input[node] = input[node] + output[pred];

                output[node] = (input[node] - node.kills) + node.generates;

                if (input[node] != old_input || output[node] != old_out)
                    changed = true;
            }
        }

	return input;
    }
}
