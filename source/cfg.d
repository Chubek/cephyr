module cephyr.cfg;

import std.typecons, std.variant, std.sumtype, std.array, std.algorithm;

import cephyr.set;
import cephyr.stack;
import cephyr.queue;

enum HASH_CONST = 0x45d9f3b;

alias Tag = size_t;

struct BasicBlock(T)
{
    alias BBSet = Set!(BasicBlock!T);

    private BBSet predecessors;
    private BBSet successors;
    T value;
    Tag tag;
    bool visited;
    static Tag global_tag;

    this(T value)
    {
        this.value = value;
        this.visited = false;
        this.tag = this.global_tag++;
    }

    void setTag(Tag tag)
    {
        this.tag = tag;
    }

    Tag getTag() const
    {
        return this.tag;
    }

    void insertSuccessor(BasicBlock!T successor)
    {
        this.successors ~= successor;
    }

    void insertPredecessor(BasicBlock!T predecessor)
    {
        this.predecessors ~= predecessor;
    }

    BBSet getNeighbors()
    {
        return this.successors + this.predecessors;
    }

    Tag toHash()
    {
        auto tag = this.tag;
        tag ^= tag >> 16;
        tag *= HASH_CONST;
        tag ^= tag >> 16;
        return tag;
    }

    bool opEquals(const BasicBlock!T rhs) const
    {
        return this.tag == rhs.tag;
    }

    void depthFirstSearch(F)(F processor)
    {
        foreach (ref neighbor; getNeighbors())
        {
            Stack!(BasicBlock!T) stack;
            neighbor.visited = true;

            stack.push(neighbor);
            while (!stack.isEmpty())
            {
                auto current = stack.pop();
                processor(current);

                foreach (ref neighbor_prime; current.getNeighbors())
                {
                    if (!neighbor_prime.visited)
                    {
                        neighbor_prime.visited = true;
                        stack.push(neighbor);
                    }
                }
            }

        }
    }

    void breadthFirstSearch(F)(F processor)
    {
        foreach (ref neighbor; getNeighbors())
        {
            Queue!(BasicBlock!T) queue;
            neighbor.visited = true;

            queue.enqueue(neighbor);
            while (!queue.isEmpty())
            {
                auto current = queue.dequeue();
                processor(current);
                foreach (ref neighbor_prime; neighbor.getNeighbors())
                {
                    if (!neighbor_prime.visited)
                    {
                        neighbor_prime.visited = true;
                        queue.enqueue(neighbor_prime);
                    }
                }

            }
        }
    }
}

class CFG(T)
{
    alias BBSet = Set!(BasicBlock!T);
    alias BBTable = BBSet*[BasicBlock!T];

    BasicBlock!T entry;
    BasicBlock!T exit;
    BBSet nodes;

    BBTable getAsTable()
    {
        BBTable table;
        nodes.iter!(x => table[x] = &this.nodes);
    }

    BBTable computeDominanceFrontiers()
    {
        auto out_values = getAsTable();
        out_values[this.entry] = Set(this.entry);

        bool changed = true;
        while (changed)
        {
            changed = false;

            foreach (node; this.nodes[])
            {
                if (node == this.entry)
                    continue;

                BBSet in_values;
                foreach (pred; node.predecessors)
                    in_values = in_values & out_values[pred];

                auto new_out = in_values + Set(node);

                if (new_out != out_values[node])
                {
                    out_values[node] = new_out;
                    changed = true;
                }

            }
        }

        return out_values;
    }
}
