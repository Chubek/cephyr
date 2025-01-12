module cephyr.set;

import std.typecons, std.algorithm, std.array, std.container, std.range;

class Set(T)
{
    alias opSlice = this.container.opSlice;

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

    void insert(T item)
    {
        this.container.insert(item);
        this.num_items++;
    }

    void concat(T[] items)
    {
        foreach (item; items)
            insert(item);
    }

    bool hasItem(T item)
    {
        foreach (elt; this.container[])
            if (elt == item)
                return true;
        return false;

    }

    Set!T unionWith(Set!T other)
    {
        Set!T set_union = new Set!T();
        other.iter!(x => set_union.insert(x));
        return set_union;
    }

    Set!T intersectWith(Set!T other)
    {
        auto common = other.filter!(x => hasItem(x));
        return new Set(common);
    }

    Set!T differenceWith(Set!T other)
    {
        auto uncommon = other.filter!(x => !hasItem(x));
        return new Set(uncommon);
    }

    Set!T opBinary(string op)(Set!T other) if (op == "+")
    {
        return unionWith(other);
    }

    Set!T opBinary(string op)(Set!T other) if (op == "&")
    {
        return intersectWith(other);
    }

    Set!T opBinary(string op)(Set!T other) if (op == "-")
    {
        return differenceWith(other);
    }

    Set!T opBinary(string op)(T item) if (op == "~")
    {
        insert(item);
        return this;
    }

    void opBinary(string op)(T item) if (op == "~=")
    {
        insert(item);
    }

    bool opEquals(const Set!T rhs) const
    {
        foreach (elt; this.container[])
        {
            foreach (elt_prime; rhs[])
            {
                if (elt != elt_prime)
                    return false;
            }
        }
        return true;
    }

}
