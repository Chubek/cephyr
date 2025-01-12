module cephyr.cfg;

import std.typecons, std.variant, std.sumtype, std.array, std.algorithm;

import cephyr.set;
import cephyr.stack;
import cephyr.queue;

alias Tag = int;

struct BasicBlock(T)
{
    alias BBSet = Set!(BasicBlock!T);

    private BBSet predecessors;
    private BBSet successors;
    T value;
    Tag tag;
    bool visited;

    this(T value)
    {
        this.value = value;
        this.visited = false;
        this.tag = -1;
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

    void depthFirstSearch(F)(F processor)
    {
        foreach (ref neighbor; getNeighbors())
        {
            if (neighbor.visited)
                continue;
            processor(neighbor);
            neighbor.visited = true;
            neighbor.depthFirstSearch(processor);
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
