module cephyr.ctrlopt;

import std.typecons, std.range, std.sumtype, std.array, std.container, std.string, std.conv;

import cephyr.flow;
import cephyr.set;
import cephyr.stack;
import cephyr.inter;
import cepyr.regalloc;

class CtrlflowOptimizer : FlowGraph
{
    void eliminateCommonSubexpr(ReachingExprs reaching_exprs)
    {
        foreach (node; this.nodes[])
        {
            auto reaching_labels = reaching_exprs[node];
            Label[size_t] memo = null;

            foreach (reaching_label; reaching_labels[])
            {
                auto instr_hash = reaching_label.used_in.instrHash();

                if (instr_hash !in memo)
                    memo[instr_hash] = reaching_label;
                else
                {
                    // TODO
                }
            }
        }
    }
}
