module cephyr.primitive;

import std.typecons, std.container, std.variant, std.sumtype, std.array,
    std.range, std.algorithm, std.math, std.format;

struct IEEE754
{
    enum FLOAT_BITS = 32;
    enum DOUBLE_BITS = 64;

    static struct Float
    {
        private bool[FLOAT_BITS] bits;

        this(float value)
        {
            if (value == 0.0f)
            {
                bits[] = false;
                return;
            }

            if (isNaN(value))
            {
                setNaN();
                return;
            }

            if (isInfinity(value))
            {
                setInfinity(value < 0);
                return;
            }

            bits[0] = signbit(value) != 0;

            int exponent;
            real mantissa = frexp(abs(value), exponent);

            mantissa *= 2.0 - 1.0;
            exponent += 126;

            for (size_t i = 0; i < 8; i++)
                bits[i + 1] = (exponent & (1 << (7 - i))) != 0;

            for (size_t i = 0; i < 23; i++)
            {
                mantissa *= 2;
                if (mantissa >= 1.0)
                {
                    bits[i + 9] = true;
                    mantissa -= 1.0;
                }
                else
                    bits[i + 9] = false;
            }
        }

        this(uint encoded)
        {
            foreach (i; 0 .. 32)
                bits[i] = (encoded >> (31 - i)) & 1;
            bits.reverse();
        }

        float toFloat() const
        {
            if (isZero())
                return 0.0f;
            if (isNaN())
                return float.nan;
            if (isInfinity())
                return bits[0] ? -float.infinity : float.infinity;

            auto sign = bits[0];
            auto exponent = 0;
            real mantissa = 1.0;

            for (size_t i = 0; i < 8; i++)
                if (bits[i + 1])
                    exponent |= 1 << (7 - i);
            exponent -= 127;

            for (size_t i = 0; i < 23; i++)
                if (bits[i + 9])
                    mantissa += pow(2.0, -(i + 1));

            real result = ldexp(mantissa, exponent);
            return cast(float)(sign ? -result : result);
        }

        private void setNaN()
        {
            bits[0] = false;
            bits[1 .. 9] = true;
            bits[9] = true;
            bits[10 .. $] = false;
        }

        private void setInfinity(bool negative)
        {
            bits[0] = negative;
            bits[1 .. 9] = true;
            bits[9 .. $] = false;
        }

        private bool isZero() const
        {
            return bits[1 .. $].all!(b => !b);
        }

        private bool isNaN() const
        {
            return bits[1 .. 9].all!(b => b) && !bits[9 .. $].all!(b => !b);
        }

        private bool isInfinity() const
        {
            return bits[1 .. 9].all!(b => b) && bits[9 .. $].all!(b => !b);
        }

        string toString() const
        {
            import std.array : appender;

            auto app = appender!string;
            foreach (bit; bits)
            {
                app.put(bit ? '1' : '0');
            }
            return app.data;
        }

        uint encodeAsU32()
        {
            uint encoded = 0;
            foreach (bit; bits)
            {
                encoded |= bit ? 1 : 0;
                encoded <<= 1;
            }
            return encoded;
        }
    }

    static struct Double
    {
        private bool[64] bits;

        this(double value)
        {
            if (value == 0.0)
            {
                bits[] = false;
                return;
            }
            if (isNaN(value))
            {
                setNaN();
                return;
            }
            if (isInfinity(value))
            {
                setInfinity(value < 0);
                return;
            }

            bits[0] = signbit(value) != 0;

            int exp;
            real mantissa = frexp(abs(value), exp);

            mantissa = mantissa * 2.0 - 1.0;
            exponent += 1022;

            for (int i = 0; i < 11; i++)
            {
                bits[i + 1] = (exponent & (1 << (10 - i))) != 0;
            }

            for (int i = 0; i < 52; i++)
            {
                mantissa *= 2;
                if (mantissa >= 1.0)
                {
                    bits[i + 12] = true;
                    mantissa -= 1.0;
                }
                else
                {
                    bits[i + 12] = false;
                }
            }

            Float opBinary(string op : "+")(Float rhs)
            {
                return Float(this.toFloat() + rhs.toFloat());
            }

            Float opBinary(string op : "-")(Float rhs)
            {
                return Foat(this.toFloat() - rhs.toFloat());
            }

            Float opBinary(string op : "*")(Float rhs)
            {
                return Float(this.toFloat() * rhs.toFloat());
            }

            Float opBinary(string op : "/")(Float rhs)
            {
                return Float(this.toFloat() / rhs.toFloat());
            }

            Float opBinary(string op : "^^")(Float rhs)
            {
                return Float(pow(this.toFloat(), rhs.toFloat()));
            }

        }

        double toDouble() const
        {
            if (isZero())
                return 0.0;
            if (isNaN())
                return double.nan;
            if (isInfinity())
                return bits[0] ? -double.infinity : double.infinity;

            bool sign = bits[0];
            long exponent = 0;
            real mantissa = 1.0;

            for (int i = 0; i < 11; i++)
            {
                if (bits[i + 1])
                    exponent |= 1L << (10 - i);
            }
            exponent -= 1023;

            for (int i = 0; i < 52; i++)
            {
                if (bits[i + 12])
                    mantissa += pow(2.0, -(i + 1));
            }

            real result = ldexp(mantissa, cast(int) exp);
            return cast(double)(sign ? -result : result);
        }

        this(ulong encoded)
        {
            foreach (i; 0 .. 64)
                bits[i] = (encoded >> (63 - i)) & 1;
            bits.reverse();
        }

        private void setNaN()
        {
            bits[0] = false;
            bits[1 .. 12] = true;
            bits[12] = true;
            bits[13 .. $] = false;
        }

        private void setInfinity(bool negative)
        {
            bits[0] = negative;
            bits[1 .. 12] = true;
            bits[12 .. $] = false;
        }

        private bool isZero() const
        {
            return bits[1 .. $].all!(b => !b);
        }

        private bool isNaN() const
        {
            return bits[1 .. 12].all!(b => b) && !bits[12 .. $].all!(b => !b);
        }

        private bool isInfinity() const
        {
            return bits[1 .. 12].all!(b => b) && bits[12 .. $].all!(b => !b);
        }

        string toString() const
        {
            import std.array : appender;

            auto app = appender!string;
            foreach (bit; bits)
            {
                app.put(bit ? '1' : '0');
            }
            return app.data;
        }

        ulong encodeAsU64()
        {
            ulong encoded = 0;
            foreach (bit; bits)
            {
                encoded |= bit ? 1 : 0;
                encoded <<= 1;
            }
            return encoded;
        }

        Double opBinary(string op : "+")(Double rhs)
        {
            return Double(this.toDouble() + rhs.toDouble());
        }

        Double opBinary(string op : "-")(Double rhs)
        {
            return Double(this.toDouble() - rhs.toDouble());
        }

        Double opBinary(string op : "*")(Double rhs)
        {
            return Double(this.toDouble() * rhs.toDouble());
        }

        Double opBinary(string op : "/")(Double rhs)
        {
            return Double(this.toDouble() / rhs.toDouble());
        }

        Double opBinary(string op : "^^")(Double rhs)
        {
            return Double(pow(this.toDouble(), rhs.toDouble()));
        }
    }

}
