#ifndef MEMORY_HPP
#define MEMORY_HPP

#include <cstddef>

size_t getCurrentRSS();
size_t getPeakRSS();
void trimWorkingSet();


#endif // MEMORY_HPP