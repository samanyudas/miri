/* A harmless process that only sleeps. verify-miri copies it under another name, such as "yabai", so Miri's setup
 * check sees a competing window manager. Use it instead of a copy of an Apple binary: macOS kills a copied platform
 * binary at launch with exit status 137.
 * Usage: <name> [seconds], 600 seconds by default. */
#include <stdlib.h>
#include <unistd.h>

int main(int argc, char **argv) {
    sleep(argc > 1 ? (unsigned)atoi(argv[1]) : 600);
    return 0;
}
