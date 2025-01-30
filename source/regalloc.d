module cephyr.regalloc;

import std.typecons, std, sumtype, std.conv, std.container, std.array, std.math;

import cephyr.set;
import cephyr.flow;
import cephyr.stack;
import cephyr.inter;

class RegisterAllocator : FlowGraph
{
    enum NUM_REGISTERS = 21;

    alias Instructions = Set!IRInstruction;
    alias RegisterSet = Set!Register;
    alias LabelStack = Stack!Label;
    alias LabelSet = Set!Label;
    alias Coloring = int[Label];

    Interference interf;
    LiveRanges live_ranges;
    AccessFreq acc_freq;
    MoveEdges move_edges;
    NestingInstr nesting_instr;
    RegisterSet pre_colored;

    Coloring coloring;
    LabelSet spilled_nodes;

    this(Interference interf, LiveRanges live_ranges, AccessFreq acc_freq,
            NestingInstr nesting_instr, MoveEdges move_edges)
    {
        this.interf = interf;
        this.live_ranges = live_ranges;
        this.acc_freq = acc_freq;
        this.nesting_instr = nesting_instr;
        this.move_edges = move_edges;
    }

    void fillPrecoloredRegisters()
    {
        foreach (label, _; this.interf)
        {
            if (label.reserved)
                this.pre_colored ~= label_prime.v_register;
        }
    }

    void colorInterferenceGraph()
    {
        LabelStack stack;
        LabelStack worklist = new Stack(this.interf.keys());

        while (!worklist.isEmpty())
        {
            auto simplified = worklist.filter!(x => this.interf[x].getLength() < NUM_REGISTERS);
            if (simplified)
            {
                auto node = simplified[0];
                stack.push(node);
                worklist = worklist.removeItem(node);
                foreach (neigh; this.interf[node][])
                    this.interf[neigh] = this.interf[neigh].removeItem(node);
            }
            else
            {
                auto spill_candidate = selectSpillCandidate();
                this.spilled_nodes ~= spill_candidate;
                foreach (neigh; this.interf[spill_candidate][])
                    this.interf[neigh] = this.interf[neigh].removeItem(spill_candidate);
                this.interf.remove(spill_candidate);
            }
        }

        while (!stack.isEmpty())
        {
            auto node = stack.pop();
            Stack!int used_colors;

            foreach (neigh; this.interf[node])
                if (neigh in coloring)
                    used_colors.push(this.coloring[neigh]);

            foreach (color; 0 .. NUM_REGISTERS)
            {
                if (color !in used_colors)
                {
                    this.coloring[node] = color;
                    break;
                }
                else
                    this.spilled_nodes ~= node;
            }
        }

        this.assignRegisters();
        this.coalesceRegisters();
    }

    Label selectSpillCandidate()
    {
        Label spill_candidate = null;
        auto max_cost = -1;

        int computeSpillCost(Label label)
        {
            auto live_range = this.live_ranges[label];
            auto start = live_range.start;
            auto end = live_range.end;
            auto lifespan = end - start;

            auto total_depth = 0;
            foreach (instr_id; start .. end)
            {
                total_depth += this.nesting_instr[instr_id];
            }
            auto average_depth = floor(total_depth / lifespan);

            return this.acc_freq[label] * lifespan * (1 + average_depth);
        }

        foreach (label, _; this.interf)
        {
            if (label.v_register in this.pre_colored)
                continue;

            auto cost = computeSpillCost(label);
            if (cost > max_cost)
            {
                max_cost = cost;
                spill_candidate = label;
            }
        }

        return spill_candidate;
    }

    void assignRegisters()
    {
        foreach (ref label, color; this.coloring)
            label.promoteToRegister(color);
    }

    void coalesceRegisters()
    {
        foreach (move_edge; this.move_edges)
        {
            auto src = move_edge.source;
            auto dst = move_edge.destination;

            if (src.v_register in this.pre_colored || dst.v_register in this.pre_colored)
                continue;

            if (src in this.coloring && dst in this.coloring)
            {
                if (dst !in this.interf[src])
                {
                    if (src.v_register in this.pre_colored)
                        this.coloring[dst] = this.coloring[src];
                    else if (dst.v_register in this.pre_colored)
                        this.coloring[src] = this.coloring[dst];
                    else
                    {
                        this.interf[dst] = this.interf[src] + this.interf[dst];
                        this.interf.remove(src);
                        this.coloring[dst] = this.coloring[src];
                        this.coloring.remove(src);
                    }
                }
            }
        }
    }

}
