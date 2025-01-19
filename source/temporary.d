module cephyr.temporary;

import std.typecons, std.variant, std.sumtype, std.array, std.algorithm, std.conv;

import cephyr.stack;

alias Label = string;

class TemporaryManager
{
    static size_t counter;
    bool[Label] active_temps;
    Stack!Label free_list;

    static struct TemporaryInfo
    {
        string purpose;
        size_t scope_level;
        bool is_ssa;
    }

    TemporaryInfo[Label] temp_info;

    Label createTemporary(string purpose = "", bool is_ssa = false)
    {
        import std.format : format;

        Label name;
        if (!this.free_list.isEmpty())
            name = this.free_list.pop();
        else
            name = format("t%d", this.counter++);

        this.active_temps[name] = true;
        this.temp_info[name] = TemporaryInfo(purpose, getCurrentScopeLevel(), is_ssa);

        return name;
    }

    Label createSSATemporary(Label base_temp, size_t label_version)
    {
        import std.format : format;

        Label name = format("%s_%d", base_temp, label_version);
        this.active_temps[name] = true;
        this.temp_info[name] = TemporaryInfo("ssa_label_version", getCurrentScopeLevel(), true);
        return name;
    }

    void releaseTemporary(Label temp)
    {
        if (temp in this.active_temps)
        {
            this.active_temps.remove(temp);
            this.free_list.push(temp);
        }
    }

    bool isTemporary(Label name) const
    {
        return (name in this.active_temps) !is null;
    }

    bool isSSA(Label temp) const
    {
        if (auto info = temp in this.temp_info)
            return info.is_ssa;
        return false;
    }

    size_t getCurrentScopeLevel() const
    {
        // TODO
    }

}
