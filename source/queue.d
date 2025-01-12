module cephyr.queue;

import std.typecons, std.container, std.array, std.algorithm, std.range;

struct Queue(T)
{
    alias opSlice = this.container.opSlice;

    DList!T container;
    size_t num_items;

    this(T[] initials)
    {
        foreach (initial; initials)
            container.insertFront(initial);
        this.num_items = initials.length;
    }

    this()
    {
        this.num_items = 0;
    }

    void iter(F)(F fn)
    {
        foreach (elt; this.container[])
            fn(elt);
    }

    T[] map(F)(F fn)
    {
        T[] result;
        foreach (elt; this.container[])
            result ~= fn(elt);
        return result;
    }

    T[] filter(F)(F fn)
    {
        T[] result;
        foreach (elt; this.container[])
            if (fn(elt))
                result ~= elt;
        return result;
    }

    T[] fold(F)(F fn, T[] initial)
    {
        T[] result = initial.dup;
        foreach (elt; this.container[])
            result ~= fn(elt);
        return result;
    }

    void enqueue(T item)
    {
        this.container.insertBack(item);
    }

    T dequeue()
    {
        auto front = this.container.front;
        this.container.removeFront();
        return front;
    }

    T peekFront()
    {
        return this.container.front;
    }

    bool isEmpty() const
    {
        return this.container.empty;
    }
}
