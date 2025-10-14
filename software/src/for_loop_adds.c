#include <stddef.h>

void _start()
{
    int value1 = 4;
    int value2 = 12;

    for (size_t i = 0; i < 32; i++)
    {
        value2 += value1;
    }
}