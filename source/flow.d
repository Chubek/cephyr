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

    BBSet predecessors;
    BBSet successors;
    T value;
    Tag tag;
    bool visited;
    bool terminal;
    static Tag global_tag;

    this(T value, bool terminal)
    {
        this.value = value;
        this.visited = false;
        this.terminal = terminal;
        this.tag = this.global_tag++;
    }

    void resetVisited()
    {
        this.visited = false;
    }

    void setTag(Tag tag)
    {
        this.tag = tag;
    }

    Tag getTag() const
    {
        return this.tag;
    }

    void addSuccessor(BasicBlock!T successor)
    {
        this.successors ~= successor;
    }

    void addPredecessor(BasicBlock!T predecessor)
    {
        this.predecessors ~= predecessor;
    }

    BBSet getNeighbors()
    {
        return this.successors;
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
        foreach (ref neighbor; getNeighbors()[])
        {
            Stack!(BasicBlock!T) stack;
            neighbor.visited = true;

            stack.push(neighbor);
            while (!stack.isEmpty())
            {
                auto current = stack.pop();
                processor(current);

                foreach (ref neighbor_prime; current.getNeighbors()[])
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
        foreach (ref neighbor; getNeighbors()[])
        {
            Queue!(BasicBlock!T) queue;
            neighbor.visited = true;

            queue.enqueue(neighbor);
            while (!queue.isEmpty())
            {
                auto current = queue.dequeue();
                processor(current);
                foreach (ref neighbor_prime; neighbor.getNeighbors()[])
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
    alias DFST = Tag[][BasicBlock!T];

    BasicBlock!T entry;
    BasicBlock!T exit;
    BBSet nodes;

    this()
    {
        this.entry = BasicBlock(T.init, false);
        this.exit = BasicBlock(T.init, true);
        this.nodes = BBSet();
    }

    void addNode(BasicBlock!T node)
    {
        this.nodes ~= node;
    }

    void addEdge(BasicBlock!T from, BasicBlock!T to)
    {
        from.addSuccessor(to);
        to.addPredecessor(from);
        addNode(from);
    }

    void resetVisited()
    {
        this.nodes.iter!(x => x.resetVisited());
    }

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

    DFST computeDFST()
    {
        resetVisited();
        DFST dfst = null;
        foreach (node; this.nodes[])
        {
            auto tags = new Tag[];
            node.depthFirstSearch!(x => tags ~= x.getTag());
            dfst[node] = tags;
        }
        return dfst;
    }
}
