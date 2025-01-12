module cephyr.stack;

import std.typecons, std.container, std.range, std.algorithm;

struct Stack(T)
{
    SList!T container;
    size_t num_items;

    this(T[] initials)
    {
        foreach (initial; initials)
            this.container.insert(initial);
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

    void push(T item)
    {
        this.container.insert(item);
    }

    T pop()
    {
        auto front = this.container.front;
        this.container.remove();
        return front;
    }

    T top()
    {
        return this.container.front;
    }
}
