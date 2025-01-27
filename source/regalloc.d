module cephyr.regalloc;

import std.typecons, std, sumtype, std.conv, std.container, std.array;

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
    alias RegisterSet = Set!Register;
    alias LabelStack = Stack!Label;

    Interference interf;
    RegisterSet pre_colored;
    LabelStack label_stack;

    this(Interference interf)
    {
        this.interf = interf;
    }

    void fillPrecoloredRegisters()
    {
        foreach (label, labels; this.interf)
        {
            foreach (label_prime; labels)
                if (label_prime.reserved)
                    this.pre_colored ~= label_prime.v_register;
        }
    }

    Interference simplifyGraph()
    {
        Interference interf = this.interf.dup;

        foreach (label, labels; interf)
        {
            if (labels.getLength() < NUM_REGISTERS)
                this.label_stack ~= label;

            interf.remove(label);

        }

        return interf;
    }

    Label selectSpillCandidate(Interference interf, LiveRanges live_ranges,
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
            auto average_depth = total_depth / live_span;

            return acc_freq[labe] * live_span * (1 + average_depth);
        }

        foreach (label, labels; interf)
        {
            if (label in this.pre_colored)
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

}
