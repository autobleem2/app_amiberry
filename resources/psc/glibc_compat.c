/* See glibc_compat.h. Linked into the console's program and each plugin; the rest of glibc is the console's. */
#define _GNU_SOURCE
#include "glibc_compat.h"
#include <errno.h>
#include <stdint.h>
#include <sys/syscall.h>
#include <unistd.h>

/* glibc 2.32: "the process has one thread" - 0 is always correct, it only costs the atomic reference counts
 * a single-threaded process could skip */
char __libc_single_threaded = 0;

/* glibc 2.25 (std::random_device): the kernel's getrandom, which the console's 4.4 kernel has */
int getentropy(void *buf, size_t len)
{
    unsigned char *p = buf;
    if (len > 256) {
        errno = EIO;
        return -1;
    }
    while (len) {
        long n = syscall(SYS_getrandom, p, len, 0);
        if (n < 0) {
            if (errno == EINTR)
                continue;
            return -1;
        }
        p += n;
        len -= (size_t)n;
    }
    return 0;
}

/* glibc 2.36 (std::random_device) */
uint32_t arc4random(void)
{
    uint32_t v = 0;
    getentropy(&v, sizeof v);
    return v;
}

/* glibc 2.30/2.31: a timed wait on a given clock, as the same wait on CLOCK_REALTIME */
static struct timespec to_realtime(clockid_t clock, const struct timespec *abs)
{
    struct timespec now_c, now_r, r;
    long long ns;
    if (clock == CLOCK_REALTIME)
        return *abs;
    clock_gettime(clock, &now_c);
    clock_gettime(CLOCK_REALTIME, &now_r);
    ns = (long long)(abs->tv_sec - now_c.tv_sec) * 1000000000LL + (abs->tv_nsec - now_c.tv_nsec);
    if (ns < 0)
        ns = 0;
    ns += now_r.tv_nsec;
    r.tv_sec = now_r.tv_sec + (time_t)(ns / 1000000000LL);
    r.tv_nsec = (long)(ns % 1000000000LL);
    return r;
}

int pthread_cond_clockwait(pthread_cond_t *c, pthread_mutex_t *m, clockid_t k, const struct timespec *t)
{
    struct timespec r = to_realtime(k, t);
    return pthread_cond_timedwait(c, m, &r);
}

int pthread_mutex_clocklock(pthread_mutex_t *m, clockid_t k, const struct timespec *t)
{
    struct timespec r = to_realtime(k, t);
    return pthread_mutex_timedlock(m, &r);
}

int pthread_rwlock_clockrdlock(pthread_rwlock_t *l, clockid_t k, const struct timespec *t)
{
    struct timespec r = to_realtime(k, t);
    return pthread_rwlock_timedrdlock(l, &r);
}

int pthread_rwlock_clockwrlock(pthread_rwlock_t *l, clockid_t k, const struct timespec *t)
{
    struct timespec r = to_realtime(k, t);
    return pthread_rwlock_timedwrlock(l, &r);
}

int sem_clockwait(sem_t *s, clockid_t k, const struct timespec *t)
{
    struct timespec r = to_realtime(k, t);
    return sem_timedwait(s, &r);
}
