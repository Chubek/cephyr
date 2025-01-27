module cephyr.regalloc;

import std.typecons, std, sumtype, std.conv, std.container, std.array, std.math;

import cephyr.set;
import cephyr.flow;
import cephyr.stack;
import cephyr.inter;

class RegisterAllocator
{
    enum NUM_REGISTERS = 21;

    alias Interference = FlowGraph.Interference;
    alias Liveness = FlowGraph.Liveness;
    alias LiveRanges = FlowGraph.LiveRanges;
    alias NestingDepths = FlowGraph.NestingDepths;
    alias AccessFreq = FlowGraph.AccessFreq;
    alias Instructions = Set!IRInstruction;
    alias RegisterSet = Set!Register;
    alias LabelStack = Stack!Label;
    alias Coloring = int[Label];

    Interference interf;
    RegisterSet pre_colored;
    Coloring coloring;

    this(Interference interf)
    {
        this.interf = interf;
    }

    void fillPrecoloredRegisters()
    {
        foreach (label, _; this.interf)
        {
            if (label.reserved)
                this.pre_colored ~= label_prime.v_register;
        }
    }

    LabelStack simplifyGraph()
    {
        LabelStack output;

        foreach (label, labels; this.interf)
        {
            if (labels.getLength() < NUM_REGISTERS)
                output ~= label;

            this.interf.remove(label);

        }

        return output;
    }

    Label selectSpillCandidate(LiveRanges live_ranges,
            NestingInstr instr_nesting_depths, AccessFreq acc_freq)
    {
        Label spill_candidate = null;
        auto max_cost = -1;

        int computeSpillCost(Label label)
        {
            auto live_range = live_ranges[label];
            auto start = live_range.start;
            auto end = live_range.end;
            auto live_span = end - start;

            auto total_depth = 0;
            foreach (instr_id; start .. end)
            {
                total_depth += instr_nesting_depths[instr_id];
            }
            auto average_depth = floor(total_depth / live_span);

            return acc_freq[label] * live_span * (1 + average_depth);
        }

        foreach (label, _; this.interf)
        {
            if (label.register in this.pre_colored)
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

    void coalesceRegisters(Instructions move_instrs)
    {
        foreach (move_instr; move_instrs)
        {
            auto src = move_instr.src[0];
            auto dst = move_instr.dst;

            if (src.register in this.pre_colored || dst.register in this.pre_colored)
                continue;

            if (src in this.coloring && dst in this.coloring)
            {
                if (dst !in this.interf[src])
                {
                    if (src.register in this.pre_colored)
                        this.coloring[dst] = this.coloring[src];
                    else if (dst.register in this.pre_colored)
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

    Coloring colorInterferenceGraph()
    {
	// TODO
    }
}
